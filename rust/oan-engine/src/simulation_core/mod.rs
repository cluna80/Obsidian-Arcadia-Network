use serde::{Deserialize, Serialize};
use uuid::Uuid;
use std::time::Instant;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Athlete {
    pub id:       String,
    pub name:     String,
    pub sport:    String,
    pub strength: f64,
    pub agility:  f64,
    pub stamina:  f64,
    pub skill:    f64,
}

impl Athlete {
    pub fn new(name: &str, sport: &str, strength: f64, agility: f64, stamina: f64, skill: f64) -> Self {
        Self {
            id:       Uuid::new_v4().to_string(),
            name:     name.to_string(),
            sport:    sport.to_string(),
            strength,
            agility,
            stamina,
            skill,
        }
    }

    pub fn rating(&self) -> f64 {
        self.strength * 0.25
            + self.agility  * 0.20
            + self.stamina  * 0.20
            + self.skill    * 0.35
    }
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MatchResult {
    pub id:            String,
    pub winner_id:     String,
    pub score_a:       f64,
    pub score_b:       f64,
    pub upset:         bool,
    pub performance_a: f64,
    pub performance_b: f64,
}

pub struct MatchSimulator {
    pub rounds: u32,
}

impl MatchSimulator {
    pub fn new() -> Self { Self { rounds: 5 } }

    pub fn simulate(&self, a: &Athlete, b: &Athlete) -> MatchResult {
        let ra      = a.rating();
        let rb      = b.rating();
        let score_a = ra * self.rounds as f64;
        let score_b = rb * self.rounds as f64;
        let winner  = if score_a >= score_b { a.id.clone() } else { b.id.clone() };
        let expected = if ra >= rb           { a.id.clone() } else { b.id.clone() };
        MatchResult {
            id:            Uuid::new_v4().to_string(),
            winner_id:     winner.clone(),
            score_a,
            score_b,
            upset:         winner != expected,
            performance_a: score_a / self.rounds as f64,
            performance_b: score_b / self.rounds as f64,
        }
    }
}

pub fn benchmark(n: usize) -> (usize, f64) {
    let sim = MatchSimulator::new();
    let athletes: Vec<Athlete> = (0..n * 2)
        .map(|i| Athlete::new(&format!("A{}", i), "combat", 70.0, 70.0, 70.0, 70.0))
        .collect();
    let start = Instant::now();
    let count = athletes
        .chunks(2)
        .filter(|p: &&[Athlete]| p.len() == 2)
        .map(|p| sim.simulate(&p[0], &p[1]))
        .count();
    (count, start.elapsed().as_secs_f64())
}
