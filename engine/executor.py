from engine.parser import parse_dsl
from engine.logger_cyber import (
    log_system,
    log_entity_cyber as log_entity,
    log_behavior_engine,
    log_execute_engine,
    log_tool_execution,
    log_reputation_update,
    log_state_transition,
    display_cycle_header,
    display_network_hierarchy,
    display_final_report,
    print_ascii_header,
    display_glitch_banner
)
from tools.tools import Tool
from engine.entity_manager import entity_manager
from engine.communication import comm_hub
from engine.coordination import coord_hub
import time


def execute_entity(file_path, cycles=1, energy_per_tool=5):
    """Execute entity with cyberpunk dashboard"""
    start_time = time.time()
    
    # Cyberpunk header
    print_ascii_header()
    display_glitch_banner()
    
    entity = parse_dsl(file_path)
    log_system("Initializing Obsidian Arcadia Runtime...", "cyber")
    log_entity(entity)
    
    # Register with EntityManager
    entity_id = entity_manager.register_entity(entity)
    
    has_behaviors = bool(entity.behavior_rules or entity.execute_rules)
    if has_behaviors:
        log_system("Behavioral Intelligence: ACTIVE", "cyber")
    
    for cycle in range(1, cycles + 1):
        if cycles > 1:
            display_cycle_header(cycle, cycles)
        
        if has_behaviors:
            old_state = entity.state if hasattr(entity, 'state') else None
            entity.apply_behaviors()
            
            if old_state and hasattr(entity, 'state') and entity.state != old_state:
                log_state_transition(entity.name, old_state, entity.state)
            
            if hasattr(entity, 'energy') and entity.energy < 10:
                log_system(f"Low Energy Warning: {entity.energy}", "warning")
        
        if has_behaviors and entity.execute_rules:
            tool_names = entity.get_conditional_tools()
        else:
            tool_names = entity.binds
        
        if not tool_names:
            log_system("No tools to execute", "warning")
            continue
        
        tools = [Tool(name) for name in tool_names]
        
        for tool in tools:
            if hasattr(entity, 'energy'):
                if entity.energy < energy_per_tool:
                    log_system(f"Insufficient energy for {tool.name}", "warning")
                    continue
            
            log_tool_execution(tool.name, entity.intent)
            tool.execute(entity.intent)
            
            old_rep = entity.reputation
            entity.update_reputation(1)
            log_reputation_update(entity.name, 1, entity.reputation)
            
            if hasattr(entity, 'energy'):
                entity.energy = max(0, entity.energy - energy_per_tool)
        
        if has_behaviors:
            old_state = entity.state if hasattr(entity, 'state') else None
            entity.apply_behaviors()
            if old_state and hasattr(entity, 'state') and entity.state != old_state:
                log_state_transition(entity.name, old_state, entity.state)
        
        if cycles > 1:
            log_system(f"Cycle {cycle} Complete:")
            log_system(f"  State: {getattr(entity, 'state', 'N/A')}")
            log_system(f"  Energy: {getattr(entity, 'energy', 'N/A')}")
            log_system(f"  Reputation: {entity.reputation}")
    
    # Final report
    execution_time = time.time() - start_time
    display_final_report(entity, execution_time)
    
    # Display network hierarchy
    display_network_hierarchy(entity_manager)
    
    return entity


def execute_multi_entity(file_paths, cycles=1, energy_per_tool=5):
    """Execute multiple entities together"""
    print_ascii_header()
    display_glitch_banner()
    
    entities = []
    
    log_system("Multi-Entity Execution Mode", "cyber")
    log_system(f"Loading {len(file_paths)} entities...")
    
    # Load all entities
    for file_path in file_paths:
        entity = parse_dsl(file_path)
        entity_id = entity_manager.register_entity(entity)
        entities.append((entity_id, entity))
        log_system(f"  Loaded: {entity.name}", "success")
    
    log_system(f"\nStarting execution with {cycles} cycle(s)...\n", "info")
    
    # Execute all entities
    for cycle in range(1, cycles + 1):
        display_cycle_header(cycle, cycles)
        
        for entity_id, entity in entities:
            log_system(f"\n--- Executing: {entity.name} ---", "cyber")
            
            if entity.behavior_rules:
                old_state = entity.state if hasattr(entity, 'state') else None
                entity.apply_behaviors()
                if old_state and hasattr(entity, 'state') and entity.state != old_state:
                    log_state_transition(entity.name, old_state, entity.state)
            
            if entity.execute_rules:
                tool_names = entity.get_conditional_tools()
            else:
                tool_names = entity.binds
            
            tools = [Tool(name) for name in tool_names]
            for tool in tools:
                if hasattr(entity, 'energy') and entity.energy < energy_per_tool:
                    continue
                    
                log_tool_execution(tool.name, entity.intent)
                tool.execute(entity.intent)
                entity.update_reputation(1)
                log_reputation_update(entity.name, 1, entity.reputation)
                
                if hasattr(entity, 'energy'):
                    entity.energy = max(0, entity.energy - energy_per_tool)
            
            if entity.behavior_rules:
                old_state = entity.state if hasattr(entity, 'state') else None
                entity.apply_behaviors()
                if old_state and hasattr(entity, 'state') and entity.state != old_state:
                    log_state_transition(entity.name, old_state, entity.state)
        
        log_system(f"\n--- Cycle {cycle} Complete ---")
        for entity_id, entity in entities:
            log_system(f"  {entity.name}: E:{getattr(entity, 'energy', 'N/A')} R:{entity.reputation} S:{getattr(entity, 'state', 'N/A')}")
    
    log_system(f"\nMULTI-ENTITY EXECUTION COMPLETE", "success")
    
    display_network_hierarchy(entity_manager)
    
    return [entity for _, entity in entities]


def test_communication():
    """Test entity communication"""
    log_system("\nTesting Communication System...", "cyber")
    
    # Broadcast
    comm_hub.broadcast("Coordinator", "Starting analysis phase")
    
    # Direct message
    comm_hub.send_to("Coordinator", "Worker1", "Process dataset A")
    
    # Channel
    comm_hub.subscribe("Worker1", "results")
    comm_hub.subscribe("Worker2", "results")
    comm_hub.publish("Worker1", "results", "Dataset A processed: 95% accuracy")
    
    # Get messages
    messages = comm_hub.get_messages("Worker1")
    log_system(f"\nWorker1 received {len(messages)} message(s)", "info")


def test_coordination():
    """Test entity coordination"""
    log_system("\nTesting Coordination System...", "cyber")
    
    # Mark entities ready
    coord_hub.mark_ready("Worker1", result={"status": "complete", "data": [1,2,3]})
    coord_hub.mark_ready("Worker2", result={"status": "complete", "data": [4,5,6]})
    
    # Aggregate results
    results = coord_hub.aggregate(["Worker1", "Worker2"])
    log_system(f"Aggregated {len(results)} results", "success")


def spawn_test_entity(parent_name, child_name, energy=50):
    """Helper to spawn a test entity"""
    parent_id = entity_manager.entity_names.get(parent_name)
    if not parent_id:
        log_system(f"Parent {parent_name} not found", "error")
        return None
    
    config = {
        'name': child_name,
        'energy': energy,
        'type': 'Worker',
        'intent': f'Assist {parent_name}',
        'binds': ['DataProcessor']
    }
    
    child_id = entity_manager.spawn_entity(parent_id, config)
    return child_id
