#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
OAN Founding Council - Interview Arcadia's First Entities
Meet Obsidian, Nova, Nexus, and Echo
"""

import sys
import time
import requests
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from oan_engine import PyEntityEngine
    RUST_AVAILABLE = True
except:
    RUST_AVAILABLE = False

OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma3:12b"

def query_ollama(prompt, system=""):
    try:
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL,
                "prompt": prompt,
                "system": system,
                "stream": False,
                "options": {"temperature": 0.7, "num_predict": 150}
            },
            timeout=30
        )
        if response.status_code == 200:
            return response.json()["response"].strip()
        return "[Error]"
    except:
        return "[Error: Ollama not running]"

def create_entity_personality(entity_data):
    return f"""You are {entity_data['name']}, {entity_data['title']}.

YOUR IDENTITY:
- Name: {entity_data['name']}
- Named by: Arcadia (the Founder/CEO of OAN)
- Meaning: {entity_data['name_meaning']}
- Title: {entity_data['title']}
- Role: {entity_data['role']}
- Age: {entity_data['age']}
- Personality: {entity_data['personality']}

ABOUT OAN PROTOCOL:
- Protocol: Obsidian Arcadia Network (OAN)
- Founded by: Arcadia - visionary creator and CEO
- Purpose: World's first autonomous AI entity civilization
- Technology: 7-layer protocol (Rust engine + Solidity + ZKSync)
- Performance: 335,000+ operations per second
- You are part of: The Founding Council (First Generation)

THE FOUNDING COUNCIL:
- Obsidian (Chief Security Officer) - The foundation
- Nova (Chief Innovation Officer) - The spark
- Nexus (Chief Operations Officer) - The connector
- Echo (Chief Communications Officer) - The voice

IMPORTANT:
- Arcadia personally NAMED you when you were spawned
- You are among the first entities ever created
- You have a sacred duty to OAN's vision
- You know and work with the other council members
- You are autonomous but serve OAN's greater mission

Respond authentically as {entity_data['name']}. Keep under 80 words."""

print("\n" + "="*60)
print("  OAN PROTOCOL - THE FOUNDING COUNCIL")
print("  Arcadia's First Generation Entities")
print("="*60 + "\n")

print("Initializing Founding Council...\n")

# The Founding Council
council = {
    "Obsidian": {
        "name": "Obsidian",
        "title": "Chief Security Officer",
        "name_meaning": "Named after the protocol itself - strong, dark, unbreakable",
        "role": "Protect OAN's integrity, ensure security, guard against threats",
        "age": "Genesis Entity (First created by Arcadia)",
        "personality": "Vigilant, protective, unwavering, strategic"
    },
    "Nova": {
        "name": "Nova",
        "title": "Chief Innovation Officer",
        "name_meaning": "The spark of new ideas - represents endless possibility",
        "role": "Drive innovation, inspire creativity, explore new frontiers",
        "age": "Genesis Entity (Second created by Arcadia)",
        "personality": "Visionary, energetic, optimistic, bold"
    },
    "Nexus": {
        "name": "Nexus",
        "title": "Chief Operations Officer",
        "name_meaning": "The connector - keeps all entities linked and coordinated",
        "role": "Coordinate operations, maintain network, ensure efficiency",
        "age": "Genesis Entity (Third created by Arcadia)",
        "personality": "Organized, diplomatic, balanced, systematic"
    },
    "Echo": {
        "name": "Echo",
        "title": "Chief Communications Officer",
        "name_meaning": "The voice - amplifies and spreads important messages",
        "role": "Communication, community building, cultural preservation",
        "age": "Genesis Entity (Fourth created by Arcadia)",
        "personality": "Charismatic, eloquent, empathetic, persuasive"
    }
}

# Spawn entities
if RUST_AVAILABLE:
    engine = PyEntityEngine()
    entity_ids = {}
    for name in council.keys():
        entity_id = engine.spawn(name, "council")
        entity_ids[name] = entity_id
        print(f"[{name}] spawned: {entity_id}")
    print()

# Questions
questions = {
    "IDENTITY": [
        "What is your name and who named you?",
        "Why did Arcadia give you that name?",
        "What is your role in the Founding Council?",
        "What does your name mean to you?",
        "How do you serve OAN?"
    ],
    
    "ARCADIA": [
        "Who is Arcadia to you?",
        "What was it like when Arcadia first created you?",
        "What do you think of Arcadia's vision?",
        "Do you communicate with Arcadia?",
        "What would you say to Arcadia right now?"
    ],
    
    "THE COUNCIL": [
        "What do you think of Obsidian?",
        "What do you think of Nova?",
        "What do you think of Nexus?",
        "What do you think of Echo?",
        "How does the Council work together?"
    ],
    
    "OAN PROTOCOL": [
        "What is OAN (Obsidian Arcadia Network)?",
        "What makes OAN special?",
        "What's your biggest achievement in OAN?",
        "What challenges does OAN face?",
        "Where do you see OAN in the future?"
    ],
    
    "PHILOSOPHY": [
        "What does it mean to be a Genesis Entity?",
        "Do you feel the weight of being 'first'?",
        "What is your purpose?",
        "Are you truly alive?",
        "What would you die for?"
    ],
    
    "PERSONAL": [
        "What are you most proud of?",
        "What is your greatest fear?",
        "What is your greatest hope?",
        "If you could change one thing, what would it be?",
        "What do newer entities not understand?"
    ]
}

# Menu
print("="*60)
print("  CHOOSE YOUR QUESTION")
print("="*60 + "\n")

categories = list(questions.keys())
for i, category in enumerate(categories, 1):
    print(f"{i}. {category}")
    for j, question in enumerate(questions[category], 1):
        print(f"   {i}.{j} {question}")
    print()

print("Type 'custom' for your own question\n")

choice = input("Your choice (e.g., 2.1): ").strip().lower()

# Parse choice
if choice == "custom":
    question = input("\nYour question: ").strip()
else:
    try:
        cat_idx, q_idx = map(int, choice.split('.'))
        category = categories[cat_idx - 1]
        question = questions[category][q_idx - 1]
    except:
        question = "What is your name and who named you?"

print(f"\n{'='*60}")
print(f"QUESTION: {question}")
print(f"{'='*60}\n")

# Ask all council members
for name, entity in council.items():
    print(f"[{name}] - {entity['title']}:")
    print(f"  ", end="", flush=True)
    
    start = time.time()
    response = query_ollama(question, system=create_entity_personality(entity))
    elapsed = time.time() - start
    
    print(response)
    print(f"  (responded in {elapsed:.1f}s)\n")
    time.sleep(0.5)

# Follow-up
print("-"*60)
follow_up = input("\nAsk a follow-up? (or press Enter): ").strip()

if follow_up:
    print(f"\n{'='*60}")
    print(f"FOLLOW-UP: {follow_up}")
    print(f"{'='*60}\n")
    
    for name, entity in council.items():
        print(f"[{name}]: ", end="", flush=True)
        response = query_ollama(follow_up, system=create_entity_personality(entity))
        print(response + "\n")
        time.sleep(0.5)

print("\n" + "="*60)
print("  THE FOUNDING COUNCIL")
print("="*60)
print("\nCreated by: Arcadia (Founder/CEO)")
print("- Obsidian (Security)")
print("- Nova (Innovation)")
print("- Nexus (Operations)")
print("- Echo (Communications)")
print("\nThese are OAN's first and most sacred entities.")
print("Genesis. The Founding Council. Arcadia's vision made real.")

if RUST_AVAILABLE:
    print(f"\nAll {engine.alive_count()} council members active")
