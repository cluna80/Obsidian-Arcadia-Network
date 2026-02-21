import ollama

# Fake entity state (later you'll pull this from your real OAN entity)
entity_state = {
    "name": "FireDrake",
    "energy": 45,
    "reputation": 72,
    "state": "Hunting",
    "opponent_energy": 60
}

available_actions = ["ATTACK", "REST", "HOARD", "FLEE"]

# Prompt the LLM to choose
prompt = f"""
Current entity: {entity_state['name']}
Energy: {entity_state['energy']}
Reputation: {entity_state['reputation']}
Current state: {entity_state['state']}
Opponent energy: {entity_state['opponent_energy']}

Available actions: {', '.join(available_actions)}

Choose ONE action that makes the most sense right now.
Respond ONLY in this format:

ACTION: <one action from the list>
REASON: <very short reason>
"""

response = ollama.chat(
    model='gemma3:12b',  # ← change if you used a different model name
    messages=[
        {'role': 'user', 'content': prompt},
    ],
    options={'temperature': 0.7}  # 0.0 = deterministic, 1.0 = creative
)

print("LLM Decision:")
print(response['message']['content'])