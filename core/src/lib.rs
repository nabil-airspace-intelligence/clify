//! Clif Core - Rust library for encoding, storage, and pipeline orchestration
//!
//! This library will handle:
//! - GIF encoding (M3)
//! - File storage and organization (M3)
//! - Metadata indexing (M4)

pub fn version() -> &'static str {
    env!("CARGO_PKG_VERSION")
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_version() {
        assert_eq!(version(), "0.1.0");
    }
}
