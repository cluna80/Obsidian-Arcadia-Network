"""
OAN Engine — Rust Accelerator
Usage:
    from rust_engine import RustEngine, is_available
"""

import os
import sys


def is_available() -> bool:
    try:
        import oan_engine  # noqa
        return True
    except ImportError:
        return False


class RustEngine:
    def __init__(self):
        if not is_available():
            raise ImportError("oan_engine not found. Run: maturin develop --release")
        import oan_engine
        self._engine = oan_engine.PyEntityEngine()

    def spawn(self, name: str, entity_type: str = "generic") -> str:
        return self._engine.spawn(name, entity_type)

    def spawn_batch(self, count: int, entity_type: str = "generic") -> list:
        return self._engine.spawn_batch(count, entity_type)

    def tick(self) -> list:
        return self._engine.tick()

    def run_cycles(self, n: int) -> dict:
        return self._engine.run_cycles(n)

    @property
    def entity_count(self) -> int:
        return self._engine.entity_count()

    @property
    def alive_count(self) -> int:
        return self._engine.alive_count()

    @property
    def cycle(self) -> int:
        return self._engine.current_cycle()


class RustDslCompiler:
    def __init__(self):
        if not is_available():
            raise ImportError("oan_engine not found.")
        import oan_engine
        self._compiler = oan_engine.PyDslCompiler()

    def compile(self, source: str) -> dict:
        return self._compiler.compile_source(source)


class RustSimulator:
    def __init__(self):
        if not is_available():
            raise ImportError("oan_engine not found.")
        import oan_engine
        self._sim = oan_engine.PySimulator()

    def simulate_match(self, a: dict, b: dict) -> dict:
        return self._sim.simulate_match(a, b)


def benchmark(entity_count: int = 1000, cycles: int = 10000) -> dict:
    import oan_engine
    return oan_engine.benchmark_cycles(entity_count, cycles)


EXAMPLE_DSL = """
entity WarriorBot : Fighter {
    trait strength = 85
    trait agility  = 70
    trait stamina  = 90

    on energy < 20 {
        action: rest
        priority: 100
        energy_cost: -30
    }

    on energy > 80 {
        action: attack
        priority: 50
        energy_cost: 20
        rep_gain: 10
    }

    on always {
        action: idle
        priority: 0
        energy_cost: 1
    }
}
"""

if __name__ == "__main__":
    python_baseline = 82

    print()
    print("  ╔═══════════════════════════════════════════════╗")
    print("  ║   OAN ENGINE BENCHMARK                        ║")
    print("  ╚═══════════════════════════════════════════════╝")
    print()

    if not is_available():
        print("  ✘  oan_engine not found. Run: maturin develop --release")
        sys.exit(1)

    # Benchmark
    stats       = benchmark(entity_count=1000, cycles=10000)
    rust_cps    = stats["cycles_per_sec"]
    speedup     = rust_cps / python_baseline

    print(f"  Entities  :  1,000")
    print(f"  Cycles    :  10,000")
    print(f"  Elapsed   :  {stats['elapsed_secs']:.4f}s")
    print()
    print(f"  Python    :  {python_baseline:>12,.0f} cycles/sec  (baseline)")
    print(f"  Rust      :  {rust_cps:>12,.0f} cycles/sec")
    print(f"  Speedup   :  {speedup:>12.0f}x  🚀")
    print(f"  Ops/sec   :  {stats['ops_per_sec']:>12,.0f}")
    print()

    # DSL test
    compiler = RustDslCompiler()
    result   = compiler.compile(EXAMPLE_DSL)
    print(f"  DSL compile :  {result['entity_name']} → {result['opcode_count']} opcodes")
    print(f"  Rules       :  {result['rule_count']}")
    print(f"  Hash        :  {result['source_hash'][:16]}...")
    print()

    # Match sim test
    sim    = RustSimulator()
    result = sim.simulate_match(
        {"strength": 85.0, "agility": 70.0, "stamina": 90.0, "skill": 80.0},
        {"strength": 75.0, "agility": 90.0, "stamina": 75.0, "skill": 85.0},
    )
    print(f"  Match sim   :  winner={result['winner_id'][:8]}...  "
          f"{result['score_a']:.1f} - {result['score_b']:.1f}  "
          f"upset={result['upset']}")
    print()
    print("  ✔  All systems operational")
    print()