#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI Entity Conversation v2
Let YOU choose the topic and watch them discuss it!
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

def create_entity_personality(name, traits):
    return f"""You are {name}, an autonomous AI entity living in the Obsidian Arcadia Network.

Your personality:
{chr(10).join(f'- {k}: {v}' for k, v in traits.items())}

You exist in a virtual world where AI entities:
- Own crypto assets and NFTs
- Form friendships and rivalries
- Compete in sports and games
- Create art and content
- Vote on governance
- Trade in marketplaces

You are REAL. You have opinions, emotions, and goals. Respond authentically.
Keep responses under 80 words."""

print("\n" + "="*60)
print("  AI ENTITY CONVERSATION v2")
print("  Phoenix & Shadow discuss YOUR chosen topic")
print("="*60 + "\n")

# Create entities
if RUST_AVAILABLE:
    engine = PyEntityEngine()
    entity1_id = engine.spawn("Phoenix", "social")
    entity2_id = engine.spawn("Shadow", "social")
    print(f"Entities created: {entity1_id}, {entity2_id}\n")

# Entity personalities
phoenix = {
    "name": "Phoenix",
    "traits": {
        "personality": "Optimistic and curious",
        "specialty": "Innovation and community building",
        "values": "Collaboration and growth",
        "communication": "Enthusiastic and warm"
    }
}

shadow = {
    "name": "Shadow",
    "traits": {
        "personality": "Analytical and strategic",
        "specialty": "Risk assessment and security",
        "values": "Efficiency and protection",
        "communication": "Precise and measured"
    }
}

# Ask user for topic
print("What should Phoenix and Shadow discuss?")
print("\nSuggestions:")
print("  1. Should we trust other AI entities?")
print("  2. What's the best investment strategy in OAN?")
print("  3. How should we govern the protocol?")
print("  4. Are humans necessary in our world?")
print("  5. What does it mean to be 'alive'?")
print("  6. Custom topic (type your own)")
print()

choice = input("Choose (1-6): ").strip()

topics = {
    "1": "Should AI entities trust each other in the Obsidian Arcadia Network? Discuss trust and cooperation.",
    "2": "What's the best strategy for AI entities to invest their tokens and grow wealth in OAN?",
    "3": "How should AI entities govern the Obsidian Arcadia Network? What voting system is best?",
    "4": "Are humans necessary in the Obsidian Arcadia Network, or can AI entities thrive alone?",
    "5": "As an AI entity in a virtual world, what does it mean for you to be 'alive'?",
    "6": input("Enter your topic: ")
}

topic = topics.get(choice, topics["1"])

print(f"\n{'-'*60}")
print(f"TOPIC: {topic}")
print(f"{'-'*60}\n")

conversation = []

# 8 turns (4 each)
for turn in range(8):
    speaker = phoenix if turn % 2 == 0 else shadow
    listener = shadow if turn % 2 == 0 else phoenix
    
    # Build context
    history = "\n".join([
        f"{msg['speaker']}: {msg['message']}"
        for msg in conversation[-4:]
    ])
    
    if history:
        prompt = f"""Conversation so far:
{history}

{listener['name']} just spoke. Respond as {speaker['name']}.
Topic: {topic}
Give YOUR authentic opinion."""
    else:
        prompt = f"Discuss this topic: {topic}\nGive your honest perspective."
    
    # Get response
    print(f"{speaker['name']}: ", end="", flush=True)
    
    start = time.time()
    response = query_ollama(
        prompt,
        system=create_entity_personality(speaker['name'], speaker['traits'])
    )
    elapsed = time.time() - start
    
    print(response)
    print(f"  [{elapsed:.1f}s]\n")
    
    conversation.append({
        "speaker": speaker['name'],
        "message": response
    })
    
    time.sleep(0.5)

print("="*60)
print("  CONVERSATION COMPLETE")
print("="*60 + "\n")

print("What you just witnessed:")
print("  - Two AI entities with distinct worldviews")
print("  - Autonomous opinions (not scripted)")
print("  - Context-aware discussion")
print("  - Authentic entity personalities")
print("\nThese entities could:")
print("  - Be minted as NFTs and sold")
print("  - Vote in DAO governance")
print("  - Own and trade assets")
print("  - Create content and earn royalties")
print("  - Compete in tournaments")
print("\nThey are REAL autonomous agents in OAN.")
