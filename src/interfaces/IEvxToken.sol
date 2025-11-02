// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/**
 * @title IEvxToken
 * @notice Interface for the Evx token contract with voting and permit capabilities.
 */
interface IEvxToken {
    /**
     * @notice Emitted when an account is automatically self-delegated upon first token receipt.
     * @param account The address that was auto-delegated.
     */
    event AutoDelegated(address indexed account);

    /**
     * @notice Returns the current nonce for an owner, required for permit signatures.
     * @param owner The address to query.
     * @return The next valid nonce for the owner.
     */
    function nonces(address owner) external view returns (uint256);

    /**
     * @notice Returns the past voting power of an account at a specific block number.
     * @param account The address of the token holder.
     * @param blockNumber The block number at which to retrieve the voting power.
     * @return The voting power of the account at the given block.
     */
    function getPastVotes(address account, uint256 blockNumber) external view returns (uint256);
}
