"""
Large Scale Agent Simulation
Supports 100-1000 agents with elite LLM subset
OPTIMIZED: Reduced Ollama calls with caching
"""

from typing import List, Dict
from cognitive_engine import create_cognitive_graph, EntityState
from emotion_system import EmotionSystem
from energy_system import EnergySystem
from market_environment import MarketEnvironment
from strategy_evolution import TradingStrategy
import random
import time

class Agent:
    """Individual agent wrapper"""
    
    def __init__(self, agent_id: str, name: str, is_elite: bool = False):
        self.agent_id = agent_id
        self.name = name
        self.is_elite = is_elite
        
        self.energy_system = EnergySystem()
        self.emotion_system = EmotionSystem()
        self.strategy = TradingStrategy()
        
        # Stats
        self.wallet = 10000.0
        self.position = None
        self.wins = 0
        self.losses = 0
        self.total_profit = 0.0
        
        # Cache LangGraph instance (expensive to create)
        self._cognitive_graph = None
        self._last_llm_call = 0
        self._llm_cooldown = 3  # Seconds between LLM calls
    
    def get_state(self, market_state: Dict) -> EntityState:
        """Get current state for cognitive engine"""
        return {
            "entity_id": self.agent_id,
            "name": self.name,
            "strength": 60.0,
            "agility": 55.0,
            "stamina": 65.0,
            "skill": 58.0,
            "energy": self.energy_system.current_energy,
            "emotion": self.emotion_system.current_emotion.value,
            "confidence": 0.5 + (self.wins / max(1, self.wins + self.losses)) * 0.5,
            "wallet": self.wallet,
            "position": self.position,
            "market_state": market_state,
            "recent_observations": [],
            "internal_reasoning": [],
            "planned_action": "",
            "action_result": {},
            "wins": self.wins,
            "losses": self.losses,
            "experience": self.wins * 50 + self.losses * 10
        }
    
    def decide(self, market_state: Dict, use_llm: bool = False):
        """Make trading decision"""
        # Throttle LLM calls
        now = time.time()
        can_use_llm = (now - self._last_llm_call) >= self._llm_cooldown
        
        if use_llm and self.is_elite and can_use_llm:
            # Use full LangGraph cognitive engine
            try:
                if self._cognitive_graph is None:
                    self._cognitive_graph = create_cognitive_graph()
                
                state = self.get_state(market_state)
                result = self._cognitive_graph.invoke(state)
                self._last_llm_call = now
                
                import json
                action_data = json.loads(result.get("planned_action", "{}"))
                return action_data.get("action", "hold")
            except Exception as e:
                print(f"[LLM ERROR] {self.name}: {e}")
                return self._rule_based_decision(market_state)
        else:
            # Simple rule-based logic
            return self._rule_based_decision(market_state)
    
    def _rule_based_decision(self, market_state: Dict):
        """Fast rule-based decision (no LLM)"""
        emotion = self.emotion_system.current_emotion.value
        trend = market_state.get("trend", "sideways")
        
        if emotion == "greedy":
            return "buy" if trend != "down" else "hold"
        elif emotion == "fearful":
            return "sell" if self.position else "hold"
        elif emotion == "aggressive":
            return "buy" if trend == "up" else "sell"
        else:  # calm
            if trend == "up":
                return "buy"
            elif trend == "down":
                return "sell" if self.position else "hold"
            else:
                return "hold"

class AgentSimulation:
    """Multi-agent simulation manager"""
    
    def __init__(self, num_agents: int = 100, elite_count: int = 20):
        self.market = MarketEnvironment()
        self.agents: List[Agent] = []
        
        # Create agents (elite subset gets LLM reasoning)
        for i in range(num_agents):
            is_elite = i < elite_count
            agent = Agent(
                agent_id=f"agent-{i:03d}",
                name=f"{'Elite' if is_elite else 'Agent'}{i:03d}",
                is_elite=is_elite
            )
            self.agents.append(agent)
        
        print(f"Created {num_agents} agents ({elite_count} elite with LLM)")
    
    def run_tick(self, tick: int, use_llm_for_elite: bool = False):
        """Execute one simulation tick"""
        market_state = self.market.get_state_dict()
        actions = []
        
        # Limit LLM calls to 1-2 per tick to avoid timeout
        llm_calls_this_tick = 0
        max_llm_per_tick = 2
        
        # Each agent decides
        for agent in self.agents:
            if agent.energy_system.current_energy >= 2:
                # Only allow LLM for first N elite agents per tick
                use_llm = (use_llm_for_elite and 
                          agent.is_elite and 
                          llm_calls_this_tick < max_llm_per_tick)
                
                decision = agent.decide(market_state, use_llm=use_llm)
                
                if use_llm and agent.is_elite:
                    llm_calls_this_tick += 1
                
                actions.append({"action": decision, "amount": 0.1})
                agent.energy_system.consume_energy(decision)
            else:
                agent.energy_system.rest()
        
        # Update market
        self.market.update(actions)
        
        # Regenerate energy
        for agent in self.agents:
            agent.energy_system.regenerate()
    
    def run(self, ticks: int = 10, use_llm: bool = False):
        """Run simulation for N ticks"""
        print(f"\nRunning simulation for {ticks} ticks...")
        print(f"LLM reasoning: {'ENABLED (throttled)' if use_llm else 'DISABLED (fast mode)'}\n")
        
        for tick in range(ticks):
            self.run_tick(tick, use_llm_for_elite=use_llm)
            
            state = self.market.get_state_dict()
            print(f"Tick {tick}: Price=${state['price']:,.2f}, Trend={state['trend']}")
        
        print(f"\n✅ Simulation complete!")
        print(f"Final price: ${self.market.price:,.2f}")
        active = sum(1 for a in self.agents if a.energy_system.current_energy > 20)
        print(f"Active agents: {active}/{len(self.agents)}")

# Example usage
if __name__ == "__main__":
    print("="*60)
    print("  OPTIMIZED AGENT SIMULATION")
    print("="*60)
    
    # Fast simulation (no LLM, 100 agents)
    print("\n[MODE 1] Fast simulation (rule-based only)")
    sim = AgentSimulation(num_agents=100, elite_count=20)
    sim.run(ticks=10, use_llm=False)
    
    print("\n" + "="*60)
    print("\n[MODE 2] Hybrid simulation (2 LLM calls/tick max)")
    sim2 = AgentSimulation(num_agents=10, elite_count=2)
    sim2.run(ticks=3, use_llm=True)
