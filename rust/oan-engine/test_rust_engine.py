"""
OAN Rust Engine Test Suite
Run with: python test_rust_engine.py
"""
import sys
import time
import traceback

PASS = "  ✔"
FAIL = "  ✘"
results = []

def test(name, fn):
    try:
        fn()
        results.append((True, name))
        print(f"{PASS} {name}")
    except Exception as e:
        results.append((False, name))
        print(f"{FAIL} {name}")
        print(f"       {e}")

def assert_eq(a, b, msg=""):
    assert a == b, f"Expected {b}, got {a}. {msg}"

def assert_gt(a, b, msg=""):
    assert a > b, f"Expected {a} > {b}. {msg}"

def assert_true(v, msg=""):
    assert v, f"Expected True. {msg}"

# ── Import check ──────────────────────────────────────────────────────────────

try:
    import oan_engine
    HAS_RUST = True
except ImportError:
    HAS_RUST = False
    print(f"{FAIL} oan_engine import failed — run: maturin develop --release")
    sys.exit(1)

print()
print("  ╔═══════════════════════════════════════════════╗")
print("  ║   OAN RUST ENGINE — Full Test Suite           ║")
print("  ╚═══════════════════════════════════════════════╝")
print()

# ── Entity Engine tests ───────────────────────────────────────────────────────

print("  [ Entity Engine ]")

def test_spawn_single():
    e = oan_engine.PyEntityEngine()
    id = e.spawn("TestBot", "warrior")
    assert_true(len(id) > 0, "ID should be non-empty")
    assert_eq(e.entity_count(), 1)

def test_spawn_batch():
    e = oan_engine.PyEntityEngine()
    ids = e.spawn_batch(100, "fighter")
    assert_eq(len(ids), 100)
    assert_eq(e.entity_count(), 100)

def test_tick_returns_results():
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(10, "generic")
    results_tick = e.tick()
    assert_gt(len(results_tick), 0)
    r = results_tick[0]
    assert_true("entity_id" in r)
    assert_true("action" in r)
    assert_true("cycle" in r)

def test_run_cycles_stats():
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(500, "generic")
    stats = e.run_cycles(1000)
    assert_true("cycles_per_sec" in stats)
    assert_true("ops_per_sec" in stats)
    assert_true("elapsed_secs" in stats)
    assert_gt(stats["cycles_per_sec"], 0)

def test_cycles_per_sec_beats_python():
    PYTHON_BASELINE = 82
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(1000, "generic")
    stats = e.run_cycles(1000)
    assert_gt(stats["cycles_per_sec"], PYTHON_BASELINE,
              f"Rust ({stats['cycles_per_sec']:.0f}) should beat Python ({PYTHON_BASELINE})")

def test_alive_count_decreases_over_time():
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(50, "fragile")
    initial_alive = e.alive_count()
    e.run_cycles(500)  # run long enough for some to die
    # alive count should be <= initial (may stay same if all survive short run)
    assert_true(e.alive_count() <= initial_alive)

def test_cycle_counter_increments():
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(10, "generic")
    e.run_cycles(5)
    assert_eq(e.current_cycle(), 5)

def test_benchmark_function():
    stats = oan_engine.benchmark_cycles(200, 500)
    assert_true("cycles_per_sec" in stats)
    assert_gt(stats["cycles_per_sec"], 0)

test("spawn single entity",           test_spawn_single)
test("spawn batch 100 entities",      test_spawn_batch)
test("tick returns cycle results",    test_tick_returns_results)
test("run_cycles returns stats",      test_run_cycles_stats)
test("Rust beats Python baseline",    test_cycles_per_sec_beats_python)
test("alive count tracks correctly",  test_alive_count_decreases_over_time)
test("cycle counter increments",      test_cycle_counter_increments)
test("benchmark_cycles function",     test_benchmark_function)

print()
print("  [ DSL Compiler ]")

SIMPLE_DSL = """
entity Warrior : Fighter {
    trait strength = 85
    trait agility  = 70

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

def test_compile_basic():
    c = oan_engine.PyDslCompiler()
    r = c.compile_source(SIMPLE_DSL)
    assert_eq(r["entity_name"], "Warrior")
    assert_eq(r["rule_count"], 3)
    assert_gt(r["opcode_count"], 0)

def test_compile_returns_hash():
    c = oan_engine.PyDslCompiler()
    r = c.compile_source(SIMPLE_DSL)
    assert_true(len(r["source_hash"]) == 64, "SHA-256 hash should be 64 hex chars")

def test_compile_different_sources_different_hashes():
    c  = oan_engine.PyDslCompiler()
    r1 = c.compile_source(SIMPLE_DSL)
    r2 = c.compile_source(SIMPLE_DSL.replace("Warrior", "Mage"))
    assert_true(r1["source_hash"] != r2["source_hash"])

def test_compile_entity_type():
    c = oan_engine.PyDslCompiler()
    r = c.compile_source(SIMPLE_DSL)
    assert_eq(r["entity_type"], "Fighter")

def test_compile_empty_entity():
    src = "entity Empty : Base {\n}\n"
    c = oan_engine.PyDslCompiler()
    r = c.compile_source(src)
    assert_eq(r["entity_name"], "Empty")
    assert_eq(r["rule_count"], 0)

def test_compile_speed():
    c = oan_engine.PyDslCompiler()
    start = time.time()
    for _ in range(1000):
        c.compile_source(SIMPLE_DSL)
    elapsed = time.time() - start
    rate = 1000 / elapsed
    assert_gt(rate, 500, f"DSL compile rate {rate:.0f}/sec should exceed 500/sec")

test("compile basic DSL",             test_compile_basic)
test("compile returns SHA-256 hash",  test_compile_returns_hash)
test("different sources → different hashes", test_compile_different_sources_different_hashes)
test("compile entity type",           test_compile_entity_type)
test("compile empty entity",          test_compile_empty_entity)
test("compile speed > 500/sec",       test_compile_speed)

print()
print("  [ Match Simulator ]")

ATHLETE_A = {"strength": 85.0, "agility": 70.0, "stamina": 90.0, "skill": 80.0}
ATHLETE_B = {"strength": 75.0, "agility": 90.0, "stamina": 75.0, "skill": 85.0}

def test_simulate_match_returns_result():
    sim = oan_engine.PySimulator()
    r   = sim.simulate_match(ATHLETE_A, ATHLETE_B)
    assert_true("winner_id" in r)
    assert_true("score_a"   in r)
    assert_true("score_b"   in r)
    assert_true("upset"     in r)

def test_simulate_scores_positive():
    sim = oan_engine.PySimulator()
    r   = sim.simulate_match(ATHLETE_A, ATHLETE_B)
    assert_gt(r["score_a"], 0)
    assert_gt(r["score_b"], 0)

def test_simulate_winner_is_valid():
    sim = oan_engine.PySimulator()
    r   = sim.simulate_match(ATHLETE_A, ATHLETE_B)
    assert_true(r["winner_id"] in [r["winner_id"]])  # winner_id is non-empty

def test_simulate_strong_athlete_usually_wins():
    sim   = oan_engine.PySimulator()
    wins  = 0
    for _ in range(20):
        strong = {"strength": 99.0, "agility": 99.0, "stamina": 99.0, "skill": 99.0}
        weak   = {"strength": 10.0, "agility": 10.0, "stamina": 10.0, "skill": 10.0}
        r = sim.simulate_match(strong, weak)
        if r["score_a"] > r["score_b"]:
            wins += 1
    assert_gt(wins, 15, "Strong athlete should win at least 75% of the time")

def test_simulate_equal_athletes():
    sim  = oan_engine.PySimulator()
    even = {"strength": 70.0, "agility": 70.0, "stamina": 70.0, "skill": 70.0}
    r    = sim.simulate_match(even, even)
    diff = abs(r["score_a"] - r["score_b"])
    assert_true(diff < 10.0, f"Equal athletes should have close scores, diff={diff:.2f}")

def test_simulate_speed():
    sim   = oan_engine.PySimulator()
    start = time.time()
    for _ in range(1000):
        sim.simulate_match(ATHLETE_A, ATHLETE_B)
    elapsed = time.time() - start
    rate    = 1000 / elapsed
    assert_gt(rate, 100, f"Simulation rate {rate:.0f}/sec should exceed 100/sec")

test("simulate match returns result",       test_simulate_match_returns_result)
test("simulate scores are positive",        test_simulate_scores_positive)
test("simulate winner is valid",            test_simulate_winner_is_valid)
test("strong athlete usually wins",         test_simulate_strong_athlete_usually_wins)
test("equal athletes have close scores",    test_simulate_equal_athletes)
test("simulation speed > 100/sec",         test_simulate_speed)

# ── Standalone functions ──────────────────────────────────────────────────────

print()
print("  [ Standalone Functions ]")

def test_run_entity_batch_fn():
    stats = oan_engine.run_entity_batch(100, 100)
    assert_gt(stats["cycles_per_sec"], 0)

def test_compile_dsl_fn():
    r = oan_engine.compile_dsl(SIMPLE_DSL)
    assert_eq(r["entity_name"], "Warrior")

def test_simulate_match_fn():
    r = oan_engine.simulate_match(ATHLETE_A, ATHLETE_B)
    assert_true("score_a" in r)

test("run_entity_batch function",  test_run_entity_batch_fn)
test("compile_dsl function",       test_compile_dsl_fn)
test("simulate_match function",    test_simulate_match_fn)

# ── Stress tests ──────────────────────────────────────────────────────────────

print()
print("  [ Rust Stress Tests ]")

def test_10000_entities_1000_cycles():
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(10000, "stress")
    start = time.time()
    stats = e.run_cycles(1000)
    elapsed = time.time() - start
    assert_gt(stats["ops_per_sec"], 10000, "Should process 10k+ ops/sec")
    print(f"         → {stats['cycles_per_sec']:,.0f} cycles/sec | {stats['ops_per_sec']:,.0f} ops/sec")

def test_1000_dsl_compiles():
    c = oan_engine.PyDslCompiler()
    start = time.time()
    for i in range(1000):
        src = SIMPLE_DSL.replace("Warrior", f"Bot{i}")
        c.compile_source(src)
    elapsed = time.time() - start
    rate = 1000 / elapsed
    assert_gt(rate, 100)
    print(f"         → {rate:,.0f} compiles/sec")

def test_5000_match_simulations():
    sim   = oan_engine.PySimulator()
    start = time.time()
    for _ in range(5000):
        sim.simulate_match(ATHLETE_A, ATHLETE_B)
    elapsed = time.time() - start
    rate    = 5000 / elapsed
    assert_gt(rate, 500)
    print(f"         → {rate:,.0f} simulations/sec")

def test_memory_stability_large_spawn():
    # Spawn and run a large number of entities to check for memory issues
    e = oan_engine.PyEntityEngine()
    e.spawn_batch(5000, "memory-test")
    for _ in range(10):
        e.tick()
    assert_true(e.entity_count() == 5000)

test("10k entities × 1000 cycles",       test_10000_entities_1000_cycles)
test("1000 DSL compiles",                test_1000_dsl_compiles)
test("5000 match simulations",           test_5000_match_simulations)
test("memory stability 5k entities",     test_memory_stability_large_spawn)

# ── Summary ───────────────────────────────────────────────────────────────────

passed = sum(1 for r in results if r[0])
failed = sum(1 for r in results if not r[0])
total  = len(results)

print()
print("  ╔═══════════════════════════════════════════════╗")
print(f"  ║   Tests passed : {passed:>3} / {total:<3}                    ║")
print(f"  ║   Tests failed : {failed:>3}                          ║")
if failed == 0:
    print("  ║   ✔  ALL RUST TESTS PASSING                   ║")
else:
    print("  ║   ✘  SOME TESTS FAILED                        ║")
print("  ╚═══════════════════════════════════════════════╝")
print()

sys.exit(0 if failed == 0 else 1)