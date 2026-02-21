# -*- coding: utf-8 -*-
"""
OAN Complete Test Suite
Master test runner for all system components
"""
import sys
import os
from datetime import datetime

# Add tests directory to path
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'tests'))

def run_test_suite(test_name, test_module):
    """Run a test module and report results"""
    print("\n" + "="*70)
    print(f"RUNNING: {test_name}")
    print("="*70)
    
    try:
        # Import and run from tests directory
        if test_module == "behavior":
            from test_behavior import run_all_tests
            run_all_tests()
        elif test_module == "communication":
            import test_communication
        elif test_module == "coordination":
            import test_coordination
        elif test_module == "spawning":
            import test_spawning
        
        print(f"\nSUCCESS: {test_name} COMPLETE")
        return True
        
    except Exception as e:
        print(f"\nFAILED: {test_name} - {e}")
        import traceback
        traceback.print_exc()
        return False

def main():
    """Run complete OAN test suite"""
    print("\n" + "="*70)
    print("OBSIDIAN ARCADIA NETWORK - COMPLETE TEST SUITE")
    print("="*70)
    print(f"Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70 + "\n")
    
    test_suites = [
        ("LAYER 1: Behavioral Intelligence", "behavior"),
        ("LAYER 3: Entity Communication", "communication"),
        ("LAYER 3: Entity Coordination", "coordination"),
        ("LAYER 3: Entity Spawning", "spawning")
    ]
    
    results = {}
    for name, module in test_suites:
        success = run_test_suite(name, module)
        results[name] = success
    
    # Final Report
    print("\n" + "="*70)
    print("FINAL TEST REPORT")
    print("="*70 + "\n")
    
    passed = sum(1 for v in results.values() if v)
    total = len(results)
    
    for name, success in results.items():
        status = "PASS" if success else "FAIL"
        print(f"{status} - {name}")
    
    print("\n" + "-"*70)
    print(f"Total: {passed}/{total} test suites passed")
    print("="*70)
    
    if passed == total:
        print("\nALL SYSTEMS OPERATIONAL!")
        print("The Obsidian Arcadia Network is ready for deployment!")
    else:
        print("\nSome tests failed. Review output above.")
    
    print("\n" + "="*70)
    print(f"Completed: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
    print("="*70 + "\n")
    
    return passed == total

if __name__ == "__main__":
    success = main()
    sys.exit(0 if success else 1)
