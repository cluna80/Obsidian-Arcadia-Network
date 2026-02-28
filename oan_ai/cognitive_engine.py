"""
Cognitive Engine - LangGraph Decision Loop WITH MEMORY
Implements: Observe → Reason → Plan → Act → Update State
NOW WITH: Short-term memory for context-aware decisions
"""

from typing import TypedDict, Annotated, Sequence, Dict, Any
from langgraph.graph import StateGraph, END
from langchain_core.messages import BaseMessage, HumanMessage, AIMessage
from langchain_community.llms import Ollama
from pydantic import BaseModel, Field
import json

# ============================================================================
# STATE DEFINITION
# ============================================================================

class EntityState(TypedDict):
    """Complete entity cognitive state"""
    # Identity
    entity_id: str
    name: str
    
    # Core stats
    strength: float
    agility: float
    stamina: float
    skill: float
    
    # Cognitive state
    energy: int
    emotion: str
    confidence: float
    
    # Economic
    wallet: float
    position: Dict[str, Any]
    
    # Decision context
    market_state: Dict[str, float]
    recent_observations: list
    internal_reasoning: list
    planned_action: str
    action_result: Dict[str, Any]
    
    # Memory (NEW!)
    memory: Any  # ShortTermMemory instance
    
    # Stats
    wins: int
    losses: int
    experience: int

# ============================================================================
# COGNITIVE NODES (WITH MEMORY)
# ============================================================================

def perception_node(state: EntityState) -> EntityState:
    """
    PHASE 1: Observe environment + recall recent memories
    """
    observations = []
    
    # Market observation
    if state.get("market_state"):
        price = state["market_state"].get("price", 0)
        trend = state["market_state"].get("trend", "unknown")
        observations.append(f"Market: ${price:.2f}, trend: {trend}")
    
    # Self observation
    observations.append(f"Energy: {state.get('energy', 100)}/100")
    observations.append(f"Emotion: {state.get('emotion', 'calm')}")
    observations.append(f"Wallet: ${state.get('wallet', 0):.2f}")
    observations.append(f"Confidence: {state.get('confidence', 0.5):.0%}")
    
    # Recent performance
    wins = state.get('wins', 0)
    losses = state.get('losses', 0)
    observations.append(f"Overall Record: {wins}W-{losses}L")
    
    # MEMORY CONTEXT (NEW!)
    if "memory" in state and state["memory"]:
        try:
            memory_context = state["memory"].format_for_llm()
            observations.append(f"\n{memory_context}")
        except:
            observations.append("Memory unavailable")
    
    state["recent_observations"] = observations
    
    print(f"\n[PERCEPTION] {state['name']} observes:")
    for obs in observations:
        print(f"  {obs}")
    
    return state

def reasoning_node(state: EntityState) -> EntityState:
    """
    PHASE 2: Reason about observations (now with memory context)
    """
    llm = Ollama(model="gemma3:12b", temperature=0.7)
    
    observations = "\n".join(state["recent_observations"])
    
    prompt = f"""You are {state['name']}, an autonomous trading entity.

Current Situation:
{observations}

Your emotional state: {state.get('emotion', 'calm')}

Analyze the situation considering your recent performance:
1. What patterns do you see in your recent trades?
2. How should your emotion and recent results influence your decision?
3. What are the risks and opportunities?
4. Should you act, wait, or adjust position size?

Keep your response concise (3-4 sentences)."""

    try:
        reasoning = llm.invoke(prompt)
        state["internal_reasoning"] = [reasoning]
        
        print(f"\n[REASONING] {state['name']} thinks:")
        print(f"  {reasoning}")
        
    except Exception as e:
        fallback = f"Analyzing with {state.get('emotion', 'calm')} emotion. Recent performance considered."
        state["internal_reasoning"] = [fallback]
        print(f"\n[REASONING] {state['name']}: {fallback}")
    
    return state

def strategy_node(state: EntityState) -> EntityState:
    """
    PHASE 3: Plan action (memory influences position sizing)
    """
    emotion = state.get("emotion", "calm")
    energy = state.get("energy", 100)
    confidence = state.get("confidence", 0.5)
    market = state.get("market_state", {})
    
    # Energy constraint
    if energy < 20:
        state["planned_action"] = "rest"
        print(f"\n[STRATEGY] {state['name']}: Too tired, must rest")
        return state
    
    # Get memory-based adjustment
    position_multiplier = 1.0
    if "memory" in state and state["memory"]:
        try:
            summary = state["memory"].get_performance_summary()
            win_rate = summary.get("win_rate", 0.5)
            
            # Adjust position size based on recent performance
            if win_rate > 0.6:
                position_multiplier = 1.2  # Increase size when winning
            elif win_rate < 0.4:
                position_multiplier = 0.7  # Decrease size when losing
            
            print(f"\n[MEMORY INFLUENCE] Recent win rate: {win_rate:.1%} -> Position multiplier: {position_multiplier}x")
        except:
            pass
    
    # Emotion-based strategy
    if emotion == "greedy":
        action = "buy" if confidence > 0.4 else "hold"
        amount = min(0.8, confidence) * position_multiplier
        
    elif emotion == "fearful":
        action = "sell" if state.get("position") else "hold"
        amount = 0.2 * position_multiplier
        
    elif emotion == "aggressive":
        action = "buy" if market.get("trend") == "up" else "sell"
        amount = 0.5 * position_multiplier
        
    else:  # calm
        action = "buy" if confidence > 0.6 else "hold"
        amount = confidence * 0.5 * position_multiplier
    
    state["planned_action"] = json.dumps({
        "action": action,
        "amount": amount,
        "emotion": emotion,
        "confidence": confidence,
        "memory_adjusted": position_multiplier != 1.0
    })
    
    print(f"\n[STRATEGY] {state['name']} plans: {action} (amount: {amount:.2f}, emotion: {emotion})")
    
    return state

def action_node(state: EntityState) -> EntityState:
    """
    PHASE 4: Execute planned action
    """
    try:
        plan = json.loads(state.get("planned_action", "{}"))
        action = plan.get("action", "hold")
        amount = plan.get("amount", 0)
        
        # Energy costs
        energy_cost = {
            "buy": 2,
            "sell": 2,
            "hold": 1,
            "rest": -10
        }.get(action, 1)
        
        result = {
            "action": action,
            "amount": amount,
            "energy_cost": energy_cost,
            "success": True
        }
        
        state["action_result"] = result
        
        print(f"\n[ACTION] {state['name']} executes: {action} (energy cost: {energy_cost})")
        
    except Exception as e:
        print(f"\n[ACTION ERROR] {state['name']}: {e}")
        state["action_result"] = {"action": "hold", "energy_cost": 1, "success": False}
    
    return state

def state_update_node(state: EntityState) -> EntityState:
    """
    PHASE 5: Update entity state based on action results
    """
    result = state.get("action_result", {})
    
    # Update energy
    energy_cost = result.get("energy_cost", 0)
    current_energy = state.get("energy", 100)
    new_energy = max(0, min(100, current_energy - energy_cost))
    state["energy"] = new_energy
    
    # Update confidence
    if result.get("success"):
        state["confidence"] = min(1.0, state.get("confidence", 0.5) + 0.01)
    
    print(f"\n[UPDATE] {state['name']} state updated:")
    print(f"  Energy: {current_energy} -> {new_energy}")
    print(f"  Confidence: {state.get('confidence', 0.5):.0%}")
    
    return state

# ============================================================================
# LANGGRAPH WORKFLOW
# ============================================================================

def create_cognitive_graph():
    """Build the LangGraph decision workflow"""
    
    workflow = StateGraph(EntityState)
    
    # Add nodes
    workflow.add_node("perception", perception_node)
    workflow.add_node("reasoning", reasoning_node)
    workflow.add_node("strategy", strategy_node)
    workflow.add_node("action", action_node)
    workflow.add_node("state_update", state_update_node)
    
    # Define edges
    workflow.set_entry_point("perception")
    workflow.add_edge("perception", "reasoning")
    workflow.add_edge("reasoning", "strategy")
    workflow.add_edge("strategy", "action")
    workflow.add_edge("action", "state_update")
    workflow.add_edge("state_update", END)
    
    # Compile
    app = workflow.compile()
    
    return app

# ============================================================================
# CLI INTERFACE
# ============================================================================

def run_cognitive_cycle(entity_json: str) -> str:
    """CLI interface for Rust engine"""
    entity_state = json.loads(entity_json)
    graph = create_cognitive_graph()
    result = graph.invoke(entity_state)
    
    output = {
        "action": json.loads(result.get("planned_action", "{}")),
        "updated_state": {
            "energy": result.get("energy"),
            "confidence": result.get("confidence"),
            "emotion": result.get("emotion")
        }
    }
    
    return json.dumps(output, indent=2)

# ============================================================================
# EXAMPLE USAGE
# ============================================================================

if __name__ == "__main__":
    import sys
    
    if len(sys.argv) > 1:
        entity_json = sys.argv[1]
        result = run_cognitive_cycle(entity_json)
        print(result)
    else:
        print("\n" + "="*60)
        print("  COGNITIVE ENGINE WITH MEMORY - DEMO")
        print("="*60 + "\n")
        
        # Import memory for demo
        try:
            from memory_system import ShortTermMemory
            memory = ShortTermMemory(max_size=10)
            
            # Add some example memories
            memory.add_memory("buy", "success", 150.0, "greedy", "Strong uptrend", {"price": 50000})
            memory.add_memory("sell", "success", 80.0, "calm", "Taking profits", {"price": 51000})
            memory.add_memory("buy", "failure", -120.0, "fearful", "Bad timing", {"price": 49000})
            
            print("✅ Memory system loaded with sample trades\n")
        except:
            memory = None
            print("⚠️  Memory system not available\n")
        
        test_entity = {
            "entity_id": "test-001",
            "name": "MemoryAgent",
            "strength": 60.0,
            "agility": 55.0,
            "stamina": 65.0,
            "skill": 58.0,
            "energy": 85,
            "emotion": "calm",
            "confidence": 0.65,
            "wallet": 1000.0,
            "position": None,
            "market_state": {
                "price": 52000.0,
                "trend": "up",
                "volatility": 0.05
            },
            "recent_observations": [],
            "internal_reasoning": [],
            "planned_action": "",
            "action_result": {},
            "memory": memory,
            "wins": 5,
            "losses": 3,
            "experience": 350
        }
        
        graph = create_cognitive_graph()
        result = graph.invoke(test_entity)
        
        print("\n" + "="*60)
        print("  COGNITIVE CYCLE COMPLETE")
        print("="*60)
        print(f"\nFinal Action: {result.get('planned_action')}")
        print(f"Energy: {result.get('energy')}")
        print(f"Confidence: {result.get('confidence'):.0%}")
        print("\n✅ Cognitive engine with memory working!\n")
