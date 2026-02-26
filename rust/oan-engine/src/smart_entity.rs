//! Smart Entity - Entity with Brain

use crate::brain::{EntityBrain, Strategy};
use crate::entity::Entity;
use std::collections::HashMap;

pub struct SmartEntity {
    pub physical: Entity,
    pub brain: EntityBrain,
}

impl SmartEntity {
    pub fn new(id: String, entity_type: String) -> Self {
        Self {
            physical: Entity::new(id.clone(), entity_type),
            brain: EntityBrain::new(id),
        }
    }
    
    pub fn get_enhanced_stats(&self) -> HashMap<String, f64> {
        self.brain.get_stats()
    }
}
