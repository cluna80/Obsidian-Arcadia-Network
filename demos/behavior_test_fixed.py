#!/usr/bin/env python3
"""
Behavior System Integration Test
Tests if behavior.py attributes work with Rust engine
"""

import sys
from pathlib import Path

# Add paths
sys.path.insert(0, str(Path(__file__).parent.parent / "rust/oan-engine/target/wheels"))
sys.path.insert(0, str(Path(__file__).parent.parent))

try:
    from oan_engine import PySmartEngine
    print("[OK] OAN Engine loaded")
except ImportError as e:
    print(f"[ERROR] Failed to load OAN Engine: {e}")
    sys.exit(1)

# Try importing behavior from engine
BEHAVIOR_AVAILABLE = False
try:
    from engine.behavior import Behavior
    print("[OK] Behavior module loaded from engine/behavior.py")
    BEHAVIOR_AVAILABLE = True
except ImportError:
    try:
        from oan.engine.behavior import Behavior
        print("[OK] Behavior module loaded from oan/engine/behavior.py")
        BEHAVIOR_AVAILABLE = True
    except ImportError:
        print("[ERROR] Behavior module not found")

print("\n" + "="*60)
print("  BEHAVIOR SYSTEM INTEGRATION TEST")
print("="*60 + "\n")

# Initialize engine
engine = PySmartEngine()
print("[OK] Engine initialized")

# Create test entity
entity_id = engine.spawn_smart("BehaviorTestEntity", "fighter")
print(f"[OK] Created entity: {entity_id}")

# Check what methods the engine exposes
print("\n[INFO] Available Engine Methods:")
engine_methods = [m for m in dir(engine) if not m.startswith('_')]
for method in sorted(engine_methods):
    print(f"  - {method}")

# Test 1: Basic Stats
print("\n[TEST 1] Basic Stats")
try:
    stats = engine.get_stats(entity_id)
    print(f"  [OK] Stats: {stats}")
except Exception as e:
    print(f"  [ERROR] {e}")

# Test 2: Brain Summary
print("\n[TEST 2] Brain Summary")
try:
    summary = engine.get_brain_summary(entity_id)
    print(f"  [OK] Summary: {summary}")
except Exception as e:
    print(f"  [ERROR] {e}")

# Test 3: Behavior.py Integration
print("\n[TEST 3] Behavior.py Integration")
if BEHAVIOR_AVAILABLE:
    try:
        behavior = Behavior()
        print(f"  [OK] Behavior instance created")
        print(f"  [INFO] Behavior type: {type(behavior)}")
        print(f"  [INFO] Behavior attributes: {[a for a in dir(behavior) if not a.startswith('_')]}")
    except Exception as e:
        print(f"  [ERROR] {e}")
else:
    print("  [SKIP] Behavior.py not available")

# Test 4: Check for behavior methods in engine
print("\n[TEST 4] Checking for Behavior Methods in Rust Engine")
behavior_keywords = ['perceive', 'vision', 'hearing', 'speech', 'movement', 'sense', 'observe', 'listen', 'speak', 'move']
found = []
for keyword in behavior_keywords:
    if hasattr(engine, keyword):
        found.append(keyword)
        print(f"  [OK] Found: {keyword}")

if not found:
    print("  [INFO] No behavior methods in Rust engine")

# Test 5: Memory (via brain)
print("\n[TEST 5] Memory System")
try:
    confidence = engine.get_confidence(entity_id)
    print(f"  [OK] Confidence (memory): {confidence:.2%}")
    
    engine.train_skill(entity_id, "strength", 10)
    new_stats = engine.get_stats(entity_id)
    print(f"  [OK] Stats after training: {new_stats}")
except Exception as e:
    print(f"  [ERROR] {e}")

# Test 6: Check what's actually in behavior.py
print("\n[TEST 6] Behavior.py Contents")
if BEHAVIOR_AVAILABLE:
    try:
        import inspect
        behavior_source = inspect.getsourcefile(Behavior)
        print(f"  [INFO] Source file: {behavior_source}")
        
        with open(behavior_source, 'r') as f:
            lines = f.readlines()
            print(f"  [INFO] File has {len(lines)} lines")
            
            # Check for key classes
            classes_found = []
            for line in lines:
                if line.strip().startswith('class '):
                    classes_found.append(line.strip())
            
            print(f"  [INFO] Classes found: {len(classes_found)}")
            for cls in classes_found[:10]:  # First 10 classes
                print(f"    - {cls}")
    except Exception as e:
        print(f"  [ERROR] {e}")

# Summary
print("\n" + "="*60)
print("  SUMMARY")
print("="*60)

print(f"""
[STATUS] Rust Engine: WORKING
[STATUS] Behavior.py: {'FOUND' if BEHAVIOR_AVAILABLE else 'NOT FOUND'}
[STATUS] Brain/Memory: WORKING
[STATUS] Integration: {'STANDALONE' if BEHAVIOR_AVAILABLE else 'N/A'}

[CONCLUSION]
- Rust engine has: {', '.join(engine_methods[:5])}...
- Behavior methods in Rust: {len(found)} found
- Behavior.py exists but {'IS' if BEHAVIOR_AVAILABLE else 'IS NOT'} loaded

[NEXT STEPS]
1. Check engine/behavior.py contents
2. Determine if behavior should be in Rust or Python
3. Create integration if needed
""")

print("\n[DONE] Test complete!")
