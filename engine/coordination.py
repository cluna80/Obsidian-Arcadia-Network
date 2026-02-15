"""
OAN Coordination System
Enables entity synchronization and coordination
"""

from typing import Dict, List, Set
from collections import defaultdict
import time


class CoordinationHub:
    """Manages entity coordination"""
    
    def __init__(self):
        self.waiting: Dict[str, Set[str]] = defaultdict(set)
        self.ready: Set[str] = set()
        self.results: Dict[str, any] = {}
    
    def wait_for(self, waiter_name: str, target_name: str):
        """Entity waits for another entity"""
        self.waiting[waiter_name].add(target_name)
        print(f"[COORDINATION] {waiter_name} waiting for {target_name}")
    
    def mark_ready(self, entity_name: str, result=None):
        """Mark entity as ready/complete"""
        self.ready.add(entity_name)
        if result is not None:
            self.results[entity_name] = result
        print(f"[COORDINATION] {entity_name} marked ready")
    
    def is_ready(self, entity_name: str) -> bool:
        """Check if entity is ready"""
        return entity_name in self.ready
    
    def can_proceed(self, entity_name: str) -> bool:
        """Check if entity can proceed (all dependencies ready)"""
        dependencies = self.waiting.get(entity_name, set())
        return all(dep in self.ready for dep in dependencies)
    
    def sync_with(self, entities: List[str]):
        """Synchronize multiple entities"""
        print(f"[COORDINATION] Syncing entities: {', '.join(entities)}")
        # Wait for all to be ready
        waiting_for = set(entities)
        while waiting_for:
            ready_now = waiting_for & self.ready
            waiting_for -= ready_now
            if waiting_for:
                time.sleep(0.1)
        print(f"[COORDINATION] All synced: {', '.join(entities)}")
    
    def aggregate(self, entities: List[str]) -> List[any]:
        """Aggregate results from multiple entities"""
        results = []
        for entity_name in entities:
            if entity_name in self.results:
                results.append(self.results[entity_name])
        print(f"[COORDINATION] Aggregated results from {len(results)} entities")
        return results


# Global coordination hub
coord_hub = CoordinationHub()
