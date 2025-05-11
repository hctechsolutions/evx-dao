// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { INebularTokenVester } from "@nebular/interfaces/INebularTokenVester.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NebularTokenVester
 * @notice Implements a linear token vesting mechanism with an initial cliff and optional immediate release.
 * @dev This contract holds tokens and gradually releases them to a beneficiary address according to a vesting schedule.
 *      It supports an initial cliff duration, an optional initial release of tokens after the cliff, and linear release
 *      of the remaining tokens over a fixed vesting duration. The contract is Ownable and only the owner can trigger
 *      token releases.
 */
contract NebularTokenVester is INebularTokenVester, Ownable {
    using SafeERC20 for IERC20;

    /// @inheritdoc INebularTokenVester
    IERC20 public immutable token;

    /// @inheritdoc INebularTokenVester
    uint256 public immutable start;

    /// @inheritdoc INebularTokenVester
    uint256 public immutable cliffDuration;

    /// @inheritdoc INebularTokenVester
    uint256 public immutable initialRelease;

    /// @inheritdoc INebularTokenVester
    uint256 public immutable totalAllocation;

    /// @inheritdoc INebularTokenVester
    uint256 public immutable vestingDuration;

    /// @inheritdoc INebularTokenVester
    uint256 public released;

    /// @notice The address that will be the beneficiary of the tokens
    address public beneficiary;

    /**
     * @notice Initializes the vesting contract with specified parameters.
     * @param _token The ERC20 token to vest.
     * @param _cliffDuration Time (in seconds) before any vesting begins.
     * @param _initialRelease Amount of tokens released immediately after cliff.
     * @param _totalAllocation Total tokens allocated for vesting.
     * @param _vestingDuration Duration (in seconds) over which remaining tokens vest linearly.
     * @param _beneficiary Address entitled to receive vested tokens.
     * @param _owner Address granted ownership privileges (can call release).
     * @dev Requires _totalAllocation > _initialRelease and _vestingDuration > 0.
     */
    constructor(
        IERC20 _token,
        uint256 _cliffDuration,
        uint256 _initialRelease,
        uint256 _totalAllocation,
        uint256 _vestingDuration,
        address _beneficiary,
        address _owner
    ) Ownable(_owner) {
        require(_totalAllocation > _initialRelease, "Invalid allocation");
        require(_vestingDuration > 0, "Vesting duration must be greater than 0");

        token = _token;
        start = block.timestamp;
        cliffDuration = _cliffDuration;
        initialRelease = _initialRelease;
        totalAllocation = _totalAllocation;
        vestingDuration = _vestingDuration;
        beneficiary = _beneficiary;
    }

    /// @inheritdoc INebularTokenVester
    function release() external override onlyOwner {
        uint256 vested = calculateVestedAmount();
        require(vested > released, "No tokens to release");

        uint256 amount = vested - released;
        released = vested;

        token.safeTransfer(beneficiary, amount);
        emit TokensReleased(amount);
    }

    /// @inheritdoc INebularTokenVester
    function calculateVestedAmount() public view override returns (uint256) {
        if (block.timestamp < start + cliffDuration) {
            return 0;
        }

        uint256 elapsed = block.timestamp - (start + cliffDuration);
        uint256 vestingAmount = totalAllocation - initialRelease;

        uint256 vestedFromVesting = (vestingAmount * elapsed) / vestingDuration;
        uint256 totalVested = initialRelease + vestedFromVesting;

        return totalVested > totalAllocation ? totalAllocation : totalVested;
    }
}
