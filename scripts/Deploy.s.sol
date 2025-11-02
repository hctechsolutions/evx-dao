// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";
import { EvxTokenVester } from "@evx-dao/contracts/EvxTokenVester.sol";
import { EvxGovernance } from "@evx-dao/contracts/EvxGovernance.sol";
import { EvxToken } from "@evx-dao/contracts/EvxToken.sol";

import { Script } from "forge-std/Script.sol";
import "forge-std/console.sol";

/**
 * @title Deploy
 * @notice Comprehensive deployment script for the Evx DAO
 */
contract Deploy is Script {
    uint256 private deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

    /// @notice Wallet addresses
    address public marketingWallet = vm.envAddress("MARKETING_WALLET");
    address public treasuryWallet = vm.envAddress("TREASURY_WALLET");
    address public partnersWallet = vm.envAddress("PARTNERS_WALLET");
    address public deployerWallet = vm.addr(deployerPrivateKey);
    address public teamWallet = vm.envAddress("TEAM_WALLET");
    address public seedWallet = vm.envAddress("SEED_WALLET");

    /// @notice DAO parameters
    uint256 public constant MIN_DELAY = 24 hours;
    uint256 public constant PROPOSERS_COUNT = 5;
    uint256 public constant EXECUTORS_COUNT = 5;

    function run() external {
        vm.startBroadcast(deployerPrivateKey);
    console.log("Verbosity");

        // ======================
        // Deploy Governance Token
        // ======================
        console.log("\nDeploying EvxToken...");
        EvxToken evx = new EvxToken(deployerWallet);
        console.log("EvxToken deployed at:", address(evx));

        // ======================
        // Deploy Timelock Controller
        // ======================
        console.log("\nDeploying TimelockController...");
        
        address[] memory proposers = new address[](PROPOSERS_COUNT);
        address[] memory executors = new address[](EXECUTORS_COUNT);
        
        for (uint i = 0; i < PROPOSERS_COUNT; i++) {
            proposers[i] = deployerWallet;
        }
        
        for (uint i = 0; i < EXECUTORS_COUNT; i++) {
            executors[i] = deployerWallet;
        }
        
        TimelockController timelock = new TimelockController(
            MIN_DELAY,
            proposers,
            executors,
            deployerWallet
        );

        console.log("TimelockController deployed at:", address(timelock));

        // ======================
        // Deploy Vesting Contracts
        // ======================
        console.log("\nDeploying Vesting Contracts...");
        
        // Deploy the vesting contracts for different allocations
        EvxTokenVester liquidityVester = new EvxTokenVester(
            evx,
            0,                  // Cliff: 0
            0,                  // Initial release: 0
            20_000_000e18,      // Total allocation: 20M tokens
            4 * 365 days,       // Vesting duration: 4 years
            treasuryWallet,     // Beneficiary: Treasury
            treasuryWallet      // The address that will own the vesting contract
        );

        console.log("Liquidity Vester deployed at:", address(liquidityVester));

        EvxTokenVester teamVester = new EvxTokenVester(
            evx,
            1 * 365 days,       // Cliff: 1 year
            0,                  // Initial release: 0
            15_000_000e18,      // Total allocation: 15M tokens
            3 * 365 days,       // Vesting duration: 3 years
            teamWallet,         // Beneficiary: Team 
            address(timelock)   // The address that will own the vesting contract
        );

        console.log("Team Vester deployed at:", address(teamVester));

        EvxTokenVester seedVester = new EvxTokenVester(
            evx,
            180 days,           // Cliff: 6 months
            0,                  // Initial release: 0
            10_000_000e18,      // Total allocation: 10M tokens
            2 * 365 days,       // Vesting duration: 2 years
            seedWallet,         // Beneficiary: Seed investors
            seedWallet          // The address that will own the vesting contract
        );

        console.log("Seed Vester deployed at:", address(seedVester));

        EvxTokenVester marketingVester = new EvxTokenVester(
            evx,
            0,                  // Cliff: 0
            3_000_000e18,       // Initial release: 3M tokens (30%)
            10_000_000e18,      // Total allocation: 10M tokens
            2 * 365 days,       // Vesting duration: 2 years
            marketingWallet,    // Beneficiary: Marketing
            address(timelock)   // The address that will own the vesting contract
        );

        console.log("Marketing Vester deployed at:", address(marketingVester));

        // ======================
        // Distribute Tokens
        // ======================
        console.log("\nDistributing tokens...");
        evx.transfer(address(liquidityVester), 20_000_000e18);
        evx.transfer(address(teamVester), 15_000_000e18);
        evx.transfer(address(seedVester), 10_000_000e18);
        evx.transfer(address(marketingVester), 10_000_000e18);
        evx.transfer(treasuryWallet, 40_000_000e18);
        evx.transfer(partnersWallet, 5_000_000e18);
        console.log("Token distribution completed");

        // ======================
        // Deploy Governance DAO
        // ======================
        console.log("\nDeploying EvxGovernance...");
        EvxGovernance dao = new EvxGovernance(evx, timelock);
        console.log("EvxGovernance deployed at:", address(dao));

        // ======================
        // Post-Deployment Setup
        // ======================
        console.log("\nConfiguring permissions...");
        
        // Transfer timelock admin to Evx DAO
        timelock.grantRole(timelock.PROPOSER_ROLE(), address(dao));
        timelock.grantRole(timelock.EXECUTOR_ROLE(), address(dao));
        timelock.grantRole(timelock.CANCELLER_ROLE(), address(dao));
        timelock.revokeRole(timelock.DEFAULT_ADMIN_ROLE(), deployerWallet);
        
        console.log("Timelock permissions transferred to DAO");

        console.log("======== DEPLOYMENT ENVIRONMENT ========");
        console.log(string.concat("EVX_TOKEN_ADDR=", vm.toString(address(evx))));
        console.log(string.concat("EVX_DAO_ADDR=", vm.toString(address(dao))));
        console.log(string.concat("DAO_TIMELOCK_ADDR=", vm.toString(address(timelock))));
        console.log(string.concat("LIQUIDITY_VESTER_ADDR=", vm.toString(address(liquidityVester))));
        console.log(string.concat("TEAM_VESTER_ADDR=", vm.toString(address(teamVester))));
        console.log(string.concat("SEED_VESTER_ADDR=", vm.toString(address(seedVester))));
        console.log(string.concat("MARKETING_VESTER_ADDR=", vm.toString(address(marketingVester))));
        console.log("===================================");

        vm.stopBroadcast();
    }
}