#!/usr/bin/env python3
"""
Smart Entity Demo - Full Brain System Integration
Shows entities learning, adapting, and building relationships
"""

import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from oan_engine import PySmartEngine
except ImportError:
    print("ERROR: Rust engine not built with brain system")
    print("Run: cd rust/oan-engine && maturin develop --release")
    sys.exit(1)

print("\n" + "="*70)
print("  SMART ENTITY DEMO - BRAIN SYSTEM")
print("  Entities Learn, Adapt, and Build Relationships")
print("="*70 + "\n")

# Create engine
engine = PySmartEngine()

# Create two smart entities
print("Creating two learning entities...\n")
fighter_a = engine.spawn_smart("ThunderFist", "fighter")
fighter_b = engine.spawn_smart("ShadowBlade", "fighter")

print(f"ThunderFist: {fighter_a}")
print(f"ShadowBlade: {fighter_b}")
print()

# Show initial stats
print("INITIAL STATE:")
print("-" * 70)
print(engine.get_brain_summary(fighter_a))
print(engine.get_brain_summary(fighter_b))
print()

# Training phase
print("TRAINING PHASE:")
print("-" * 70)
print("ThunderFist trains strength...")
engine.train_skill(fighter_a, "strength", 10.0)
print("ShadowBlade trains agility...")
engine.train_skill(fighter_b, "agility", 10.0)
print()

# Show stats after training
stats_a = engine.get_stats(fighter_a)
stats_b = engine.get_stats(fighter_b)
print(f"ThunderFist stats: {stats_a}")
print(f"ShadowBlade stats: {stats_b}")
print()

# Simulate 15 matches
print("COMBAT PHASE (15 matches):")
print("="*70 + "\n")

for match_num in range(1, 16):
    # Get strategies before match
    strategy_a = engine.get_strategy(fighter_a, fighter_b)
    strategy_b = engine.get_strategy(fighter_b, fighter_a)
    
    # Simulate match
    result = engine.smart_match(fighter_a, fighter_b)
    
    winner_name = "ThunderFist" if result["winner"] == 1.0 else "ShadowBlade"
    
    print(f"Match {match_num}: {winner_name} wins!")
    print(f"  Score: {result['score_a']:.1f} - {result['score_b']:.1f}")
    print(f"  ThunderFist strategy: {strategy_a} | Confidence: {engine.get_confidence(fighter_a):.0%}")
    print(f"  ShadowBlade strategy: {strategy_b} | Confidence: {engine.get_confidence(fighter_b):.0%}")
    print()

# Final analysis
print("="*70)
print("  FINAL RESULTS")
print("="*70 + "\n")

print("ThunderFist:")
print(f"  {engine.get_brain_summary(fighter_a)}")
print(f"  Win Rate: {engine.get_win_rate(fighter_a):.1%}")
print()

print("ShadowBlade:")
print(f"  {engine.get_brain_summary(fighter_b)}")
print(f"  Win Rate: {engine.get_win_rate(fighter_b):.1%}")
print()

# Relationship analysis
print("RELATIONSHIP ANALYSIS:")
print("-" * 70)
rel_a = engine.get_relationship(fighter_a, fighter_b)
rel_b = engine.get_relationship(fighter_b, fighter_a)

print(f"ThunderFist's view of ShadowBlade:")
print(f"  Trust level: {rel_a['trust_level']:.2f}")
print(f"  Record: {int(rel_a['wins_against'])}-{int(rel_a['losses_against'])}")
print(f"  Win rate: {rel_a['win_rate']:.1%}")
print()

print(f"ShadowBlade's view of ThunderFist:")
print(f"  Trust level: {rel_b['trust_level']:.2f}")
print(f"  Record: {int(rel_b['wins_against'])}-{int(rel_b['losses_against'])}")
print(f"  Win rate: {rel_b['win_rate']:.1%}")
print()

print("="*70)
print("  WHAT WAS DEMONSTRATED")
print("="*70)
print("""
LEARNING FROM EXPERIENCE:
  - Entities track wins/losses
  - Confidence adjusts based on performance
  - Experience points accumulate

ADAPTIVE STRATEGIES:
  - Aggressive vs dominant opponents
  - Defensive vs difficult opponents
  - Balanced for even matchups

RELATIONSHIP BUILDING:
  - Trust levels evolve
  - Win/loss history tracked
  - Influences future decisions

SKILL DEVELOPMENT:
  - Training increases skill levels
  - Skills influenced by confidence
  - Experience boosts performance

INTELLIGENCE:
  - Entities make strategic decisions
  - Learn from each interaction
  - Build mental models of opponents

This is TRUE artificial intelligence, not just simulation!
""")

print(f"\n{engine.alive_count()} entities active in OAN with functional brains\n")
