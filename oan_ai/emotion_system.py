"""
Emotional State Engine
Manages entity emotions and their influence on decisions
"""

from enum import Enum
from typing import Dict
import random

class Emotion(Enum):
    CALM = "calm"
    GREEDY = "greedy"
    FEARFUL = "fearful"
    AGGRESSIVE = "aggressive"

class EmotionSystem:
    """
    Emotion state machine for entities
    Emotions transition based on performance and market conditions
    """
    
    def __init__(self):
        self.current_emotion = Emotion.CALM
        self.emotion_intensity = 0.5  # 0-1
        
    def update_emotion(self, 
                      profit: float, 
                      market_volatility: float,
                      win_rate: float) -> Emotion:
        """
        Update emotion based on context
        
        Triggers:
        - Recent profit → greedy
        - Recent loss → fearful
        - High volatility → aggressive
        - Stable performance → calm
        """
        
        # Profit influence
        if profit > 100:
            self.current_emotion = Emotion.GREEDY
            self.emotion_intensity = min(1.0, profit / 500)
            
        elif profit < -100:
            self.current_emotion = Emotion.FEARFUL
            self.emotion_intensity = min(1.0, abs(profit) / 500)
            
        # Volatility influence
        elif market_volatility > 0.1:
            self.current_emotion = Emotion.AGGRESSIVE
            self.emotion_intensity = market_volatility
            
        # Return to calm if stable
        elif 0.4 < win_rate < 0.6:
            self.current_emotion = Emotion.CALM
            self.emotion_intensity = 0.5
        
        return self.current_emotion
    
    def get_emotion_modifiers(self) -> Dict[str, float]:
        """
        Get decision modifiers based on emotion
        
        Returns multipliers for:
        - trade_size: How much to trade
        - risk_tolerance: Willingness to take risks
        - patience: How long to wait
        """
        
        modifiers = {
            Emotion.CALM: {
                "trade_size": 1.0,
                "risk_tolerance": 1.0,
                "patience": 1.0
            },
            Emotion.GREEDY: {
                "trade_size": 1.5,  # Larger trades
                "risk_tolerance": 1.3,  # More risk
                "patience": 0.7  # Less patient
            },
            Emotion.FEARFUL: {
                "trade_size": 0.5,  # Smaller trades
                "risk_tolerance": 0.6,  # Less risk
                "patience": 1.5  # More patient
            },
            Emotion.AGGRESSIVE: {
                "trade_size": 1.2,
                "risk_tolerance": 1.4,
                "patience": 0.5  # Very impatient
            }
        }
        
        return modifiers[self.current_emotion]
    
    def __str__(self):
        return f"{self.current_emotion.value} (intensity: {self.emotion_intensity:.2f})"

# Example usage
if __name__ == "__main__":
    emotion_system = EmotionSystem()
    
    print("Emotion System Demo\n")
    
    # Scenario 1: Big profit
    print("Scenario 1: Made $200 profit")
    emotion = emotion_system.update_emotion(profit=200, market_volatility=0.05, win_rate=0.7)
    print(f"  Emotion: {emotion_system}")
    print(f"  Modifiers: {emotion_system.get_emotion_modifiers()}\n")
    
    # Scenario 2: Big loss
    print("Scenario 2: Lost $150")
    emotion = emotion_system.update_emotion(profit=-150, market_volatility=0.05, win_rate=0.3)
    print(f"  Emotion: {emotion_system}")
    print(f"  Modifiers: {emotion_system.get_emotion_modifiers()}\n")
    
    # Scenario 3: High volatility
    print("Scenario 3: Volatile market")
    emotion = emotion_system.update_emotion(profit=0, market_volatility=0.15, win_rate=0.5)
    print(f"  Emotion: {emotion_system}")
    print(f"  Modifiers: {emotion_system.get_emotion_modifiers()}\n")
