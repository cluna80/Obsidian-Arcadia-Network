#!/usr/bin/env python3
"""
Test Entity Brain System
Shows entities learning and adapting
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

print("\n" + "="*70)
print("  ENTITY BRAIN SYSTEM TEST")
print("  Watching Entities Learn and Adapt")
print("="*70 + "\n")

print("NOTE: Full brain integration requires Rust recompilation")
print("This demonstrates the CONCEPT with simulation\n")

# Simulate brain functionality
class EntityBrainSim:
    def __init__(self, entity_id):
        self.entity_id = entity_id
        self.wins = 0
        self.losses = 0
        self.confidence = 0.5
        self.experience = 0
        self.relationships = {}
        self.strategy = "Balanced"
        
    def learn_from_match(self, opponent_id, won):
        if won:
            self.wins += 1
            self.confidence = min(1.0, self.confidence + 0.02)
            self.experience += 10
        else:
            self.losses += 1
            self.confidence = max(0.0, self.confidence - 0.01)
            self.experience += 5
            
        # Update relationship
        if opponent_id not in self.relationships:
            self.relationships[opponent_id] = {"wins": 0, "losses": 0}
            
        if won:
            self.relationships[opponent_id]["wins"] += 1
        else:
            self.relationships[opponent_id]["losses"] += 1
            
    def decide_strategy(self, opponent_id):
        if opponent_id in self.relationships:
            rel = self.relationships[opponent_id]
            total = rel["wins"] + rel["losses"]
            if total > 0:
                win_rate = rel["wins"] / total
                if win_rate > 0.7:
                    return "Aggressive"
                elif win_rate < 0.3:
                    return "Defensive"
        return "Balanced"
    
    def win_rate(self):
        total = self.wins + self.losses
        return self.wins / total if total > 0 else 0.0

# Create two entities
print("Creating two learning entities...\n")
fighter_a = EntityBrainSim("FighterA")
fighter_b = EntityBrainSim("FighterB")

print(f"{fighter_a.entity_id}: Confidence {fighter_a.confidence:.0%} | Strategy: {fighter_a.strategy}")
print(f"{fighter_b.entity_id}: Confidence {fighter_b.confidence:.0%} | Strategy: {fighter_b.strategy}")
print()

# Simulate 20 matches
print("Simulating 20 matches...\n")

import random

for match_num in range(1, 21):
    # Fighter A decides strategy
    strategy_a = fighter_a.decide_strategy(fighter_b.entity_id)
    strategy_b = fighter_b.decide_strategy(fighter_a.entity_id)
    
    # Simulate match (simplified)
    a_score = random.uniform(80, 120) * fighter_a.confidence
    b_score = random.uniform(80, 120) * fighter_b.confidence
    
    # Apply strategy bonuses
    if strategy_a == "Aggressive":
        a_score *= 1.2
    elif strategy_a == "Defensive":
        a_score *= 0.9
        
    if strategy_b == "Aggressive":
        b_score *= 1.2
    elif strategy_b == "Defensive":
        b_score *= 0.9
    
    a_won = a_score > b_score
    
    # Both learn
    fighter_a.learn_from_match(fighter_b.entity_id, a_won)
    fighter_b.learn_from_match(fighter_a.entity_id, not a_won)
    
    winner = fighter_a.entity_id if a_won else fighter_b.entity_id
    
    print(f"Match {match_num}: {winner} wins")
    print(f"  {fighter_a.entity_id}: {strategy_a} → Confidence {fighter_a.confidence:.0%}")
    print(f"  {fighter_b.entity_id}: {strategy_b} → Confidence {fighter_b.confidence:.0%}")
    print()

# Final stats
print("="*70)
print("  FINAL RESULTS")
print("="*70 + "\n")

print(f"{fighter_a.entity_id}:")
print(f"  Record: {fighter_a.wins}-{fighter_a.losses} ({fighter_a.win_rate():.1%})")
print(f"  Confidence: {fighter_a.confidence:.0%}")
print(f"  Experience: {fighter_a.experience} XP")
print(f"  Strategy vs {fighter_b.entity_id}: {fighter_a.decide_strategy(fighter_b.entity_id)}")
print()

print(f"{fighter_b.entity_id}:")
print(f"  Record: {fighter_b.wins}-{fighter_b.losses} ({fighter_b.win_rate():.1%})")
print(f"  Confidence: {fighter_b.confidence:.0%}")
print(f"  Experience: {fighter_b.experience} XP")
print(f"  Strategy vs {fighter_a.entity_id}: {fighter_b.decide_strategy(fighter_a.entity_id)}")

print("\n" + "="*70)
print("  WHAT THIS DEMONSTRATES")
print("="*70)
print("""
Entity Brain Features:
  ✅ Learning from wins/losses
  ✅ Confidence adjustment
  ✅ Experience accumulation
  ✅ Relationship tracking
  ✅ Strategy adaptation
  ✅ Win rate analysis

Next Steps:
  1. Rebuild Rust engine with brain module
  2. Full integration with match system
  3. Long-term memory patterns
  4. Skill leveling system
  5. Goal tracking
  6. Advanced decision trees

This makes entities TRULY intelligent!
""")
