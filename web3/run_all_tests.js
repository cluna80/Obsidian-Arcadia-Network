#!/usr/bin/env node
const { exec } = require('child_process');
const util = require('util');
const execPromise = util.promisify(exec);
const fs = require('fs');

const tests = [
  { name: 'Layer 2 — Web3 Foundation', file: 'test/layer2.test.js' },
  { name: 'Layer 3 — AI & Behavior', file: 'test/layer3.test.js' },
  { name: 'Layer 4 — Media Systems', file: 'test/layer4.test.js' },
  { name: 'Layer 5 — Metaverse Sports', file: 'test/layer5.test.js' },
  { name: 'Layer 6 — Marketplace', file: 'test/layer6.test.js' },
  { name: 'Layer 7.1-7.4 — Safety (Execution, Audit, Enforcement, Stability)', file: 'test/layer7-1-4.test.js' },
  { name: 'Layer 7.5-7.6 — Safety (Trust, Insurance)', file: 'test/layer7-5-6.test.js' },
  { name: 'Integration — Cross-Layer', file: 'test/integration.test.js' },
  { name: 'Security — Edge Cases', file: 'test/security.test.js' },
];

console.log('\n╔═══════════════════════════════════════════════════╗');
console.log('║  ��� OAN PROTOCOL — MASTER TEST SUITE             ║');
console.log('╚═══════════════════════════════════════════════════╝\n');

async function runTest(test) {
  if (!fs.existsSync(test.file)) {
    console.log(`⊘ ${test.name}: SKIPPED (file not found)\n`);
    return { name: test.name, passing: 0, failing: 0, duration: 0, skipped: true };
  }

  const startTime = Date.now();
  
  try {
    console.log(`▶ Running: ${test.name}`);
    
    const { stdout } = await execPromise(`npx hardhat test ${test.file}`, { 
      maxBuffer: 1024 * 1024 * 10 
    });
    
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    
    const passingMatch = stdout.match(/(\d+) passing/);
    const failingMatch = stdout.match(/(\d+) failing/);
    
    const passing = passingMatch ? parseInt(passingMatch[1]) : 0;
    const failing = failingMatch ? parseInt(failingMatch[1]) : 0;
    
    if (failing === 0) {
      console.log(`✔ ${test.name}: ${passing} passing (${duration}s)\n`);
    } else {
      console.log(`✘ ${test.name}: ${passing} passing, ${failing} failing (${duration}s)\n`);
    }
    
    return { name: test.name, passing, failing, duration };
    
  } catch (error) {
    const duration = ((Date.now() - startTime) / 1000).toFixed(1);
    console.log(`✘ ${test.name}: CRASHED (${duration}s)\n`);
    return { name: test.name, passing: 0, failing: 1, duration };
  }
}

async function runAllTests() {
  const results = [];
  
  for (const test of tests) {
    const result = await runTest(test);
    if (!result.skipped) results.push(result);
  }
  
  console.log('\n╔═══════════════════════════════════════════════════╗');
  console.log('║  TEST RESULTS SUMMARY                              ║');
  console.log('╚═══════════════════════════════════════════════════╝\n');
  
  let totalPassing = 0;
  let totalFailing = 0;
  
  results.forEach(r => {
    const status = r.failing === 0 ? '✔' : '✘';
    const pad = ' '.repeat(Math.max(0, 50 - r.name.length));
    console.log(`${status}  ${r.name}${pad}${r.passing} / ${r.failing} (${r.duration}s)`);
    totalPassing += r.passing;
    totalFailing += r.failing;
  });
  
  console.log('\n╔═══════════════════════════════════════════════════╗');
  console.log(`║  Total passing : ${totalPassing.toString().padEnd(36)}║`);
  console.log(`║  Total failing : ${totalFailing.toString().padEnd(36)}║`);
  
  if (totalFailing === 0) {
    console.log('║  ✔  ALL TESTS PASSED                               ║');
  } else {
    console.log('║  ✘  SOME TESTS FAILED                              ║');
  }
  console.log('╚═══════════════════════════════════════════════════╝\n');
  
  process.exit(totalFailing > 0 ? 1 : 0);
}

runAllTests().catch(console.error);
