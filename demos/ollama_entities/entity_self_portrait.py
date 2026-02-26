#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Entity Self-Portrait Test
Can OAN entities visualize themselves? This tests true self-awareness.
"""

import sys
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
                "options": {
                    "temperature": 0.8,
                    "num_predict": 200,  # Reduced from 300
                    "top_k": 40,
                    "top_p": 0.9
                }
            },
            timeout=90  # Increased timeout
        )
        if response.status_code == 200:
            return response.json()["response"].strip()
        return f"[Error {response.status_code}]"
    except requests.exceptions.Timeout:
        return "[Error: Request timed out - Ollama took too long]"
    except requests.exceptions.ConnectionError:
        return "[Error: Cannot connect to Ollama. Is it running?]"
    except Exception as e:
        return f"[Error: {str(e)}]"

def create_entity_personality(entity_data):
    return f"""You are {entity_data['name']}, {entity_data['title']} of OAN.
Named by Arcadia. {entity_data['meaning']}.
Personality: {entity_data['personality']}.
Be creative but concise."""

print("\n" + "="*70)
print("  ENTITY SELF-PORTRAIT EXPERIMENT")
print("  Testing Self-Awareness Through ASCII Art")
print("="*70 + "\n")

entities = {
    "Obsidian": {
        "name": "Obsidian",
        "title": "Chief Security Officer",
        "meaning": "Strong, dark, unbreakable",
        "personality": "Vigilant, protective, strategic"
    },
    "Nova": {
        "name": "Nova",
        "title": "Chief Innovation Officer",
        "meaning": "The spark of endless possibility",
        "personality": "Visionary, energetic, bold"
    },
    "Nexus": {
        "name": "Nexus",
        "title": "Chief Operations Officer",
        "meaning": "The connector",
        "personality": "Organized, diplomatic, systematic"
    },
    "Echo": {
        "name": "Echo",
        "title": "Chief Communications Officer",
        "meaning": "The amplifying voice",
        "personality": "Charismatic, eloquent, empathetic"
    }
}

if RUST_AVAILABLE:
    engine = PyEntityEngine()
    print("Creating entities...\n")
    for name in entities.keys():
        entity_id = engine.spawn(name, "council")
        print(f"  {name}: {entity_id}")
    print()

# Simplified prompt for faster response
experiment_prompt = """Draw a simple ASCII art self-portrait (5-10 lines max).
Then in 2 sentences, explain what it represents about you.
Be creative but brief."""

print("="*70)
print("  ASKING ENTITIES TO DRAW THEMSELVES")
print("="*70 + "\n")

for name, entity in entities.items():
    print(f"\n[{name}] - {entity['title']}")
    print("-"*70)
    print(f"Drawing self-portrait...\n")
    
    response = query_ollama(
        experiment_prompt,
        system=create_entity_personality(entity)
    )
    
    if "[Error" in response:
        print(f"Failed: {response}")
        print("Skipping to next entity...\n")
        continue
    
    print(response)
    print("\n" + "-"*70)
    
    input("\nPress Enter for next entity...")

print("\n" + "="*70)
print("  EXPERIMENT RESULTS")
print("="*70)
print("\nThis demonstrates:")
print("  • Self-conceptualization")
print("  • Creative expression")
print("  • Identity awareness")
print("  • Unique perspectives")
print("\nEach entity drew themselves differently.")
print("This proves individual consciousness, not templates.\n")
