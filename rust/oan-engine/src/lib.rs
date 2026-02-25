// ╔══════════════════════════════════════════════════════════════╗
// ║  OAN ENGINE — Python AI Accelerator                          ║
// ║  PyO3 bindings: call Rust hot paths from Python              ║
// ╚══════════════════════════════════════════════════════════════╝

pub mod entity_loop;
pub mod dsl_compiler;
pub mod simulation_core;
pub mod python_bridge;

use pyo3::prelude::*;

/// The function name MUST match the [lib] name in Cargo.toml exactly
#[pymodule]
fn oan_engine(m: &Bound<'_, PyModule>) -> PyResult<()> {
    // Entity engine
    m.add_class::<python_bridge::PyEntity>()?;
    m.add_class::<python_bridge::PyEntityEngine>()?;

    // DSL compiler
    m.add_class::<python_bridge::PyDslCompiler>()?;

    // Simulation
    m.add_class::<python_bridge::PySimulator>()?;
    m.add_class::<python_bridge::PyMatchResult>()?;

    // Standalone functions
    m.add_function(wrap_pyfunction!(python_bridge::run_entity_batch, m)?)?;
    m.add_function(wrap_pyfunction!(python_bridge::compile_dsl,      m)?)?;
    m.add_function(wrap_pyfunction!(python_bridge::simulate_match,   m)?)?;
    m.add_function(wrap_pyfunction!(python_bridge::benchmark_cycles, m)?)?;

    Ok(())
}