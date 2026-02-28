"""
Short-Term Memory System for Cognitive Agents
Tracks recent actions, outcomes, and performance for better decision-making
"""

from typing import List, Dict, Any
from dataclasses import dataclass, field
from datetime import datetime
from collections import deque

@dataclass
class MemoryEntry:
    """Single memory entry"""
    timestamp: datetime
    action: str
    outcome: str  # success, failure, neutral
    profit: float
    emotion: str
    reasoning: str
    market_state: Dict[str, Any]

class ShortTermMemory:
    """
    Rolling window of recent experiences
    Used by LangGraph to inform future decisions
    """
    
    def __init__(self, max_size: int = 10):
        self.max_size = max_size
        self.memories: deque = deque(maxlen=max_size)
        
    def add_memory(self, 
                   action: str, 
                   outcome: str,
                   profit: float,
                   emotion: str,
                   reasoning: str,
                   market_state: Dict):
        """Add new memory entry"""
        entry = MemoryEntry(
            timestamp=datetime.now(),
            action=action,
            outcome=outcome,
            profit=profit,
            emotion=emotion,
            reasoning=reasoning,
            market_state=market_state
        )
        self.memories.append(entry)
    
    def get_recent_memories(self, n: int = 5) -> List[MemoryEntry]:
        """Get N most recent memories"""
        return list(self.memories)[-n:]
    
    def get_performance_summary(self) -> Dict[str, Any]:
        """Summarize recent performance"""
        if not self.memories:
            return {
                "total_trades": 0,
                "wins": 0,
                "losses": 0,
                "total_profit": 0,
                "win_rate": 0,
                "avg_profit": 0,
                "recent_streak": "none"
            }
        
        wins = sum(1 for m in self.memories if m.outcome == "success")
        losses = sum(1 for m in self.memories if m.outcome == "failure")
        total_profit = sum(m.profit for m in self.memories)
        
        # Detect streaks
        recent_outcomes = [m.outcome for m in list(self.memories)[-3:]]
        if len(set(recent_outcomes)) == 1 and recent_outcomes[0] != "neutral":
            streak = f"{len(recent_outcomes)} {recent_outcomes[0]}s in a row"
        else:
            streak = "mixed"
        
        return {
            "total_trades": len(self.memories),
            "wins": wins,
            "losses": losses,
            "total_profit": total_profit,
            "win_rate": wins / len(self.memories) if self.memories else 0,
            "avg_profit": total_profit / len(self.memories) if self.memories else 0,
            "recent_streak": streak
        }
    
    def format_for_llm(self) -> str:
        """
        Format recent memories as context for LLM
        Returns a human-readable summary
        """
        if not self.memories:
            return "No trading history yet."
        
        summary = self.get_performance_summary()
        recent = self.get_recent_memories(5)
        
        context = f"""RECENT TRADING HISTORY:

Performance Summary:
- Last {summary['total_trades']} trades: {summary['wins']}W-{summary['losses']}L
- Win Rate: {summary['win_rate']:.1%}
- Total P/L: ${summary['total_profit']:.2f}
- Average P/L: ${summary['avg_profit']:.2f}
- Recent Streak: {summary['recent_streak']}

Last 5 Trades:
"""
        
        for i, mem in enumerate(reversed(recent), 1):
            context += f"\n{i}. {mem.action.upper()} -> {mem.outcome} (${mem.profit:+.2f}) [{mem.emotion}]"
            if mem.reasoning and len(mem.reasoning) > 10:
                context += f"\n   Why: {mem.reasoning[:80]}..."
        
        return context
    
    def clear(self):
        """Clear all memories"""
        self.memories.clear()

# Example usage
if __name__ == "__main__":
    print("Memory System Demo\n")
    
    memory = ShortTermMemory(max_size=10)
    
    # Simulate some trades
    print("Simulating trades...")
    memory.add_memory("buy", "success", 150.0, "greedy", "Market trending up strongly", {"price": 50000})
    memory.add_memory("sell", "success", 80.0, "calm", "Taking profits at resistance", {"price": 51000})
    memory.add_memory("buy", "failure", -120.0, "fearful", "Tried to recover losses", {"price": 49000})
    memory.add_memory("hold", "neutral", 0.0, "calm", "Waiting for clear signal", {"price": 49500})
    memory.add_memory("buy", "success", 200.0, "greedy", "Strong momentum confirmed", {"price": 52000})
    
    print("\nMemory Context for LLM:")
    print("="*60)
    print(memory.format_for_llm())
    
    print("\n" + "="*60)
    print("\nPerformance Summary:")
    summary = memory.get_performance_summary()
    for key, value in summary.items():
        print(f"  {key}: {value}")
    
    print("\n✅ Memory system working!\n")
