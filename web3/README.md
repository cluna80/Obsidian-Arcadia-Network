# OAN Web3 Integration - Phase 2.1

## Files

- `contracts/OANEntity.sol` - ERC-721 NFT contract
- `scripts/deploy.js` - Hardhat deployment script
- `scripts/oan_web3.py` - Python Web3 integration
- `scripts/metadata_generator.py` - NFT metadata creator
- `scripts/entity_minter.py` - Complete minting workflow

## Setup

### Install Hardhat (Solidity)
```bash
npm install --save-dev hardhat @openzeppelin/contracts
npm install --save-dev @nomicfoundation/hardhat-ethers ethers
```

### Install Python Dependencies
```bash
pip install web3 requests
```

## Usage

### Deploy Contract
```bash
cd web3
npx hardhat run scripts/deploy.js --network localhost
```

### Mint Entity
```python
from scripts.entity_minter import EntityMinter

minter = EntityMinter(
    provider_url="http://localhost:8545",
    contract_address="0x...",
    private_key="0x..."
)

result = minter.mint_from_dsl("../examples/worker1.ent")
```

## Status

Phase 2.1: Tokenized Entities
- âœ… NFT Smart Contract
- âœ… Deployment Scripts
- âœ… Python Integration
- âœ… Metadata Generation
- íº§ IPFS Integration (Optional)
- íº§ Testnet Deployment (Next)

For complete documentation, see repository root.
