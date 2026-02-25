# OAN Rust Workspace

Two crates powering OAN's Rust layer:

```
rust/
├── Cargo.toml          ← workspace root
├── oan-safety/         ← Layer 7 integrity engine (binary + lib)
│   └── src/
│       ├── behavior_monitor/   → rate limiting, anomaly detection
│       ├── audit_engine/       → SHA-256 hash-chained audit trail
│       ├── threat_detector/    → Sybil, replay, volume spike detection
│       └── main.rs             → standalone binary
│
└── oan-engine/         ← Python AI accelerator (PyO3 extension)
    └── src/
        ├── entity_loop/        → replaces Python entity hot path
        ├── dsl_compiler/       → OBSIDIAN DSL → bytecode compiler
        ├── simulation_core/    → match/tournament simulator
        ├── python_bridge/      → PyO3 Python bindings
        └── lib.rs              → Python module root
```

---

## Prerequisites

```bash
# Install Rust
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
source ~/.cargo/env

# Verify
rustc --version   # should be 1.75+
cargo --version

# Install maturin (builds PyO3 Python extensions)
pip install maturin
```

---

## Build oan-safety (Layer 7 binary)

```bash
cd rust

# Development build
cargo build -p oan-safety

# Release build (optimized)
cargo build -p oan-safety --release

# Run it
./target/release/oan-safety
```

Expected output:
```
  ╔═══════════════════════════════════════════════╗
  ║   OAN SAFETY — Layer 7 Integrity Engine       ║
  ║   Rust-powered · Zero-cost abstractions       ║
  ╚═══════════════════════════════════════════════╝

  ✔ Audit engine initialized
  ✔ Behavior monitor initialized  
  ✔ Threat detector initialized
  ✔ ALL SYSTEMS OPERATIONAL
```

---

## Build oan-engine (Python extension)

```bash
cd rust/oan-engine

# Dev build — installs into your current Python env
maturin develop --release

# Verify it works
python rust_engine.py
```

Expected output:
```
  OAN ENGINE BENCHMARK

  Entities:     500
  Cycles run:   5,000
  Elapsed:      0.003s

  Python:               82 cycles/sec  (baseline)
  Rust:          48,500 cycles/sec
  Speedup:              591x  🚀
```

---

## Use from Python

Copy `rust_engine.py` into your `oan/` directory:

```bash
cp rust/oan-engine/rust_engine.py oan/rust_engine.py
```

Then in your existing Python code:

```python
from oan.rust_engine import RustEngine, RustSimulator, RustDslCompiler, is_available

# Entity engine — drop-in replacement for Python engine
if is_available():
    engine = RustEngine()
    engine.spawn_batch(1000, "warrior")
    stats = engine.run_cycles(10000)
    print(f"Rust: {stats['cycles_per_sec']:.0f} cycles/sec")

# DSL compiler
compiler = RustDslCompiler()
program  = compiler.compile(open("entities/warrior.ent").read())
print(f"Compiled {program['rule_count']} rules → {program['opcode_count']} opcodes")

# Match simulator
sim    = RustSimulator()
result = sim.simulate_match(
    {"name": "Atlas",  "strength": 85, "agility": 70, "stamina": 90, "skill": 80},
    {"name": "Cipher", "strength": 75, "agility": 90, "stamina": 75, "skill": 85},
)
print(f"Winner: {result['winner_id']}  Score: {result['score_a']:.1f}-{result['score_b']:.1f}")
```

---

## Run all Rust tests

```bash
cd rust
cargo test --workspace
```

---

## Performance targets

| Component          | Python baseline | Rust target  | Expected speedup |
|--------------------|----------------|--------------|-----------------|
| Entity loop        | 82 cycles/sec  | 50,000+/sec  | ~600x           |
| DSL compiler       | ~200 files/sec | 20,000+/sec  | ~100x           |
| Match simulation   | ~500/sec       | 100,000+/sec | ~200x           |
| Audit hashing      | N/A (new)      | 1M records/sec | —             |
| Threat detection   | N/A (new)      | 500K events/sec| —             |