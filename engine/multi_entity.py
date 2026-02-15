"""
Multi-Entity Actions
Handles spawning, communication, and coordination between entities
"""

from typing import Dict, List, Optional, Any
from engine.entity import Entity


class SpawnAction:
    """Represents a SPAWN command"""
    
    def __init__(self, entity_name: str, config: Dict[str, Any]):
        self.entity_name = entity_name
        self.config = config
    
    def execute(self, parent_entity: Entity, entity_manager):
        """Execute the spawn action"""
        from entity_manager import entity_manager as em
        
        # Get parent ID
        parent_id = None
        for eid, entity in em.entities.items():
            if entity == parent_entity:
                parent_id = eid
                break
        
        if not parent_id:
            print(f"[SPAWN] ❌ Parent entity not registered")
            return None
        
        # Prepare config
        spawn_config = {
            'name': self.entity_name,
            **self.config
        }
        
        # Spawn child
        child_id = em.spawn_entity(parent_id, spawn_config)
        return child_id
    
    def __repr__(self):
        return f"SpawnAction({self.entity_name}, {self.config})"


class MessageAction:
    """Represents communication actions"""
    
    def __init__(self, action_type: str, target: str, message: str = ""):
        self.action_type = action_type  # BROADCAST, SEND, LISTEN
        self.target = target  # channel name or entity name
        self.message = message
    
    def __repr__(self):
        return f"MessageAction({self.action_type}, {self.target})"


class CoordinationAction:
    """Represents coordination actions"""
    
    def __init__(self, action_type: str, targets: List[str]):
        self.action_type = action_type  # WAIT, SYNC, AGGREGATE
        self.targets = targets
    
    def __repr__(self):
        return f"CoordinationAction({self.action_type}, {self.targets})"


def parse_spawn_config(config_str: str) -> Dict[str, Any]:
    """
    Parse spawn configuration
    
    Example:
    TYPE: Analyzer, ENERGY: 50, INTENT: "Help parent"
    """
    config = {}
    
    # Split by comma
    parts = config_str.split(',')
    
    for part in parts:
        part = part.strip()
        if ':' not in part:
            continue
        
        key, value = part.split(':', 1)
        key = key.strip().lower()
        value = value.strip().strip('"').strip("'")
        
        # Type conversion
        if key in ['energy', 'reputation', 'spawn_cost']:
            try:
                value = int(value)
            except ValueError:
                pass
        elif key == 'tokenized':
            value = value.lower() == 'true'
        elif key == 'binds':
            value = [v.strip() for v in value.split(',')]
        
        config[key] = value
    
    return config


# Example usage in DSL:
"""
ENTITY ParentBot
ENERGY 100

BEHAVIOR
  IF REPUTATION > 5 THEN SPAWN ChildAnalyzer WITH {TYPE: Analyzer, ENERGY: 50}
END

INTENT "Coordinate analysis tasks"
MODE Production
"""