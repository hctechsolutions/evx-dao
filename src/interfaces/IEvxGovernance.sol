// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IEvxToken } from "@evx-dao/interfaces/IEvxToken.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";

/*
 * @title Interface for Evx Governance
 * @notice Defines the external API of the IEvxGovernance contract
 */
interface IEvxGovernance is IGovernor {
    /**
     * @notice Returns the governance token used for voting.
     * @return The IEvxToken contract address.
     */
    function evxToken() external view returns (IEvxToken);

    /**
     * @notice Checks if a proposal needs queuing before execution.
     * @param proposalId The unique proposal identifier.
     * @return True if the proposal requires queuing.
     */
    function proposalNeedsQueuing(uint256 proposalId) external view returns (bool);

    /**
     * @notice Returns the required voting delay before voting starts.
     * @return The number of blocks for the voting delay.
     */
    function votingDelay() external view returns (uint256);

    /**
     * @notice Returns the duration of the voting period.
     * @return The number of blocks voting remains open.
     */
    function votingPeriod() external view returns (uint256);

    /**
     * @notice Returns the required quorum for a given block.
     * @param blockNumber The block number for quorum calculation.
     * @return The quorum value at the specified block.
     */
    function quorum(uint256 blockNumber) external view returns (uint256);

    /**
     * @notice Retrieves past voting power of an account.
     * @param account The address of the voter.
     * @param blockNumber The block number at which to retrieve votes.
     * @return The voting power at the given block.
     */
    function getVotes(address account, uint256 blockNumber) external view returns (uint256);

    /**
     * @notice Returns the clock mode used by the governor.
     * @return A string identifying the clock mode.
     */
    function CLOCK_MODE() external view returns (string memory);

    /**
     * @notice Returns the current clock value (block number).
     * @return The block number used as clock.
     */
    function clock() external view returns (uint48);

    /**
     * @notice Returns the counting mode used by the governor.
     * @return A string identifying the counting mode.
     */
    function COUNTING_MODE() external view returns (string memory);

    /**
     * @notice Checks if an account has voted on a proposal.
     * @param proposalId The unique proposal identifier.
     * @param account The address of the voter.
     * @return True if the account has voted.
     */
    function hasVoted(uint256 proposalId, address account) external view returns (bool);

    /**
    * @notice Retrieves the current state of a governance proposal.
    * @param proposalId The unique identifier of the proposal.
    * @return proposalState The state of the proposal (e.g., Pending, Active, Canceled, etc.).
    */
    function state(uint256 proposalId) external view returns (ProposalState proposalState);
}