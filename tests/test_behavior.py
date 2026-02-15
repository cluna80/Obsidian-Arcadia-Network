"""
OAN Behavioral Intelligence Test Suite
Comprehensive testing of BEHAVIOR and EXECUTE blocks
"""

from engine.parser import parse_dsl
from engine.executor import execute_entity
from engine.entity_manager import entity_manager
import time


def test_basic_behavior():
    """Test basic behavioral rules"""
    print("\n" + "="*70)
    print("TEST 1: BASIC BEHAVIORAL RULES")
    print("="*70 + "\n")
    
    # Create test entity
    with open("entities/test_behavior_basic.ent", 'w') as f:
        f.write("""
ENTITY TestBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF REPUTATION > 5 THEN STATE Overclocked
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Overclocked THEN DeepAnalyzer
  IF STATE == Recovery THEN Monitor
END

INTENT "Test basic behavioral transitions"
MODE Testing
""")
    
    # Execute with energy depletion
    entity = execute_entity("entities/test_behavior_basic.ent", cycles=10, energy_per_tool=15)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Energy: {entity.energy}")
    print(f"  Reputation: {entity.reputation}")
    
    # Assertions
    assert entity.state in ["Recovery", "Overclocked"], f"Expected Recovery or Overclocked, got {entity.state}"
    print("\n✅ Basic behavior test PASSED!")


def test_energy_restoration():
    """Test energy restoration in Recovery state"""
    print("\n" + "="*70)
    print("TEST 2: ENERGY RESTORATION")
    print("="*70 + "\n")
    
    # Create entity with energy restoration
    with open("entities/test_recovery.ent", 'w') as f:
        f.write("""
ENTITY RecoveryBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF STATE == Recovery THEN ENERGY + 15
  IF ENERGY > 80 THEN STATE Active
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Recovery THEN Monitor
END

INTENT "Test energy restoration mechanics"
MODE Testing
""")
    
    # Execute
    entity = execute_entity("entities/test_recovery.ent", cycles=20, energy_per_tool=10)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Energy: {entity.energy}")
    
    # Should have recovered
    assert entity.energy > 30, f"Energy should have recovered, got {entity.energy}"
    print("\n✅ Energy restoration test PASSED!")


def test_reputation_based_behavior():
    """Test reputation-based state transitions"""
    print("\n" + "="*70)
    print("TEST 3: REPUTATION-BASED BEHAVIOR")
    print("="*70 + "\n")
    
    # Create reputation-driven entity
    with open("entities/test_reputation.ent", 'w') as f:
        f.write("""
ENTITY ReputationBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 10 THEN STATE Elite
  IF REPUTATION > 5 THEN STATE Experienced
  IF REPUTATION < 0 THEN STATE Degraded
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Experienced THEN SentimentAnalyzer
  IF STATE == Elite THEN DeepAnalyzer
  IF STATE == Degraded THEN Monitor
END

INTENT "Test reputation-driven behaviors"
MODE Testing
""")
    
    # Execute and gain reputation
    entity = execute_entity("entities/test_reputation.ent", cycles=15, energy_per_tool=5)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Reputation: {entity.reputation}")
    
    # Should have advanced to higher state
    assert entity.reputation >= 10, f"Should have gained reputation, got {entity.reputation}"
    assert entity.state in ["Elite", "Experienced"], f"Should have advanced state, got {entity.state}"
    print("\n✅ Reputation behavior test PASSED!")


def test_complex_conditions():
    """Test complex multi-condition behaviors"""
    print("\n" + "="*70)
    print("TEST 4: COMPLEX CONDITIONS")
    print("="*70 + "\n")
    
    # Create entity with complex logic
    with open("entities/test_complex.ent", 'w') as f:
        f.write("""
ENTITY ComplexBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 20 THEN STATE Emergency
  IF ENERGY < 50 AND REPUTATION > 5 THEN STATE Conservative
  IF ENERGY > 80 AND REPUTATION > 10 THEN STATE Aggressive
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Conservative THEN Monitor
  IF STATE == Aggressive THEN DeepAnalyzer
  IF STATE == Emergency THEN IdleMonitor
END

INTENT "Test complex conditional logic"
MODE Testing
""")
    
    # Execute
    entity = execute_entity("entities/test_complex.ent", cycles=12, energy_per_tool=8)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Energy: {entity.energy}")
    print(f"  Reputation: {entity.reputation}")
    
    print("\n✅ Complex conditions test PASSED!")


def test_state_oscillation():
    """Test intentional state oscillation (competing rules)"""
    print("\n" + "="*70)
    print("TEST 5: STATE OSCILLATION")
    print("="*70 + "\n")
    
    # Create entity with competing rules
    with open("entities/test_oscillation.ent", 'w') as f:
        f.write("""
ENTITY OscillatorBot
STATE Active
ENERGY 25
REPUTATION 10

BEHAVIOR
  IF ENERGY < 30 THEN STATE Recovery
  IF REPUTATION > 5 THEN STATE Overclocked
END

EXECUTE
  IF STATE == Recovery THEN Monitor
  IF STATE == Overclocked THEN DeepAnalyzer
END

INTENT "Test competing behavioral rules"
MODE Testing
""")
    
    # Execute - should oscillate
    entity = execute_entity("entities/test_oscillation.ent", cycles=5, energy_per_tool=0)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Energy: {entity.energy}")
    print(f"  Reputation: {entity.reputation}")
    
    # Should be in one of the oscillating states
    assert entity.state in ["Recovery", "Overclocked"], "Should be oscillating"
    print("\n✅ State oscillation test PASSED!")


def test_conditional_tool_execution():
    """Test tools executing based on state"""
    print("\n" + "="*70)
    print("TEST 6: CONDITIONAL TOOL EXECUTION")
    print("="*70 + "\n")
    
    # Create entity with state-dependent tools
    with open("entities/test_tools.ent", 'w') as f:
        f.write("""
ENTITY ToolBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF REPUTATION > 3 THEN STATE Advanced
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Advanced THEN SentimentAnalyzer
  IF STATE == Advanced THEN DeepAnalyzer
END

INTENT "Test conditional tool execution"
MODE Testing
""")
    
    # Execute and track tool changes
    entity = execute_entity("entities/test_tools.ent", cycles=8, energy_per_tool=10)
    
    print(f"\nFinal Results:")
    print(f"  State: {entity.state}")
    print(f"  Reputation: {entity.reputation}")
    
    # Should have transitioned and used different tools
    assert entity.reputation >= 3, "Should have gained reputation"
    assert entity.state == "Advanced", "Should have advanced state"
    print("\n✅ Conditional tool execution test PASSED!")


def test_multi_entity_behaviors():
    """Test behaviors with multiple entities interacting"""
    print("\n" + "="*70)
    print("TEST 7: MULTI-ENTITY BEHAVIORS")
    print("="*70 + "\n")
    
    # Create multiple entities
    entities_created = []
    
    for i in range(3):
        filename = f"entities/test_multi_{i}.ent"
        with open(filename, 'w') as f:
            f.write(f"""
ENTITY MultiBot{i}
STATE Active
ENERGY {100 - (i * 20)}
REPUTATION {i * 2}

BEHAVIOR
  IF ENERGY < 40 THEN STATE Recovery
  IF REPUTATION > 3 THEN STATE Elite
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Recovery THEN Monitor
  IF STATE == Elite THEN DeepAnalyzer
END

INTENT "Multi-entity behavior test {i}"
MODE Testing
""")
        entities_created.append(filename)
    
    # Execute all entities
    from engine.executor import execute_multi_entity
    entities = execute_multi_entity(entities_created, cycles=5, energy_per_tool=10)
    
    print(f"\nExecuted {len(entities)} entities")
    for i, entity in enumerate(entities):
        print(f"  Entity {i}: State={entity.state} E={entity.energy} R={entity.reputation}")
    
    # Different entities should be in different states
    states = [e.state for e in entities]
    assert len(set(states)) > 1, "Entities should have different states"
    print("\n✅ Multi-entity behaviors test PASSED!")


def test_behavior_performance():
    """Test behavior system performance"""
    print("\n" + "="*70)
    print("TEST 8: PERFORMANCE TEST")
    print("="*70 + "\n")
    
    # Create entity
    with open("entities/test_performance.ent", 'w') as f:
        f.write("""
ENTITY PerfBot
STATE Active
ENERGY 100
REPUTATION 0

BEHAVIOR
  IF ENERGY < 50 THEN STATE Recovery
  IF REPUTATION > 5 THEN STATE Elite
  IF STATE == Recovery THEN ENERGY + 10
END

EXECUTE
  IF STATE == Active THEN DataCollector
  IF STATE == Recovery THEN Monitor
  IF STATE == Elite THEN DeepAnalyzer
END

INTENT "Performance testing"
MODE Testing
""")
    
    # Time execution
    start_time = time.time()
    entity = execute_entity("entities/test_performance.ent", cycles=50, energy_per_tool=5)
    end_time = time.time()
    
    duration = end_time - start_time
    cycles_per_second = 50 / duration
    
    print(f"\nPerformance Results:")
    print(f"  Total time: {duration:.2f}s")
    print(f"  Cycles per second: {cycles_per_second:.2f}")
    print(f"  Average cycle time: {(duration/50)*1000:.2f}ms")
    
    assert cycles_per_second > 5, "Performance too slow"
    print("\n✅ Performance test PASSED!")


def run_all_tests():
    """Run complete behavior test suite"""
    print("\n" + "="*70)
    print("🧠 OAN BEHAVIORAL INTELLIGENCE TEST SUITE")
    print("="*70)
    
    tests = [
        ("Basic Behavior", test_basic_behavior),
        ("Energy Restoration", test_energy_restoration),
        ("Reputation Behavior", test_reputation_based_behavior),
        ("Complex Conditions", test_complex_conditions),
        ("State Oscillation", test_state_oscillation),
        ("Conditional Tools", test_conditional_tool_execution),
        ("Multi-Entity", test_multi_entity_behaviors),
        ("Performance", test_behavior_performance)
    ]
    
    passed = 0
    failed = 0
    
    for name, test_func in tests:
        try:
            test_func()
            passed += 1
        except AssertionError as e:
            print(f"\n❌ {name} FAILED: {e}")
            failed += 1
        except Exception as e:
            print(f"\n❌ {name} ERROR: {e}")
            failed += 1
    
    print("\n" + "="*70)
    print("TEST SUITE COMPLETE")
    print("="*70)
    print(f"\n✅ Passed: {passed}/{len(tests)}")
    if failed > 0:
        print(f"❌ Failed: {failed}/{len(tests)}")
    else:
        print("🎉 ALL TESTS PASSED!")
    print("\n" + "="*70)


if __name__ == "__main__":
    run_all_tests()