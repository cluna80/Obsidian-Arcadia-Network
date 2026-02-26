# OAN Protocol - Interactive Demos

Complete demonstration suite for the Obsidian Arcadia Network.

## Quick Start
```bash
# Launch interactive demo menu
python demo_launcher.py
```

## Demo Categories

### í´– AI Entity Demos (Ollama-Powered)
**Location:** `ollama_entities/`  
**Requirements:** Ollama + Gemma 12B

1. **AI Entity Conversation** - Autonomous dialogue between entities
2. **Founding Council Interview** - Meet the Genesis Entities  
3. **AI Battle Arena** - Strategic combat with AI commentary
4. **AI Movie Director** - AI-generated movie scripts

### í²° Investor Demos
**Location:** `investor_demo/`  
**Requirements:** Rust Engine

5. **Live Economy Simulation** - Real revenue generation (60 seconds)
   - Shows: $1.3k revenue, $6k volume, 5 revenue streams
   - Projections: $716M/year â†’ $7.17T at scale

### í¶€ Performance Demos
**Location:** `../rust/integration_tests/`  
**Requirements:** Rust Engine

6. **Tournament Bracket** - 64 athletes, 41k matches/sec
7. **Battle Royale** - 100 fighters, last one standing
8. **Ultimate Stress Test** - 1.5M entities/sec, 710k compiles/sec
9. **Full Stack Integration** - Complete entity pipeline
10. **All Integration Tests** - 370+ tests

### í³¦ Legacy Demos
**Location:** Various folders  
**Requirements:** Python only

11. **Entity Spawning** - Create and manage entities
12. **Marketplace** - NFT trading simulation
13. **Reputation System** - Track entity reputation
14. **AI Battle** - Combat mechanics

## Setup by Demo Type

### For Ollama Demos (1-4)
```bash
# Install Ollama
# Visit: https://ollama.ai

# Start Ollama (separate terminal)
ollama serve

# Pull model
ollama pull gemma3:12b

# Run demos
cd ollama_entities
python oan_founding_council.py
```

### For Rust Demos (5-10)
```bash
# Build Rust engine (one-time)
cd rust/oan-engine
pip install maturin
maturin develop --release

# Run demos
cd ../integration_tests
python test_tournament.py
```

### For Legacy Demos (11-14)
```bash
# Already installed with pip install -e .
cd demos/entity_spawning
python main.py  # or whatever the script is
```

## Recommended Demo Paths

**For Investors:**
1. Live Economy Simulation (shows revenue)
2. Ultimate Stress Test (shows performance)
3. Founding Council Interview (shows vision)

**For Developers:**
1. Full Stack Integration (shows architecture)
2. Ultimate Stress Test (shows capabilities)
3. All Integration Tests (shows reliability)

**For Community/Marketing:**
1. Founding Council Interview (shows personality)
2. AI Battle Arena (shows entertainment)
3. Battle Royale (shows excitement)

**For Technical Evaluation:**
1. Ultimate Stress Test (raw numbers)
2. All Integration Tests (comprehensive)
3. Tournament Bracket (consistency)

## Performance Metrics

From these demos you'll observe:

| Metric | Value |
|--------|-------|
| Match Simulations | 335,840/sec |
| Entity Spawning | 1,550,116/sec |
| DSL Compilation | 710,634/sec |
| Revenue (current) | $716M/year |
| Revenue (at scale) | $7.17T/year |

## Demo Duration Guide

| Demo | Time | Difficulty |
|------|------|------------|
| AI Conversation | 3 min | Easy |
| Founding Council | 5-10 min | Easy |
| Battle Arena | 2 min | Easy |
| Movie Director | 3 min | Easy |
| Live Economy | 1 min | Easy |
| Tournament | 1 min | Easy |
| Battle Royale | 1 min | Easy |
| Stress Test | 2 min | Medium |
| Full Stack | 1 min | Medium |
| All Tests | 5 min | Medium |

## Troubleshooting

**"Ollama not responding"**
```bash
# Check if running
curl http://localhost:11434/api/version

# Start it
ollama serve
```

**"Rust engine not found"**
```bash
# Build it
cd rust/oan-engine
maturin develop --release

# Verify
python -c "from oan_engine import PyEntityEngine"
```

**"Module not found"**
```bash
# Install from project root
pip install -e .
```

## What Each Demo Demonstrates

| Demo | Showcases | Best For |
|------|-----------|----------|
| AI Conversation | Autonomy, Personality | Community |
| Founding Council | Lore, Vision | Everyone |
| Battle Arena | Strategy, AI | Marketing |
| Movie Director | Creativity | Content |
| Live Economy | Revenue | Investors |
| Tournament | Performance | Developers |
| Battle Royale | Fun Factor | Marketing |
| Stress Test | Raw Power | Investors |
| Full Stack | Integration | Developers |
| All Tests | Reliability | Investors |

## Next Steps

After exploring the demos:

1. **Deploy to Testnet**
```bash
   cd web3
   npx hardhat run scripts/deploy.js --network mumbai
```

2. **Run Full Test Suite**
```bash
   npx hardhat test
```

3. **Build Your Own**
   - Check `docs/DEVELOPMENT.md`
   - Join Discord for help

---

**Repository:** https://github.com/cluna80/Obsidian-Arcadia-Network  
**Discord:** [Join our community](https://discord.gg/oan)  
**Documentation:** `docs/`
