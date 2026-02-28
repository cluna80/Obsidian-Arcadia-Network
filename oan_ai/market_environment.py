"""
Market Environment Module
Advanced market simulation with realistic dynamics
"""

import random
import math
from typing import Dict, List
from dataclasses import dataclass
from datetime import datetime

@dataclass
class MarketState:
    """Current market conditions"""
    price: float
    volume: float
    buy_pressure: float
    sell_pressure: float
    volatility: float
    liquidity: float
    trend: str  # up, down, sideways
    timestamp: datetime

class MarketEnvironment:
    """
    Realistic market simulation
    
    Price dynamics:
    price = price + (buy_pressure - sell_pressure) * liquidity_factor + noise
    """
    
    def __init__(self, initial_price: float = 52000.0):
        self.price = initial_price
        self.base_price = initial_price
        self.volume = 1000000.0
        self.buy_pressure = 0.5
        self.sell_pressure = 0.5
        self.volatility = 0.02  # 2% default
        self.liquidity = 0.8
        
        self.price_history: List[float] = [initial_price]
        self.volume_history: List[float] = [self.volume]
        
    def update(self, agent_actions: List[Dict] = None):
        """
        Update market state based on agent actions
        
        Args:
            agent_actions: List of {action: 'buy'/'sell', amount: float}
        """
        # Process agent actions
        if agent_actions:
            for action in agent_actions:
                if action["action"] == "buy":
                    self.buy_pressure += action["amount"] * 0.1
                    self.volume += action["amount"] * self.price
                elif action["action"] == "sell":
                    self.sell_pressure += action["amount"] * 0.1
                    self.volume += action["amount"] * self.price
        
        # Decay pressures (mean reversion)
        self.buy_pressure *= 0.95
        self.sell_pressure *= 0.95
        
        # Ensure pressures stay in bounds
        self.buy_pressure = max(0.1, min(2.0, self.buy_pressure))
        self.sell_pressure = max(0.1, min(2.0, self.sell_pressure))
        
        # Calculate price change
        pressure_delta = (self.buy_pressure - self.sell_pressure)
        liquidity_factor = 1.0 / (1.0 + self.liquidity)
        noise = random.gauss(0, self.volatility)
        
        price_change = (pressure_delta * liquidity_factor + noise) * self.price * 0.01
        
        # Update price
        self.price += price_change
        self.price = max(self.price * 0.5, min(self.price * 1.5, self.price))  # Circuit breaker
        
        # Update volume (mean revert to base)
        self.volume = self.volume * 0.9 + 1000000 * 0.1
        
        # Update volatility (increases with large moves)
        if abs(price_change / self.price) > 0.02:
            self.volatility = min(0.10, self.volatility * 1.1)
        else:
            self.volatility = max(0.01, self.volatility * 0.95)
        
        # Track history
        self.price_history.append(self.price)
        self.volume_history.append(self.volume)
        
        # Keep only last 100 ticks
        if len(self.price_history) > 100:
            self.price_history.pop(0)
            self.volume_history.pop(0)
    
    def get_trend(self) -> str:
        """Calculate current trend from recent history"""
        if len(self.price_history) < 5:
            return "sideways"
        
        recent = self.price_history[-5:]
        change = (recent[-1] - recent[0]) / recent[0]
        
        if change > 0.02:
            return "up"
        elif change < -0.02:
            return "down"
        else:
            return "sideways"
    
    def get_state(self) -> MarketState:
        """Get current market state"""
        return MarketState(
            price=self.price,
            volume=self.volume,
            buy_pressure=self.buy_pressure,
            sell_pressure=self.sell_pressure,
            volatility=self.volatility,
            liquidity=self.liquidity,
            trend=self.get_trend(),
            timestamp=datetime.now()
        )
    
    def get_state_dict(self) -> Dict:
        """Get state as dictionary for JSON serialization"""
        state = self.get_state()
        return {
            "price": round(state.price, 2),
            "volume": round(state.volume, 2),
            "buy_pressure": round(state.buy_pressure, 2),
            "sell_pressure": round(state.sell_pressure, 2),
            "volatility": round(state.volatility, 3),
            "liquidity": round(state.liquidity, 2),
            "trend": state.trend
        }

# Example usage
if __name__ == "__main__":
    print("Market Environment Demo\n")
    
    market = MarketEnvironment(initial_price=52000)
    
    print(f"Initial state: {market.get_state_dict()}\n")
    
    # Simulate 10 ticks with random agent activity
    for tick in range(10):
        # Random agent actions
        actions = []
        if random.random() > 0.5:
            actions.append({"action": "buy", "amount": random.uniform(0.1, 0.5)})
        else:
            actions.append({"action": "sell", "amount": random.uniform(0.1, 0.5)})
        
        market.update(actions)
        state = market.get_state_dict()
        
        print(f"Tick {tick + 1}:")
        print(f"  Price: ${state['price']:,.2f}")
        print(f"  Trend: {state['trend']}")
        print(f"  Volatility: {state['volatility']:.1%}")
        print(f"  Buy/Sell: {state['buy_pressure']:.2f} / {state['sell_pressure']:.2f}\n")
    
    print(f"Price movement: ${market.price_history[0]:,.2f} → ${market.price_history[-1]:,.2f}")
    change_pct = ((market.price_history[-1] - market.price_history[0]) / market.price_history[0]) * 100
    print(f"Change: {change_pct:+.2f}%")
