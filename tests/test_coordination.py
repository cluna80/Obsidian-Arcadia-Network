from engine.executor import execute_multi_entity
from engine.coordination import coord_hub
from engine.communication import comm_hub

def main():
    entities = execute_multi_entity([
        "entities/worker1.ent",
        "entities/worker2.ent"
    ], cycles=2, energy_per_tool=10)
    
    print("\n" + "="*70)
    print("TESTING ENTITY COORDINATION")
    print("="*70 + "\n")
    
    # Simulate workers completing tasks
    print("Simulating task completion...")
    coord_hub.mark_ready("Worker1", result={"data": "1000 data points", "accuracy": 98})
    coord_hub.mark_ready("Worker2", result={"sentiment": "Bullish", "confidence": 95})
    
    # Check if workers are ready
    print(f"\nWorker1 ready: {coord_hub.is_ready('Worker1')}")
    print(f"Worker2 ready: {coord_hub.is_ready('Worker2')}")
    
    # Aggregate results
    print("\nAggregating results from workers...")
    results = coord_hub.aggregate(["Worker1", "Worker2"])
    
    print("\nAggregated Results:")
    for i, result in enumerate(results, 1):
        print(f"  {i}. {result}")
    
    # Test waiting
    print("\n" + "-"*70)
    print("Testing WAIT coordination...")
    coord_hub.wait_for("Coordinator", "Worker1")
    coord_hub.wait_for("Coordinator", "Worker2")
    
    print(f"\nCoordinator can proceed: {coord_hub.can_proceed('Coordinator')}")
    
    print("\n" + "="*70 + "\n")

if __name__ == "__main__":
    main()
