// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title OANToken
 * @dev Governance token for Obsidian Arcadia Network
 */
contract OANToken is ERC20, ERC20Burnable, ERC20Permit, ERC20Votes, Ownable {

    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 * 10**18;

    ///  Optional hard cap (VERY GOOD PRACTICE)
    uint256 public constant MAX_SUPPLY = 2_000_000_000 * 10**18;

    event TokensMinted(address indexed to, uint256 amount);

    constructor()
        ERC20("Obsidian Arcadia Network", "OAN")
        ERC20Permit("Obsidian Arcadia Network")
        Ownable(msg.sender)
    {
        _mint(msg.sender, INITIAL_SUPPLY);
    }

    /**
     *  Controlled Minting (DAO / Owner / Treasury)
     */
    function mint(address to, uint256 amount) external onlyOwner {

        require(totalSupply() + amount <= MAX_SUPPLY, "Max supply exceeded");

        _mint(to, amount);

        emit TokensMinted(to, amount);
    }

    /**
     * Required Overrides (OpenZeppelin)
     */
    function _update(address from, address to, uint256 value)
        internal override(ERC20, ERC20Votes)
    {
        super._update(from, to, value);
    }

    function nonces(address owner)
        public view override(ERC20Permit, Nonces)
        returns (uint256)
    {
        return super.nonces(owner);
    }
}
