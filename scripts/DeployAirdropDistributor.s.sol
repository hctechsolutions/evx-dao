// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { EvxAirdropDistributor } from "@evx-dao/contracts/EvxAirdropDistributor.sol";
import "forge-std/console.sol";

/**
 * @title DeployAirdropDistributor
 * @notice Deploy + fund Merkle distributor for Sepolia MVP (Story 5.3).
 * @dev Env:
 *   DEPLOYER_PRIVATE_KEY
 *   EVX_TOKEN_ADDR          — existing Sepolia EVX
 *   AIRDROP_MERKLE_ROOT     — bytes32 hex (must match Platform seed)
 *   AIRDROP_FUND_AMOUNT     — wei string (optional; default 1000e18)
 *
 * Funding uses deployer EVX balance (treasury/marketing transfer offline if needed).
 * Does NOT call EvxTokenVester.release — vesters ≠ retail claim UX.
 */
contract DeployAirdropDistributor is Script {
    uint256 private deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");
    address private tokenAddr = vm.envAddress("EVX_TOKEN_ADDR");
    bytes32 private merkleRoot = vm.envBytes32("AIRDROP_MERKLE_ROOT");

    function run() external {
        uint256 fundAmount = vm.envOr("AIRDROP_FUND_AMOUNT", uint256(1000 ether));
        address deployer = vm.addr(deployerPrivateKey);

        vm.startBroadcast(deployerPrivateKey);

        EvxAirdropDistributor distributor =
            new EvxAirdropDistributor(tokenAddr, merkleRoot);
        console.log("EvxAirdropDistributor deployed at:", address(distributor));

        uint256 bal = IERC20(tokenAddr).balanceOf(deployer);
        console.log("Deployer EVX balance:", bal);

        if (fundAmount > 0 && bal >= fundAmount) {
            require(
                IERC20(tokenAddr).transfer(address(distributor), fundAmount),
                "fund transfer failed"
            );
            console.log("Funded distributor with:", fundAmount);
        } else {
            console.log(
                "SKIP fund - deployer balance insufficient; fund offline from marketing/treasury slice"
            );
        }

        console.log("======== AIRDROP DEPLOYMENT ========");
        console.log(string.concat("EVX_TOKEN_ADDR=", vm.toString(tokenAddr)));
        console.log(
            string.concat("AIRDROP_DISTRIBUTOR_ADDR=", vm.toString(address(distributor)))
        );
        console.log("AIRDROP_MERKLE_ROOT=");
        console.logBytes32(merkleRoot);
        console.log("====================================");

        vm.stopBroadcast();
    }
}
