"""
Energy Constraint System
Prevents infinite agent actions through resource management
"""

from typing import Dict
from datetime import datetime, timedelta

class EnergySystem:
    """
    Energy-based action throttling
    
    Rules:
    - Trade: -2 energy
    - Analysis: -1 energy
    - Rest: +3 energy per tick
    - Energy regenerates 1 per minute when idle
    """
    
    def __init__(self, max_energy: int = 100):
        self.max_energy = max_energy
        self.current_energy = max_energy
        self.last_action_time = datetime.now()
        
        # Action costs
        self.action_costs = {
            "buy": 2,
            "sell": 2,
            "analyze": 1,
            "train": 3,
            "match": 5,
            "rest": -10,  # Recovers energy
            "idle": 0
        }
    
    def can_afford(self, action: str) -> bool:
        """Check if entity has enough energy for action"""
        cost = self.action_costs.get(action, 1)
        return self.current_energy >= cost
    
    def consume_energy(self, action: str) -> bool:
        """
        Consume energy for action
        Returns True if successful, False if insufficient energy
        """
        cost = self.action_costs.get(action, 1)
        
        if self.current_energy >= cost:
            self.current_energy -= cost
            self.current_energy = max(0, min(self.max_energy, self.current_energy))
            self.last_action_time = datetime.now()
            return True
        return False
    
    def regenerate(self, ticks: int = 1):
        """Passive energy regeneration"""
        regen_amount = ticks
        self.current_energy = min(self.max_energy, self.current_energy + regen_amount)
    
    def rest(self):
        """Active rest to recover energy faster"""
        recovery = abs(self.action_costs["rest"])
        self.current_energy = min(self.max_energy, self.current_energy + recovery)
        print(f"[REST] Recovered {recovery} energy → {self.current_energy}/{self.max_energy}")
    
    def get_status(self) -> Dict:
        """Get current energy status"""
        percentage = (self.current_energy / self.max_energy) * 100
        
        status = "exhausted" if percentage < 20 else \
                 "tired" if percentage < 50 else \
                 "normal" if percentage < 80 else \
                 "energized"
        
        return {
            "current": self.current_energy,
            "max": self.max_energy,
            "percentage": percentage,
            "status": status,
            "can_act": self.current_energy >= 2
        }
    
    def __str__(self):
        status = self.get_status()
        return f"Energy: {status['current']}/{status['max']} ({status['status']})"

# Example usage
if __name__ == "__main__":
    print("Energy System Demo\n")
    
    energy = EnergySystem(max_energy=100)
    
    print(f"Initial: {energy}\n")
    
    # Simulate actions
    actions = ["buy", "analyze", "sell", "train", "match"]
    
    for action in actions:
        if energy.can_afford(action):
            energy.consume_energy(action)
            cost = energy.action_costs[action]
            print(f"Action: {action} (-{cost} energy)")
            print(f"  {energy}")
        else:
            print(f"Action: {action} - INSUFFICIENT ENERGY!")
            print(f"  {energy}")
        print()
    
    # Rest to recover
    print("Taking a rest...")
    energy.rest()
    print(f"  {energy}\n")
    
    # Passive regeneration
    print("Idle for 5 ticks...")
    energy.regenerate(ticks=5)
    print(f"  {energy}\n")
    
    print(f"Final status: {energy.get_status()}")
