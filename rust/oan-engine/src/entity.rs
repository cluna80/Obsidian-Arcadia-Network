//! Basic Entity structure

#[derive(Debug, Clone)]
pub struct Entity {
    pub id: String,
    pub entity_type: String,
    pub state: String,
}

impl Entity {
    pub fn new(id: String, entity_type: String) -> Self {
        Self {
            id,
            entity_type,
            state: "active".to_string(),
        }
    }
}
