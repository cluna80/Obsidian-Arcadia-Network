// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract OptionsExchange is Ownable, ReentrancyGuard {
    
    struct Option {uint256 id;address writer;address holder;uint256 underlyingAsset;uint256 strikePrice;uint256 premium;uint256 expiry;bool isCall;bool isExercised;bool isActive;}
    
    mapping(uint256 => Option) public options;
    uint256 public optionCount;
    uint256 public tradingVolume;
    
    event OptionWritten(uint256 indexed optionId, address indexed writer, uint256 strikePrice, uint256 premium);
    event OptionPurchased(uint256 indexed optionId, address indexed buyer);
    event OptionExercised(uint256 indexed optionId, uint256 profit);
    event OptionExpired(uint256 indexed optionId);
    
    constructor() Ownable(msg.sender) {}
    
    function writeOption(uint256 underlyingAsset,uint256 strikePrice,uint256 premium,uint256 duration,bool isCall) external payable returns (uint256) {require(msg.value >= strikePrice);optionCount++;options[optionCount] = Option(optionCount,msg.sender,address(0),underlyingAsset,strikePrice,premium,block.timestamp + duration,isCall,false,true);emit OptionWritten(optionCount, msg.sender, strikePrice, premium);return optionCount;}
    
    function buyOption(uint256 optionId) external payable nonReentrant {Option storage opt = options[optionId];require(opt.isActive && opt.holder == address(0) && msg.value >= opt.premium);opt.holder = msg.sender;payable(opt.writer).transfer(msg.value);tradingVolume += msg.value;emit OptionPurchased(optionId, msg.sender);}
    
    function exerciseOption(uint256 optionId, uint256 currentPrice) external nonReentrant {Option storage opt = options[optionId];require(opt.holder == msg.sender && opt.isActive && block.timestamp < opt.expiry);uint256 profit = 0;if(opt.isCall && currentPrice > opt.strikePrice){profit = currentPrice - opt.strikePrice;}else if(!opt.isCall && currentPrice < opt.strikePrice){profit = opt.strikePrice - currentPrice;}require(profit > 0);opt.isExercised = true;opt.isActive = false;payable(opt.holder).transfer(profit);emit OptionExercised(optionId, profit);}
    
    function expireOption(uint256 optionId) external {Option storage opt = options[optionId];require(block.timestamp >= opt.expiry && opt.isActive);opt.isActive = false;if(!opt.isExercised && opt.holder == address(0)){payable(opt.writer).transfer(opt.strikePrice);}emit OptionExpired(optionId);}
}
