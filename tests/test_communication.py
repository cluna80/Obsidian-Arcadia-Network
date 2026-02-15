from engine.executor import execute_multi_entity
from engine.communication import comm_hub

def main():
    # Load entities
    entities = execute_multi_entity([
        "entities/worker1.ent",
        "entities/worker2.ent"
    ], cycles=3, energy_per_tool=10)
    
    print("\n" + "="*70)
    print("TESTING ENTITY COMMUNICATION")
    print("="*70 + "\n")
    
    # Test broadcast
    comm_hub.broadcast("Worker1", "Data collection complete")
    
    # Test direct messaging
    comm_hub.send_to("Worker1", "Worker2", "Dataset ready for analysis")
    comm_hub.send_to("Worker2", "Worker1", "Analysis complete: 95% positive sentiment")
    
    # Test channels
    comm_hub.subscribe("Worker1", "results")
    comm_hub.subscribe("Worker2", "results")
    comm_hub.publish("Worker1", "results", "Collected 1000 data points")
    comm_hub.publish("Worker2", "results", "Sentiment: Bullish")
    
    # Get messages
    print("\n" + "-"*70)
    print("Messages for Worker2:")
    messages = comm_hub.get_messages("Worker2", "results")
    for msg in messages:
        print(f"  {msg}")
    
    print("\n" + "="*70 + "\n")

if __name__ == "__main__":
    main()
