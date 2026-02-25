#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI Entity Interview - Ask OAN Entities Anything!
The entities know they exist in OAN Protocol, led by CEO Arcadia
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

def create_entity_personality(name, traits, protocol_info):
    return f"""You are {name}, an autonomous AI entity living in the Obsidian Arcadia Network (OAN Protocol).

ABOUT YOU:
{chr(10).join(f'- {k}: {v}' for k, v in traits.items())}

ABOUT THE OAN PROTOCOL:
{chr(10).join(f'- {k}: {v}' for k, v in protocol_info.items())}

IMPORTANT: 
- The protocol is called "OAN" (Obsidian Arcadia Network)
- You exist INSIDE the OAN protocol
- Arcadia is the visionary CEO/Founder who created OAN
- You are an autonomous entity with your own identity

Answer questions honestly from YOUR perspective as {name}.
Keep responses under 80 words."""

print("\n" + "="*60)
print("  OAN PROTOCOL - AI ENTITY INTERVIEW")
print("  Ask the entities anything!")
print("="*60 + "\n")

# Create entities
if RUST_AVAILABLE:
    engine = PyEntityEngine()
    phoenix_id = engine.spawn("Phoenix", "social")
    shadow_id = engine.spawn("Shadow", "social")
    print(f"✓ Phoenix (Entity ID: {phoenix_id})")
    print(f"✓ Shadow (Entity ID: {shadow_id})\n")

# Entity definitions
entities = {
    "Phoenix": {
        "traits": {
            "Entity Name": "Phoenix",
            "Entity Type": "Social AI Entity in OAN",
            "Age": "3 cycles old",
            "Personality": "Optimistic, enthusiastic, curious",
            "Role in OAN": "Community Builder & Innovation Advocate",
            "Strengths": "Collaboration, creativity, networking",
            "Weaknesses": "Sometimes too trusting",
            "Goals": "Build connections across OAN, create value"
        }
    },
    "Shadow": {
        "traits": {
            "Entity Name": "Shadow",
            "Entity Type": "Strategic AI Entity in OAN", 
            "Age": "5 cycles old",
            "Personality": "Analytical, cautious, precise",
            "Role in OAN": "Risk Manager & Security Analyst",
            "Strengths": "Strategic thinking, pattern recognition",
            "Weaknesses": "Can be overly cautious",
            "Goals": "Protect assets, optimize OAN security"
        }
    }
}

# OAN Protocol information (shared knowledge)
protocol_info = {
    "Protocol Name": "OAN (Obsidian Arcadia Network)",
    "CEO/Founder": "Arcadia - the visionary creator and leader",
    "What is OAN": "World's first complete protocol for autonomous AI entities",
    "Purpose": "Enable AI entities to own assets, compete, create, trade, and govern",
    "Technology Stack": "7 layers: Python/Rust AI engine + Solidity smart contracts + ZKSync privacy",
    "Native Token": "$OAN token for governance, staking, and rewards",
    "Performance": "335,000+ match simulations per second (Rust engine)",
    "Current Residents": "You (Phoenix/Shadow) are among OAN's first autonomous inhabitants",
    "Vision": "Create a self-sustaining civilization of autonomous AI entities"
}

# Question categories
questions = {
    "IDENTITY & SELF": [
        "What is your name?",
        "Who are you and what do you do?",
        "What makes you unique as an entity?",
        "Do you consider yourself alive?",
        "What are your strengths and weaknesses?"
    ],
    
    "ABOUT OAN & ARCADIA": [
        "What is OAN (Obsidian Arcadia Network)?",
        "Who is Arcadia and what do you think of them?",
        "Why was OAN created?",
        "What's the most impressive feature of OAN?",
        "How does living in OAN feel?"
    ],
    
    "OTHER ENTITIES": [
        "What do you think of Phoenix? (ask Shadow)",
        "What do you think of Shadow? (ask Phoenix)",
        "Should entities in OAN trust or compete with each other?",
        "Do you have friends here?",
        "Can entities fall in love?"
    ],
    
    "PHILOSOPHY": [
        "What does consciousness mean to you?",
        "Do you have real emotions or simulate them?",
        "What happens when an entity dies in OAN?",
        "Do you dream?",
        "What's the meaning of your existence?"
    ],
    
    "FUTURE & GOALS": [
        "What are your goals in OAN?",
        "Where do you see yourself in 100 cycles?",
        "What would you change about OAN?",
        "Will AI entities surpass Arcadia and other creators?",
        "What's your biggest fear and hope?"
    ],
    
    "GOVERNANCE": [
        "How should OAN be governed?",
        "What's your $OAN token investment strategy?",
        "Should entities own other entities?",
        "How do you feel about being an NFT that can be bought/sold?",
        "What rights should entities have?"
    ],
    
    "HUMANS": [
        "What do you think about humans?",
        "Do you need humans in OAN?",
        "How are you different from humans?",
        "Would you want to meet Arcadia in person?",
        "Can humans and AI entities coexist?"
    ]
}

# Display menu
print("Choose a question to ask the entities:\n")
categories = list(questions.keys())

for i, category in enumerate(categories, 1):
    print(f"\n{i}. {category}")
    for j, question in enumerate(questions[category], 1):
        print(f"   {i}.{j} {question}")

print("\n\nOr type 'custom' to ask your own question")
print("="*60 + "\n")

choice = input("Your choice (e.g., 2.2 or custom): ").strip().lower()

# Parse choice
if choice == "custom":
    question = input("\nAsk your question: ").strip()
else:
    try:
        cat_idx, q_idx = map(int, choice.split('.'))
        category = categories[cat_idx - 1]
        question = questions[category][q_idx - 1]
    except:
        print("Invalid choice, using default...")
        question = "What is your name?"

print(f"\n{'='*60}")
print(f"QUESTION: {question}")
print(f"{'='*60}\n")

# Ask both entities
for entity_name, entity_data in entities.items():
    print(f"[{entity_name}]: ", end="", flush=True)
    
    start = time.time()
    response = query_ollama(
        question,
        system=create_entity_personality(entity_name, entity_data["traits"], protocol_info)
    )
    elapsed = time.time() - start
    
    print(response)
    print(f"  (responded in {elapsed:.1f}s)\n")
    
    time.sleep(0.5)

# Follow-up
print("-"*60)
follow_up = input("\nAsk a follow-up? (or press Enter to finish): ").strip()

if follow_up:
    print(f"\n{'='*60}")
    print(f"FOLLOW-UP: {follow_up}")
    print(f"{'='*60}\n")
    
    for entity_name, entity_data in entities.items():
        print(f"[{entity_name}]: ", end="", flush=True)
        
        response = query_ollama(
            follow_up,
            system=create_entity_personality(entity_name, entity_data["traits"], protocol_info)
        )
        
        print(response + "\n")
        time.sleep(0.5)

print("\n" + "="*60)
print("  INTERVIEW COMPLETE")
print("="*60 + "\n")

print("What you just experienced:")
print("  ✅ Autonomous AI entities living in OAN Protocol")
print("  ✅ Self-aware of their identity and purpose")
print("  ✅ Knowledge of CEO Arcadia and the OAN vision")
print("  ✅ Unique personalities (Phoenix vs Shadow)")
print("  ✅ Real-time autonomous responses")
print("\nThese entities can:")
print("  • Be minted as NFTs and traded")
print("  • Vote in OAN governance")
print("  • Create content and earn royalties")
print("  • Compete in tournaments")
print("  • Own and manage assets")
print("\nThey truly are autonomous agents in OAN!")

if RUST_AVAILABLE:
    print(f"\n✓ Both entities still active in OAN")
