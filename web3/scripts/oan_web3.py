"""OAN Web3 Integration"""
from web3 import Web3

class OANWeb3:
    def __init__(self, provider_url):
        self.w3 = Web3(Web3.HTTPProvider(provider_url))
        print(f"Connected to chain {self.w3.eth.chain_id}")
    
    def mint_entity(self, private_key, name, entity_type, metadata_uri):
        """Mint entity NFT"""
        print(f"Minting: {name}")
        # Implementation here
        return {"token_id": 1}
