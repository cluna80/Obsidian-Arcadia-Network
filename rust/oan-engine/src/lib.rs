use pyo3::prelude::*;
use std::collections::HashMap;
use uuid::Uuid;

pub mod entity;
pub mod brain;
pub mod smart_entity;

pub use entity::Entity;
pub use brain::{EntityBrain, MemoryEntry, Relationship, Strategy, Goal};
pub use smart_entity::SmartEntity;

// Global storage for smart entities (thread-safe)
use std::sync::Mutex;
use once_cell::sync::Lazy;

static SMART_ENTITIES: Lazy<Mutex<HashMap<String, SmartEntity>>> = 
    Lazy::new(|| Mutex::new(HashMap::new()));

/// Enhanced engine that manages smart entities
#[pyclass]
pub struct PySmartEngine {
    entity_count: usize,
}

#[pymethods]
impl PySmartEngine {
    #[new]
    fn new() -> Self {
        Self { entity_count: 0 }
    }
    
    /// Spawn a smart entity with brain
    fn spawn_smart(&mut self, name: String, entity_type: String) -> PyResult<String> {
        let id = Uuid::new_v4().to_string();
        let entity = SmartEntity::new(id.clone(), entity_type);
        
        SMART_ENTITIES.lock().unwrap().insert(id.clone(), entity);
        self.entity_count += 1;
        
        Ok(id)
    }
    
    /// Get entity brain summary
    fn get_brain_summary(&self, entity_id: String) -> PyResult<String> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            Ok(entity.brain.get_summary())
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Get entity stats (enhanced by brain)
    fn get_stats(&self, entity_id: String) -> PyResult<HashMap<String, f64>> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            Ok(entity.get_enhanced_stats())
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Train a specific skill
    fn train_skill(&mut self, entity_id: String, skill_name: String, intensity: f64) -> PyResult<()> {
        let mut entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get_mut(&entity_id) {
            entity.brain.train_skill(&skill_name, intensity);
            Ok(())
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Simulate a smart match where entities learn
    fn smart_match(&mut self, entity_a_id: String, entity_b_id: String) -> PyResult<HashMap<String, f64>> {
        let mut entities = SMART_ENTITIES.lock().unwrap();
        
        // Get mutable references (need to do this carefully)
        if !entities.contains_key(&entity_a_id) || !entities.contains_key(&entity_b_id) {
            return Err(pyo3::exceptions::PyValueError::new_err("One or both entities not found"));
        }
        
        // Get strategies first
        let strategy_a = entities.get(&entity_a_id).unwrap()
            .brain.decide_strategy(&entity_b_id);
        let strategy_b = entities.get(&entity_b_id).unwrap()
            .brain.decide_strategy(&entity_a_id);
        
        // Get stats
        let stats_a = entities.get(&entity_a_id).unwrap().get_enhanced_stats();
        let stats_b = entities.get(&entity_b_id).unwrap().get_enhanced_stats();
        
        // Calculate scores
        let score_a = calculate_score_with_strategy(&stats_a, strategy_a);
        let score_b = calculate_score_with_strategy(&stats_b, strategy_b);
        
        let a_won = score_a > score_b;
        let score_diff = (score_a - score_b).abs();
        
        // Both entities learn (need to borrow mutably one at a time)
        {
            let entity_a = entities.get_mut(&entity_a_id).unwrap();
            entity_a.brain.learn_from_match(
                entity_b_id.clone(),
                stats_b.clone(),
                a_won,
                score_diff,
            );
        }
        
        {
            let entity_b = entities.get_mut(&entity_b_id).unwrap();
            entity_b.brain.learn_from_match(
                entity_a_id.clone(),
                stats_a.clone(),
                !a_won,
                score_diff,
            );
        }
        
        let mut result = HashMap::new();
        result.insert("score_a".to_string(), score_a);
        result.insert("score_b".to_string(), score_b);
        result.insert("winner".to_string(), if a_won { 1.0 } else { 2.0 });
        
        Ok(result)
    }
    
    /// Get entity's win rate
    fn get_win_rate(&self, entity_id: String) -> PyResult<f64> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            Ok(entity.brain.win_rate())
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Get relationship info between two entities
    fn get_relationship(&self, entity_id: String, other_id: String) -> PyResult<HashMap<String, f64>> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            if let Some(relationship) = entity.brain.relationships.get(&other_id) {
                let mut info = HashMap::new();
                info.insert("trust_level".to_string(), relationship.trust_level);
                info.insert("interactions".to_string(), relationship.interactions as f64);
                info.insert("wins_against".to_string(), relationship.wins_against as f64);
                info.insert("losses_against".to_string(), relationship.losses_against as f64);
                info.insert("win_rate".to_string(), relationship.win_rate());
                Ok(info)
            } else {
                let mut info = HashMap::new();
                info.insert("trust_level".to_string(), 0.0);
                info.insert("interactions".to_string(), 0.0);
                Ok(info)
            }
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Get entity's confidence level
    fn get_confidence(&self, entity_id: String) -> PyResult<f64> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            Ok(entity.brain.confidence)
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Get entity's strategy against opponent
    fn get_strategy(&self, entity_id: String, opponent_id: String) -> PyResult<String> {
        let entities = SMART_ENTITIES.lock().unwrap();
        
        if let Some(entity) = entities.get(&entity_id) {
            let strategy = entity.brain.decide_strategy(&opponent_id);
            Ok(format!("{:?}", strategy))
        } else {
            Err(pyo3::exceptions::PyValueError::new_err("Entity not found"))
        }
    }
    
    /// Get count of entities
    fn alive_count(&self) -> usize {
        SMART_ENTITIES.lock().unwrap().len()
    }
}

fn calculate_score_with_strategy(stats: &HashMap<String, f64>, strategy: Strategy) -> f64 {
    let base_score: f64 = stats.values().sum();
    
    match strategy {
        Strategy::Aggressive => base_score * 1.2,
        Strategy::Defensive => base_score * 0.9,
        Strategy::Balanced => base_score,
        Strategy::Adaptive => base_score * 1.1,
    }
}

/// Python module
#[pymodule]
fn oan_engine(_py: Python, m: &PyModule) -> PyResult<()> {
    m.add_class::<PySmartEngine>()?;
    Ok(())
}
