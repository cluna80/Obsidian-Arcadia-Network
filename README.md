# ��� Obsidian Arcadia Network

**Complete Autonomous AI Agent Protocol with Web3 Infrastructure**

[![PyPI](https://badge.fury.io/py/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![Python](https://img.shields.io/pypi/pyversions/obsidian-arcadia-network.svg)](https://pypi.org/project/obsidian-arcadia-network/)
[![License](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Tests](https://img.shields.io/badge/tests-100%25-brightgreen.svg)]()

Build autonomous AI agents that **think**, **adapt**, **evolve**, and operate on-chain using the **OBSIDIAN** language.

---

## ��� What is OAN?

The **Obsidian Arcadia Network** is a complete two-layer protocol for autonomous AI agents:

### **��� Layer 1: Core AI Engine** ✅ COMPLETE
Python-based behavioral intelligence system with multi-agent coordination

### **⛓️ Layer 2: Web3 Protocol** ✅ COMPLETE
17 Solidity smart contracts providing full on-chain infrastructure

---

## ��� Project Status
```
╔══════════════════════════════════════════════════════════════╗
║                   PROJECT COMPLETE STATUS                     ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  LAYER 1: CORE ENGINE                            ✅ 100%    ║
║  ├─ OBSIDIAN Language                           ✅          ║
║  ├─ Behavioral Intelligence                     ✅          ║
║  ├─ Multi-Agent Coordination                    ✅          ║
║  ├─ Entity Spawning                             ✅          ║
║  ├─ 100% Test Coverage                          ✅          ║
║  └─ Published on PyPI                           ✅          ║
║                                                              ║
║  LAYER 2: WEB3 PROTOCOL                          ✅ 100%    ║
║  ├─ Phase 2.1: Tokenized Entities               ✅          ║
║  ├─ Phase 2.2: Smart Contract Layer             ✅          ║
║  ├─ Phase 2.3: Identity & Reputation            ✅          ║
║  ├─ Phase 2.4: DAO & Governance                 ✅          ║
║  ├─ Phase 2.5: Protocol Economy                 ✅          ║
║  └─ 17 Contracts Compiled                       ✅          ║
║                                                              ║
║  STATUS: PRODUCTION READY ���                                 ║
╚══════════════════════════════════════════════════════════════╝
```

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
print(f"Final reputation: {result.reputation}")
```

### With OBSIDIAN Language
```obsidian
ENTITY TradingBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 50 THEN STATE Elite
  IF ENERGY < 30 THEN STATE Recovery
  IF STATE == Recovery THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN MarketAnalyzer
  IF STATE == Elite THEN AdvancedTrader
END

INTENT "Execute profitable trades"
```

---

## ��� LAYER 1: CORE ENGINE

### Components (8 Modules)

1. **Parser** (`parser.py`) - Parse OBSIDIAN DSL files
2. **Entity** (`entity.py`) - Core agent data structure
3. **Behavior Engine** (`behavior.py`) - Conditional logic system
4. **Executor** (`executor.py`) - Runtime execution engine
5. **Entity Manager** (`entity_manager.py`) - Network management
6. **Communication Hub** (`communication.py`) - Inter-agent messaging
7. **Coordination Hub** (`coordination.py`) - Synchronization primitives
8. **Logger** (`logger_cyber.py`) - Cyberpunk visualization

### Features

- ✅ **OBSIDIAN Language** - Simple DSL for agent definitions
- ✅ **Behavioral Intelligence** - Agents adapt based on energy, reputation, state
- ✅ **Multi-Agent Networks** - Entities communicate and coordinate
- ✅ **Entity Spawning** - Dynamic parent-child relationships
- ✅ **High Performance** - 180+ cycles/second
- ✅ **Cyberpunk Dashboard** - Beautiful terminal output with Rich
- ✅ **100% Test Coverage** - 18+ comprehensive tests

### Test Results
```
LAYER 1: TEST SUMMARY
======================================================================
✅ Behavioral Intelligence       (8/8 tests)   - 100% Pass
✅ Entity Communication          (3/3 tests)   - 100% Pass
✅ Entity Coordination           (3/3 tests)   - 100% Pass
✅ Entity Spawning               (4/4 tests)   - 100% Pass

Total: 18/18 tests passed
Performance: 187 cycles/second
Status: PRODUCTION READY ✅
```

### Performance Metrics

- **Speed**: 180-200 cycles/second (single entity)
- **Memory**: ~1KB per entity
- **Scalability**: 100+ entities tested
- **Dependencies**: Only `rich>=13.0.0`

### Documentation

| File | Description |
|------|-------------|
| [LAYER1_COMPLETE.md](LAYER1_COMPLETE.md) | Complete Layer 1 documentation |
| [OBSIDIAN_LANGUAGE.md](OBSIDIAN_LANGUAGE.md) | OBSIDIAN language reference |
| [QUICKSTART.md](QUICKSTART.md) | 5-minute tutorial |
| [EXAMPLES.md](EXAMPLES.md) | 13 real-world examples |
| [TESTING.md](TESTING.md) | Testing guide |
| [ARCHITECTURE.md](ARCHITECTURE.md) | System architecture |

---

## ⛓️ LAYER 2: WEB3 PROTOCOL

### Overview

17 production-ready Solidity smart contracts providing complete Web3 infrastructure for OAN entities.

### Phase 2.1: Tokenized Entities ✅

**Contracts**: 1  
**Status**: Compiled ✅

- **OANEntity.sol** - ERC-721 NFT contract
  - Entity minting
  - Parent-child spawning
  - On-chain state (energy, reputation)
  - Generation tracking
  - DSL hash provenance

**Features**:
- Mint entities as NFTs
- Spawn child entities on-chain
- Energy costs for spawning (20 per child)
- Cooldown mechanics (100 blocks)
- Parent-child relationship tracking

---

### Phase 2.2: Smart Contract Layer ✅

**Contracts**: 4  
**Status**: Compiled ✅

#### 1. EntityRegistry.sol
Central registry for all OAN entities
- Register entities with NFT contracts
- Track ownership across contracts
- Entity lifecycle management
- Global entity ID system

#### 2. ReputationOracle.sol
On-chain reputation tracking
- Initialize entity reputation
- Update scores based on actions
- Record success/failure rates
- Reputation bounds (-100 to 1000)
- Role-based access control

#### 3. ToolMarketplace.sol
Buy, sell, and trade tools
- Create tools with pricing
- List tools for sale
- Platform fees (2.5%)
- Sales tracking
- Ownership management

#### 4. EntitySpawning.sol
Advanced spawning mechanics
- Tiered spawning system
- Generation-based costs
- Reputation requirements
- Cooldown enforcement
- Spawn history tracking

**Gas Estimates**:
- Entity Registration: ~100k gas
- Reputation Update: ~50k gas
- Tool Creation: ~150k gas
- Entity Spawning: ~250k gas

---

### Phase 2.3: Identity & Reputation ✅

**Contracts**: 3  
**Status**: Compiled ✅

#### 1. DecentralizedIdentity.sol
DID system for entities
- **DID Format**: `did:oan:entity:{id}`
- Create unique identifiers
- Link to controllers
- Update metadata (IPFS)
- Transfer control
- Deactivate DIDs

#### 2. SoulboundCredentials.sol
Non-transferable achievements
- Issue credentials to entities
- Soulbound (cannot transfer)
- Credential types: Achievement, Badge, Certification
- Expiration dates
- Revocation system
- Query by holder or type

**Credential Types**:
- `genesis_entity` - Genesis badge
- `high_reputation` - 100+ reputation
- `top_performer` - Top 10% entities
- `early_adopter` - Launch participant
- `tool_creator` - Created tools

#### 3. ReputationStaking.sol
Stake tokens for reputation boost
- **Staking Tiers**:
  - Bronze: 1 ETH, 30 days, +5% reputation
  - Silver: 5 ETH, 60 days, +10% reputation
  - Gold: 10 ETH, 90 days, +20% reputation
  - Platinum: 50 ETH, 180 days, +50% reputation
- Time-locked withdrawals
- Automatic bonus calculation

**Example**:
```
Entity "TradingBot":
- Base reputation: 150
- Stakes 10 ETH (Gold tier): +30 reputation
- Total: 180 reputation
- Unlocks advanced features
```

---

### Phase 2.4: DAO & Governance ✅

**Contracts**: 5  
**Status**: Compiled ✅

#### 1. OANToken.sol
$OAN Governance Token (ERC-20)
- **Total Supply**: 1,000,000,000 (1 billion)
- **Max Supply**: 10,000,000,000 (10 billion)
- **Emission Rate**: 5% per year
- ERC20Votes (delegation)
- ERC20Permit (gasless approvals)
- Burnable

**Allocation**:
- 40% Community rewards
- 30% DAO Treasury
- 20% Team (vested)
- 10% Ecosystem development

#### 2. DAOTreasury.sol
Treasury management
- Execute payments
- Role-based access
- Payment tracking
- Emergency withdrawals
- Treasury statistics

#### 3. ProposalSystem.sol
Proposal creation and management
- **Proposal Types**:
  - Standard (general governance)
  - Treasury (spending)
  - Protocol Upgrade
  - Parameter Change
  - Emergency
- **Parameters**:
  - Voting Delay: 1 day
  - Voting Period: 3 days
  - Proposal Threshold: 100k OAN
  - Quorum: 4M OAN (0.4%)

#### 4. VotingMechanism.sol
Vote casting and counting
- Vote types: For, Against, Abstain
- **Voting Power Formula**:
```
  Power = Token Balance 
        + (Staked Amount × 0.5)
        + (Reputation ÷ 10)
```
- Vote history tracking
- Participation rate calculation

#### 5. OANDAO.sol
Main DAO coordinator
- Initialize all components
- Update configurations
- Upgrade contracts
- Guardian controls

**DAO Workflow**:
```
1. Create Proposal → 2. Voting Delay (1d) → 3. Vote (3d) 
→ 4. Queue → 5. Timelock (2d) → 6. Execute
```

---

### Phase 2.5: Protocol Economy ✅

**Contracts**: 4  
**Status**: Compiled ✅

#### 1. EntityMarketplace.sol
Buy, sell, trade entities
- Fixed price listings
- Auction system with bids
- Offer system (make/accept)
- Platform fees (2.5%)
- Volume tracking
- Sales statistics

#### 2. RevenueDistribution.sol
Protocol revenue sharing
- **Revenue Split**:
  - 40% to Stakers
  - 30% to Treasury
  - 20% to Creators
  - 10% to Burn
- Automatic distribution
- Claimable shares
- Transparent tracking

#### 3. OANLiquidityPool.sol
OAN/ETH liquidity pool
- Add/remove liquidity
- Simple AMM (x×y=k)
- Swap fees (0.3%)
- LP share tracking
- Rewards distribution

#### 4. TokenEconomics.sol
Economic management
- **Supply Management**:
  - Initial: 1B OAN
  - Max: 10B OAN
  - Emission: 5%/year
- **Fee Structure**:
  - Trading: 2.5%
  - Marketplace: 2.5%
  - Spawning: 1%
- **Incentives**:
  - Entity Creation: 100 OAN
  - Tool Creation: 50 OAN
  - High Reputation: 200 OAN
  - Liquidity Provider: 500 OAN

---

## ��� Token Economics

### $OAN Token

**Supply**:
- Initial: 1,000,000,000 OAN
- Max: 10,000,000,000 OAN
- Emission: 5% per year

**Allocation**:
- 40% Community (400M)
- 30% Treasury (300M)
- 20% Team (200M)
- 10% Ecosystem (100M)

**Utility**:
1. **Governance** - Vote on proposals
2. **Staking** - Boost reputation + earn rewards
3. **Fees** - Pay for spawning, marketplace
4. **Liquidity** - Provide liquidity, earn fees
5. **Incentives** - Earn for contributions

### Revenue Distribution
```
Protocol Revenue
    ↓
┌────┬────┬────┬────┐
│40% │30% │20% │10% │
│    │    │    │    │
Stake Treas Crea Burn
  rs   ury  tors
```

### Fee Structure

- Trading Fee: 2.5%
- Marketplace Fee: 2.5%
- Spawning Fee: 1%
- Swap Fee: 0.3%

---

## ��� Complete Statistics

### Layer 1 (Python)
- **Components**: 8 core modules
- **Tests**: 18+ comprehensive tests
- **Coverage**: 100%
- **Performance**: 180+ cycles/second
- **Memory**: ~1KB per entity
- **PyPI**: Published ✅

### Layer 2 (Solidity)
- **Contracts**: 17 smart contracts
- **Phases**: 5 complete phases
- **Compilation**: 100% success
- **Gas Optimized**: Yes
- **Audited**: Pending

### Total Deliverables
- **Code Files**: 30+
- **Documentation**: 10+ comprehensive guides
- **Examples**: 13 real-world examples
- **Tests**: 40+ tests across layers
- **Smart Contracts**: 17 production-ready

---

## ��� Features Showcase

### Cyberpunk Dashboard
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

### OBSIDIAN Language Example
```obsidian
ENTITY ResearchBot
TYPE Researcher
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 10 THEN STATE Experienced
  IF REPUTATION > 30 THEN STATE Expert
  IF ENERGY < 20 THEN STATE Resting
  IF STATE == Resting THEN ENERGY + 15
END

EXECUTE
  IF STATE == Active THEN WebScraper
  IF STATE == Experienced THEN DeepAnalyzer
  IF STATE == Expert THEN AIResearcher
  IF STATE == Resting THEN LiteratureReader
END

INTENT "Conduct autonomous research"
MODE Production
WORLD ResearchNetwork
TOKENIZED True
```

---

## ��� Complete Documentation

### Core Documentation
- [README.md](README.md) - This file
- [QUICKSTART.md](QUICKSTART.md) - 5-minute tutorial
- [CONTRIBUTING.md](CONTRIBUTING.md) - Contribution guide

### Layer 1 Documentation
- [LAYER1_COMPLETE.md](LAYER1_COMPLETE.md) - Complete Layer 1 docs
- [OBSIDIAN_LANGUAGE.md](OBSIDIAN_LANGUAGE.md) - Language reference
- [EXAMPLES.md](EXAMPLES.md) - 13 examples
- [TESTING.md](TESTING.md) - Testing guide
- [ARCHITECTURE.md](ARCHITECTURE.md) - System architecture

### Layer 2 Documentation
- [web3/LAYER2_COMPLETE.md](web3/LAYER2_COMPLETE.md) - Complete Layer 2 docs
- [web3/PHASE_2.1.md](web3/PHASE_2.1.md) - Tokenized Entities
- [web3/PHASE_2.2.md](web3/PHASE_2.2.md) - Smart Contract Layer
- [web3/PHASE_2.3.md](web3/PHASE_2.3.md) - Identity & Reputation
- [web3/PHASE_2.4.md](web3/PHASE_2.4.md) - DAO & Governance
- [web3/PHASE_2.5.md](web3/PHASE_2.5.md) - Protocol Economy

---

## ���️ Installation Options
```bash
# Core package only
pip install obsidian-arcadia-network

# With Web3 support
pip install obsidian-arcadia-network[web3]

# With development tools
pip install obsidian-arcadia-network[dev]

# Install from source
git clone https://github.com/cluna80/Obsidian-Arcadia-Network.git
cd Obsidian-Arcadia-Network
pip install -e .
```

---

## ��� Testing

### Run All Tests
```bash
# Layer 1 tests
python run_all_tests.py

# With pytest
pytest tests/ -v

# With coverage
pytest tests/ --cov=oan --cov-report=html
```

### Layer 2 Compilation
```bash
cd web3
npx hardhat compile
```

**Expected Output**:
```
✅ Compiled 17+ Solidity files successfully
```

---

## ��� Use Cases

### Trading & Finance
- Algorithmic trading bots
- Risk management agents
- Portfolio optimizers
- Market analyzers

### Research & Data
- Autonomous researchers
- Data collectors
- Sentiment analyzers
- Trend predictors

### Content & Creative
- Content generators
- SEO optimizers
- Social media managers
- Creative assistants

### Web3 & Gaming
- NFT entities with AI
- Blockchain games
- DeFi automation
- DAO agents

---

## ��� Deployment

### Testnet Deployment (Recommended First)

1. Deploy contracts to testnet (Mumbai/Sepolia)
2. Test all functionality
3. Mint test entities
4. Run integration tests

### Mainnet Deployment

1. Security audit
2. Deploy $OAN token
3. Deploy all 17 contracts
4. Initialize DAO
5. Add initial liquidity
6. Launch!

---

## ��� Contributing

We welcome contributions!

1. Fork the repository
2. Create feature branch
3. Make changes with tests
4. Submit pull request

See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

---

## ��� License

MIT License - see [LICENSE](LICENSE)

---

## ��� Links

- **GitHub**: https://github.com/cluna80/Obsidian-Arcadia-Network
- **PyPI**: https://pypi.org/project/obsidian-arcadia-network/
- **Documentation**: See repository
- **Issues**: https://github.com/cluna80/Obsidian-Arcadia-Network/issues

---

## ��� Roadmap

### ✅ Phase 1: Foundation (COMPLETE)
- Core engine
- OBSIDIAN language
- Multi-agent system
- Testing suite

### ✅ Phase 2: Web3 Integration (COMPLETE)
- Smart contracts (17 total)
- $OAN token
- DAO governance
- Protocol economy

### ��� Phase 3: Production Launch
- Testnet deployment
- Security audit
- Mainnet deployment
- Community launch

### ��� Phase 4: Advanced Features
- Machine learning integration
- Cross-chain bridges
- Mobile apps
- Advanced coordination patterns

---

## ��� Achievements

✅ **Published on PyPI**  
✅ **17 Smart Contracts Compiled**  
✅ **100% Test Coverage**  
✅ **Complete Documentation**  
✅ **Production Ready**  

---

## ��� **Welcome to the Rogue AI Lab**

**Two complete layers. One powerful protocol.**
```python
import oan

# Layer 1: AI Agents
oan.print_banner()
entity = oan.execute_entity("my_entity.obs")

# Layer 2: Web3 (Coming to mainnet)
# Mint entities as NFTs
# Stake $OAN tokens
# Vote on DAO proposals
# Trade on marketplace
```

**Build the future of autonomous AI agents.** ���

⭐ **Star us on GitHub!**

---

**Made with ��� by the OAN Development Team**
