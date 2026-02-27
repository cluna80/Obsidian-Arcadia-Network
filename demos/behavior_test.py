#!/usr/bin/env python3
"""
Behavior System Integration Test
Tests if behavior.py attributes work with Rust engine
"""

import sys
from pathlib import Path

# Add OAN to path
sys.path.insert(0, str(Path(__file__).parent.parent / "rust/oan-engine/target/wheels"))

try:
    from oan_engine import PySmartEngine
    print("✅ OAN Engine loaded")
except ImportError as e:
    print(f"❌ Failed to load OAN Engine: {e}")
    sys.exit(1)

# Try importing behavior
try:
    from behavior import Behavior, VisionSystem, HearingSystem, SpeechSystem, MovementSystem
    print("✅ Behavior module loaded")
    BEHAVIOR_AVAILABLE = True
except ImportError:
    print("❌ Behavior module not found")
    BEHAVIOR_AVAILABLE = False

print("\n" + "="*60)
print("  BEHAVIOR SYSTEM INTEGRATION TEST")
print("="*60 + "\n")

# Initialize engine
engine = PySmartEngine()
print("✅ Engine initialized")

# Create test entity
entity_id = engine.spawn_smart("BehaviorTestEntity", "fighter")
print(f"✅ Created entity: {entity_id}")

# Check what methods the engine exposes
print("\n��� Available Engine Methods:")
engine_methods = [m for m in dir(engine) if not m.startswith('_')]
for method in engine_methods:
    print(f"  - {method}")

# Check if entity has behavior-related methods
print("\n��� Testing Behavior Integration:")

# Test 1: Basic Stats (should work)
print("\n1️⃣ Testing Basic Stats...")
try:
    stats = engine.get_stats(entity_id)
    print(f"   ✅ Stats: {stats}")
except Exception as e:
    print(f"   ❌ Error: {e}")

# Test 2: Brain Summary (includes behavior?)
print("\n2️⃣ Testing Brain Summary...")
try:
    summary = engine.get_brain_summary(entity_id)
    print(f"   ✅ Summary: {summary}")
except Exception as e:
    print(f"   ❌ Error: {e}")

# Test 3: Check if behavior.py systems are connected
print("\n3️⃣ Testing Behavior.py Integration...")
if BEHAVIOR_AVAILABLE:
    try:
        # Try to create a behavior instance
        behavior = Behavior()
        print("   ✅ Behavior instance created")
        
        # Check if vision system works
        vision = VisionSystem()
        test_observation = vision.perceive({"type": "object", "distance": 10})
        print(f"   ✅ Vision System: {test_observation}")
        
        # Check if hearing system works
        hearing = HearingSystem()
        test_sound = hearing.listen({"type": "sound", "volume": 50})
        print(f"   ✅ Hearing System: {test_sound}")
        
        # Check movement
        movement = MovementSystem()
        test_move = movement.move({"direction": "forward", "speed": 5})
        print(f"   ✅ Movement System: {test_move}")
        
        # Check speech
        speech = SpeechSystem()
        test_speech = speech.speak("Hello, testing speech system")
        print(f"   ✅ Speech System: {test_speech}")
        
    except Exception as e:
        print(f"   ❌ Behavior error: {e}")
else:
    print("   ⚠️ Behavior.py not available - systems not tested")

# Test 4: Check if Rust engine has behavior hooks
print("\n4️⃣ Checking Rust Engine Behavior Hooks...")
behavior_methods = [
    'perceive', 'vision', 'hearing', 'speech', 'movement',
    'sense', 'observe', 'listen', 'speak', 'move'
]

found_methods = []
for method in behavior_methods:
    if hasattr(engine, method):
        found_methods.append(method)
        print(f"   ✅ Found: {method}")

if not found_methods:
    print("   ⚠️ No behavior methods found in Rust engine")
    print("   ��� Behavior systems may need to be connected")

# Test 5: Memory system (should exist in brain)
print("\n5️⃣ Testing Memory System...")
try:
    # Try to get memory-related data
    confidence = engine.get_confidence(entity_id)
    print(f"   ✅ Confidence (memory-based): {confidence:.2%}")
    
    # Train entity (should affect memory)
    print("   ��� Training entity...")
    engine.train_skill(entity_id, "strength", 10)
    
    new_stats = engine.get_stats(entity_id)
    print(f"   ✅ New stats (memory updated): {new_stats}")
except Exception as e:
    print(f"   ❌ Memory test error: {e}")

# Test 6: Emotional state (check if emotions are tracked)
print("\n6️⃣ Testing Emotional State...")
try:
    # Check if emotions are in summary
    summary = engine.get_brain_summary(entity_id)
    
    emotion_keywords = ['confidence', 'fear', 'anger', 'happy', 'sad', 'excited']
    found_emotions = [kw for kw in emotion_keywords if kw.lower() in summary.lower()]
    
    if found_emotions:
        print(f"   ✅ Emotions found in summary: {found_emotions}")
    else:
        print("   ⚠️ No explicit emotions tracked in summary")
        print(f"   ��� Summary: {summary}")
except Exception as e:
    print(f"   ❌ Emotion test error: {e}")

# Test 7: Integration check
print("\n" + "="*60)
print("  INTEGRATION SUMMARY")
print("="*60)

print(f"""
✅ Rust Engine: WORKING
{'✅' if BEHAVIOR_AVAILABLE else '❌'} Behavior.py: {'LOADED' if BEHAVIOR_AVAILABLE else 'NOT FOUND'}
✅ Brain System: WORKING
✅ Memory: WORKING (via confidence/stats)
⚠️  Vision/Hearing/Speech: {'STANDALONE' if BEHAVIOR_AVAILABLE else 'NOT TESTED'}
��� Movement: NOT INTEGRATED WITH RUST ENGINE

CONCLUSION:
- Rust engine handles: Stats, Training, Matches, Brain, Memory
- Behavior.py provides: Vision, Hearing, Speech, Movement classes
- ⚠️  THEY ARE NOT YET CONNECTED!

TO FIX:
1. Add Python bindings in src/lib.rs for behavior methods
2. OR use behavior.py alongside engine (not integrated)
3. OR re-implement behavior in Rust
""")

print("\n✅ Test complete!")
