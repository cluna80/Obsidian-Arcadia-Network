// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

contract DerivativeMarkets is Ownable, ReentrancyGuard {
    
    enum DerivativeType {Call, Put, Future, Swap}
    enum UnderlyingAsset {EntityReputation, EntityPerformance, WorldSuccess, TokenPrice}
    
    struct Derivative {uint256 id;DerivativeType derivativeType;UnderlyingAsset underlying;uint256 underlyingId;uint256 strikePrice;uint256 premium;uint256 expiry;address creator;address buyer;bool isSettled;uint256 settlementValue;}
    
    mapping(uint256 => Derivative) public derivatives;
    uint256 public derivativeCount;
    uint256 public totalVolume;
    
    event DerivativeCreated(uint256 indexed derivativeId, DerivativeType derivativeType, uint256 strikePrice, uint256 expiry);
    event DerivativePurchased(uint256 indexed derivativeId, address indexed buyer, uint256 premium);
    event DerivativeSettled(uint256 indexed derivativeId, uint256 settlementValue);
    
    constructor() Ownable(msg.sender) {}
    
    function createDerivative(DerivativeType derivativeType,UnderlyingAsset underlying,uint256 underlyingId,uint256 strikePrice,uint256 premium,uint256 duration) external returns (uint256) {derivativeCount++;derivatives[derivativeCount] = Derivative(derivativeCount,derivativeType,underlying,underlyingId,strikePrice,premium,block.timestamp + duration,msg.sender,address(0),false,0);emit DerivativeCreated(derivativeCount, derivativeType, strikePrice, block.timestamp + duration);return derivativeCount;}
    
    function buyDerivative(uint256 derivativeId) external payable nonReentrant {Derivative storage deriv = derivatives[derivativeId];require(deriv.buyer == address(0) && msg.value >= deriv.premium);deriv.buyer = msg.sender;payable(deriv.creator).transfer(msg.value);totalVolume += msg.value;emit DerivativePurchased(derivativeId, msg.sender, msg.value);}
    
    function settleDerivative(uint256 derivativeId, uint256 currentValue) external {Derivative storage deriv = derivatives[derivativeId];require(block.timestamp >= deriv.expiry && !deriv.isSettled);uint256 payout = 0;if(deriv.derivativeType == DerivativeType.Call && currentValue > deriv.strikePrice){payout = currentValue - deriv.strikePrice;}else if(deriv.derivativeType == DerivativeType.Put && currentValue < deriv.strikePrice){payout = deriv.strikePrice - currentValue;}deriv.isSettled = true;deriv.settlementValue = payout;if(payout > 0 && deriv.buyer != address(0)){payable(deriv.buyer).transfer(payout);}emit DerivativeSettled(derivativeId, payout);}
    
    function getDerivative(uint256 derivativeId) external view returns (Derivative memory) {return derivatives[derivativeId];}
}
