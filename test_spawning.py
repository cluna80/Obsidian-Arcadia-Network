from engine.parser import parse_dsl
from engine.entity_manager import entity_manager
from engine.executor import spawn_test_entity

def main():
    print("="*70)
    print("TESTING ENTITY SPAWNING")
    print("="*70 + "\n")
    
    # Create parent entity
    parent = parse_dsl("entities/worker1.ent")
    parent_id = entity_manager.register_entity(parent)
    
    print(f"Parent entity created: {parent.name}")
    print(f"Parent energy: {parent.energy}\n")
    
    # Spawn first child
    print("Spawning Child1...")
    child1_id = spawn_test_entity("Worker1", "Child1", energy=50)
    
    if child1_id:
        print(f"✓ Child1 spawned successfully\n")
    
    # Spawn second child
    print("Spawning Child2...")
    child2_id = spawn_test_entity("Worker1", "Child2", energy=30)
    
    if child2_id:
        print(f"✓ Child2 spawned successfully\n")
    
    # Display hierarchy
    entity_manager.display_hierarchy()
    
    # Try spawning without enough energy
    print("\nAttempting to spawn with low energy...")
    child3_id = spawn_test_entity("Worker1", "Child3", energy=50)

if __name__ == "__main__":
    main()
