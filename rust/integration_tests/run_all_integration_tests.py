#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Run All Integration Tests"""
import subprocess
import sys

tests = [
    ("Full Protocol Integration", "test_full_protocol.py"),
    ("Tournament Simulation", "test_tournament.py"),
    ("Battle Royale", "test_battle_royale.py"),
    ("Full Stack Integration", "test_full_stack.py"),
    ("Ultimate Stress Test", "test_ultimate_stress.py"),
]

print("\n" + "="*60)
print("  OAN PROTOCOL - INTEGRATION TEST SUITE")
print("="*60 + "\n")

passed = 0
failed = 0

for name, script in tests:
    print(f"Running: {name}...")
    result = subprocess.run([sys.executable, script], 
                          capture_output=True, text=True)
    if result.returncode == 0:
        print(f"  PASS\n")
        passed += 1
    else:
        print(f"  FAIL")
        print(result.stderr)
        failed += 1

print("="*60)
print(f"  RESULTS: {passed} passed, {failed} failed")
print("="*60 + "\n")

sys.exit(0 if failed == 0 else 1)
