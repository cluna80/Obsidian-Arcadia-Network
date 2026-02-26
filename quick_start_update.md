## ��� Quick Start

### Prerequisites
```bash
# Python 3.10+
python --version

# Rust (for high-performance engine)
rustc --version

# Node.js 18+
node --version

# Git
git --version
```

### Installation
```bash
# 1. Clone the repository
git clone https://github.com/cluna80/Obsidian-Arcadia-Network.git
cd Obsidian-Arcadia-Network

# 2. Install OAN Protocol (Python package)
pip install -e .

# 3. Build Rust engine (optional, for maximum performance)
cd rust/oan-engine
pip install maturin
maturin develop --release
cd ../..

# 4. Install Solidity dependencies
cd web3
npm install
cd ..
```

### Launch OAN CLI
```bash
# Start the OAN command-line interface
oan

# This launches the interactive CLI with:
# - Entity management
# - Protocol status
# - Demo launcher
# - Test runner
```

### Quick Test
```bash
# Test the installation
oan --version

# Run protocol tests
cd web3
npx hardhat test

# Run Rust integration tests
cd ../rust/integration_tests
python test_full_protocol.py

# Run investor demo
cd ../../demos/investor_demo
python live_economy_demo.py
```

### Interactive Demos
```bash
# AI Entity Conversations (requires Ollama)
cd demos/ollama_entities
python ai_entity_conversation.py

# Founding Council Interview
python oan_founding_council.py

# AI Battle Arena
python ai_battle_arena.py

# Live Economy Simulation
cd ../investor_demo
python live_economy_demo.py
```

### Using Ollama Demos
```bash
# 1. Install Ollama (if not already installed)
# Visit: https://ollama.ai

# 2. Start Ollama server (in separate terminal)
ollama serve

# 3. Pull a model
ollama pull gemma3:12b

# 4. Run AI demos
cd demos/ollama_entities
python oan_founding_council.py
```

### What You Get

After installation, you have access to:
- ✅ `oan` CLI command (interactive interface)
- ✅ 125+ Smart Contracts (all 7 layers)
- ✅ High-performance Rust engine (335k+ ops/sec)
- ✅ AI-powered entity demos (Ollama integration)
- ✅ Live economy simulator
- ✅ Complete test suites (370+ tests)
