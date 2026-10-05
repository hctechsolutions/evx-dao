// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import { IEvxAirdropDistributor } from "@evx-dao/interfaces/IEvxAirdropDistributor.sol";

/**
 * @title EvxAirdropDistributor
 * @notice Merkle claim distributor for EVX airdrop seasons (Uniswap-style).
 * @dev Compatible leaf packing: keccak256(abi.encodePacked(index, account, amount)).
 *      Immutables: token, merkleRoot, claimDeadline, distributionIdHash, totalAllocated, treasury.
 *      No setRoot / no Ownable root rotate (D19). No Pausable (D25: explicit no-pause).
 *      CEI + nonReentrant on claim/sweeps. Profile B sweeps: unclaimed then excess.
 */
contract EvxAirdropDistributor is IEvxAirdropDistributor, ReentrancyGuard {
    using SafeERC20 for IERC20;

    address public immutable override token;
    bytes32 public immutable override merkleRoot;
    uint256 public immutable override claimDeadline;
    bytes32 public immutable override distributionIdHash;
    uint256 public immutable override totalAllocated;
    address public immutable override treasury;

    /// @dev Sweep accumulator: sum of amounts paid via successful `claim`.
    ///      Platform economic SoT (D30) remains Σ allocation.amount where isClaimed(index);
    ///      this counter must stay ≤ totalAllocated and is used only for unclaimed = total − claimed.
    uint256 public override claimedAmount;

    /// @dev True after sweepUnclaimed — gates sweepExcess (D23).
    bool public override unclaimedSwept;

    /// @dev bitmap of claimed indices (Uniswap MerkleDistributor pattern)
    mapping(uint256 => uint256) private claimedBitMap;

    error AlreadyClaimed();
    error InvalidProof();
    error InvalidToken();
    error InvalidMerkleRoot();
    error InvalidDeadline();
    error InvalidTotalAllocated();
    error InvalidDistributionIdHash();
    error InvalidTreasury();
    error InvalidAmount();
    error InvalidAccount();
    error ExceedsTotalAllocated();
    error ClaimWindowClosed();
    error ClaimWindowOpen();
    error Unauthorized();
    error AlreadySwept();
    error UnclaimedNotSwept();
    error InsufficientBalanceForUnclaimed();

    constructor(
        address token_,
        bytes32 merkleRoot_,
        uint256 claimDeadline_,
        bytes32 distributionIdHash_,
        uint256 totalAllocated_,
        address treasury_
    ) {
        if (token_ == address(0)) revert InvalidToken();
        if (merkleRoot_ == bytes32(0)) revert InvalidMerkleRoot();
        if (claimDeadline_ <= block.timestamp || claimDeadline_ == type(uint256).max) {
            revert InvalidDeadline();
        }
        if (totalAllocated_ == 0) revert InvalidTotalAllocated();
        if (distributionIdHash_ == bytes32(0)) revert InvalidDistributionIdHash();
        if (treasury_ == address(0)) revert InvalidTreasury();

        token = token_;
        merkleRoot = merkleRoot_;
        claimDeadline = claimDeadline_;
        distributionIdHash = distributionIdHash_;
        totalAllocated = totalAllocated_;
        treasury = treasury_;

        emit DistributorInitialized(
            merkleRoot_,
            claimDeadline_,
            token_,
            distributionIdHash_,
            totalAllocated_,
            treasury_
        );
    }

    /// @inheritdoc IEvxAirdropDistributor
    function isClaimed(uint256 index) public view override returns (bool) {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        uint256 claimedWord = claimedBitMap[claimedWordIndex];
        uint256 mask = (1 << claimedBitIndex);
        return claimedWord & mask == mask;
    }

    function _setClaimed(uint256 index) private {
        uint256 claimedWordIndex = index / 256;
        uint256 claimedBitIndex = index % 256;
        claimedBitMap[claimedWordIndex] =
            claimedBitMap[claimedWordIndex] | (1 << claimedBitIndex);
    }

    /// @inheritdoc IEvxAirdropDistributor
    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external override nonReentrant {
        if (block.timestamp > claimDeadline) revert ClaimWindowClosed();
        if (account == address(0)) revert InvalidAccount();
        if (amount == 0) revert InvalidAmount();
        if (isClaimed(index)) revert AlreadyClaimed();
        if (claimedAmount + amount > totalAllocated) revert ExceedsTotalAllocated();

        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) {
            revert InvalidProof();
        }

        _setClaimed(index);
        claimedAmount += amount;
        IERC20(token).safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }

    /**
     * @notice After deadline, treasury sweeps unclaimed (= totalAllocated - claimedAmount).
     * @dev Invariant: balance >= unclaimed before; after, remaining is excess only (or 0).
     */
    function sweepUnclaimed(address to) external override nonReentrant {
        if (msg.sender != treasury) revert Unauthorized();
        if (to != treasury) revert InvalidTreasury();
        if (block.timestamp <= claimDeadline) revert ClaimWindowOpen();
        if (unclaimedSwept) revert AlreadySwept();

        uint256 unclaimed = totalAllocated - claimedAmount;
        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal < unclaimed) revert InsufficientBalanceForUnclaimed();

        unclaimedSwept = true;
        if (unclaimed > 0) {
            IERC20(token).safeTransfer(to, unclaimed);
        }
        emit UnclaimedSwept(to, unclaimed);
    }

    /**
     * @notice After unclaimed swept, treasury sweeps remaining excess balance.
     */
    function sweepExcess(address to) external override nonReentrant {
        if (msg.sender != treasury) revert Unauthorized();
        if (to != treasury) revert InvalidTreasury();
        if (!unclaimedSwept) revert UnclaimedNotSwept();

        uint256 bal = IERC20(token).balanceOf(address(this));
        if (bal > 0) {
            IERC20(token).safeTransfer(to, bal);
        }
        emit ExcessSwept(to, bal);
    }
}
