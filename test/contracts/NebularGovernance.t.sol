// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/governance/extensions/GovernorCountingSimple.sol";
import "@openzeppelin/contracts/governance/TimelockController.sol";
import "@openzeppelin/contracts/governance/IGovernor.sol";
import "forge-std/Test.sol";

import "@nebular/contracts/NebularGovernance.sol";
import "@nebular/contracts/NebularToken.sol";


/**
 * @title NebularGovernanceTest
 * @dev Unit tests for the NebularGovernance contract.
 */
contract NebularGovernanceTest is Test {
    NebularGovernance public dao;
    NebularToken public token;
    TimelockController public timelock;

    address public constant ADMIN = address(1);
    address public constant VOTER1 = address(2);
    address public constant VOTER2 = address(3);
    address public constant OWNER = address(4);

    uint256 public constant VOTING_DELAY = 5760;
    uint256 public constant VOTING_PERIOD = 40320;
    uint256 public constant QUORUM_PERCENT = 51; // 51%

    event ProposalCreated(
        uint256 proposalId, address proposer, address[] targets, uint256[] values, bytes[] calldatas, string description
    );

    /**
     * @dev Sets up the environment by deploying the token, timelock, and DAO,
     *      and configuring token transfers, delegation, and timelock roles.
     */
    function setUp() public {
        // Deploy Governance Token
        token = new NebularToken(ADMIN);

        // Transfer tokens from ADMIN to voters
        vm.startPrank(ADMIN);
        token.transfer(VOTER1, 40_000_000e18);
        token.transfer(VOTER2, 40_000_000e18);
        vm.stopPrank();

        // Delegate votes for voters
        vm.prank(VOTER1);
        token.delegate(VOTER1);
        vm.prank(VOTER2);
        token.delegate(VOTER2);

        // Deploy Timelock
        address[] memory proposers = new address[](1);
        proposers[0] = address(this);
        address[] memory executors = new address[](1);
        executors[0] = address(0);
        timelock = new TimelockController(1 days, proposers, executors, ADMIN);

        // Deploy DAO
        dao = new NebularGovernance(token, timelock);

        // Set timelock roles using ADMIN
        vm.startPrank(ADMIN);
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(dao));
        vm.stopPrank();
    }

    /**
     * @dev Tests the initial configuration of the NebularGovernance.
     */
    function testInitialization() public view {
        assertEq(dao.name(), "NBL Governance DAO");
        assertEq(dao.votingDelay(), VOTING_DELAY);
        assertEq(dao.votingPeriod(), VOTING_PERIOD);
        assertEq(dao.quorumNumerator(), QUORUM_PERCENT);
        assertEq(address(dao.nebularToken()), address(token));
    }

    /**
     * @dev Tests the full proposal lifecycle: creation, voting, queuing, and execution.
     */
    function testProposalLifecycle() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0x123);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("release()");
        string memory description = "Test Proposal";
        bytes32 descriptionHash = keccak256(bytes(description));
        
        // Create proposal as VOTER1
        vm.prank(VOTER1);
        uint256 proposalId = dao.propose(targets, values, calldatas, description);

        // Check initial state (Pending)
        assertEq(uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Pending));

        // Advance to voting period
        vm.roll(block.number + VOTING_DELAY + 1);
        assertEq(uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Active));

        // Cast votes
        vm.prank(VOTER1);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));
        vm.prank(VOTER2);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));

        // Verify vote count
        (, uint256 forVotes,) = dao.proposalVotes(proposalId);
        assertEq(forVotes, token.getPastVotes(VOTER1, block.number - 1) + token.getPastVotes(VOTER2, block.number - 1));

        // Finalize voting
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded));

        // Queue the proposal
        dao.queue(targets, values, calldatas, descriptionHash);
        assertEq(uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Queued), "Should be Queued");

        // Execute after timelock delay
        vm.warp(block.timestamp + 1 days + 1);
        dao.execute(targets, values, calldatas, descriptionHash);
        assertEq(uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Executed), "Should be Executed");
    }

    /**
     * @dev Tests that executing a proposal without queuing reverts.
     */
    function testCannotExecuteWithoutQueue() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0x123);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("dummy()");
        string memory description = "Test Proposal";
        bytes32 descriptionHash = keccak256(bytes(description));

        // Create proposal as VOTER1
        vm.prank(VOTER1);
        uint256 proposalId = dao.propose(targets, values, calldatas, description);

        // Advance to voting period
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast votes
        vm.prank(VOTER1);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));
        vm.prank(VOTER2);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));

        // Finalize voting
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(
            uint256(dao.state(proposalId)), uint256(IGovernor.ProposalState.Succeeded), "Proposal should be Succeeded"
        );

        // Attempt to execute without queueing
        vm.expectRevert();
        dao.execute(targets, values, calldatas, descriptionHash);
    }

    /**
     * @dev Tests the quorum calculation based on the token total supply.
     */
    function testQuorumCalculation() public {
        vm.roll(block.number + 1);
        uint256 totalSupply = token.getPastTotalSupply(block.number - 1);
        uint256 expectedQuorum = (totalSupply * QUORUM_PERCENT) / 100;
        assertEq(dao.quorum(block.number - 1), expectedQuorum, "Incorrect quorum calculation");
    }

    /**
     * @dev Tests vote counting with different vote types.
     */
    function testVoteCounting() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0x123);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("dummy()");
        string memory description = "Test Proposal";

        vm.prank(VOTER1);
        uint256 proposalId = dao.propose(targets, values, calldatas, description);
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast different vote types
        vm.prank(VOTER1);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));
        vm.prank(VOTER2);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.Against));

        (uint256 againstVotes, uint256 forVotes,) = dao.proposalVotes(proposalId);
        assertEq(forVotes, token.getPastVotes(VOTER1, block.number - 1), "Incorrect For votes");
        assertEq(againstVotes, token.getPastVotes(VOTER2, block.number - 1), "Incorrect Against votes");
    }

    /**
     * @dev Tests timelock integration by checking role assignments.
     */
    function testTimelockIntegration() public view {
        bytes32 proposerRole = timelock.PROPOSER_ROLE();
        bytes32 executorRole = timelock.EXECUTOR_ROLE();
        assertTrue(timelock.hasRole(proposerRole, address(dao)));
        assertTrue(timelock.hasRole(executorRole, address(dao)));
    }

    /**
     * @dev Tests that a proposal fails if the quorum is not met.
     */
    function testProposalFailsWithoutQuorum() public {
        address[] memory targets = new address[](1);
        targets[0] = address(0x123);
        uint256[] memory values = new uint256[](1);
        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encodeWithSignature("dummy()");

        // Create proposal as VOTER1
        vm.prank(VOTER1);
        uint256 proposalId = dao.propose(targets, values, calldatas, "Test Proposal");

        // Advance to voting period
        vm.roll(block.number + VOTING_DELAY + 1);

        // Cast vote only from VOTER1 (insufficient quorum)
        vm.prank(VOTER1);
        dao.castVote(proposalId, uint8(GovernorCountingSimple.VoteType.For));

        // Finalize voting
        vm.roll(block.number + VOTING_PERIOD + 1);
        assertEq(
            uint256(dao.state(proposalId)),
            uint256(IGovernor.ProposalState.Defeated),
            "Should fail due to insufficient quorum"
        );
    }
}
