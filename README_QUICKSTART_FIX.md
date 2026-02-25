## íº€ Quick Start

### Prerequisites
```````````bash
# Python 3.10+
python3 --version  # Use python3 on Linux/WSL

# Node.js 18+
node --version

# Git
git --version
```````````

### Installation
```````````bash
# Clone repository
git clone https://github.com/cluna80/Obsidian-Arcadia-Network.git
cd Obsidian-Arcadia-Network

# Install Python dependencies
pip3 install requests  # Required for demos
pip3 install -e .      # Install OAN package

# Install Solidity dependencies (Layers 2-6)
cd web3
npm install
```````````

### Run Tests
```````````bash
# Python tests (Layer 1)
python3 run_all_tests.py

# All Solidity tests
cd web3
npx hardhat test

# Specific layer tests
npx hardhat test test/layer2.test.js
npx hardhat test test/layer3.test.js
npx hardhat test test/layer4.test.js
npx hardhat test test/layer5.test.js
npx hardhat test test/layer6.test.js

# Security tests
npx hardhat test test/security.test.js
```````````

## í¾® Live Demos

### AI Battle Royale
Two AI models fight, winner gets minted as NFT entity!
```````````bash
# Start Ollama (Terminal 1)
ollama serve

# Run demo (Terminal 2)
cd demos/ai_battle
python3 battle_demo_dual.py
```````````

**Features:**
- Real AI decision-making (Ollama + tactical AI)
- Turn-based combat system
- Winner minted as NFT entity
- Battle history tracked on-chain

**Note:** Use `python3` on Linux/WSL/Mac. Windows users can use `python`.
