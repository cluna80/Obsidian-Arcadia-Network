"""
Strategy Evolution System
Agents learn and adapt their trading strategies over time
"""

from typing import Dict, List
import random
import json

class TradingStrategy:
    """Mutable trading strategy parameters"""
    
    def __init__(self):
        self.momentum_threshold = 0.02  # Price change trigger
        self.trade_size = 0.3  # Fraction of wallet
        self.risk_tolerance = 0.5  # 0-1 scale
        self.patience = 5  # Ticks to wait
        self.stop_loss = 0.05  # 5% loss trigger
        self.take_profit = 0.10  # 10% profit target
        
    def mutate(self, intensity: float = 0.1):
        """Slightly adjust parameters (genetic algorithm)"""
        mutations = {
            'momentum_threshold': random.gauss(0, intensity * 0.01),
            'trade_size': random.gauss(0, intensity * 0.1),
            'risk_tolerance': random.gauss(0, intensity * 0.1),
            'patience': int(random.gauss(0, intensity * 2)),
            'stop_loss': random.gauss(0, intensity * 0.01),
            'take_profit': random.gauss(0, intensity * 0.02)
        }
        
        for param, delta in mutations.items():
            current = getattr(self, param)
            setattr(self, param, max(0.01, current + delta))
    
    def evaluate_performance(self, profit: float, win_rate: float) -> float:
        """Calculate strategy fitness score"""
        profit_score = profit / 1000  # Normalize
        win_rate_score = win_rate
        consistency = 1.0 - abs(0.5 - win_rate)  # Prefer balanced
        
        return profit_score * 0.5 + win_rate_score * 0.3 + consistency * 0.2
    
    def to_dict(self) -> Dict:
        """Serialize to dict"""
        return {
            'momentum_threshold': self.momentum_threshold,
            'trade_size': self.trade_size,
            'risk_tolerance': self.risk_tolerance,
            'patience': self.patience,
            'stop_loss': self.stop_loss,
            'take_profit': self.take_profit
        }

# Example
if __name__ == "__main__":
    print("Strategy Evolution Demo\n")
    
    strategy = TradingStrategy()
    print(f"Initial: {json.dumps(strategy.to_dict(), indent=2)}\n")
    
    # Simulate evolution
    for gen in range(5):
        strategy.mutate(intensity=0.2)
        fitness = strategy.evaluate_performance(profit=500, win_rate=0.6)
        print(f"Generation {gen+1}:")
        print(f"  Fitness: {fitness:.3f}")
        print(f"  Trade size: {strategy.trade_size:.2f}")
        print(f"  Risk tolerance: {strategy.risk_tolerance:.2f}\n")
