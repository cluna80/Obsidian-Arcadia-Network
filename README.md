# ��� Obsidian Arcadia Network

**Autonomous AI agent network with behavioral intelligence + Web3 protocol**

[![PyPI](https://badge.fury.io/py/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![Python](https://img.shields.io/pypi/pyversions/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-100%25-brightgreen.svg)]()

Build autonomous AI agents that **think**, **adapt**, and **evolve** using **OBSIDIAN** language + complete Web3 infrastructure.

---

## ��� What is OAN?

The **Obsidian Arcadia Network** is a complete protocol for autonomous AI agents with:

### **Layer 1: Core Engine** ✅
- ��� Behavioral Intelligence
- ��� Multi-Agent Coordination  
- ��� Dynamic Entity Spawning
- ⚡ High Performance (180+ cycles/sec)
- ��� Cyberpunk Dashboard

### **Layer 2: Web3 Protocol** ✅
- ��� NFT Entities (ERC-721)
- ���️ Full DAO Governance
- ��� $OAN Token Economy
- ��� Decentralized Identity (DID)
- ��� Soulbound Credentials
- ��� Entity + Tool Marketplaces

---

## ��� Quick Start

### Installation
```bash
pip install obsidian-arcadia-network
```

### Your First Entity
```python
import oan

entity = oan.Entity(name="MyBot", state="Active", energy=100, reputation=0)
result = oan.execute_entity(entity, cycles=10)
```

---

## ��� OBSIDIAN Language

**OBSIDIAN** - The Language of Autonomous Intelligence
```obsidian
ENTITY TradingBot
TYPE Trader
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
  IF STATE == Recovery THEN Monitor
END

INTENT "Execute profitable trades"
MODE Production
TOKENIZED True
```

---

## ��� Documentation

| Document | Description |
|----------|-------------|
| [QUICKSTART.md](QUICKSTART.md) | Get started in 5 minutes |
| [OBSIDIAN_LANGUAGE.md](OBSIDIAN_LANGUAGE.md) | Complete DSL reference |
| [EXAMPLES.md](EXAMPLES.md) | 13 real-world examples |
| [TESTING.md](TESTING.md) | Testing guide |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System design |
| [web3/LAYER2_COMPLETE.md](web3/LAYER2_COMPLETE.md) | Web3 protocol docs |

---

## ✨ Core Features

### Behavioral Intelligence
```python
# Entities adapt based on conditions
IF ENERGY < 30 THEN STATE Recovery
IF REPUTATION > 50 THEN STATE Elite
```

### Multi-Agent Networks
```python
entities = oan.execute_multi_entity([
    "coordinator.obs",
    "worker1.obs",
    "worker2.obs"
], cycles=10)
```

### Communication
```python
oan.comm_hub.broadcast("Bot1", "Hello network!")
oan.comm_hub.send_to("Bot1", "Bot2", "Task complete")
```

---

## ��� Web3 Protocol

### Layer 2: Complete Smart Contract System

**17 Production-Ready Contracts:**

#### Phase 2.1: Tokenized Entities
- OANEntity.sol - ERC-721 NFT with spawning

#### Phase 2.2: Smart Contract Layer
- EntityRegistry.sol
- ReputationOracle.sol
- ToolMarketplace.sol
- EntitySpawning.sol

#### Phase 2.3: Identity & Reputation
- DecentralizedIdentity.sol (DID)
- SoulboundCredentials.sol
- ReputationStaking.sol

#### Phase 2.4: DAO & Governance
- OANToken.sol ($OAN - 1B supply)
- DAOTreasury.sol
- ProposalSystem.sol
- VotingMechanism.sol
- OANDAO.sol

#### Phase 2.5: Protocol Economy
- EntityMarketplace.sol
- RevenueDistribution.sol
- OANLiquidityPool.sol
- TokenEconomics.sol

### Token Economics

**$OAN Token:**
- Initial Supply: 1 billion
- Max Supply: 10 billion
- Emission: 5% yearly

**Allocation:**
- 40% Community
- 30% Treasury
- 20% Team
- 10% Ecosystem

**Revenue Split:**
- 40% Stakers
- 30% Treasury
- 20% Creators
- 10% Burn

---

## ��� Testing
```bash
python run_all_tests.py
```

Output:
```
✅ PASS - Behavioral Intelligence
✅ PASS - Entity Communication
✅ PASS - Entity Coordination
✅ PASS - Entity Spawning
��� ALL SYSTEMS OPERATIONAL!
```

---

## ��� Cyberpunk Dashboard
```
╔═══════════════════════════════════════╗
║  OBSIDIAN ARCADIA NETWORK            ║
║      R O G U E   A I   L A B         ║
╚═══════════════════════════════════════╝

        ◢ NETWORK TOPOLOGY ◣         
┏━━━━━━━━━━━┳━━━━━━━━┳━━━━━━━━┳━━━━━┓
┃ NODE      ┃ STATE  ┃ ENERGY ┃ REP ┃
┡━━━━━━━━━━━╇━━━━━━━━╇━━━━━━━━╇━━━━━┩
│ ● Worker1 │ Active │ 80     │ 15  │
│ ● Worker2 │ Elite  │ 90     │ 25  │
└───────────┴────────┴────────┴─────┘
```

---

## ��� Performance

- **Speed**: 180+ cycles/second
- **Memory**: ~1KB per entity
- **Scale**: 100+ entities tested
- **Coverage**: 100%

---

## ���️ Architecture
```
┌─────────────────────────────────────┐
│    LAYER 1: CORE ENGINE (v1.0.0)   │
│  • OBSIDIAN DSL Parser              │
│  • Behavioral Intelligence          │
│  • Multi-Entity Coordination        │
│  • Cyberpunk Dashboard              │
└─────────────────────────────────────┘
          ↓
┌─────────────────────────────────────┐
│   LAYER 2: WEB3 (17 Contracts)     │
│  • NFT Entities                     │
│  • DAO Governance                   │
│  • Token Economy                    │
│  • Decentralized Identity           │
└─────────────────────────────────────┘
```

---

## ��� Use Cases

- **Trading Bots** - Adaptive trading strategies
- **Research Agents** - Autonomous research
- **Content Creators** - AI content generation
- **Data Collectors** - Intelligent data gathering
- **Multi-Agent Systems** - Coordinated networks
- **Web3 Gaming** - NFT entities with AI

---

## ��� Installation Options
```bash
# Core package
pip install obsidian-arcadia-network

# With Web3 support
pip install obsidian-arcadia-network[web3]

# With development tools
pip install obsidian-arcadia-network[dev]
```

---

## ��� Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

---

## ��� License

MIT - see [LICENSE](LICENSE)

---

## ��� Links

- **GitHub**: https://github.com/cluna80/Obsidian-Arcadia-Network
- **PyPI**: https://pypi.org/project/obsidian-arcadia-network/
- **Documentation**: See repository docs
- **Web3 Contracts**: [web3/](web3/)

---

## ��� Status

### Layer 1: Core Engine ✅
- v1.0.0 Released on PyPI
- 100% Test Coverage
- Complete Documentation

### Layer 2: Web3 Protocol ✅
- 17 Smart Contracts
- All Compiled & Ready
- Ready for Testnet

### Next: Production Deployment ���

---

��� **Build agents that think, adapt, and evolve.** ���

⭐ **Star us on GitHub!**
