use wasm_bindgen::prelude::*;
use serde_json;

// Core pure Rust function (no WASM deps) - easy to test
pub fn verify_reputation_delta(
    current_rep: u64,
    delta: i64,
    max_positive_delta: u64,
    max_negative_delta: u64,
) -> (bool, u64, String) {
    let abs_delta = delta.abs() as u64;

    let is_positive = delta >= 0;

    let is_allowed = if is_positive {
        abs_delta <= max_positive_delta
    } else {
        abs_delta <= max_negative_delta
    };

    // We allow reputation to go down to 0 (saturating behavior is intentional)
    let new_rep = if is_positive {
        current_rep.saturating_add(abs_delta)
    } else {
        current_rep.saturating_sub(abs_delta)
    };

    // Core fix: validity depends only on whether the delta is within allowed bounds
    let is_valid = is_allowed;

    let reason = if is_valid {
        if !is_positive && abs_delta > current_rep {
            "valid update (saturated at 0)".to_string()
        } else {
            "valid update".to_string()
        }
    } else if !is_allowed {
        "delta exceeds allowed limits".to_string()
    } else {
        "invalid (unexpected)".to_string()  // fallback - shouldn't reach here
    };

    (is_valid, new_rep, reason)
}

// WASM export - wraps the pure function
#[wasm_bindgen]
pub fn verify_reputation_delta_wasm(
    current_rep: u64,
    delta: i64,
    max_positive_delta: u64,
    max_negative_delta: u64,
) -> JsValue {
    let (is_valid, new_rep, reason) = verify_reputation_delta(
        current_rep,
        delta,
        max_positive_delta,
        max_negative_delta,
    );

    let result = serde_json::json!({
        "is_valid": is_valid,
        "new_rep": new_rep,
        "delta_applied": delta,
        "reason": reason
    });

    serde_wasm_bindgen::to_value(&result).unwrap()
}

// Tests - use the pure Rust function (no WASM deps)
#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_valid_positive_delta() {
        let (is_valid, new_rep, reason) = verify_reputation_delta(100, 20, 50, 10);
        assert!(is_valid);
        assert_eq!(new_rep, 120);
        assert_eq!(reason, "valid update");
    }

    #[test]
    fn test_invalid_negative_delta() {
        let (is_valid, new_rep, reason) = verify_reputation_delta(100, -30, 50, 10);
        assert!(!is_valid);
        assert_eq!(new_rep, 70);
        assert_eq!(reason, "delta exceeds allowed limits");
    }

    #[test]
    fn test_negative_overflow() {
        let (is_valid, new_rep, reason) = verify_reputation_delta(5, -10, 50, 10);
        assert!(is_valid);                  // Now correctly true
        assert_eq!(new_rep, 0);             // Saturated at 0
        assert_eq!(reason, "valid update (saturated at 0)");
    }
}