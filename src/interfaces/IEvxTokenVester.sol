// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
 * @title IEvxTokenVester
 * @notice Interface for the EvxTokenVester vesting contract handling configurable release schedules.
 */
interface IEvxTokenVester {
    /**
     * @notice Emitted when vested tokens are released to the beneficiary.
     * @param amount The amount of tokens released.
     */
    event TokensReleased(uint256 indexed amount);

    /**
     * @notice Returns the ERC20 token being vested.
     * @return The IERC20 token contract.
     */
    function token() external view returns (IERC20);

    /**
     * @notice Returns the timestamp when vesting starts.
     * @return The Unix timestamp of vesting start.
     */
    function start() external view returns (uint256);

    /**
     * @notice Returns the duration of the cliff period before vesting begins.
     * @return Duration of the cliff in seconds.
     */
    function cliffDuration() external view returns (uint256);

    /**
     * @notice Returns the initial amount of tokens released at vesting start.
     * @return The amount of tokens for the initial release.
     */
    function initialRelease() external view returns (uint256);

    /**
     * @notice Returns the total amount of tokens allocated for vesting.
     * @return The total vesting allocation of tokens.
     */
    function totalAllocation() external view returns (uint256);

    /**
     * @notice Returns the duration over which the remaining tokens vest linearly.
     * @return Vesting duration in seconds.
     */
    function vestingDuration() external view returns (uint256);

    /**
     * @notice Returns the address of the beneficiary.
     * @return The beneficiary address.
     */
    function beneficiary() external view returns (address);

    /**
     * @notice Returns the total amount of tokens already released.
     * @return The amount of tokens released so far.
     */
    function released() external view returns (uint256);

    /**
     * @notice Releases any vested tokens to the beneficiary.
     * @dev Can only be called by the contract owner. Reverts if no tokens are available.
     */
    function release() external;

    /**
     * @notice Calculates the total amount of tokens vested up to the current timestamp.
     * @return The total vested token amount.
     */
    function calculateVestedAmount() external view returns (uint256);
}
