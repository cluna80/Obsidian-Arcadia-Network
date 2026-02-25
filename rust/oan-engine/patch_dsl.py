import os

# Fix 1: patch rust_engine.py — RustDslCompiler calls compile_source not compile
path = "rust_engine.py"
src  = open(path).read()
src  = src.replace(
    "return self._compiler.compile(source)",
    "return self._compiler.compile_source(source)"
)
open(path, "w").write(src)
print("patched rust_engine.py")

# Fix 2: patch python_bridge/mod.rs — rename compile → compile_source to avoid
# PyO3 dispatch confusion with the internal DslCompiler.compile() method
pb = open("src/python_bridge/mod.rs").read()
pb = pb.replace(
    "    pub fn compile(&self, py: Python<'_>, source: &str) -> PyResult<PyObject> {",
    "    pub fn compile_source(&self, py: Python<'_>, source: &str) -> PyResult<PyObject> {"
)
open("src/python_bridge/mod.rs", "w").write(pb)
print("patched python_bridge/mod.rs")

print("\nNow run:")
print("  maturin develop --release")
print("  python rust_engine.py")