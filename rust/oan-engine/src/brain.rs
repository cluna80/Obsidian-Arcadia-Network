//! Entity Brain System - Minimal Working Version

use std::collections::{HashMap, VecDeque};
use serde::{Deserialize, Serialize};

const MAX_SHORT_TERM_MEMORY: usize = 100;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MemoryEntry {
    pub timestamp: u64,
    pub event_type: String,
    pub outcome: f64,
    pub context: HashMap<String, String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Relationship {
    pub entity_id: String,
    pub trust_level: f64,
    pub interactions: u64,
    pub last_interaction: u64,
    pub wins_against: u64,
    pub losses_against: u64,
}

impl Relationship {
    pub fn new(entity_id: String) -> Self {
        Self {
            entity_id,
            trust_level: 0.0,
            interactions: 0,
            last_interaction: current_timestamp(),
            wins_against: 0,
            losses_against: 0,
        }
    }
    
    pub fn update_after_match(&mut self, won: bool) {
        self.interactions += 1;
        self.last_interaction = current_timestamp();
        
        if won {
            self.wins_against += 1;
            self.trust_level = (self.trust_level - 0.05).max(-1.0);
        } else {
            self.losses_against += 1;
            self.trust_level = (self.trust_level + 0.05).min(1.0);
        }
    }
    
    pub fn win_rate(&self) -> f64 {
        if self.interactions == 0 {
            return 0.5;
        }
        self.wins_against as f64 / self.interactions as f64
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize)]
pub enum Strategy {
    Aggressive,
    Balanced,
    Defensive,
    Adaptive,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Goal {
    pub goal_type: String,
    pub priority: u8,
    pub progress: f64,
    pub deadline: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct EntityBrain {
    pub entity_id: String,
    pub created_at: u64,
    pub short_term_memory: VecDeque<MemoryEntry>,
    pub long_term_memory: HashMap<String, f64>,
    pub relationships: HashMap<String, Relationship>,
    pub experience_points: u64,
    pub total_matches: u64,
    pub wins: u64,
    pub losses: u64,
    pub draws: u64,
    pub skill_levels: HashMap<String, f64>,
    pub training_sessions: u64,
    pub preferred_strategy: Strategy,
    pub risk_tolerance: f64,
    pub confidence: f64,
    pub goals: Vec<Goal>,
    pub achievement_count: u64,
    pub earnings: f64,
    pub net_worth: f64,
    pub reputation_score: f64,
}

impl EntityBrain {
    pub fn new(entity_id: String) -> Self {
        let mut skill_levels = HashMap::new();
        skill_levels.insert("strength".to_string(), 50.0);
        skill_levels.insert("agility".to_string(), 50.0);
        skill_levels.insert("stamina".to_string(), 50.0);
        skill_levels.insert("skill".to_string(), 50.0);
        
        Self {
            entity_id,
            created_at: current_timestamp(),
            short_term_memory: VecDeque::with_capacity(MAX_SHORT_TERM_MEMORY),
            long_term_memory: HashMap::new(),
            relationships: HashMap::new(),
            experience_points: 0,
            total_matches: 0,
            wins: 0,
            losses: 0,
            draws: 0,
            skill_levels,
            training_sessions: 0,
            preferred_strategy: Strategy::Balanced,
            risk_tolerance: 0.5,
            confidence: 0.5,
            goals: Vec::new(),
            achievement_count: 0,
            earnings: 0.0,
            net_worth: 0.0,
            reputation_score: 50.0,
        }
    }
    
    pub fn learn_from_match(
        &mut self,
        opponent_id: String,
        opponent_stats: HashMap<String, f64>,
        won: bool,
        score_diff: f64,
    ) {
        self.total_matches += 1;
        
        if won {
            self.wins += 1;
            self.confidence = (self.confidence + 0.02).min(1.0);
            self.experience_points += 10;
        } else {
            self.losses += 1;
            self.confidence = (self.confidence - 0.01).max(0.0);
            self.experience_points += 5;
        }
        
        self.relationships
            .entry(opponent_id.clone())
            .or_insert_with(|| Relationship::new(opponent_id.clone()))
            .update_after_match(won);
    }
    
    pub fn decide_strategy(&self, opponent_id: &str) -> Strategy {
        if let Some(relationship) = self.relationships.get(opponent_id) {
            let win_rate = relationship.win_rate();
            
            if win_rate > 0.7 {
                return Strategy::Aggressive;
            } else if win_rate < 0.3 {
                return Strategy::Defensive;
            }
        }
        
        self.preferred_strategy
    }
    
    pub fn train_skill(&mut self, skill_name: &str, intensity: f64) {
        let current_level = self.skill_levels.get(skill_name).unwrap_or(&50.0);
        let gain = intensity * 0.5;
        let new_level = (current_level + gain).min(100.0);
        
        self.skill_levels.insert(skill_name.to_string(), new_level);
        self.training_sessions += 1;
        self.experience_points += (intensity * 2.0) as u64;
    }
    
    pub fn get_stats(&self) -> HashMap<String, f64> {
        let mut stats = self.skill_levels.clone();
        
        for (_, value) in stats.iter_mut() {
            *value *= 1.0 + (self.confidence * 0.2);
        }
        
        stats
    }
    
    pub fn win_rate(&self) -> f64 {
        if self.total_matches == 0 {
            return 0.0;
        }
        self.wins as f64 / self.total_matches as f64
    }
    
    pub fn get_summary(&self) -> String {
        format!(
            "Entity: {} | Level: {} | Record: {}-{}-{} ({:.1}%) | Confidence: {:.0}% | XP: {}",
            self.entity_id,
            self.experience_points / 100,
            self.wins,
            self.losses,
            self.draws,
            self.win_rate() * 100.0,
            self.confidence * 100.0,
            self.experience_points
        )
    }
}

fn current_timestamp() -> u64 {
    use std::time::{SystemTime, UNIX_EPOCH};
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .unwrap()
        .as_secs()
}
