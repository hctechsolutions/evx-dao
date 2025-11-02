// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "@evx-dao/contracts/EvxTokenVester.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/**
 * @title EvxTokenVesterTest
 * @dev Unit tests for the EvxTokenVester contract
 */
contract MockERC20 is ERC20 {
    constructor() ERC20("Mock Token", "MOCK") {}

    function mint(address to, uint256 amount) public {
        _mint(to, amount);
    }
}

contract EvxTokenVesterTest is Test {
    MockERC20 public token;
    EvxTokenVester public vesting;

    uint256 public constant CLIFF_DURATION = 365 days;
    uint256 public constant INITIAL_RELEASE = 1e18; // 1 token
    uint256 public constant TOTAL_ALLOCATION = 10e18; // 10 tokens
    uint256 public constant VESTING_DURATION = 2 * 365 days;

    address public owner = address(0x1);
    address public nonOwner = address(0x2);

    /**
     * @dev Sets up the test environment
     */
    function setUp() public {
        vm.startPrank(owner);

        token = new MockERC20();
        vesting = new EvxTokenVester(
            token, 
            CLIFF_DURATION, 
            INITIAL_RELEASE, 
            TOTAL_ALLOCATION, 
            VESTING_DURATION, 
            owner,
            owner
        );

        token.mint(address(vesting), TOTAL_ALLOCATION);

        vm.stopPrank();
    }

    /**
     * @dev Tests initial contract setup
     */
    function testInitialSetup() public view {
        assertEq(address(vesting.token()), address(token));
        assertEq(vesting.start(), block.timestamp);
        assertEq(vesting.cliffDuration(), CLIFF_DURATION);
        assertEq(vesting.initialRelease(), INITIAL_RELEASE);
        assertEq(vesting.totalAllocation(), TOTAL_ALLOCATION);
        assertEq(vesting.vestingDuration(), VESTING_DURATION);
    }

    /**
     * @dev Tests that no tokens are vested before the cliff period
     */
    function testBeforeCliff() public {
        vm.warp(vesting.start() + CLIFF_DURATION - 1);
        assertEq(vesting.calculateVestedAmount(), 0);
    }

    /**
     * @dev Tests that the initial release occurs immediately after the cliff
     */
    function testAtCliff() public {
        vm.warp(vesting.start() + CLIFF_DURATION);
        assertEq(vesting.calculateVestedAmount(), INITIAL_RELEASE);
    }

    /**
     * @dev Tests partial token release during the vesting period
     */
    function testDuringVesting() public {
        uint256 halfVesting = CLIFF_DURATION + (VESTING_DURATION / 2);
        vm.warp(vesting.start() + halfVesting);

        uint256 expected =
            INITIAL_RELEASE + (TOTAL_ALLOCATION - INITIAL_RELEASE) * (halfVesting - CLIFF_DURATION) / VESTING_DURATION;

        assertEq(vesting.calculateVestedAmount(), expected);
    }

    /**
     * @dev Tests full token release after the vesting period
     */
    function testAfterVesting() public {
        vm.warp(vesting.start() + CLIFF_DURATION + VESTING_DURATION + 1);
        assertEq(vesting.calculateVestedAmount(), TOTAL_ALLOCATION);
    }

    /**
     * @dev Tests token release functionality
     */
    function testRelease() public {
        vm.warp(vesting.start() + CLIFF_DURATION + VESTING_DURATION);

        uint256 ownerBalanceBefore = token.balanceOf(owner);
        vm.prank(owner);
        vesting.release();

        assertEq(token.balanceOf(owner), ownerBalanceBefore + TOTAL_ALLOCATION);
        assertEq(vesting.released(), TOTAL_ALLOCATION);
    }

    /**
     * @dev Tests multiple releases over time
     */
    function testMultipleReleases() public {
        vm.warp(vesting.start() + CLIFF_DURATION + (VESTING_DURATION / 2));
        vm.prank(owner);
        vesting.release();

        uint256 firstRelease =
            INITIAL_RELEASE + (TOTAL_ALLOCATION - INITIAL_RELEASE) * (VESTING_DURATION / 2) / VESTING_DURATION;

        vm.warp(vesting.start() + CLIFF_DURATION + VESTING_DURATION);
        vm.prank(owner);
        vesting.release();

        assertEq(vesting.released(), TOTAL_ALLOCATION);
        assertEq(token.balanceOf(owner), firstRelease + (TOTAL_ALLOCATION - firstRelease));
    }

    /**
     * @dev Tests that only the owner can release tokens
     */
    function testOnlyOwnerCanRelease() public {
        vm.warp(vesting.start() + CLIFF_DURATION);
        vm.prank(nonOwner);
        vm.expectRevert(abi.encodeWithSignature("OwnableUnauthorizedAccount(address)", nonOwner));
        vesting.release();
    }

    /**
     * @dev Tests that tokens cannot be released if none are available
     */
    function testNothingToRelease() public {
        vm.warp(vesting.start() + CLIFF_DURATION);
        vm.prank(owner);
        vesting.release();

        vm.prank(owner);
        vm.expectRevert("No tokens to release");
        vesting.release();
    }
}
