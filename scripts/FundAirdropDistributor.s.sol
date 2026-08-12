// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { Script } from "forge-std/Script.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "forge-std/console.sol";

/**
 * @title FundAirdropDistributor
 * @notice Transfer EVX from funder (treasury) → existing distributor (Story 5.3 AC#4).
 * @dev Env:
 *   FUNDER_PRIVATE_KEY   — treasury (or marketing) key holding EVX
 *   EVX_TOKEN_ADDR
 *   AIRDROP_DISTRIBUTOR_ADDR
 *   AIRDROP_FUND_AMOUNT  — wei (default 150e18 covers seed leaves 100+50)
 */
contract FundAirdropDistributor is Script {
    uint256 private funderPrivateKey = vm.envUint("FUNDER_PRIVATE_KEY");
    address private tokenAddr = vm.envAddress("EVX_TOKEN_ADDR");
    address private distributor = vm.envAddress("AIRDROP_DISTRIBUTOR_ADDR");

    function run() external {
        uint256 fundAmount = vm.envOr("AIRDROP_FUND_AMOUNT", uint256(150 ether));
        address funder = vm.addr(funderPrivateKey);

        uint256 bal = IERC20(tokenAddr).balanceOf(funder);
        console.log("Funder:", funder);
        console.log("Funder EVX balance:", bal);
        console.log("Distributor:", distributor);
        console.log("Fund amount:", fundAmount);

        require(fundAmount > 0, "AIRDROP_FUND_AMOUNT must be > 0");
        require(bal >= fundAmount, "funder EVX balance insufficient");

        vm.startBroadcast(funderPrivateKey);
        require(
            IERC20(tokenAddr).transfer(distributor, fundAmount),
            "fund transfer failed"
        );
        vm.stopBroadcast();

        console.log(
            "Funded distributor. New balance:",
            IERC20(tokenAddr).balanceOf(distributor)
        );
    }
}
