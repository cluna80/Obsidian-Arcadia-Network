"""
Cognitive Engine - LangGraph Decision Loop
Implements: Observe → Reason → Plan → Act → Update State
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
    
    # Core stats (from Rust engine)
    strength: float
    agility: float
    stamina: float
    skill: float
    
    # Cognitive state
    energy: int  # 0-100, consumed by actions
    emotion: str  # calm, greedy, fearful, aggressive
    confidence: float  # 0-1
    
    # Economic
    wallet: float
    position: Dict[str, Any]  # Current market position
    
    # Decision context
    market_state: Dict[str, float]
    recent_observations: list
    internal_reasoning: list
    planned_action: str
    action_result: Dict[str, Any]
    
    # Memory
    wins: int
    losses: int
    experience: int

# ============================================================================
# PYDANTIC MODELS FOR STRUCTURED OUTPUT
# ============================================================================

class MarketAnalysis(BaseModel):
    """Structured market analysis"""
    trend: str = Field(description="Market trend: bullish, bearish, or sideways")
    confidence: float = Field(description="Confidence in analysis 0-1")
    risk_level: str = Field(description="Risk assessment: low, medium, high")
    reasoning: str = Field(description="Brief reasoning for the analysis")

class TradingDecision(BaseModel):
    """Structured trading decision"""
    action: str = Field(description="Action to take: buy, sell, hold, rest")
    amount: float = Field(description="Amount to trade (0-1, fraction of wallet)")
    reasoning: str = Field(description="Why this decision was made")
    emotion_influence: str = Field(description="How emotion affected the decision")

# ============================================================================
# COGNITIVE NODES
# ============================================================================

def perception_node(state: EntityState) -> EntityState:
    """
    PHASE 1: Observe environment
    - Read market state
    - Check energy levels
    - Assess emotional state
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
    observations.append(f"Record: {wins}W-{losses}L")
    
    state["recent_observations"] = observations
    
    print(f"\n[PERCEPTION] {state['name']} observes:")
    for obs in observations:
        print(f"  • {obs}")
    
    return state

def reasoning_node(state: EntityState) -> EntityState:
    """
    PHASE 2: Reason about observations
    Uses Ollama LLM for analysis
    """
    # Initialize Ollama (local)
    llm = Ollama(model="gemma3:12b", temperature=0.7)
    
    # Build reasoning prompt
    observations = "\n".join(state["recent_observations"])
    
    prompt = f"""You are {state['name']}, an autonomous trading entity.

Current Situation:
{observations}

Your emotional state is: {state.get('emotion', 'calm')}

Analyze the situation and provide your reasoning:
1. What is the market doing?
2. How should your emotion influence your decision?
3. What are the risks and opportunities?
4. Should you act or wait?

Keep your response concise (3-4 sentences)."""

    try:
        reasoning = llm.invoke(prompt)
        state["internal_reasoning"] = [reasoning]
        
        print(f"\n[REASONING] {state['name']} thinks:")
        print(f"  {reasoning}")
        
    except Exception as e:
        # Fallback if Ollama unavailable
        state["internal_reasoning"] = [f"[Ollama unavailable] Basic analysis based on {state.get('emotion', 'calm')} emotion"]
        print(f"\n[REASONING] {state['name']}: Ollama unavailable, using fallback logic")
    
    return state

def strategy_node(state: EntityState) -> EntityState:
    """
    PHASE 3: Plan action based on reasoning
    Emotion influences strategy selection
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
    
    # Emotion-based strategy
    if emotion == "greedy":
        # High risk, high reward
        action = "buy" if confidence > 0.4 else "hold"
        amount = min(0.8, confidence)  # Larger positions
        
    elif emotion == "fearful":
        # Risk averse
        action = "sell" if state.get("position") else "hold"
        amount = 0.2  # Small positions only
        
    elif emotion == "aggressive":
        # Frequent trading
        action = "buy" if market.get("trend") == "up" else "sell"
        amount = 0.5
        
    else:  # calm
        # Balanced approach
        action = "buy" if confidence > 0.6 else "hold"
        amount = confidence * 0.5
    
    state["planned_action"] = json.dumps({
        "action": action,
        "amount": amount,
        "emotion": emotion,
        "confidence": confidence
    })
    
    print(f"\n[STRATEGY] {state['name']} plans: {action} (amount: {amount:.2f}, emotion: {emotion})")
    
    return state

def action_node(state: EntityState) -> EntityState:
    """
    PHASE 4: Execute planned action
    Returns results for state update
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
            "rest": -10  # Rest recovers energy
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
    
    # Update confidence based on success
    if result.get("success"):
        state["confidence"] = min(1.0, state.get("confidence", 0.5) + 0.01)
    
    print(f"\n[UPDATE] {state['name']} state updated:")
    print(f"  Energy: {current_energy} → {new_energy}")
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
    
    # Define edges (flow)
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
# CLI INTERFACE (for Rust integration)
# ============================================================================

def run_cognitive_cycle(entity_json: str) -> str:
    """
    CLI interface for Rust engine
    
    Input: JSON string with entity state
    Output: JSON string with updated state and action
    
    Usage:
        python cognitive_engine.py '{"entity_id": "...", "name": "...", ...}'
    """
    # Parse input
    entity_state = json.loads(entity_json)
    
    # Create workflow
    graph = create_cognitive_graph()
    
    # Run cognitive cycle
    result = graph.invoke(entity_state)
    
    # Return updated state
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
        # CLI mode (for Rust integration)
        entity_json = sys.argv[1]
        result = run_cognitive_cycle(entity_json)
        print(result)
    else:
        # Demo mode
        print("\n" + "="*60)
        print("  COGNITIVE ENGINE DEMO")
        print("="*60 + "\n")
        
        # Sample entity state
        test_entity = {
            "entity_id": "test-001",
            "name": "CognitiveAgent",
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
            "wins": 5,
            "losses": 3,
            "experience": 350
        }
        
        # Run cognitive cycle
        graph = create_cognitive_graph()
        result = graph.invoke(test_entity)
        
        print("\n" + "="*60)
        print("  COGNITIVE CYCLE COMPLETE")
        print("="*60)
        print(f"\nFinal Action: {result.get('planned_action')}")
        print(f"Energy: {result.get('energy')}")
        print(f"Confidence: {result.get('confidence'):.0%}")
        print("\n✅ Cognitive engine working!\n")
