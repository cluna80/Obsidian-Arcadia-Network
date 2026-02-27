#!/usr/bin/env python3
"""
OAN Protocol Architecture Analysis
Determines what needs Rust integration vs staying in Python
"""

import os
from pathlib import Path

modules = {
    'behavior.py': 'Rule engine for conditional logic',
    'communication.py': 'Inter-entity messaging',
    'coordination.py': 'Multi-entity coordination',
    'entity_manager.py': 'Entity lifecycle management',
    'entity.py': 'Entity class definition',
    'executor.py': 'Tool/action execution',
    'logger_cyber.py': 'Logging system',
    'multi_entity.py': 'Multi-entity operations',
    'parser.py': 'OBSIDIAN language parser'
}

def analyze_module(filepath):
    """Analyze a Python module"""
    if not os.path.exists(filepath):
        return None
    
    with open(filepath, 'r', encoding='utf-8', errors='ignore') as f:
        lines = f.readlines()
    
    # Count classes and functions
    classes = [l.strip() for l in lines if l.strip().startswith('class ')]
    functions = [l.strip() for l in lines if l.strip().startswith('def ') and not l.strip().startswith('def __')]
    
    # Check for performance-critical code
    has_loops = any('for ' in l or 'while ' in l for l in lines)
    has_math = any('import numpy' in l or 'import math' in l for l in lines)
    
    # Check dependencies
    imports = [l.strip() for l in lines if 'import ' in l and not l.strip().startswith('#')]
    
    return {
        'lines': len(lines),
        'classes': len(classes),
        'functions': len(functions),
        'has_loops': has_loops,
        'has_math': has_math,
        'imports': len(imports),
        'class_names': [c.split('class ')[1].split('(')[0].split(':')[0] for c in classes[:5]]
    }

print("="*80)
print("  OAN PROTOCOL ARCHITECTURE ANALYSIS")
print("="*80 + "\n")

results = {}

for module_name, description in modules.items():
    print(f"��� {module_name}")
    print(f"   {description}")
    
    # Check both locations
    paths = [
        f"engine/{module_name}",
        f"oan/engine/{module_name}"
    ]
    
    found = False
    for path in paths:
        if os.path.exists(path):
            analysis = analyze_module(path)
            if analysis:
                found = True
                results[module_name] = analysis
                print(f"   ✅ Found at: {path}")
                print(f"   ��� Lines: {analysis['lines']} | Classes: {analysis['classes']} | Functions: {analysis['functions']}")
                if analysis['class_names']:
                    print(f"   ���️  Classes: {', '.join(analysis['class_names'])}")
                break
    
    if not found:
        print(f"   ❌ Not found")
        results[module_name] = None
    
    print()

print("="*80)
print("  INTEGRATION RECOMMENDATIONS")
print("="*80 + "\n")

recommendations = {
    'RUST_INTEGRATION': [],  # Performance-critical, should be in Rust
    'PYTHON_LAYER': [],      # High-level logic, keep in Python
    'HYBRID': [],            # Core in Rust, wrapper in Python
    'NOT_FOUND': []
}

for module_name, analysis in results.items():
    if analysis is None:
        recommendations['NOT_FOUND'].append(module_name)
    elif module_name in ['behavior.py', 'entity.py']:
        # Core logic - consider Rust
        recommendations['HYBRID'].append((module_name, 'Core entity logic with Python wrapper'))
    elif module_name in ['parser.py']:
        # DSL parsing - keep in Python (easier to modify)
        recommendations['PYTHON_LAYER'].append((module_name, 'DSL parsing best in Python'))
    elif module_name in ['communication.py', 'coordination.py', 'multi_entity.py']:
        # Orchestration - Python is fine
        recommendations['PYTHON_LAYER'].append((module_name, 'Orchestration layer'))
    elif module_name in ['entity_manager.py']:
        # Management - hybrid approach
        recommendations['HYBRID'].append((module_name, 'Manager pattern - hybrid'))
    elif module_name in ['executor.py']:
        # Tool execution - Python is fine
        recommendations['PYTHON_LAYER'].append((module_name, 'Tool execution wrapper'))
    elif module_name in ['logger_cyber.py']:
        # Logging - definitely Python
        recommendations['PYTHON_LAYER'].append((module_name, 'Logging stays in Python'))

print("��� MOVE TO RUST (Performance-critical):")
for item in recommendations['RUST_INTEGRATION']:
    print(f"   • {item}")
if not recommendations['RUST_INTEGRATION']:
    print("   (None - current Rust implementation is sufficient)")
print()

print("⚡ HYBRID APPROACH (Rust core + Python wrapper):")
for module, reason in recommendations['HYBRID']:
    print(f"   • {module}: {reason}")
print()

print("��� KEEP IN PYTHON (High-level logic):")
for module, reason in recommendations['PYTHON_LAYER']:
    print(f"   • {module}: {reason}")
print()

if recommendations['NOT_FOUND']:
    print("❌ NOT FOUND:")
    for module in recommendations['NOT_FOUND']:
        print(f"   • {module}")
    print()

print("="*80)
print("  RECOMMENDED ARCHITECTURE")
print("="*80 + "\n")

print("""
┌─────────────────────────────────────────────────────────────────┐
│                     OAN PROTOCOL STACK                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  PYTHON LAYER (Orchestration & High-Level Logic)      │   │
│  ├────────────────────────────────────────────────────────┤   │
│  │  • parser.py         (OBSIDIAN DSL)                   │   │
│  │  • communication.py  (Messaging)                       │   │
│  │  • coordination.py   (Multi-entity orchestration)     │   │
│  │  • executor.py       (Tool execution)                  │   │
│  │  • logger_cyber.py   (Logging)                        │   │
│  │  • multi_entity.py   (Swarm coordination)             │   │
│  └────────────────────────────────────────────────────────┘   │
│                            ↕                                    │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  PYTHON WRAPPERS (Bridge Layer)                        │   │
│  ├────────────────────────────────────────────────────────┤   │
│  │  • behavior.py       (Rule engine wrapper)            │   │
│  │  • entity_manager.py (Entity lifecycle)               │   │
│  │  • entity.py         (Entity wrapper class)           │   │
│  └────────────────────────────────────────────────────────┘   │
│                            ↕                                    │
│  ┌────────────────────────────────────────────────────────┐   │
│  │  RUST CORE (Performance & Memory)                      │   │
│  ├────────────────────────────────────────────────────────┤   │
│  │  • Smart Entity Brain  (Already implemented! ✅)       │   │
│  │  • Stats & Skills      (Already implemented! ✅)       │   │
│  │  • Memory & Learning   (Already implemented! ✅)       │   │
│  │  • Relationships       (Already implemented! ✅)       │   │
│  │  • Training & Matches  (Already implemented! ✅)       │   │
│  └────────────────────────────────────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

✅ WHAT YOU ALREADY HAVE IN RUST:
   - Entity brain with memory
   - Stats, training, confidence
   - Win/loss tracking, relationships
   - Match simulation

��� WHAT SHOULD STAY IN PYTHON:
   - OBSIDIAN parser (easier to modify DSL)
   - Communication & coordination (orchestration)
   - Logging (standard Python libraries)
   - Tool execution (flexibility)

⚡ WHAT COULD BE HYBRID:
   - Behavior rules (Rust evaluator + Python wrapper)
   - Entity management (Rust core + Python API)

��� RECOMMENDATION:
   DON'T port everything to Rust! Use Python for what it's good at:
   - Rapid iteration
   - High-level orchestration
   - DSL parsing
   - Integration with external services
   
   Current Rust core is PERFECT for:
   - Entity brains (done! ✅)
   - Performance-critical calculations (done! ✅)
   - Memory management (done! ✅)
""")

print("\n✅ Analysis complete!")
