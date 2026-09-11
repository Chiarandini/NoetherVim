//! A workspace member with one passing and one failing test, matching the
//! single-crate fixture so checkpoint 5b asserts the same 1-and-1 split.

pub fn add(a: i32, b: i32) -> i32 {
    a + b
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn passes() {
        assert_eq!(add(1, 2), 3);
    }

    #[test]
    fn fails() {
        assert_eq!(add(1, 2), 4);
    }
}
