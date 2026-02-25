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

    pub fn compile_source(&self, py: Python<'_>, source: &str) -> PyResult<PyObject> {
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
