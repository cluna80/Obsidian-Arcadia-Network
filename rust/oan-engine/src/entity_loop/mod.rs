use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::time::Instant;
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum EntityStatus { Alive, Dead }

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Entity {
    pub id:          String,
    pub name:        String,
    pub entity_type: String,
    pub age:         u32,
    pub energy:      f64,
    pub health:      f64,
    pub reputation:  f64,
    pub status:      EntityStatus,
    pub traits:      HashMap<String, f64>,
    pub cycle_count: u64,
}

impl Entity {
    pub fn new(name: &str, entity_type: &str) -> Self {
        Self {
            id:          Uuid::new_v4().to_string(),
            name:        name.to_string(),
            entity_type: entity_type.to_string(),
            age:         0,
            energy:      100.0,
            health:      100.0,
            reputation:  50.0,
            status:      EntityStatus::Alive,
            traits:      HashMap::new(),
            cycle_count: 0,
        }
    }

    pub fn is_alive(&self) -> bool {
        matches!(self.status, EntityStatus::Alive)
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CycleResult {
    pub entity_id:    String,
    pub cycle:        u64,
    pub action_taken: String,
    pub energy_delta: f64,
    pub rep_delta:    f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct BenchmarkStats {
    pub total_cycles:   u64,
    pub total_entities: u64,
    pub alive_entities: u64,
    pub total_ops:      u64,
    pub elapsed_secs:   f64,
    pub cycles_per_sec: f64,
    pub ops_per_sec:    f64,
}

pub struct EntityEngine {
    pub entities: Vec<Entity>,
    pub cycle:    u64,
}

impl EntityEngine {
    pub fn new() -> Self {
        Self { entities: Vec::new(), cycle: 0 }
    }

    pub fn spawn(&mut self, name: &str, entity_type: &str) -> String {
        let e  = Entity::new(name, entity_type);
        let id = e.id.clone();
        self.entities.push(e);
        id
    }

    pub fn spawn_batch(&mut self, count: usize, entity_type: &str) -> Vec<String> {
        let ids: Vec<String> = (0..count)
            .map(|i| self.spawn(&format!("Entity-{}", i), entity_type))
            .collect();
        ids
    }

    pub fn tick(&mut self) -> Vec<CycleResult> {
        self.cycle += 1;
        let cycle = self.cycle;
        self.entities
            .par_iter_mut()
            .filter(|e| e.is_alive())
            .map(|e| {
                e.cycle_count += 1;
                e.age         += 1;
                e.energy       = (e.energy - 1.0).max(0.0);
                if e.energy <= 0.0 {
                    e.status = EntityStatus::Dead;
                }
                let action = if e.energy < 20.0 {
                    e.energy = (e.energy + 30.0).min(100.0);
                    "rest"
                } else if e.energy > 80.0 {
                    e.energy -= 20.0;
                    "compete"
                } else {
                    "idle"
                };
                CycleResult {
                    entity_id:    e.id.clone(),
                    cycle,
                    action_taken: action.to_string(),
                    energy_delta: 0.0,
                    rep_delta:    0.0,
                }
            })
            .collect()
    }

    pub fn run_cycles(&mut self, n: u64) -> BenchmarkStats {
        let start   = Instant::now();
        let mut ops = 0u64;
        for _ in 0..n {
            ops += self.tick().len() as u64;
        }
        let elapsed = start.elapsed().as_secs_f64();
        let alive   = self.entities.iter().filter(|e| e.is_alive()).count() as u64;
        BenchmarkStats {
            total_cycles:   n,
            total_entities: self.entities.len() as u64,
            alive_entities: alive,
            total_ops:      ops,
            elapsed_secs:   elapsed,
            cycles_per_sec: n as f64 / elapsed,
            ops_per_sec:    ops as f64 / elapsed,
        }
    }
}
