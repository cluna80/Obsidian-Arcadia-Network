"""NFT Metadata Generator for OAN Entities"""
import json
from datetime import datetime

class MetadataGenerator:
    def generate_metadata(self, entity_name, entity_type, energy, reputation, generation=1):
        """Generate ERC-721 compliant metadata"""
        metadata = {
            "name": f"{entity_name} #{generation}G",
            "description": f"{entity_name} is an autonomous entity in the Obsidian Arcadia Network.",
            "attributes": [
                {"trait_type": "Entity Type", "value": entity_type},
                {"trait_type": "Generation", "value": generation},
                {"trait_type": "Energy", "value": energy, "max_value": 1000},
                {"trait_type": "Reputation", "value": reputation, "max_value": 1000}
            ],
            "created": datetime.utcnow().isoformat()
        }
        return metadata
    
    def save_metadata(self, metadata, output_path):
        """Save metadata to JSON file"""
        with open(output_path, 'w') as f:
            json.dump(metadata, f, indent=2)
        print(f"Metadata saved to {output_path}")
