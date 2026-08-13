// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { EvxAirdropDistributor } from "@evx-dao/contracts/EvxAirdropDistributor.sol";
import "forge-std/console.sol";

/**
 * @title DeployAirdropDistributor
 * @notice Deploy + fund Merkle distributor (Story 5.3/5.4 Profile B).
 * @dev Env:
 *   DEPLOYER_PRIVATE_KEY
 *   EVX_TOKEN_ADDR
 *   AIRDROP_MERKLE_ROOT
 *   AIRDROP_CLAIM_DEADLINE     — unix timestamp (must be future, not uint256.max)
 *   AIRDROP_DISTRIBUTION_ID_HASH — bytes32
 *   AIRDROP_TOTAL_ALLOCATED    — wei (uint)
 *   AIRDROP_TREASURY           — HARD GATE: Timelock or DAO-controlled address
 *                                (sweep authority + canonical destination; D24)
 *   AIRDROP_FUND_AMOUNT        — wei (optional; default = TOTAL; must be >= TOTAL)
 */
contract DeployAirdropDistributor is Script {
    using SafeERC20 for IERC20;

    uint256 private deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address private tokenAddr = vm.envAddress("EVX_TOKEN_ADDR");
    bytes32 private merkleRoot = vm.envBytes32("AIRDROP_MERKLE_ROOT");
    uint256 private claimDeadline = vm.envUint("AIRDROP_CLAIM_DEADLINE");
    bytes32 private distributionIdHash = vm.envBytes32("AIRDROP_DISTRIBUTION_ID_HASH");
    uint256 private totalAllocated = vm.envUint("AIRDROP_TOTAL_ALLOCATED");
    address private treasury = vm.envAddress("AIRDROP_TREASURY");

    function run() external {
        uint256 fundAmount = vm.envOr("AIRDROP_FUND_AMOUNT", totalAllocated);
        require(fundAmount >= totalAllocated, "fundAmount < totalAllocated");
        require(treasury != address(0), "treasury required (Timelock/DAO)");
        require(tokenAddr != address(0), "token required");
        require(merkleRoot != bytes32(0), "merkleRoot required");
        require(distributionIdHash != bytes32(0), "distributionIdHash required");
        require(
            claimDeadline > block.timestamp && claimDeadline != type(uint256).max,
            "claimDeadline must be future and finite"
        );
        require(totalAllocated > 0, "totalAllocated required");

        address deployer = vm.addr(deployerPrivateKey);
        uint256 bal = IERC20(tokenAddr).balanceOf(deployer);
        console.log("Deployer EVX balance:", bal);
        require(bal >= fundAmount, "deployer EVX < fundAmount; fund before deploy");

        vm.startBroadcast(deployerPrivateKey);

        EvxAirdropDistributor distributor = new EvxAirdropDistributor(
            tokenAddr,
            merkleRoot,
            claimDeadline,
            distributionIdHash,
            totalAllocated,
            treasury
        );
        console.log("EvxAirdropDistributor deployed at:", address(distributor));

        IERC20(tokenAddr).safeTransfer(address(distributor), fundAmount);
        require(
            IERC20(tokenAddr).balanceOf(address(distributor)) >= totalAllocated,
            "distributor received < totalAllocated"
        );
        console.log("Funded distributor with:", fundAmount);

        console.log("======== AIRDROP DEPLOYMENT ========");
        console.log(string.concat("EVX_TOKEN_ADDR=", vm.toString(tokenAddr)));
        console.log(
            string.concat("AIRDROP_DISTRIBUTOR_ADDR=", vm.toString(address(distributor)))
        );
        console.log("AIRDROP_MERKLE_ROOT=");
        console.logBytes32(merkleRoot);
        console.log("AIRDROP_DISTRIBUTION_ID_HASH=");
        console.logBytes32(distributionIdHash);
        console.log("claimDeadline=", claimDeadline);
        console.log("totalAllocated=", totalAllocated);
        console.log("treasury=", treasury);
        console.log("====================================");

        vm.stopBroadcast();
    }
}
