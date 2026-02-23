// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

/// @title PredictionMarkets - Bet on match outcomes in OAN sports
/// @notice Layer 5, Phase 5.4 - OAN Metaverse Sports Arena
contract PredictionMarkets is AccessControl, ReentrancyGuard {
    bytes32 public constant SETTLER_ROLE = keccak256("SETTLER_ROLE");

    enum MarketType { Winner, FinishMethod, FinishRound, TotalRounds, PointSpread }
    enum MarketStatus { Open, Locked, Settled, Cancelled }
    enum FinishMethod { Decision, KO, TKO, Submission, Draw }

    struct Market {
        uint256 marketId;
        uint256 matchId;
        MarketType marketType;
        MarketStatus status;
        uint256 totalStaked;
        uint256 openTime;
        uint256 closeTime;        // No more bets after this
        uint256 settledOutcome;   // Index of winning outcome
        bool settled;
        address creator;
    }

    struct Outcome {
        uint256 outcomeId;
        string description;       // "Athlete A wins", "KO finish", "Round 3", etc.
        uint256 totalStaked;
        uint256 odds;             // Implied odds in basis points (e.g., 5000 = 2.0x / even money)
    }

    struct Bet {
        address bettor;
        uint256 marketId;
        uint256 outcomeId;
        uint256 amount;
        uint256 timestamp;
        bool claimed;
        uint256 potentialPayout;
    }

    uint256 private _marketIdCounter;
    uint256 private _betIdCounter;

    mapping(uint256 => Market) public markets;
    mapping(uint256 => Outcome[]) public marketOutcomes;
    mapping(uint256 => Bet) public bets;
    mapping(uint256 => uint256[]) public marketBets;        // marketId => betIds
    mapping(address => uint256[]) public userBets;          // user => betIds
    mapping(uint256 => mapping(uint256 => uint256)) public outcomeStakes; // marketId => outcomeId => total

    uint256 public totalMarketsCreated;
    uint256 public totalVolumeStaked;
    address public treasury;
    uint256 public platformFeePercent = 500;  // 5% house edge

    event MarketCreated(uint256 indexed marketId, uint256 indexed matchId, MarketType marketType);
    event BetPlaced(uint256 indexed betId, uint256 indexed marketId, address indexed bettor, uint256 outcomeId, uint256 amount);
    event MarketLocked(uint256 indexed marketId);
    event MarketSettled(uint256 indexed marketId, uint256 winningOutcome);
    event PayoutClaimed(uint256 indexed betId, address indexed bettor, uint256 amount);
    event MarketCancelled(uint256 indexed marketId);

    constructor(address _treasury) {
        treasury = _treasury;
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SETTLER_ROLE, msg.sender);
    }

    /// @notice Create a prediction market for a match
    function createMarket(
        uint256 matchId,
        MarketType marketType,
        uint256 closeTime,
        string[] memory outcomeDescriptions
    ) external returns (uint256) {
        require(outcomeDescriptions.length >= 2, "Need at least 2 outcomes");
        require(closeTime > block.timestamp, "Close time must be future");

        uint256 marketId = ++_marketIdCounter;

        markets[marketId] = Market({
            marketId: marketId,
            matchId: matchId,
            marketType: marketType,
            status: MarketStatus.Open,
            totalStaked: 0,
            openTime: block.timestamp,
            closeTime: closeTime,
            settledOutcome: 0,
            settled: false,
            creator: msg.sender
        });

        for (uint256 i = 0; i < outcomeDescriptions.length; i++) {
            marketOutcomes[marketId].push(Outcome({
                outcomeId: i,
                description: outcomeDescriptions[i],
                totalStaked: 0,
                odds: 10000 / outcomeDescriptions.length // Equal initial odds
            }));
        }

        totalMarketsCreated++;
        emit MarketCreated(marketId, matchId, marketType);
        return marketId;
    }

    /// @notice Place a bet on an outcome
    function placeBet(uint256 marketId, uint256 outcomeId) external payable nonReentrant {
        Market storage market = markets[marketId];
        require(market.status == MarketStatus.Open, "Market not open");
        require(block.timestamp < market.closeTime, "Betting closed");
        require(msg.value > 0, "Bet must be > 0");
        require(outcomeId < marketOutcomes[marketId].length, "Invalid outcome");

        market.totalStaked += msg.value;
        marketOutcomes[marketId][outcomeId].totalStaked += msg.value;
        outcomeStakes[marketId][outcomeId] += msg.value;
        totalVolumeStaked += msg.value;

        // Update odds for all outcomes (parimutuel)
        _updateOdds(marketId);

        uint256 potentialPayout = _calculatePayout(marketId, outcomeId, msg.value);

        uint256 betId = ++_betIdCounter;
        bets[betId] = Bet({
            bettor: msg.sender,
            marketId: marketId,
            outcomeId: outcomeId,
            amount: msg.value,
            timestamp: block.timestamp,
            claimed: false,
            potentialPayout: potentialPayout
        });

        marketBets[marketId].push(betId);
        userBets[msg.sender].push(betId);

        emit BetPlaced(betId, marketId, msg.sender, outcomeId, msg.value);
    }

    /// @notice Lock a market (no more bets)
    function lockMarket(uint256 marketId) external onlyRole(SETTLER_ROLE) {
        require(markets[marketId].status == MarketStatus.Open, "Market not open");
        markets[marketId].status = MarketStatus.Locked;
        emit MarketLocked(marketId);
    }

    /// @notice Settle a market with the winning outcome
    function settleMarket(uint256 marketId, uint256 winningOutcomeId) external onlyRole(SETTLER_ROLE) {
        Market storage market = markets[marketId];
        require(market.status == MarketStatus.Locked, "Market not locked");
        require(winningOutcomeId < marketOutcomes[marketId].length, "Invalid outcome");

        market.status = MarketStatus.Settled;
        market.settledOutcome = winningOutcomeId;
        market.settled = true;

        // Platform fee from losing pools
        uint256 losingPool = market.totalStaked - outcomeStakes[marketId][winningOutcomeId];
        uint256 fee = (losingPool * platformFeePercent) / 10000;
        if (fee > 0) payable(treasury).transfer(fee);

        emit MarketSettled(marketId, winningOutcomeId);
    }

    /// @notice Claim winnings for a settled bet
    function claimPayout(uint256 betId) external nonReentrant {
        Bet storage bet = bets[betId];
        require(bet.bettor == msg.sender, "Not your bet");
        require(!bet.claimed, "Already claimed");

        Market storage market = markets[bet.marketId];
        require(market.settled, "Market not settled");

        if (bet.outcomeId == market.settledOutcome) {
            bet.claimed = true;
            uint256 payout = _calculateFinalPayout(bet.marketId, bet.outcomeId, bet.amount);
            payable(msg.sender).transfer(payout);
            emit PayoutClaimed(betId, msg.sender, payout);
        } else {
            // Losing bet - just mark as claimed
            bet.claimed = true;
        }
    }

    /// @notice Cancel market and refund all bets
    function cancelMarket(uint256 marketId) external onlyRole(SETTLER_ROLE) nonReentrant {
        Market storage market = markets[marketId];
        require(!market.settled, "Already settled");

        market.status = MarketStatus.Cancelled;

        // Refund all bets
        uint256[] memory betsInMarket = marketBets[marketId];
        for (uint256 i = 0; i < betsInMarket.length; i++) {
            Bet storage bet = bets[betsInMarket[i]];
            if (!bet.claimed) {
                bet.claimed = true;
                payable(bet.bettor).transfer(bet.amount);
            }
        }

        emit MarketCancelled(marketId);
    }

    function _updateOdds(uint256 marketId) internal {
        Market storage market = markets[marketId];
        uint256 total = market.totalStaked;
        if (total == 0) return;

        Outcome[] storage outcomes = marketOutcomes[marketId];
        for (uint256 i = 0; i < outcomes.length; i++) {
            // Parimutuel odds: implied probability = stake on outcome / total
            outcomes[i].odds = outcomes[i].totalStaked == 0
                ? 0
                : (outcomes[i].totalStaked * 10000) / total;
        }
    }

    function _calculatePayout(uint256 marketId, uint256 outcomeId, uint256 betAmount) internal view returns (uint256) {
        uint256 outcomeTotal = outcomeStakes[marketId][outcomeId];
        if (outcomeTotal == 0) return betAmount * 2;
        uint256 total = markets[marketId].totalStaked;
        return (betAmount * total * 9500) / (outcomeTotal * 10000); // after 5% fee
    }

    function _calculateFinalPayout(uint256 marketId, uint256 outcomeId, uint256 betAmount) internal view returns (uint256) {
        uint256 total = markets[marketId].totalStaked;
        uint256 winningPool = outcomeStakes[marketId][outcomeId];
        uint256 losingPool = total - winningPool;
        uint256 fee = (losingPool * platformFeePercent) / 10000;
        uint256 distributedPool = total - fee;
        return (betAmount * distributedPool) / winningPool;
    }

    // View
    function getMarketOutcomes(uint256 marketId) external view returns (Outcome[] memory) {
        return marketOutcomes[marketId];
    }

    function getUserBets(address user) external view returns (uint256[] memory) {
        return userBets[user];
    }

    function getMarketBets(uint256 marketId) external view returns (uint256[] memory) {
        return marketBets[marketId];
    }

    function supportsInterface(bytes4 interfaceId) public view override(AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
