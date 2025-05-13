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

import { INebularGovernance } from "@nebular-dao/interfaces/INebularGovernance.sol";
import { INebularToken } from "@nebular-dao/interfaces/INebularToken.sol";

/**
 * @title Nebular Governance DAO
 * @notice Core contract for Nebular protocol governance, enabling proposal creation, voting, queuing and execution.
 * @dev Inherits OpenZeppelin's Governor with TimelockControl, Votes, CountingOverridable and QuorumFraction extensions.
 */
contract NebularGovernance is
    INebularGovernance,
    Governor,
    GovernorTimelockControl,
    GovernorVotes,
    GovernorCountingOverridable,
    GovernorVotesQuorumFraction
{
    /// @inheritdoc INebularGovernance
    INebularToken public immutable nebularToken;

    /**
     * @notice Initializes the Nebular Governance DAO.
     * @param _token The governance token contract implementing INebularToken.
     * @param _timelock The TimelockController enforcing execution delay before proposal execution.
     */
    constructor(INebularToken _token, TimelockController _timelock)
        Governor("NBL Governance DAO")
        GovernorVotes(IVotes(address(_token)))
        GovernorTimelockControl(_timelock)
        GovernorCountingOverridable()
        GovernorVotesQuorumFraction(51)
    {
        nebularToken = _token;
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

    /// @inheritdoc INebularGovernance
    function state(uint256 proposalId)
        public
        view
        override(INebularGovernance, Governor, GovernorTimelockControl)
        returns (ProposalState)
    {
        return super.state(proposalId);
    }

    /// @inheritdoc INebularGovernance
    function proposalNeedsQueuing(uint256 proposalId)
        public
        view
        override(INebularGovernance, Governor, GovernorTimelockControl)
        returns (bool)
    {
        return super.proposalNeedsQueuing(proposalId);
    }

    /// @inheritdoc INebularGovernance
    function votingDelay() public pure override(INebularGovernance, Governor) returns (uint256) {
        return 5760;
    }

    /// @inheritdoc INebularGovernance
    function votingPeriod() public pure override(INebularGovernance, Governor) returns (uint256) {
        return 40320;
    }

    /// @inheritdoc INebularGovernance
    function quorum(uint256 blockNumber)
        public
        view
        override(INebularGovernance, Governor, GovernorVotesQuorumFraction)
        returns (uint256)
    {
        return super.quorum(blockNumber);
    }

    /// @inheritdoc INebularGovernance
    function getVotes(address account, uint256 blockNumber)
        public
        view
        override(INebularGovernance, Governor)
        returns (uint256)
    {
        return nebularToken.getPastVotes(account, blockNumber);
    }

    /// @inheritdoc INebularGovernance
    function CLOCK_MODE() public pure override(INebularGovernance, Governor, GovernorVotes) returns (string memory) {
        return "mode=blocknumber&from=default";
    }

    /// @inheritdoc INebularGovernance
    function clock() public view override(INebularGovernance, Governor, GovernorVotes) returns (uint48) {
        return uint48(block.number);
    }

    /// @inheritdoc INebularGovernance
    function COUNTING_MODE() 
        public 
        pure 
        override(INebularGovernance, IGovernor, GovernorCountingOverridable) 
        returns (string memory) 
    {
        return "support=bravo&quorum=for,abstain";
    }

    /// @inheritdoc INebularGovernance
    function hasVoted(uint256 proposalId, address account)
        public
        view
        override(INebularGovernance, IGovernor, GovernorCountingOverridable)
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
