#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Battle Royale - Last One Standing
100 fighters compete until one remains
"""
from oan_engine import PyEntityEngine, simulate_match
import random
import time

print("\n" + "="*60)
print("  BATTLE ROYALE - 100 FIGHTERS")
print("="*60 + "\n")

# Create 100 fighters
fighters = []
engine = PyEntityEngine()

for i in range(100):
    # Random stats (60-90 range)
    fighter = {
        "strength": random.randint(60, 90),
        "agility": random.randint(60, 90),
        "stamina": random.randint(60, 90),
        "skill": random.randint(60, 90)
    }
    fighters.append(fighter)
    engine.spawn(f"Fighter_{i}", "combat")

print(f"Created 100 fighters with random stats\n")

# Battle Royale - random matchups
start_time = time.time()
alive = list(range(100))
round_num = 1
total_matches = 0

while len(alive) > 1:
    print(f"Round {round_num}: {len(alive)} fighters remaining")
    
    # Random matchups
    random.shuffle(alive)
    survivors = []
    
    for i in range(0, len(alive) - 1, 2):
        f1 = alive[i]
        f2 = alive[i + 1]
        
        result = simulate_match(fighters[f1], fighters[f2])
        winner = f1 if result["score_a"] > result["score_b"] else f2
        survivors.append(winner)
        total_matches += 1
    
    # Handle odd fighter (gets bye)
    if len(alive) % 2 == 1:
        survivors.append(alive[-1])
        print(f"  Fighter_{alive[-1]} gets a bye")
    
    alive = survivors
    round_num += 1

elapsed = time.time() - start_time

print("\n" + "="*60)
print("  CHAMPION CROWNED!")
print("="*60)
print(f"\nChampion: Fighter_{alive[0]}")
print(f"Stats: {fighters[alive[0]]}")
print(f"Rounds survived: {round_num - 1}")
print(f"Total matches fought: {total_matches}")
print(f"Total time: {elapsed:.2f}s")
print(f"Matches/sec: {total_matches/elapsed:.0f}\n")
