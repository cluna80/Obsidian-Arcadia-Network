"""
OAN Entity Manager
Manages multiple entities, spawning, and lifecycle
"""

from typing import Dict, List, Optional
from engine.entity import Entity
import uuid


class EntityManager:
    """Manages all entities in the OAN network"""
    
    def __init__(self):
        self.entities: Dict[str, Entity] = {}
        self.entity_names: Dict[str, str] = {}
        self.parent_child: Dict[str, List[str]] = {}
        self.active_entities: List[str] = []
        
    def register_entity(self, entity: Entity, parent_id: Optional[str] = None) -> str:
        """Register an entity in the network"""
        entity_id = str(uuid.uuid4())
        
        self.entities[entity_id] = entity
        self.entity_names[entity.name] = entity_id
        self.active_entities.append(entity_id)
        
        if parent_id:
            if parent_id not in self.parent_child:
                self.parent_child[parent_id] = []
            self.parent_child[parent_id].append(entity_id)
        
        print(f"[ENTITY MANAGER] Registered: {entity.name} (ID: {entity_id[:8]}...)")
        if parent_id:
            parent = self.entities.get(parent_id)
            parent_name = parent.name if parent else "Unknown"
            print(f"[ENTITY MANAGER]   Parent: {parent_name}")
        
        return entity_id
    
    def spawn_entity(self, parent_id: str, config: dict) -> Optional[str]:
        """Spawn a new entity from a parent"""
        parent = self.entities.get(parent_id)
        if not parent:
            print(f"[ENTITY MANAGER] Cannot spawn: Parent not found")
            return None
        
        spawn_cost = config.get('spawn_cost', 20)
        if hasattr(parent, 'energy') and parent.energy < spawn_cost:
            print(f"[ENTITY MANAGER] Insufficient energy to spawn (need: {spawn_cost}, have: {parent.energy})")
            return None
        
        try:
            child_name = config.get('name', f"{parent.name}_Child")
            child = Entity(
                name=child_name,
                type=config.get('type', parent.type),
                state=config.get('state', 'Active'),
                energy=config.get('energy', 50),
                modules=config.get('modules', []),
                intent=config.get('intent', f"Assist {parent.name}"),
                binds=config.get('binds', []),
                mode=config.get('mode', parent.mode),
                world=config.get('world', parent.world),
                tokenized=config.get('tokenized', False),
                reputation=config.get('reputation', 0)
            )
            
            if hasattr(parent, 'energy'):
                parent.energy -= spawn_cost
            
            child_id = self.register_entity(child, parent_id=parent_id)
            
            print(f"[ENTITY MANAGER] Spawned: {child.name}")
            print(f"[ENTITY MANAGER]   Parent energy: {parent.energy}")
            
            return child_id
            
        except Exception as e:
            print(f"[ENTITY MANAGER] Spawn failed: {e}")
            return None
    
    def get_entity(self, entity_id: str) -> Optional[Entity]:
        """Get entity by ID"""
        return self.entities.get(entity_id)
    
    def get_entity_by_name(self, name: str) -> Optional[Entity]:
        """Get entity by name"""
        entity_id = self.entity_names.get(name)
        return self.entities.get(entity_id) if entity_id else None
    
    def get_children(self, parent_id: str) -> List[Entity]:
        """Get all children of a parent entity"""
        child_ids = self.parent_child.get(parent_id, [])
        return [self.entities[cid] for cid in child_ids if cid in self.entities]
    
    def get_active_entities(self) -> List[Entity]:
        """Get all active entities"""
        return [self.entities[eid] for eid in self.active_entities if eid in self.entities]
    
    def display_hierarchy(self):
        """Display entity hierarchy"""
        print("\n" + "="*70)
        print("OBSIDIAN ARCADIA NETWORK - ENTITY HIERARCHY")
        print("="*70)
        
        root_ids = [eid for eid in self.entities.keys() 
                   if not any(eid in children for children in self.parent_child.values())]
        
        def print_tree(entity_id: str, indent: int = 0):
            entity = self.entities.get(entity_id)
            if not entity:
                return
            
            prefix = "  " * indent + ("└─ " if indent > 0 else "")
            status = "●" if entity_id in self.active_entities else "○"
            energy_info = f"E:{entity.energy}" if hasattr(entity, 'energy') else ""
            rep_info = f"R:{entity.reputation}" if hasattr(entity, 'reputation') else ""
            
            print(f"{prefix}{status} {entity.name} [{entity.state}] {energy_info} {rep_info}")
            
            children = self.parent_child.get(entity_id, [])
            for child_id in children:
                print_tree(child_id, indent + 1)
        
        for root_id in root_ids:
            print_tree(root_id)
        
        stats = self.get_network_stats()
        print("\n" + "-"*70)
        print(f"Total: {stats['total_entities']} | Active: {stats['active_entities']} | "
              f"Parents: {stats['parent_entities']} | Children: {stats['total_children']}")
        print("="*70 + "\n")
    
    def get_network_stats(self) -> dict:
        """Get network statistics"""
        return {
            'total_entities': len(self.entities),
            'active_entities': len(self.active_entities),
            'parent_entities': len(self.parent_child),
            'total_children': sum(len(children) for children in self.parent_child.values())
        }


# Global entity manager instance
entity_manager = EntityManager()
