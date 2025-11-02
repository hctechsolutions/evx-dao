// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { GovernorCountingOverridable } from "@openzeppelin/contracts/governance/extensions/GovernorCountingOverridable.sol";
import { GovernorVotesQuorumFraction } from "@openzeppelin/contracts/governance/extensions/GovernorVotesQuorumFraction.sol";
import { GovernorTimelockControl } from "@openzeppelin/contracts/governance/extensions/GovernorTimelockControl.sol";
import { GovernorVotes } from "@openzeppelin/contracts/governance/extensions/GovernorVotes.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { IGovernor } from "@openzeppelin/contracts/governance/IGovernor.sol";
import { IVotes } from "@openzeppelin/contracts/governance/utils/IVotes.sol";
import { Governor } from "@openzeppelin/contracts/governance/Governor.sol";

import { IEvxGovernance } from "@evx-dao/interfaces/IEvxGovernance.sol";
import { IEvxToken } from "@evx-dao/interfaces/IEvxToken.sol";

/**
 * @title Evx Governance DAO
 * @notice Core contract for Evx protocol governance, enabling proposal creation, voting, queuing and execution.
 * @dev Inherits OpenZeppelin's Governor with TimelockControl, Votes, CountingOverridable and QuorumFraction extensions.
 */
contract EvxGovernance is
    IEvxGovernance,
    Governor,
    GovernorTimelockControl,
    GovernorVotes,
    GovernorCountingOverridable,
    GovernorVotesQuorumFraction
{
    /// @inheritdoc IEvxGovernance
    IEvxToken public immutable evxToken;

    /**
     * @notice Initializes the Evx Governance DAO.
     * @param _token The governance token contract implementing IEvxToken.
     * @param _timelock The TimelockController enforcing execution delay before proposal execution.
     */
    constructor(IEvxToken _token, TimelockController _timelock)
        Governor("EVX Governance DAO")
        GovernorVotes(IVotes(address(_token)))
        GovernorTimelockControl(_timelock)
        GovernorCountingOverridable()
        GovernorVotesQuorumFraction(51)
    {
        evxToken = _token;
    }

    /**
     * @notice Cancels a proposal before execution.
     * @dev Resolves multiple inheritance conflicts by overriding the _cancel function.
     * @param targets The addresses of the contract calls.
     * @param values The ether values to be sent in the transactions.
     * @param calldatas The encoded function calls.
     * @param descriptionHash The keccak256 hash of the proposal description.
     * @return uint256 The proposal ID that was canceled.
     */
    function _cancel(
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint256) {
        return super._cancel(targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Returns the address of the executor responsible for executing proposals.
     * @dev Resolves multiple inheritance conflicts by overriding the _executor function.
     * @return address The executor's address.
     */
    function _executor() internal view override(Governor, GovernorTimelockControl) returns (address) {
        return super._executor();
    }

    /// @inheritdoc IEvxGovernance
    function state(uint256 proposalId)
        public
        view
        override(IEvxGovernance, Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @inheritdoc IEvxGovernance
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(IEvxGovernance, Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @inheritdoc IEvxGovernance
    function votingDelay() public pure override(IEvxGovernance, Governor) returns (uint256) {
        return 5760;
    }

    /// @inheritdoc IEvxGovernance
    function votingPeriod() public pure override(IEvxGovernance, Governor) returns (uint256) {
        return 40320;
    }

    /// @inheritdoc IEvxGovernance
    function quorum(uint256 blockNumber)
        public
        view
        override(IEvxGovernance, Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /// @inheritdoc IEvxGovernance
    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(IEvxGovernance, Governor)
        returns (uint256)
    {
        return evxToken.getPastVotes(account, blockNumber);
    }

    /// @inheritdoc IEvxGovernance
    function CLOCK_MODE() public pure override(IEvxGovernance, Governor, GovernorVotes) returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    /// @inheritdoc IEvxGovernance
    function clock() public view override(IEvxGovernance, Governor, GovernorVotes) returns (uint48) {
        return uint48(block.number);
    }

    /// @inheritdoc IEvxGovernance
    function COUNTING_MODE() 
        public 
        pure 
        override(IEvxGovernance, IGovernor, GovernorCountingOverridable) 
        returns (string memory) 
    {
        return "support=bravo&quorum=for,abstain";
    }

    /// @inheritdoc IEvxGovernance
    function hasVoted(uint256 proposalId, address account)
        public
        view
        override(IEvxGovernance, IGovernor, GovernorCountingOverridable)
        returns (bool)
    {
        return super.hasVoted(proposalId, account);
    }

    /**
     * @notice Executes the operations associated with a successful governance proposal.
     * @dev This function is called after a proposal passes and is scheduled for execution.
     * @param proposalId The unique identifier of the proposal.
     * @param targets The list of contract addresses that will receive transactions.
     * @param values The amounts of ETH to send with each transaction.
     * @param calldatas The calldata to execute on each target contract.
     * @param descriptionHash The keccak256 hash of the proposal description.
     */
    function _executeOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) {
        super._executeOperations(proposalId, targets, values, calldatas, descriptionHash);
    }

    /**
     * @notice Queues a governance proposal for execution.
     * @dev Once a proposal passes, it must be queued in the timelock before execution.
     * @param proposalId The unique identifier of the proposal.
     * @param targets The list of contract addresses that will receive transactions.
     * @param values The amounts of ETH to send with each transaction.
     * @param calldatas The calldata to execute on each target contract.
     * @param descriptionHash The keccak256 hash of the proposal description.
     * @return result The timestamp when the proposal will be executable.
     */
    function _queueOperations(
        uint256 proposalId,
        address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        bytes32 descriptionHash
    ) internal override(Governor, GovernorTimelockControl) returns (uint48 result) {
        return super._queueOperations(proposalId, targets, values, calldatas, descriptionHash);
    }
}
