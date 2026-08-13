// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxAirdropDistributor
 * @notice Uniswap MerkleDistributor–style retail claim + Story 5.4 integrity surface.
 * @dev Leaf = keccak256(abi.encodePacked(index, account, amount)).
 *      Profile B: treasury-gated sweepUnclaimed / sweepExcess after claimDeadline.
 *      No setRoot; no pause (D19/D25).
 */
interface IEvxAirdropDistributor {
    event Claimed(uint256 index, address account, uint256 amount);

    event DistributorInitialized(
        bytes32 merkleRoot,
        uint256 claimDeadline,
        address token,
        bytes32 distributionIdHash,
        uint256 totalAllocated,
        address treasury
    );

    event UnclaimedSwept(address to, uint256 amount);
    event ExcessSwept(address to, uint256 amount);

    function token() external view returns (address);

    function merkleRoot() external view returns (bytes32);

    function claimDeadline() external view returns (uint256);

    function distributionIdHash() external view returns (bytes32);

    function totalAllocated() external view returns (uint256);

    function claimedAmount() external view returns (uint256);

    function treasury() external view returns (address);

    function unclaimedSwept() external view returns (bool);

    function isClaimed(uint256 index) external view returns (bool);

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;

    function sweepUnclaimed(address to) external;

    function sweepExcess(address to) external;
}
