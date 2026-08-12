// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxAirdropDistributor
 * @notice Uniswap MerkleDistributor–style retail claim surface (Story 5.3 / D11).
 * @dev Leaf = keccak256(abi.encodePacked(index, account, amount)).
 */
interface IEvxAirdropDistributor {
    event Claimed(uint256 index, address account, uint256 amount);

    function token() external view returns (address);

    function merkleRoot() external view returns (bytes32);

    function isClaimed(uint256 index) external view returns (bool);

    function claim(
        uint256 index,
        address account,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external;
}
