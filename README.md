# í¼‘ Obsidian Arcadia Network

**Autonomous AI agent network with behavioral intelligence**

[![PyPI](https://badge.fury.io/py/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![Python](https://img.shields.io/pypi/pyversions/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

Build autonomous AI agents that **think**, **adapt**, and **evolve** using the **OBSIDIAN** language.

---

## íº€ Quick Start
```bash
pip install obsidian-arcadia-network
```
```python
import oan

entity = oan.Entity(name="MyBot", state="Active", energy=100, reputation=0)
result = oan.execute_entity(entity, cycles=10)
```

---

## í³– Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Get started in 5 minutes |
| [OBSIDIAN_LANGUAGE.md](OBSIDIAN_LANGUAGE.md) | Complete DSL reference |
| [EXAMPLES.md](EXAMPLES.md) | Real-world examples |
| [TESTING.md](TESTING.md) | Testing guide |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Technical design |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to contribute |

---

## í¼‘ OBSIDIAN Language

**OBSIDIAN** - The Language of Autonomous Intelligence
```obsidian
ENTITY TradingBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 50 THEN STATE Aggressive
  IF ENERGY < 30 THEN STATE Recovery
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN MarketAnalyzer
  IF STATE == Aggressive THEN HighFrequencyTrader
END

INTENT "Execute profitable trades"
```

---

## âœ¨ Features

- í·  **Behavioral Intelligence** - Agents adapt based on conditions
- í¼Š **Multi-Agent Networks** - Entities communicate and coordinate
- í´¥ **Dynamic Spawning** - Create child entities
- âš¡ **High Performance** - 180+ cycles/second
- í¾¨ **Cyberpunk Dashboard** - Beautiful visualization
- í³¦ **Production Ready** - 100% test coverage

---

## í·ª Testing
```bash
python run_all_tests.py
```

Output:
```
âœ… PASS - Behavioral Intelligence
âœ… PASS - Entity Communication
âœ… PASS - Entity Coordination
âœ… PASS - Entity Spawning
í¾‰ ALL SYSTEMS OPERATIONAL!
```

---

## í¼ Use Cases

- **Trading Bots** - Adaptive trading strategies
- **Research Agents** - Autonomous research
- **Content Creators** - AI content generation
- **Data Collectors** - Intelligent data gathering
- **Multi-Agent Systems** - Coordinated networks

---

## í´ Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## í³„ License

MIT - see [LICENSE](LICENSE)

---

## í´— Links

- **GitHub**: https://github.com/cluna80/Obsidian-Arcadia-Network
- **PyPI**: https://pypi.org/project/obsidian-arcadia-network/
- **Documentation**: See repository docs

---

## í¾¯ Roadmap

- **v1.0.0** (Current) âœ… - Core engine
- **v1.5.0** (Q2 2026) - Enhanced features
- **v2.0.0** (Q3 2026) - Web3 integration
- **v3.0.0** (Q4 2026) - Advanced features

---

í¼‘ **Build agents that think, adapt, and evolve.** í´¥

â­ **Star us on GitHub!**
