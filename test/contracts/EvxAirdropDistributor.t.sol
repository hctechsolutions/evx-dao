// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import { EvxToken } from "@evx-dao/contracts/EvxToken.sol";
import { EvxAirdropDistributor } from "@evx-dao/contracts/EvxAirdropDistributor.sol";

/**
 * @title EvxAirdropDistributorTest
 * @dev Story 5.3 claim paths + Story 5.4 deadline/sweep/threat model.
 */
contract EvxAirdropDistributorTest is Test {
    EvxToken public token;
    EvxAirdropDistributor public distributor;

    address public owner = address(0xA11CE);
    address public treasury = address(0x7E45);
    address public eligible = address(0xE1E61);
    address public other = address(0xB0B);

    uint256 public constant INDEX = 0;
    uint256 public constant AMOUNT = 100 ether;
    uint256 public constant TOTAL = AMOUNT;
    bytes32 public constant DIST_ID_HASH = bytes32(uint256(0xD15));

    bytes32 public leaf;
    bytes32 public merkleRoot;
    bytes32[] public proof; // empty — single-leaf tree (root == leaf)
    uint256 public deadline;

    event Claimed(uint256 index, address account, uint256 amount);
    event UnclaimedSwept(address to, uint256 amount);
    event ExcessSwept(address to, uint256 amount);

    function setUp() public {
        token = new EvxToken(owner);
        deadline = block.timestamp + 30 days;

        leaf = keccak256(abi.encodePacked(INDEX, eligible, AMOUNT));
        merkleRoot = leaf;

        distributor = new EvxAirdropDistributor(
            address(token),
            merkleRoot,
            deadline,
            DIST_ID_HASH,
            TOTAL,
            treasury
        );

        vm.prank(owner);
        token.transfer(address(distributor), AMOUNT);
    }

    function _deploy(
        bytes32 root,
        uint256 total,
        uint256 fund
    ) internal returns (EvxAirdropDistributor) {
        EvxAirdropDistributor d = new EvxAirdropDistributor(
            address(token),
            root,
            deadline,
            DIST_ID_HASH,
            total,
            treasury
        );
        if (fund > 0) {
            vm.prank(owner);
            token.transfer(address(d), fund);
        }
        return d;
    }

    function testClaimHappyPath() public {
        assertFalse(distributor.isClaimed(INDEX));

        vm.expectEmit(true, true, true, true, address(distributor));
        emit Claimed(INDEX, eligible, AMOUNT);

        distributor.claim(INDEX, eligible, AMOUNT, proof);

        assertTrue(distributor.isClaimed(INDEX));
        assertEq(token.balanceOf(eligible), AMOUNT);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(distributor.claimedAmount(), AMOUNT);
    }

    function testAlreadyClaimed() public {
        distributor.claim(INDEX, eligible, AMOUNT, proof);

        vm.expectRevert(EvxAirdropDistributor.AlreadyClaimed.selector);
        distributor.claim(INDEX, eligible, AMOUNT, proof);
    }

    function testInvalidProof() public {
        bytes32[] memory badProof = new bytes32[](1);
        badProof[0] = bytes32(uint256(0xdead));

        bytes32 sibling = keccak256(abi.encodePacked(uint256(1), other, AMOUNT));
        bytes32 root = _hashPair(leaf, sibling);
        EvxAirdropDistributor dist2 = _deploy(root, AMOUNT, AMOUNT);

        vm.expectRevert(EvxAirdropDistributor.InvalidProof.selector);
        dist2.claim(INDEX, eligible, AMOUNT, badProof);
    }

    function testWrongAccount() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidProof.selector);
        distributor.claim(INDEX, other, AMOUNT, proof);
    }

    function testZeroAmount() public {
        // Zero amount cannot match a non-zero leaf; also explicit InvalidAmount if proof somehow matched.
        // Build a tree whose leaf is zero amount for eligible — claim must still reject amount==0.
        bytes32 zeroLeaf = keccak256(abi.encodePacked(INDEX, eligible, uint256(0)));
        EvxAirdropDistributor dist0 = new EvxAirdropDistributor(
            address(token),
            zeroLeaf,
            deadline,
            DIST_ID_HASH,
            1, // totalAllocated must be > 0
            treasury
        );
        vm.expectRevert(EvxAirdropDistributor.InvalidAmount.selector);
        dist0.claim(INDEX, eligible, 0, proof);
    }

    function testZeroAccount() public {
        bytes32 zeroLeaf = keccak256(abi.encodePacked(INDEX, address(0), AMOUNT));
        EvxAirdropDistributor dist0 = _deploy(zeroLeaf, TOTAL, TOTAL);
        vm.expectRevert(EvxAirdropDistributor.InvalidAccount.selector);
        dist0.claim(INDEX, address(0), AMOUNT, proof);
    }

    function testClaimAfterDeadline() public {
        vm.warp(deadline + 1);
        vm.expectRevert(EvxAirdropDistributor.ClaimWindowClosed.selector);
        distributor.claim(INDEX, eligible, AMOUNT, proof);
    }

    function testRejectZeroToken() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidToken.selector);
        new EvxAirdropDistributor(
            address(0), merkleRoot, deadline, DIST_ID_HASH, TOTAL, treasury
        );
    }

    function testRejectZeroRoot() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidMerkleRoot.selector);
        new EvxAirdropDistributor(
            address(token), bytes32(0), deadline, DIST_ID_HASH, TOTAL, treasury
        );
    }

    function testRejectPastDeadline() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidDeadline.selector);
        new EvxAirdropDistributor(
            address(token), merkleRoot, block.timestamp, DIST_ID_HASH, TOTAL, treasury
        );
    }

    function testRejectMaxDeadline() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidDeadline.selector);
        new EvxAirdropDistributor(
            address(token), merkleRoot, type(uint256).max, DIST_ID_HASH, TOTAL, treasury
        );
    }

    function testRejectZeroTotalAllocated() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidTotalAllocated.selector);
        new EvxAirdropDistributor(
            address(token), merkleRoot, deadline, DIST_ID_HASH, 0, treasury
        );
    }

    function testRejectZeroTreasury() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidTreasury.selector);
        new EvxAirdropDistributor(
            address(token), merkleRoot, deadline, DIST_ID_HASH, TOTAL, address(0)
        );
    }

    /// @dev Matches Platform / leaf-golden.json: 2-leaf sorted tree (Season-1 Sepolia EOAs).
    function testClaimTwoLeafTreeGolden() public {
        address account0 = address(0x07c072E0EDAB5b6180534dbE6c3bD86BC9901126);
        address account1 = address(0xDf961CEe234af74b6Ac4D644736B325eE7391416);
        uint256 amount0 = 100 ether;
        uint256 amount1 = 50 ether;
        uint256 total = amount0 + amount1;

        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(0), account0, amount0));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(1), account1, amount1));
        bytes32 root = _hashPair(leaf0, leaf1);

        // Golden root from leaf-golden.json
        assertEq(
            root,
            bytes32(0x799e3b776fdc5153c4862cf341203fe068e4c494e83e553d610caa1288c2c9f8)
        );
        assertEq(
            leaf0,
            bytes32(0xdc9db32201433ba984c3d0b599c61711c3f920b722c65fdc0684654d8bc286cf)
        );
        assertEq(
            leaf1,
            bytes32(0x80eb3c7c4df5d5990fdd36fd5ec0a719c92e9651ff266fb91750e5b877025ae1)
        );

        EvxAirdropDistributor dist2 = _deploy(root, total, total);

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
        assertEq(dist2.claimedAmount(), total);
    }

    function testSweepUnclaimedAfterDeadline() public {
        // Partial claim then deadline → sweep unclaimed
        distributor.claim(INDEX, eligible, AMOUNT, proof);
        // claimed all — unclaimed = 0; fund excess separately
        vm.prank(owner);
        token.transfer(address(distributor), 25 ether);

        vm.warp(deadline + 1);
        vm.prank(treasury);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit UnclaimedSwept(treasury, 0);
        distributor.sweepUnclaimed(treasury);

        assertTrue(distributor.unclaimedSwept());
        assertEq(token.balanceOf(address(distributor)), 25 ether);

        vm.prank(treasury);
        vm.expectEmit(true, true, true, true, address(distributor));
        emit ExcessSwept(treasury, 25 ether);
        distributor.sweepExcess(treasury);
        assertEq(token.balanceOf(address(distributor)), 0);
        assertEq(token.balanceOf(treasury), 25 ether);
    }

    function testSweepUnclaimedPartialClaims() public {
        address account0 = address(0x1111111111111111111111111111111111111111);
        address account1 = address(0x2222222222222222222222222222222222222222);
        uint256 amount0 = 100 ether;
        uint256 amount1 = 50 ether;
        uint256 total = amount0 + amount1;

        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(0), account0, amount0));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(1), account1, amount1));
        bytes32 root = _hashPair(leaf0, leaf1);
        EvxAirdropDistributor dist2 = _deploy(root, total, total);

        bytes32[] memory proof0 = new bytes32[](1);
        proof0[0] = leaf1;
        dist2.claim(0, account0, amount0, proof0);

        vm.warp(deadline + 1);
        uint256 unclaimed = amount1;
        assertEq(token.balanceOf(address(dist2)), unclaimed);

        vm.prank(treasury);
        dist2.sweepUnclaimed(treasury);
        assertEq(token.balanceOf(treasury), unclaimed);
        assertEq(token.balanceOf(address(dist2)), 0);
        assertTrue(dist2.unclaimedSwept());
    }

    /// @dev AC5/Inv14: after partial claim + excess funding, sweepUnclaimed leaves only excess.
    function testSweepUnclaimedLeavesExcessOnly() public {
        address account0 = address(0x1111111111111111111111111111111111111111);
        address account1 = address(0x2222222222222222222222222222222222222222);
        uint256 amount0 = 100 ether;
        uint256 amount1 = 50 ether;
        uint256 total = amount0 + amount1;
        uint256 excess = 25 ether;

        bytes32 leaf0 = keccak256(abi.encodePacked(uint256(0), account0, amount0));
        bytes32 leaf1 = keccak256(abi.encodePacked(uint256(1), account1, amount1));
        bytes32 root = _hashPair(leaf0, leaf1);
        EvxAirdropDistributor dist2 = _deploy(root, total, total + excess);

        bytes32[] memory proof0 = new bytes32[](1);
        proof0[0] = leaf1;
        dist2.claim(0, account0, amount0, proof0);

        assertEq(token.balanceOf(address(dist2)), amount1 + excess);

        vm.warp(deadline + 1);
        vm.prank(treasury);
        dist2.sweepUnclaimed(treasury);

        assertEq(token.balanceOf(treasury), amount1);
        assertEq(token.balanceOf(address(dist2)), excess);
        assertTrue(dist2.unclaimedSwept());

        vm.prank(treasury);
        dist2.sweepExcess(treasury);
        assertEq(token.balanceOf(address(dist2)), 0);
        assertEq(token.balanceOf(treasury), amount1 + excess);
    }

    function testSweepUnclaimedBeforeDeadlineReverts() public {
        vm.prank(treasury);
        vm.expectRevert(EvxAirdropDistributor.ClaimWindowOpen.selector);
        distributor.sweepUnclaimed(treasury);
    }

    function testSweepExcessBeforeUnclaimedReverts() public {
        vm.warp(deadline + 1);
        vm.prank(treasury);
        vm.expectRevert(EvxAirdropDistributor.UnclaimedNotSwept.selector);
        distributor.sweepExcess(treasury);
    }

    function testSweepUnauthorized() public {
        vm.warp(deadline + 1);
        vm.prank(other);
        vm.expectRevert(EvxAirdropDistributor.Unauthorized.selector);
        distributor.sweepUnclaimed(treasury);
    }

    function testSweepToNonTreasuryReverts() public {
        vm.warp(deadline + 1);
        vm.prank(treasury);
        vm.expectRevert(EvxAirdropDistributor.InvalidTreasury.selector);
        distributor.sweepUnclaimed(other);
    }

    function testInsufficientBalanceForUnclaimed() public {
        // Fund below totalAllocated; no claims → unclaimed cannot be swept
        EvxAirdropDistributor under = _deploy(merkleRoot, TOTAL, TOTAL / 2);
        vm.warp(deadline + 1);
        vm.prank(treasury);
        vm.expectRevert(EvxAirdropDistributor.InsufficientBalanceForUnclaimed.selector);
        under.sweepUnclaimed(treasury);
    }

    function testAlreadySwept() public {
        vm.warp(deadline + 1);
        vm.prank(treasury);
        distributor.sweepUnclaimed(treasury);
        vm.prank(treasury);
        vm.expectRevert(EvxAirdropDistributor.AlreadySwept.selector);
        distributor.sweepUnclaimed(treasury);
    }

    function testSweepExcessUnauthorized() public {
        vm.warp(deadline + 1);
        vm.prank(treasury);
        distributor.sweepUnclaimed(treasury);
        vm.prank(other);
        vm.expectRevert(EvxAirdropDistributor.Unauthorized.selector);
        distributor.sweepExcess(treasury);
    }

    function testRejectZeroDistributionIdHash() public {
        vm.expectRevert(EvxAirdropDistributor.InvalidDistributionIdHash.selector);
        new EvxAirdropDistributor(
            address(token), merkleRoot, deadline, bytes32(0), TOTAL, treasury
        );
    }

    function testClaimExceedsTotalAllocated() public {
        // Leaf amount > totalAllocated binding → claim blocked before transfer
        bytes32 bigLeaf = keccak256(abi.encodePacked(INDEX, eligible, AMOUNT));
        EvxAirdropDistributor tiny = new EvxAirdropDistributor(
            address(token),
            bigLeaf,
            deadline,
            DIST_ID_HASH,
            1, // totalAllocated far below leaf amount
            treasury
        );
        vm.prank(owner);
        token.transfer(address(tiny), AMOUNT);
        vm.expectRevert(EvxAirdropDistributor.ExceedsTotalAllocated.selector);
        tiny.claim(INDEX, eligible, AMOUNT, proof);
    }

    function testGetters() public view {
        assertEq(distributor.token(), address(token));
        assertEq(distributor.merkleRoot(), merkleRoot);
        assertEq(distributor.claimDeadline(), deadline);
        assertEq(distributor.distributionIdHash(), DIST_ID_HASH);
        assertEq(distributor.totalAllocated(), TOTAL);
        assertEq(distributor.treasury(), treasury);
    }

    function _hashPair(bytes32 a, bytes32 b) private pure returns (bytes32) {
        return a < b
            ? keccak256(abi.encodePacked(a, b))
            : keccak256(abi.encodePacked(b, a));
    }
}
