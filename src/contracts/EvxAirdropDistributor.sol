// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { MerkleProof } from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import { IEvxAirdropDistributor } from "@evx-dao/interfaces/IEvxAirdropDistributor.sol";

/**
 * @title EvxAirdropDistributor
 * @notice Merkle claim distributor for EVX airdrop seasons (Uniswap-style).
 * @dev Compatible leaf packing: keccak256(abi.encodePacked(index, account, amount)).
 *      Integrity/ops (root rotate, deadline, sweep, pause) → Story 5.4.
 */
contract EvxAirdropDistributor is IEvxAirdropDistributor {
    using SafeERC20 for IERC20;

    address public immutable override token;
    bytes32 public immutable override merkleRoot;

    /// @dev bitmap of claimed indices (Uniswap MerkleDistributor pattern)
    mapping(uint256 => uint256) private claimedBitMap;

    error AlreadyClaimed();
    error InvalidProof();
    error InvalidToken();
    error InvalidMerkleRoot();

    constructor(address token_, bytes32 merkleRoot_) {
        if (token_ == address(0)) revert InvalidToken();
        if (merkleRoot_ == bytes32(0)) revert InvalidMerkleRoot();
        token = token_;
        merkleRoot = merkleRoot_;
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
    ) external override {
        if (isClaimed(index)) revert AlreadyClaimed();

        bytes32 node = keccak256(abi.encodePacked(index, account, amount));
        if (!MerkleProof.verify(merkleProof, merkleRoot, node)) {
            revert InvalidProof();
        }

        _setClaimed(index);
        IERC20(token).safeTransfer(account, amount);

        emit Claimed(index, account, amount);
    }
}
