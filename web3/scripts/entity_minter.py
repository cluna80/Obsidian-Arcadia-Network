"""Complete Entity Minting Workflow"""
import sys
sys.path.append('../..')

from oan.engine.parser import parse_dsl
from metadata_generator import MetadataGenerator

class EntityMinter:
    def __init__(self, provider_url, contract_address, private_key):
        """Initialize minter"""
        self.provider_url = provider_url
        self.contract_address = contract_address
        self.private_key = private_key
        self.metadata_gen = MetadataGenerator()
        print("[MINTER] Initialized")
    
    def mint_from_dsl(self, dsl_path):
        """Mint entity from OBSIDIAN file"""
        print(f"\n[1/3] Parsing {dsl_path}...")
        entity = parse_dsl(dsl_path)
        print(f"      Entity: {entity.name}")
        
        print("\n[2/3] Generating metadata...")
        metadata = self.metadata_gen.generate_metadata(
            entity_name=entity.name,
            entity_type=entity.type,
            energy=entity.energy,
            reputation=entity.reputation
        )
        
        print("\n[3/3] Ready to mint!")
        print(f"      Name: {entity.name}")
        print(f"      Type: {entity.type}")
        
        return {
            'entity': entity,
            'metadata': metadata,
            'ready': True
        }

if __name__ == "__main__":
    minter = EntityMinter(
        provider_url="http://localhost:8545",
        contract_address="0x...",
        private_key="0x..."
    )
    
    result = minter.mint_from_dsl("../../examples/worker1.ent")
    print(f"\n✅ Entity ready to mint: {result['entity'].name}")
