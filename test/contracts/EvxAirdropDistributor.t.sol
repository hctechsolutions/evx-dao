// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { EvxToken } from "@evx-dao/contracts/EvxToken.sol";
import { EvxAirdropDistributor } from "@evx-dao/contracts/EvxAirdropDistributor.sol";

/**
 * @title EvxAirdropDistributorTest
 * @dev Foundry tests: happy path, already claimed, invalid proof, wrong account.
 */
contract EvxAirdropDistributorTest is Test {
    EvxToken public token;
    EvxAirdropDistributor public distributor;

    address public owner = address(0xA11CE);
    address public eligible = address(0xE1E61);
    address public other = address(0xB0B);

    uint256 public constant INDEX = 0;
    uint256 public constant AMOUNT = 100 ether;

    bytes32 public leaf;
    bytes32 public merkleRoot;
    bytes32[] public proof; // empty — single-leaf tree (root == leaf)

    event Claimed(uint256 index, address account, uint256 amount);

    function setUp() public {
        token = new EvxToken(owner);

        leaf = keccak256(abi.encodePacked(INDEX, eligible, AMOUNT));
        merkleRoot = leaf;

        distributor = new EvxAirdropDistributor(address(token), merkleRoot);

        vm.prank(owner);
        token.transfer(address(distributor), AMOUNT);
    }

    function testClaimHappyPath() public {
        assertFalse(distributor.isClaimed(INDEX));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(INDEX, eligible, AMOUNT);

        distributor.claim(INDEX, eligible, AMOUNT, proof);

        assertTrue(distributor.isClaimed(INDEX));
        assertEq(token.balanceOf(eligible), AMOUNT);
        assertEq(token.balanceOf(address(distributor)), 0);
    }

    function testAlreadyClaimed() public {
        distributor.claim(INDEX, eligible, AMOUNT, proof);

        vm.expectRevert(EvxAirdropDistributor.AlreadyClaimed.selector);
        distributor.claim(INDEX, eligible, AMOUNT, proof);
    }

    function testInvalidProof() public {
        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = bytes32(uint256(0xdead));

        // Rebuild distributor with a two-node root so empty proof is invalid
        bytes32 sibling = keccak256(abi.encodePacked(uint256(1), other, AMOUNT));
        bytes32 root = _hashPair(leaf, sibling);
        EvxAirdropDistributor dist2 = new EvxAirdropDistributor(address(token), root);

        vm.prank(owner);
        token.transfer(address(dist2), AMOUNT);

        // Wrong sibling → invalid
        vm.expectRevert(EvxAirdropDistributor.InvalidProof.selector);
        dist2.claim(INDEX, eligible, AMOUNT, badProof);
    }

    function testWrongAccount() public {
        // Same index/amount leaf was built for `eligible`; claiming for `other` fails
        vm.expectRevert(EvxAirdropDistributor.InvalidProof.selector);
        distributor.claim(INDEX, other, AMOUNT, proof);
    }

    function testRejectZeroToken() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidToken.selector);
        new EvxAirdropDistributor(address(0), merkleRoot);
    }

    function testRejectZeroRoot() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidMerkleRoot.selector);
        new EvxAirdropDistributor(address(token), bytes32(0));
    }

    /// @dev Matches Platform seed shape: 2-leaf sorted tree with sibling proofs.
    function testClaimTwoLeafTree() public {
        address account0 = address(0x1111111111111111111111111111111111111111);
        address account1 = address(0x2222222222222222222222222222222222222222);
        uint256 amount0 = 100 ether;
        uint256 amount1 = 50 ether;

        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(0), account0, amount0));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(1), account1, amount1));
        bytes32 root = _hashPair(leaf0, leaf1);

        EvxAirdropDistributor dist2 = new EvxAirdropDistributor(address(token), root);
        vm.prank(owner);
        token.transfer(address(dist2), amount0 + amount1);

        bytes32[] memory proof0 = new bytes32[](1);
        proof0[0] = leaf1;
        dist2.claim(0, account0, amount0, proof0);
        assertTrue(dist2.isClaimed(0));
        assertEq(token.balanceOf(account0), amount0);

        bytes32[] memory proof1 = new bytes32[](1);
        proof1[0] = leaf0;
        dist2.claim(1, account1, amount1, proof1);
        assertTrue(dist2.isClaimed(1));
        assertEq(token.balanceOf(account1), amount1);
        assertEq(token.balanceOf(address(dist2)), 0);
    }

    function testTokenAndRootGetters() public view {
        assertEq(distributor.token(), address(token));
        assertEq(distributor.merkleRoot(), merkleRoot);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }
}
