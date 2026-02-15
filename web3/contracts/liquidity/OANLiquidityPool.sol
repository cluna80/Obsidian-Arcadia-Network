// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/**
 * @title OANLiquidityPool
 * @dev Simple liquidity pool for OAN token
 */
contract OANLiquidityPool is Ownable, ReentrancyGuard {
    
    struct LiquidityProvider {
        uint256 ethAmount;
        uint256 tokenAmount;
        uint256 shares;
        uint256 depositedAt;
    }
    
    mapping(address => LiquidityProvider) public providers;
    
    uint256 public totalEth;
    uint256 public totalTokens;
    uint256 public totalShares;
    uint256 public totalProviders;
    
    uint256 public swapFee = 30; // 0.3%
    uint256 public constant FEE_DENOMINATOR = 10000;
    
    event LiquidityAdded(address indexed provider, uint256 ethAmount, uint256 tokenAmount, uint256 shares);
    event LiquidityRemoved(address indexed provider, uint256 ethAmount, uint256 tokenAmount);
    event Swap(address indexed user, uint256 amountIn, uint256 amountOut, bool ethToToken);
    
    constructor() Ownable(msg.sender) {}
    
    receive() external payable {}
    
    function addLiquidity(uint256 tokenAmount) external payable nonReentrant {
        require(msg.value > 0, "Must send ETH");
        require(tokenAmount > 0, "Must send tokens");
        
        uint256 shares;
        
        if (totalShares == 0) {
            shares = msg.value; // Initial liquidity
        } else {
            uint256 ethShare = (msg.value * totalShares) / totalEth;
            uint256 tokenShare = (tokenAmount * totalShares) / totalTokens;
            shares = ethShare < tokenShare ? ethShare : tokenShare;
        }
        
        providers[msg.sender].ethAmount += msg.value;
        providers[msg.sender].tokenAmount += tokenAmount;
        providers[msg.sender].shares += shares;
        providers[msg.sender].depositedAt = block.timestamp;
        
        if (providers[msg.sender].shares == shares) {
            totalProviders++;
        }
        
        totalEth += msg.value;
        totalTokens += tokenAmount;
        totalShares += shares;
        
        emit LiquidityAdded(msg.sender, msg.value, tokenAmount, shares);
    }
    
    function removeLiquidity(uint256 shares) external nonReentrant {
        require(shares > 0, "Invalid shares");
        require(providers[msg.sender].shares >= shares, "Insufficient shares");
        
        uint256 ethAmount = (shares * totalEth) / totalShares;
        uint256 tokenAmount = (shares * totalTokens) / totalShares;
        
        providers[msg.sender].shares -= shares;
        providers[msg.sender].ethAmount -= ethAmount;
        providers[msg.sender].tokenAmount -= tokenAmount;
        
        totalShares -= shares;
        totalEth -= ethAmount;
        totalTokens -= tokenAmount;
        
        payable(msg.sender).transfer(ethAmount);
        // Transfer tokens (would need token contract reference)
        
        emit LiquidityRemoved(msg.sender, ethAmount, tokenAmount);
    }
    
    function swapEthForTokens() external payable nonReentrant {
        require(msg.value > 0, "Must send ETH");
        
        uint256 fee = (msg.value * swapFee) / FEE_DENOMINATOR;
        uint256 ethAfterFee = msg.value - fee;
        
        uint256 tokenAmount = getTokensForEth(ethAfterFee);
        
        totalEth += msg.value;
        totalTokens -= tokenAmount;
        
        // Transfer tokens (would need token contract reference)
        
        emit Swap(msg.sender, msg.value, tokenAmount, true);
    }
    
    function getTokensForEth(uint256 ethAmount) public view returns (uint256) {
        if (totalEth == 0 || totalTokens == 0) return 0;
        return (ethAmount * totalTokens) / (totalEth + ethAmount);
    }
    
    function getEthForTokens(uint256 tokenAmount) public view returns (uint256) {
        if (totalEth == 0 || totalTokens == 0) return 0;
        return (tokenAmount * totalEth) / (totalTokens + tokenAmount);
    }
    
    function getPoolStats() external view returns (
        uint256 eth,
        uint256 tokens,
        uint256 shares,
        uint256 providers
    ) {
        return (totalEth, totalTokens, totalShares, totalProviders);
    }
}
