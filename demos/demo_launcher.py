#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OAN Protocol - Demo Launcher
Interactive menu to run all available demos
"""

import os
import sys

def print_banner():
    print("\n" + "="*70)
    print("  OAN PROTOCOL - DEMO LAUNCHER")
    print("  Explore all features of Obsidian Arcadia Network")
    print("="*70 + "\n")

def main():
    print_banner()
    
    demos = {
        "1": {
            "name": "Ì¥ñ AI Entity Conversation",
            "desc": "Two AI entities have autonomous dialogue",
            "path": "ollama_entities/ai_entity_conversation.py",
            "requires": "Ollama"
        },
        "2": {
            "name": "Ì±ë Founding Council Interview",
            "desc": "Meet Obsidian, Nova, Nexus, Echo - ask anything",
            "path": "ollama_entities/oan_founding_council.py",
            "requires": "Ollama"
        },
        "3": {
            "name": "Ìµä AI Battle Arena",
            "desc": "AI fighters strategize and compete",
            "path": "ollama_entities/ai_battle_arena.py",
            "requires": "Ollama"
        },
        "4": {
            "name": "Ìæ¨ AI Movie Director",
            "desc": "Generate movie scripts with AI entities",
            "path": "ollama_entities/ai_movie_director.py",
            "requires": "Ollama"
        },
        "5": {
            "name": "Ì≤∞ Live Economy Simulation (INVESTOR DEMO)",
            "desc": "60-second revenue generation demo",
            "path": "investor_demo/live_economy_demo.py",
            "requires": "Rust Engine"
        },
        "6": {
            "name": "ÌøÜ Tournament Bracket",
            "desc": "64-athlete tournament (41k matches/sec)",
            "path": "../rust/integration_tests/test_tournament.py",
            "requires": "Rust Engine"
        },
        "7": {
            "name": "Ì≤Ä Battle Royale",
            "desc": "100 fighters elimination (52k matches/sec)",
            "path": "../rust/integration_tests/test_battle_royale.py",
            "requires": "Rust Engine"
        },
        "8": {
            "name": "‚ö° Ultimate Stress Test",
            "desc": "Maximum load: 1.5M entities/sec",
            "path": "../rust/integration_tests/test_ultimate_stress.py",
            "requires": "Rust Engine"
        },
        "9": {
            "name": "Ìºë Full Stack Integration",
            "desc": "Entity ‚Üí Training ‚Üí Match ‚Üí NFT",
            "path": "../rust/integration_tests/test_full_stack.py",
            "requires": "Rust Engine"
        },
        "10": {
            "name": "Ì∑™ All Integration Tests",
            "desc": "Run complete test suite (370+ tests)",
            "path": "../rust/integration_tests/run_all_integration_tests.py",
            "requires": "Rust Engine"
        },
        "11": {
            "name": "ÌæÆ Entity Spawning Demo",
            "desc": "Create and manage entities",
            "path": "entity_spawning/",
            "requires": "Python"
        },
        "12": {
            "name": "ÌøõÔ∏è Marketplace Demo",
            "desc": "NFT trading and marketplace",
            "path": "marketplace_demo/",
            "requires": "Python"
        },
        "13": {
            "name": "‚≠ê Reputation System Demo",
            "desc": "Entity reputation tracking",
            "path": "reputation_demo/",
            "requires": "Python"
        },
        "14": {
            "name": "‚öîÔ∏è AI Battle Demo",
            "desc": "Combat simulation",
            "path": "ai_battle/",
            "requires": "Python"
        }
    }
    
    print("Available Demos:\n")
    for key, demo in sorted(demos.items(), key=lambda x: int(x[0])):
        print(f"  [{key:>2}] {demo['name']}")
        print(f"       {demo['desc']}")
        if demo['requires'] != "Python":
            print(f"       Requires: {demo['requires']}")
        print()
    
    print("  [0] Exit\n")
    
    choice = input("Choose a demo (0-14): ").strip()
    
    if choice == "0":
        print("\nGoodbye! Ìºë\n")
        sys.exit(0)
    
    if choice in demos:
        demo = demos[choice]
        print(f"\n{'='*70}")
        print(f"  Launching: {demo['name']}")
        print(f"{'='*70}\n")
        
        if demo['requires'] == "Ollama":
            print("‚ö†Ô∏è  Make sure Ollama is running: ollama serve\n")
        elif demo['requires'] == "Rust Engine":
            print("‚ö†Ô∏è  Requires Rust engine: cd rust/oan-engine && maturin develop --release\n")
        
        demo_path = os.path.join(os.path.dirname(__file__), demo['path'])
        
        if os.path.isdir(demo_path):
            # Find the main script in the directory
            scripts = [f for f in os.listdir(demo_path) if f.endswith('.py')]
            if scripts:
                demo_path = os.path.join(demo_path, scripts[0])
                os.system(f"python {demo_path}")
            else:
                print(f"‚ö†Ô∏è  No Python scripts found in {demo['path']}")
        else:
            os.system(f"python {demo_path}")
    else:
        print("\n‚ùå Invalid choice. Please select 0-14.\n")

if __name__ == "__main__":
    main()
