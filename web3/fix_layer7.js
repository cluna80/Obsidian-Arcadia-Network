const fs = require('fs');

// ── Fix 1: BehaviorAuditor.sol ───────────────────────────────────────────────
// uint256 reputationDelta can't be compared to -100, change to int256
{
  const path = 'contracts/layer7/auditing/BehaviorAuditor.sol';
  let src = fs.readFileSync(path, 'utf8');
  const before = src;
  src = src.replace(/uint256 reputationDelta/g, 'int256 reputationDelta');
  fs.writeFileSync(path, src);
  console.log(src !== before
    ? '✔ BehaviorAuditor.sol fixed'
    : '⚠ BehaviorAuditor.sol - pattern not found, check manually');
}

// ── Fix 2: TransparencyRegistry.sol ─────────────────────────────────────────
// A) local var 'records' shadows mapping 'records' → rename local to entityRecs
// B) records[records[i]] double-index → records[entityRecs[i]]
{
  const path = 'contracts/layer7/auditing/TransparencyRegistry.sol';
  let src = fs.readFileSync(path, 'utf8');
  const before = src;

  // Rename local variable declaration
  src = src.replace(
    'uint256[] storage records = entityRecords[entityId];',
    'uint256[] storage entityRecs = entityRecords[entityId];'
  );

  // Fix the double-index bug
  src = src.replace(
    'AuditRecord storage record = records[records[i]];',
    'AuditRecord storage record = records[entityRecs[i]];'
  );

  // Fix any loop or length references using the old local var name
  // Only inside function bodies - replace remaining local 'records.' that aren't the mapping
  // The mapping is accessed as records[...] with a uint256 key
  // Local var references are: records.length, for(...records.length...)
  src = src.replace(/\bentityRecs\b/g, 'entityRecs'); // already done above, no-op
  // Fix loop length reference if it uses the old name
  src = src.replace(
    /for \(uint256 i = 0; i < records\.length; i\+\+\) \{[\s\S]*?AuditRecord storage record/,
    (match) => match.replace('records.length', 'entityRecs.length')
  );

  fs.writeFileSync(path, src);
  console.log(src !== before
    ? '✔ TransparencyRegistry.sol fixed'
    : '⚠ TransparencyRegistry.sol - pattern not found, check manually');
}

console.log('\nDone. Run: npx hardhat compile');