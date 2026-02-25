use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use sha2::{Digest, Sha256};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CompiledProgram {
    pub entity_name:  String,
    pub entity_type:  String,
    pub traits:       HashMap<String, f64>,
    pub rule_count:   usize,
    pub opcode_count: usize,
    pub source_hash:  String,
}

pub struct DslCompiler;

impl DslCompiler {
    pub fn new() -> Self { Self }

    pub fn compile(&self, source: &str) -> anyhow::Result<CompiledProgram> {
        let mut name  = String::from("Unknown");
        let mut etype = String::from("Generic");
        let mut traits: HashMap<String, f64> = HashMap::new();
        let mut rule_count = 0usize;

        for line in source.lines() {
            let line = line.trim();
            if line.starts_with("entity ") {
                let clean: Vec<&str> = line
                    .trim_end_matches(" {")
                    .split_whitespace()
                    .collect();
                if clean.len() > 1 { name  = clean[1].to_string(); }
                if clean.len() > 3 { etype = clean[3].to_string(); }
            } else if line.starts_with("trait ") {
                let parts: Vec<&str> = line.splitn(3, ' ').collect();
                if parts.len() == 3 {
                    let kv: Vec<&str> = parts[2].splitn(2, '=').collect();
                    if kv.len() == 2 {
                        if let Ok(v) = kv[1].trim().parse::<f64>() {
                            traits.insert(kv[0].trim().to_string(), v);
                        }
                    }
                }
            } else if line.starts_with("on ") {
                rule_count += 1;
            }
        }

        let mut hasher = Sha256::new();
        hasher.update(source.as_bytes());
        let source_hash = hex::encode(hasher.finalize());

        Ok(CompiledProgram {
            entity_name:  name,
            entity_type:  etype,
            traits,
            rule_count,
            opcode_count: rule_count * 4,
            source_hash,
        })
    }
}
