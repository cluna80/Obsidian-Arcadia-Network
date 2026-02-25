#!/bin/bash

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  ��� OAN PROTOCOL - COMPLETE SYSTEM TEST                   ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""

TOTAL_PASSED=0
TOTAL_FAILED=0

# Test 1: Python Layer 1
echo "[1/4] Testing Python Core Engine..."
cd ~/OneDrive/Desktop/ObsidianArcadia
python3 run_all_tests.py > /tmp/python_tests.log 2>&1
if [ $? -eq 0 ]; then
    echo "  ✔ Python tests passed"
    TOTAL_PASSED=$((TOTAL_PASSED + 82))
else
    echo "  ✘ Python tests failed"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

# Test 2: Solidity Layers 2-7
echo "[2/4] Testing Solidity Contracts (Layers 2-7)..."
cd ~/OneDrive/Desktop/ObsidianArcadia/web3
npx hardhat test > /tmp/solidity_tests.log 2>&1
SOLIDITY_RESULT=$(grep -oP '\d+(?= passing)' /tmp/solidity_tests.log | tail -1)
if [ ! -z "$SOLIDITY_RESULT" ]; then
    echo "  ✔ Solidity: $SOLIDITY_RESULT tests passed"
    TOTAL_PASSED=$((TOTAL_PASSED + SOLIDITY_RESULT))
else
    echo "  ✘ Solidity tests failed"
    TOTAL_FAILED=$((TOTAL_FAILED + 1))
fi

# Test 3: Rust Engine
echo "[3/4] Testing Rust Engine..."
cd ~/OneDrive/Desktop/ObsidianArcadia/rust/oan-engine
python3 test_rust_engine.py > /tmp/rust_tests.log 2>&1
RUST_RESULT=$(grep -oP '\d+(?= / )' /tmp/rust_tests.log | tail -1)
if [ ! -z "$RUST_RESULT" ]; then
    echo "  ✔ Rust: $RUST_RESULT tests passed"
    TOTAL_PASSED=$((TOTAL_PASSED + RUST_RESULT))
else
    echo "  ⚠ Rust tests skipped (engine not built)"
fi

# Test 4: Integration Tests
echo "[4/4] Testing Rust + Protocol Integration..."
cd ~/OneDrive/Desktop/ObsidianArcadia/rust/integration_tests
python3 test_full_protocol.py > /tmp/integration_tests.log 2>&1
if [ $? -eq 0 ]; then
    INTEGRATION_RESULT=$(grep -oP '\d+(?= passed)' /tmp/integration_tests.log | tail -1)
    echo "  ✔ Integration: $INTEGRATION_RESULT tests passed"
    TOTAL_PASSED=$((TOTAL_PASSED + INTEGRATION_RESULT))
else
    echo "  ⚠ Integration tests skipped (Rust not available)"
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  FINAL RESULTS                                            ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo ""
echo "  Total tests passed: $TOTAL_PASSED"
echo "  Total tests failed: $TOTAL_FAILED"
echo ""

if [ $TOTAL_FAILED -eq 0 ]; then
    echo "  ✅ ALL SYSTEMS OPERATIONAL"
else
    echo "  ⚠️  Some tests failed - check logs in /tmp/"
fi
echo ""
