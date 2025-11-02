// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { ECDSA } from "@openzeppelin/contracts/utils/cryptography/ECDSA.sol";
import "@evx-dao/contracts/EvxToken.sol";

/**
 * @title EvxTokenTest
 * @dev Unit tests for the EvxToken contract.
 */
contract EvxTokenTest is Test {
    EvxToken public token;
    address public owner = address(1);
    address public user1 = address(0x123);
    address public user2 = address(0x456);

    /**
     * @dev Deploys the EvxToken contract before each test.
     */
    function setUp() public {
        token = new EvxToken(owner);
    }

    /**
     * @dev Verifies that the initial supply is minted to the owner.
     */
    function testInitialSupply() public view {
        uint256 expectedSupply = 100_000_000 * 10 ** token.decimals();
        assertEq(token.totalSupply(), expectedSupply);
        assertEq(token.balanceOf(owner), expectedSupply);
    }

    /**
     * @dev Checks the token's name and symbol.
     */
    function testNameSymbol() public view {
        assertEq(token.name(), "Evx Governance Token");
        assertEq(token.symbol(), "EVX");
    }

    /**
     * @dev Tests delegation of votes and verifies voting power equals balance.
     */
    function testDelegate() public {
        vm.prank(owner);
        token.delegate(owner);
        uint256 ownerVotes = token.getVotes(owner);
        uint256 ownerBalance = token.balanceOf(owner);
        assertEq(ownerVotes, ownerBalance);
    }

    /**
     * @dev Ensures transfers update voting power correctly after delegation.
     */
    function testTransferUpdatesVotes() public {
        // Owner delegates to self
        vm.prank(owner);
        token.delegate(owner);

        uint256 initialOwnerBalance = token.balanceOf(owner);
        uint256 initialUserBalance = token.balanceOf(user1);
        uint256 transferAmount = 1_000 * 10 ** token.decimals();

        vm.prank(owner);
        token.transfer(user1, transferAmount);

        uint256 finalOwnerBalance = token.balanceOf(owner);
        uint256 finalUserBalance = token.balanceOf(user1);
        uint256 finalOwnerVotes = token.getVotes(owner);

        assertEq(finalOwnerBalance, initialOwnerBalance - transferAmount);
        assertEq(finalUserBalance, initialUserBalance + transferAmount);
        assertEq(finalOwnerVotes, finalOwnerBalance);
    }

    /**
     * @dev Validates that the permit nonce starts at zero.
     */
    function testNonces() public view {
        uint256 initialNonce = token.nonces(owner);
        assertEq(initialNonce, 0);
    }

    /**
     * @notice Tests that recipients of transfers are automatically self-delegated.
     * @dev After transfer, the delegate and vote count for the recipient should reflect the amount received.
     */
    function testAutoDelegationOnTransfer() public {
        uint256 amount = 1000 * 1e18;
        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.delegates(user1), user1, "User1 should be self-delegated");
        assertEq(token.getVotes(user1), amount, "User1 voting power incorrect");
    }

    /**
     * @notice Tests vote updates when tokens move between accounts.
     * @dev Vote balances should decrease for sender and increase for receiver, with self-delegation.
     */
    function testVotesUpdateOnTransfer() public {
        uint256 amount = 500 * 1e18;
        vm.prank(owner);
        token.transfer(user1, amount);
        assertEq(token.getVotes(user1), amount, "User1 initial voting power incorrect");

        vm.prank(user1);
        token.transfer(user2, amount);

        assertEq(token.getVotes(user1), 0, "User1 should have lost voting power");
        assertEq(token.delegates(user2), user2, "User2 should be self-delegated");
        assertEq(token.getVotes(user2), amount, "User2 voting power incorrect");
    }
}
