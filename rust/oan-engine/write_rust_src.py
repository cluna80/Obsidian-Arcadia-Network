import os

os.makedirs("src/entity_loop",    exist_ok=True)
os.makedirs("src/dsl_compiler",   exist_ok=True)
os.makedirs("src/simulation_core",exist_ok=True)
os.makedirs("src/python_bridge",  exist_ok=True)

# ── entity_loop/mod.rs ────────────────────────────────────────────────────────
with open("src/entity_loop/mod.rs", "w") as f:
    f.write("""\
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Instant;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EntityStatus { Alive, Dead }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entity {
    pub id:          String,
    pub name:        String,
    pub entity_type: String,
    pub age:         u32,
    pub energy:      f64,
    pub health:      f64,
    pub reputation:  f64,
    pub status:      EntityStatus,
    pub traits:      HashMap<String, f64>,
    pub cycle_count: u64,
}

impl Entity {
    pub fn new(name: &str, entity_type: &str) -> Self {
        Self {
            id:          Uuid::new_v4().to_string(),
            name:        name.to_string(),
            entity_type: entity_type.to_string(),
            age:         0,
            energy:      100.0,
            health:      100.0,
            reputation:  50.0,
            status:      EntityStatus::Alive,
            traits:      HashMap::new(),
            cycle_count: 0,
        }
    }

    pub fn is_alive(&self) -> bool {
        matches!(self.status, EntityStatus::Alive)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CycleResult {
    pub entity_id:    String,
    pub cycle:        u64,
    pub action_taken: String,
    pub energy_delta: f64,
    pub rep_delta:    f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BenchmarkStats {
    pub total_cycles:   u64,
    pub total_entities: u64,
    pub alive_entities: u64,
    pub total_ops:      u64,
    pub elapsed_secs:   f64,
    pub cycles_per_sec: f64,
    pub ops_per_sec:    f64,
}

pub struct EntityEngine {
    pub entities: Vec<Entity>,
    pub cycle:    u64,
}

impl EntityEngine {
    pub fn new() -> Self {
        Self { entities: Vec::new(), cycle: 0 }
    }

    pub fn spawn(&mut self, name: &str, entity_type: &str) -> String {
        let e  = Entity::new(name, entity_type);
        let id = e.id.clone();
        self.entities.push(e);
        id
    }

    pub fn spawn_batch(&mut self, count: usize, entity_type: &str) -> Vec<String> {
        let ids: Vec<String> = (0..count)
            .map(|i| self.spawn(&format!("Entity-{}", i), entity_type))
            .collect();
        ids
    }

    pub fn tick(&mut self) -> Vec<CycleResult> {
        self.cycle += 1;
        let cycle = self.cycle;
        self.entities
            .par_iter_mut()
            .filter(|e| e.is_alive())
            .map(|e| {
                e.cycle_count += 1;
                e.age         += 1;
                e.energy       = (e.energy - 1.0).max(0.0);
                if e.energy <= 0.0 {
                    e.status = EntityStatus::Dead;
                }
                let action = if e.energy < 20.0 {
                    e.energy = (e.energy + 30.0).min(100.0);
                    "rest"
                } else if e.energy > 80.0 {
                    e.energy -= 20.0;
                    "compete"
                } else {
                    "idle"
                };
                CycleResult {
                    entity_id:    e.id.clone(),
                    cycle,
                    action_taken: action.to_string(),
                    energy_delta: 0.0,
                    rep_delta:    0.0,
                }
            })
            .collect()
    }

    pub fn run_cycles(&mut self, n: u64) -> BenchmarkStats {
        let start   = Instant::now();
        let mut ops = 0u64;
        for _ in 0..n {
            ops += self.tick().len() as u64;
        }
        let elapsed = start.elapsed().as_secs_f64();
        let alive   = self.entities.iter().filter(|e| e.is_alive()).count() as u64;
        BenchmarkStats {
            total_cycles:   n,
            total_entities: self.entities.len() as u64,
            alive_entities: alive,
            total_ops:      ops,
            elapsed_secs:   elapsed,
            cycles_per_sec: n as f64 / elapsed,
            ops_per_sec:    ops as f64 / elapsed,
        }
    }
}
""")
print("wrote entity_loop/mod.rs")

# ── dsl_compiler/mod.rs ───────────────────────────────────────────────────────
with open("src/dsl_compiler/mod.rs", "w") as f:
    f.write("""\
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledProgram {
    pub entity_name:  String,
    pub entity_type:  String,
    pub traits:       HashMap<String, f64>,
    pub rule_count:   usize,
    pub opcode_count: usize,
    pub source_hash:  String,
}

pub struct DslCompiler;

impl DslCompiler {
    pub fn new() -> Self { Self }

    pub fn compile(&self, source: &str) -> anyhow::Result<CompiledProgram> {
        let mut name  = String::from("Unknown");
        let mut etype = String::from("Generic");
        let mut traits: HashMap<String, f64> = HashMap::new();
        let mut rule_count = 0usize;

        for line in source.lines() {
            let line = line.trim();
            if line.starts_with("entity ") {
                let clean: Vec<&str> = line
                    .trim_end_matches(" {")
                    .split_whitespace()
                    .collect();
                if clean.len() > 1 { name  = clean[1].to_string(); }
                if clean.len() > 3 { etype = clean[3].to_string(); }
            } else if line.starts_with("trait ") {
                let parts: Vec<&str> = line.splitn(3, ' ').collect();
                if parts.len() == 3 {
                    let kv: Vec<&str> = parts[2].splitn(2, '=').collect();
                    if kv.len() == 2 {
                        if let Ok(v) = kv[1].trim().parse::<f64>() {
                            traits.insert(kv[0].trim().to_string(), v);
                        }
                    }
                }
            } else if line.starts_with("on ") {
                rule_count += 1;
            }
        }

        let mut hasher = Sha256::new();
        hasher.update(source.as_bytes());
        let source_hash = hex::encode(hasher.finalize());

        Ok(CompiledProgram {
            entity_name:  name,
            entity_type:  etype,
            traits,
            rule_count,
            opcode_count: rule_count * 4,
            source_hash,
        })
    }
}
""")
print("wrote dsl_compiler/mod.rs")

# ── simulation_core/mod.rs ────────────────────────────────────────────────────
with open("src/simulation_core/mod.rs", "w") as f:
    f.write("""\
use serde::{Deserialize, Serialize};
use uuid::Uuid;
use std::time::Instant;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Athlete {
    pub id:       String,
    pub name:     String,
    pub sport:    String,
    pub strength: f64,
    pub agility:  f64,
    pub stamina:  f64,
    pub skill:    f64,
}

impl Athlete {
    pub fn new(name: &str, sport: &str, strength: f64, agility: f64, stamina: f64, skill: f64) -> Self {
        Self {
            id:       Uuid::new_v4().to_string(),
            name:     name.to_string(),
            sport:    sport.to_string(),
            strength,
            agility,
            stamina,
            skill,
        }
    }

    pub fn rating(&self) -> f64 {
        self.strength * 0.25
            + self.agility  * 0.20
            + self.stamina  * 0.20
            + self.skill    * 0.35
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchResult {
    pub id:            String,
    pub winner_id:     String,
    pub score_a:       f64,
    pub score_b:       f64,
    pub upset:         bool,
    pub performance_a: f64,
    pub performance_b: f64,
}

pub struct MatchSimulator {
    pub rounds: u32,
}

impl MatchSimulator {
    pub fn new() -> Self { Self { rounds: 5 } }

    pub fn simulate(&self, a: &Athlete, b: &Athlete) -> MatchResult {
        let ra      = a.rating();
        let rb      = b.rating();
        let score_a = ra * self.rounds as f64;
        let score_b = rb * self.rounds as f64;
        let winner  = if score_a >= score_b { a.id.clone() } else { b.id.clone() };
        let expected = if ra >= rb           { a.id.clone() } else { b.id.clone() };
        MatchResult {
            id:            Uuid::new_v4().to_string(),
            winner_id:     winner.clone(),
            score_a,
            score_b,
            upset:         winner != expected,
            performance_a: score_a / self.rounds as f64,
            performance_b: score_b / self.rounds as f64,
        }
    }
}

pub fn benchmark(n: usize) -> (usize, f64) {
    let sim = MatchSimulator::new();
    let athletes: Vec<Athlete> = (0..n * 2)
        .map(|i| Athlete::new(&format!("A{}", i), "combat", 70.0, 70.0, 70.0, 70.0))
        .collect();
    let start = Instant::now();
    let count = athletes
        .chunks(2)
        .filter(|p: &&[Athlete]| p.len() == 2)
        .map(|p| sim.simulate(&p[0], &p[1]))
        .count();
    (count, start.elapsed().as_secs_f64())
}
""")
print("wrote simulation_core/mod.rs")

# ── python_bridge/mod.rs ──────────────────────────────────────────────────────
with open("src/python_bridge/mod.rs", "w") as f:
    f.write("""\
use crate::entity_loop::EntityEngine;
use crate::dsl_compiler::DslCompiler;
use crate::simulation_core::{Athlete, MatchSimulator};
use pyo3::prelude::*;
use pyo3::types::PyDict;
use std::collections::HashMap;

#[pyclass(name = "PyEntity")]
#[derive(Clone)]
pub struct PyEntity {
    #[pyo3(get)] pub id:         String,
    #[pyo3(get)] pub name:       String,
    #[pyo3(get)] pub energy:     f64,
    #[pyo3(get)] pub health:     f64,
    #[pyo3(get)] pub reputation: f64,
    #[pyo3(get)] pub age:        u32,
    #[pyo3(get)] pub alive:      bool,
}

#[pymethods]
impl PyEntity {
    fn __repr__(&self) -> String {
        format!("<Entity id={} name={} energy={:.1}>", self.id, self.name, self.energy)
    }
}

#[pyclass(name = "PyEntityEngine")]
pub struct PyEntityEngine { engine: EntityEngine }

#[pymethods]
impl PyEntityEngine {
    #[new]
    pub fn new() -> Self { Self { engine: EntityEngine::new() } }

    pub fn spawn(&mut self, name: &str, entity_type: &str) -> String {
        self.engine.spawn(name, entity_type)
    }

    pub fn spawn_batch(&mut self, count: usize, entity_type: &str) -> Vec<String> {
        self.engine.spawn_batch(count, entity_type)
    }

    pub fn run_cycles(&mut self, py: Python<'_>, n: u64) -> PyResult<PyObject> {
        let s = self.engine.run_cycles(n);
        let d = PyDict::new_bound(py);
        d.set_item("cycles_per_sec", s.cycles_per_sec)?;
        d.set_item("ops_per_sec",    s.ops_per_sec)?;
        d.set_item("elapsed_secs",   s.elapsed_secs)?;
        d.set_item("alive_entities", s.alive_entities)?;
        d.set_item("total_cycles",   s.total_cycles)?;
        Ok(d.into())
    }

    pub fn entity_count(&self)  -> usize { self.engine.entities.len() }
    pub fn alive_count(&self)   -> usize {
        self.engine.entities.iter().filter(|e| e.is_alive()).count()
    }
    pub fn current_cycle(&self) -> u64   { self.engine.cycle }
}

#[pyclass(name = "PyDslCompiler")]
pub struct PyDslCompiler { compiler: DslCompiler }

#[pymethods]
impl PyDslCompiler {
    #[new]
    pub fn new() -> Self { Self { compiler: DslCompiler::new() } }

    pub fn compile(&self, py: Python<'_>, source: &str) -> PyResult<PyObject> {
        let p = self.compiler.compile(source)
            .map_err(|e| pyo3::exceptions::PyValueError::new_err(e.to_string()))?;
        let d = PyDict::new_bound(py);
        d.set_item("entity_name",  &p.entity_name)?;
        d.set_item("rule_count",   p.rule_count)?;
        d.set_item("opcode_count", p.opcode_count)?;
        d.set_item("source_hash",  &p.source_hash)?;
        Ok(d.into())
    }
}

#[pyclass(name = "PyMatchResult")]
#[derive(Clone)]
pub struct PyMatchResult {
    #[pyo3(get)] pub id:            String,
    #[pyo3(get)] pub winner_id:     String,
    #[pyo3(get)] pub score_a:       f64,
    #[pyo3(get)] pub score_b:       f64,
    #[pyo3(get)] pub upset:         bool,
    #[pyo3(get)] pub performance_a: f64,
    #[pyo3(get)] pub performance_b: f64,
}

#[pymethods]
impl PyMatchResult {
    fn __repr__(&self) -> String {
        format!("<Match winner={} {:.1}-{:.1}>", self.winner_id, self.score_a, self.score_b)
    }
}

#[pyclass(name = "PySimulator")]
pub struct PySimulator { sim: MatchSimulator }

#[pymethods]
impl PySimulator {
    #[new]
    pub fn new() -> Self { Self { sim: MatchSimulator::new() } }

    pub fn simulate_match(
        &self,
        py: Python<'_>,
        a: HashMap<String, f64>,
        b: HashMap<String, f64>,
    ) -> PyResult<PyObject> {
        let mk = |m: &HashMap<String, f64>, name: &str| Athlete::new(
            name, "combat",
            *m.get("strength").unwrap_or(&70.0),
            *m.get("agility").unwrap_or(&70.0),
            *m.get("stamina").unwrap_or(&70.0),
            *m.get("skill").unwrap_or(&70.0),
        );
        let ra = mk(&a, "A");
        let rb = mk(&b, "B");
        let r  = self.sim.simulate(&ra, &rb);
        let d  = PyDict::new_bound(py);
        d.set_item("winner_id", &r.winner_id)?;
        d.set_item("score_a",   r.score_a)?;
        d.set_item("score_b",   r.score_b)?;
        d.set_item("upset",     r.upset)?;
        Ok(d.into())
    }
}

#[pyfunction]
pub fn run_entity_batch(py: Python<'_>, entity_count: usize, cycles: u64) -> PyResult<PyObject> {
    let mut engine = EntityEngine::new();
    engine.spawn_batch(entity_count, "generic");
    let s = engine.run_cycles(cycles);
    let d = PyDict::new_bound(py);
    d.set_item("cycles_per_sec", s.cycles_per_sec)?;
    d.set_item("ops_per_sec",    s.ops_per_sec)?;
    d.set_item("elapsed_secs",   s.elapsed_secs)?;
    d.set_item("alive_entities", s.alive_entities)?;
    Ok(d.into())
}

#[pyfunction]
pub fn compile_dsl(py: Python<'_>, source: &str) -> PyResult<PyObject> {
    let p = DslCompiler::new().compile(source)
        .map_err(|e| pyo3::exceptions::PyValueError::new_err(e.to_string()))?;
    let d = PyDict::new_bound(py);
    d.set_item("entity_name",  &p.entity_name)?;
    d.set_item("rule_count",   p.rule_count)?;
    d.set_item("opcode_count", p.opcode_count)?;
    Ok(d.into())
}

#[pyfunction]
pub fn simulate_match(
    py: Python<'_>,
    a: HashMap<String, f64>,
    b: HashMap<String, f64>,
) -> PyResult<PyObject> {
    let sim = PySimulator::new();
    sim.simulate_match(py, a, b)
}

#[pyfunction]
pub fn benchmark_cycles(py: Python<'_>, entity_count: usize, cycles: u64) -> PyResult<PyObject> {
    run_entity_batch(py, entity_count, cycles)
}
""")
print("wrote python_bridge/mod.rs")

print("\nAll files written. Run: maturin develop --release")