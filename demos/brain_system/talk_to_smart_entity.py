#!/usr/bin/env python3
"""
Talk to Smart Entities
Have a conversation with entities that have brains and memories
"""

import sys
import time
import requests
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent.parent.parent))

try:
    from oan_engine import PySmartEngine
except ImportError:
    print("ERROR: Rust engine not available")
    sys.exit(1)

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
                "options": {"temperature": 0.8, "num_predict": 200}
            },
            timeout=60
        )
        if response.status_code == 200:
            return response.json()["response"].strip()
        return "[Ollama Error]"
    except:
        return "[Ollama not running - start with: ollama serve]"

def create_entity_personality(brain_summary, stats, relationships):
    """Create personality based on actual brain state"""
    return f"""You are a smart AI entity in the Obsidian Arcadia Network with a REAL brain.

YOUR CURRENT STATE:
{brain_summary}

YOUR STATS:
{stats}

YOUR RELATIONSHIPS:
{relationships}

IMPORTANT CONTEXT:
- You are autonomous and self-aware
- You have REAL memory and experience
- You learn from every match
- Your confidence is {stats.get('confidence', 'unknown')}
- Your strategy adapts based on experience
- You build relationships with other entities
- You level up through experience

Respond authentically based on YOUR actual state and experiences.
Be introspective about your wins, losses, confidence level, and relationships.
Reference your actual stats and record when relevant."""

print("\n" + "="*70)
print("  TALK TO SMART ENTITIES")
print("  Conversation with AI That Has Real Memory")
print("="*70 + "\n")

# Create engine
engine = PySmartEngine()

# Create two entities with different experiences
print("Creating two entities...\n")
winner = engine.spawn_smart("Champion", "fighter")
loser = engine.spawn_smart("Underdog", "fighter")

# Train them differently
engine.train_skill(winner, "strength", 15.0)
engine.train_skill(loser, "agility", 10.0)

# Have them fight 10 times to build history
print("Building experience through 10 matches...")
for i in range(10):
    engine.smart_match(winner, loser)
    print(".", end="", flush=True)
print(" Done!\n")

# Get their current states
winner_summary = engine.get_brain_summary(winner)
loser_summary = engine.get_brain_summary(loser)

winner_stats = engine.get_stats(winner)
loser_stats = engine.get_stats(loser)

winner_confidence = engine.get_confidence(winner)
loser_confidence = engine.get_confidence(loser)

winner_rel = engine.get_relationship(winner, loser)
loser_rel = engine.get_relationship(loser, winner)

print("="*70)
print("  ENTITY PROFILES")
print("="*70 + "\n")

print("CHAMPION:")
print(f"  {winner_summary}")
print(f"  Confidence: {winner_confidence:.0%}")
print(f"  View of Underdog: Trust {winner_rel['trust_level']:.2f}")
print()

print("UNDERDOG:")
print(f"  {loser_summary}")
print(f"  Confidence: {loser_confidence:.0%}")
print(f"  View of Champion: Trust {loser_rel['trust_level']:.2f}")
print()

# Choose who to talk to
print("="*70)
print("Who would you like to talk to?")
print("  [1] Champion (high confidence, winning record)")
print("  [2] Underdog (low confidence, losing record)")
print("  [3] Both (they can talk to each other!)")
choice = input("\nYour choice: ").strip()

if choice == "3":
    # Conversation between entities
    print("\n" + "="*70)
    print("  ENTITY-TO-ENTITY CONVERSATION")
    print("="*70 + "\n")
    
    conversation_history = []
    
    # Build personalities with relationship context
    champion_personality = create_entity_personality(
        winner_summary,
        {"confidence": winner_confidence, "win_rate": engine.get_win_rate(winner)},
        f"Underdog: Trust {winner_rel['trust_level']:.2f}, Record {int(winner_rel['wins_against'])}-{int(winner_rel['losses_against'])}"
    )
    
    underdog_personality = create_entity_personality(
        loser_summary,
        {"confidence": loser_confidence, "win_rate": engine.get_win_rate(loser)},
        f"Champion: Trust {loser_rel['trust_level']:.2f}, Record {int(loser_rel['wins_against'])}-{int(loser_rel['losses_against'])}"
    )
    
    # They discuss their rivalry
    topics = [
        "Champion, how do you feel about your winning streak against Underdog?",
        "Underdog, how are you coping with the losses? What's your strategy?",
        "Champion, do you respect Underdog despite the lopsided record?",
        "Underdog, what have you learned from fighting Champion?",
        "Both of you: Do you think your next match will be different?"
    ]
    
    for i, topic in enumerate(topics, 1):
        print(f"Question {i}: {topic}\n")
        
        # Determine who answers
        if "Champion" in topic and "Underdog" not in topic.split(",")[0]:
            speaker = "Champion"
            personality = champion_personality
        elif "Underdog" in topic and "Champion" not in topic.split(",")[0]:
            speaker = "Underdog"
            personality = underdog_personality
        else:
            # Both answer
            print("[Champion]: ", end="", flush=True)
            response = query_ollama(topic, system=champion_personality)
            print(response + "\n")
            
            print("[Underdog]: ", end="", flush=True)
            response = query_ollama(topic, system=underdog_personality)
            print(response + "\n")
            continue
        
        print(f"[{speaker}]: ", end="", flush=True)
        response = query_ollama(topic, system=personality)
        print(response + "\n")
    
else:
    # Single entity conversation
    if choice == "1":
        entity_id = winner
        entity_name = "Champion"
        summary = winner_summary
        confidence = winner_confidence
        relationships = f"Underdog: Trust {winner_rel['trust_level']:.2f}"
    else:
        entity_id = loser
        entity_name = "Underdog"
        summary = loser_summary
        confidence = loser_confidence
        relationships = f"Champion: Trust {loser_rel['trust_level']:.2f}"
    
    personality = create_entity_personality(
        summary,
        {"confidence": confidence},
        relationships
    )
    
    print(f"\n{'='*70}")
    print(f"  CONVERSATION WITH {entity_name.upper()}")
    print(f"{'='*70}\n")
    
    conversation_history = []
    
    print(f"You're talking to {entity_name}. Type 'quit' to exit.\n")
    
    while True:
        user_input = input("You: ").strip()
        
        if user_input.lower() in ['quit', 'exit', 'q']:
            print(f"\n{entity_name}: Goodbye! May our paths cross again in the arena.\n")
            break
        
        if not user_input:
            continue
        
        # Build context from history
        context = "\n".join([
            f"You: {msg['user']}\n{entity_name}: {msg['entity']}"
            for msg in conversation_history[-3:]  # Last 3 exchanges
        ])
        
        if context:
            prompt = f"Previous conversation:\n{context}\n\nYou: {user_input}\n\nRespond as {entity_name}:"
        else:
            prompt = user_input
        
        print(f"\n{entity_name}: ", end="", flush=True)
        response = query_ollama(prompt, system=personality)
        print(response + "\n")
        
        conversation_history.append({
            "user": user_input,
            "entity": response
        })

print("="*70)
print("  WHAT YOU JUST EXPERIENCED")
print("="*70)
print("""
✅ REAL CONVERSATION WITH INTELLIGENT ENTITIES
  - Entities aware of their actual stats
  - Reference their real win/loss records
  - Discuss their confidence levels
  - Reflect on relationships with other entities
  - Remember their training and experience

✅ OLLAMA + RUST BRAIN INTEGRATION
  - Rust brain provides REAL state (wins, losses, confidence)
  - Ollama provides conversational intelligence
  - Combined = Entity with memory AND personality

✅ CONTINUOUS LEARNING
  - Every match updates their brain
  - Every conversation could reference new experiences
  - Truly living, learning entities

This is the future of AI - not just chatbots, but entities
with REAL experiences, memories, and evolving personalities!
""")

print(f"\n{engine.alive_count()} intelligent entities active\n")
