# í·ª Testing Guide

## Run All Tests
```bash
python run_all_tests.py
```

## Expected Output
```
í¼‘ OBSIDIAN ARCADIA NETWORK - COMPLETE TEST SUITE
âœ… PASS - Behavioral Intelligence
âœ… PASS - Entity Communication
âœ… PASS - Entity Coordination
âœ… PASS - Entity Spawning
í¾‰ ALL SYSTEMS OPERATIONAL! í¾‰
```

## Individual Tests
```bash
python tests/test_behavior.py
python tests/test_communication.py
python tests/test_coordination.py
python tests/test_spawning.py
```

## Test Your Entity
```python
import oan

# Test parsing
entity = oan.parse_dsl("my_entity.obs")
assert entity.name == "MyBot"

# Test execution
result = oan.execute_entity("my_entity.obs", cycles=10)
assert result.reputation > 0

print("âœ… Tests passed!")
```

## Performance Test
```python
import oan
import time

start = time.time()
entity = oan.execute_entity("bot.obs", cycles=100)
duration = time.time() - start

print(f"Performance: {100/duration:.0f} cycles/sec")
assert 100/duration > 50  # Should be >50 cycles/sec
```

## Coverage
```bash
pip install pytest pytest-cov
pytest tests/ --cov=oan --cov-report=html
```

**Expected: 100% coverage** âœ…
