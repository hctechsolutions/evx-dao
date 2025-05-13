// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import { ERC20Permit, Nonces } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { ERC20Votes, Votes } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import { INebularToken } from "@nebular-dao/interfaces/INebularToken.sol";
import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title NebularToken
 * @notice Governance token with voting and permit capabilities
 * @dev Extends OpenZeppelin's ERC20, ERC20Votes, ERC20Permit, and Ownable
 */
contract NebularToken is ERC20, ERC20Votes, ERC20Permit, Ownable, INebularToken {

    /**
     * @notice Initializes the Nebular Governance Token
     * @param initialOwner Address that will receive the initial supply
     */
    constructor(address initialOwner)
        ERC20("Nebular Governance Token", "NBL")
        ERC20Permit("Nebular Governance Token")
        Ownable(initialOwner)
    {
        _mint(initialOwner, 100_000_000 * 10 ** decimals());
    }

    /**
     * @notice Internal function to handle token transfers and voting power
     * @dev Ensures proper update of voting power and nonces
     */
    function _update(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._update(from, to, amount);

        if (to != address(0) && delegates(to) == address(0)) {
            _delegate(to, to);
            emit AutoDelegated(to);
        }
    }

    /// @inheritdoc INebularToken
    function nonces(address owner) public view override(INebularToken, ERC20Permit, Nonces) returns (uint256) {
        return super.nonces(owner);
    }

    /// @inheritdoc INebularToken
    function getPastVotes(address account, uint256 blockNumber)
        public
        view
        override(INebularToken, Votes)
        returns (uint256)
    {
        return super.getPastVotes(account, blockNumber);
    }
}
