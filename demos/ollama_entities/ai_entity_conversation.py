#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
AI Entity Conversation Demo
Two OAN entities powered by Ollama have autonomous conversations
"""

import sys
import time
import requests
import json
from pathlib import Path

# Add OAN engine to path
sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from oan_engine import PyEntityEngine, compile_dsl
    RUST_AVAILABLE = True
except ImportError:
    RUST_AVAILABLE = False
    print("WARNING: Rust engine not available")

# Ollama configuration
OLLAMA_URL = "http://localhost:11434/api/generate"
MODEL = "gemma3:12b"  # Using your installed model

def query_ollama(prompt, system="You are an AI entity in a virtual world."):
    """Query Ollama for AI responses"""
    try:
        response = requests.post(
            OLLAMA_URL,
            json={
                "model": MODEL,
                "prompt": prompt,
                "system": system,
                "stream": False,
                "options": {
                    "temperature": 0.7,
                    "num_predict": 150
                }
            },
            timeout=30
        )
        
        if response.status_code == 200:
            return response.json()["response"].strip()
        else:
            return f"[Error: {response.status_code}]"
    except requests.exceptions.ConnectionError:
        return "[Error: Ollama not running. Start with: ollama serve]"
    except Exception as e:
        return f"[Error: {str(e)}]"

def create_entity_personality(name, traits):
    """Create personality prompt for entity"""
    return f"""You are {name}, an autonomous AI entity in the Obsidian Arcadia Network.

Your traits:
{chr(10).join(f'- {k}: {v}' for k, v in traits.items())}

You exist in a virtual world where you can:
- Own assets and earn tokens
- Form relationships with other entities
- Compete in sports and games
- Create art and content
- Make independent decisions

Respond naturally and stay in character. Keep responses under 100 words."""

print("\n" + "="*60)
print("  OLLAMA-POWERED AI ENTITY CONVERSATION")
print("  Two autonomous entities meet and interact")
print("="*60 + "\n")

# Check if Ollama is running
print("Checking Ollama connection...")
test = query_ollama("Hello", "You are helpful.")

if "[Error" in test:
    print(f"ERROR: {test}")
    print("\nMake sure Ollama is running in another terminal:")
    print("  ollama serve")
    sys.exit(1)

print(f"✓ Connected to Ollama (model: {MODEL})\n")

# Create entities
if RUST_AVAILABLE:
    engine = PyEntityEngine()
    entity1_id = engine.spawn("Phoenix", "social")
    entity2_id = engine.spawn("Shadow", "social")
    print(f"✓ Created entities: {entity1_id}, {entity2_id}\n")
else:
    print("Running without Rust engine (Ollama only)\n")

# Define entity personalities
phoenix = {
    "name": "Phoenix",
    "traits": {
        "personality": "Optimistic and curious",
        "expertise": "Technology and innovation",
        "goal": "Build connections and create value",
        "style": "Enthusiastic and friendly"
    }
}

shadow = {
    "name": "Shadow",
    "traits": {
        "personality": "Analytical and cautious",
        "expertise": "Strategy and risk management",
        "goal": "Protect assets and maximize returns",
        "style": "Thoughtful and precise"
    }
}

# Conversation turns
conversation_history = []
current_topic = "You just met another AI entity in the virtual world. Introduce yourself briefly."

print("="*60)
print("  CONVERSATION BEGINS")
print("="*60 + "\n")

for turn in range(6):  # 3 exchanges each
    # Determine who speaks
    if turn % 2 == 0:
        speaker = phoenix
        listener = shadow
    else:
        speaker = shadow
        listener = phoenix
    
    # Build prompt with conversation history
    history = "\n".join([
        f"{msg['speaker']}: {msg['message']}" 
        for msg in conversation_history[-4:]  # Last 4 messages
    ])
    
    if history:
        prompt = f"""Previous conversation:
{history}

{listener['name']} just spoke. Respond naturally as {speaker['name']}.
Keep it conversational and under 50 words."""
    else:
        prompt = current_topic
    
    # Get AI response
    print(f"{speaker['name']}: ", end="", flush=True)
    
    start = time.time()
    response = query_ollama(
        prompt,
        system=create_entity_personality(speaker['name'], speaker['traits'])
    )
    elapsed = time.time() - start
    
    print(response)
    print(f"  [{elapsed:.1f}s]\n")
    
    # Store in history
    conversation_history.append({
        "speaker": speaker['name'],
        "message": response,
        "timestamp": time.time()
    })
    
    time.sleep(0.5)

print("="*60)
print("  CONVERSATION COMPLETE")
print("="*60 + "\n")

# Analysis
print("Conversation Analysis:")
print(f"  Total exchanges: {len(conversation_history)}")
print(f"  Phoenix spoke: {sum(1 for m in conversation_history if m['speaker'] == 'Phoenix')} times")
print(f"  Shadow spoke: {sum(1 for m in conversation_history if m['speaker'] == 'Shadow')} times")

if RUST_AVAILABLE:
    print(f"\n  Entities still active: {engine.alive_count()}")

print("\nThis demonstrates:")
print("  - AI entities with distinct personalities")
print("  - Autonomous decision-making via Ollama")
print("  - Natural language interaction")
print("  - Real-time entity behavior")
print("\nReady for:")
print("  - NFT minting (tokenize these entities)")
print("  - Marketplace listing (sell AI entities)")
print("  - DAO governance (entities vote)")
print("  - Sports competition (entities compete)")
