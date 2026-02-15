from engine.executor import execute_multi_entity


def main():
    entities = execute_multi_entity([
        "entities/worker1.ent",
        "entities/worker2.ent"
    ], cycles=5, energy_per_tool=10)


if __name__ == "__main__":
    main()
