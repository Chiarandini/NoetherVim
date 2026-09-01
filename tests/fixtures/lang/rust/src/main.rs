mod messy;
fn add(a: i32, b: i32) -> i32 {
    a + b
}

fn main() {
    println!("{}", add(40, 2) + messy::messy(0) - 1);
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
