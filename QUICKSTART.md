# íº€ Quick Start - Obsidian Arcadia Network

## Installation
```bash
pip install obsidian-arcadia-network
```

## Your First Entity (30 seconds)
```python
import oan

# Create entity
entity = oan.Entity(
    name="MyBot",
    state="Active",
    energy=100,
    reputation=0
)

# Run it
result = oan.execute_entity(entity, cycles=10)
print(f"Reputation: {result.reputation}")
```

## With OBSIDIAN Language

Create `bot.obs`:
```obsidian
ENTITY AdaptiveBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF REPUTATION > 5 THEN STATE Elite
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Elite THEN AdvancedTool
  IF STATE == Recovery THEN Monitor
END

INTENT "Self-regulating entity"
```

Run it:
```python
import oan
entity = oan.execute_entity("bot.obs", cycles=20)
```

## Multi-Entity Network
```python
import oan

entities = oan.execute_multi_entity([
    "worker1.obs",
    "worker2.obs"
], cycles=5)
```

## Communication
```python
import oan

oan.comm_hub.broadcast("Bot1", "Hello network!")
oan.comm_hub.send_to("Bot1", "Bot2", "Task complete")
```

## Next Steps

- See `OBSIDIAN_LANGUAGE.md` for complete reference
- See `EXAMPLES.md` for 13 real-world examples
- See `TESTING.md` for testing guide

**Build agents that think, adapt, and evolve!** í¼‘
