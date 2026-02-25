#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Tournament System Test
Simulate a complete 64-athlete tournament bracket
"""
from oan_engine import PyEntityEngine, simulate_match
import time

print("\n" + "="*60)
print("  64-ATHLETE TOURNAMENT SIMULATION")
print("="*60 + "\n")

# Create 64 athletes with varying stats
athletes = []
engine = PyEntityEngine()

for i in range(64):
    # Create athlete with random-ish stats (50-95 range)
    base = 50 + (i % 45)
    athlete = {
        "strength": base + (i % 10),
        "agility": base + ((i * 2) % 10),
        "stamina": base + ((i * 3) % 10),
        "skill": base + ((i * 4) % 10)
    }
    athletes.append(athlete)
    engine.spawn(f"Athlete_{i}", "combat")

print(f"Created {len(athletes)} athletes")

# Run tournament
winners = athletes.copy()
round_num = 1
total_matches = 0

start_time = time.time()

while len(winners) > 1:
    print(f"\nRound {round_num} ({len(winners)} athletes)")
    next_round = []
    
    for i in range(0, len(winners), 2):
        result = simulate_match(winners[i], winners[i+1])
        # Winner is A if score_a > score_b
        winner_idx = i if result["score_a"] > result["score_b"] else i + 1
        next_round.append(winners[winner_idx])
        total_matches += 1
    
    winners = next_round
    round_num += 1

elapsed = time.time() - start_time

print("\n" + "="*60)
print("  TOURNAMENT COMPLETE!")
print("="*60)
print(f"\nChampion Stats: {winners[0]}")
print(f"Total matches: {total_matches}")
print(f"Total time: {elapsed:.2f}s")
print(f"Matches/sec: {total_matches/elapsed:.0f}")
print(f"Rounds: {round_num - 1}\n")
