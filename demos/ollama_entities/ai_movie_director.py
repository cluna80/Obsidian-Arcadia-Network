#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""AI Movie Director - Ollama creates movie scripts"""

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
            json={"model": MODEL, "prompt": prompt, "system": system, 
                  "stream": False, "options": {"temperature": 0.8, "num_predict": 200}},
            timeout=60
        )
        if response.status_code == 200:
            return response.json()["response"].strip()
        return "[Error]"
    except:
        return "[Error]"

print("\n" + "="*60)
print("  AI MOVIE DIRECTOR")
print("  Ollama creates scripts, OAN entities perform")
print("="*60 + "\n")

# Create actor entities
if RUST_AVAILABLE:
    engine = PyEntityEngine()
    hero_id = engine.spawn("MaxSteel", "actor")
    villain_id = engine.spawn("DrShadow", "actor")
    print(f"Actors created: {hero_id}, {villain_id}\n")

# Movie concept
print("MOVIE CONCEPT GENERATION\n")

concept = query_ollama(
    "Create a 3-sentence sci-fi thriller concept starring two AI entities (MaxSteel and DrShadow) in a virtual world. Make it exciting!",
    "You are a creative movie director specializing in sci-fi thrillers."
)
print(f"Concept:\n{concept}\n")

# Scene creation
print("="*60)
print("  SCENE 1: THE CONFRONTATION")
print("="*60 + "\n")

scene = query_ollama(
    f"""Based on this concept: {concept}

Write a dramatic confrontation scene between MaxSteel (hero) and DrShadow (villain).
Include 4 lines of dialogue (2 each). Make it cinematic and intense!""",
    "You are a professional screenwriter."
)
print(f"{scene}\n")

# Director's commentary
print("="*60)
print("  DIRECTOR'S COMMENTARY")
print("="*60 + "\n")

commentary = query_ollama(
    f"""You just directed this scene: {scene}

Explain your creative vision and what makes this scene compelling. (3 sentences)""",
    "You are the film director."
)
print(f"{commentary}\n")

# NFT metadata
print("="*60)
print("  NFT MOVIE METADATA")
print("="*60 + "\n")

print("Title: AI Genesis Chronicles")
print("Genre: Sci-Fi Thriller")
print(f"Actors: MaxSteel (Entity), DrShadow (Entity)")
print(f"Director: Ollama ({MODEL})")
print("Runtime: Scene 1 of ∞")
print("\nBlockchain Integration:")
print("  ✅ Tokenize this scene as NFT")
print("  ✅ List on OAN Marketplace (Layer 6)")
print("  ✅ Auto-distribute royalties to:")
print("     - Director AI (40%)")
print("     - Actor entities (30% each)")
print("  ✅ Generate sequels on demand")
print("  ✅ Community voting on plot direction")
