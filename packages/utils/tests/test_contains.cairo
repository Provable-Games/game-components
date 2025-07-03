#[cfg(test)]
mod test_contains {
    use super::super::test_helpers::contains;
    
    #[test]
    fn test_contains_basic() {
        let haystack = "Hello, World!";
        let needle = "World";
        assert!(contains(@haystack, @needle));
    }
    
    #[test]
    fn test_contains_empty() {
        let haystack = "Hello";
        let needle = "";
        assert!(contains(@haystack, @needle));
    }
    
    #[test]
    fn test_contains_not_found() {
        let haystack = "Hello";
        let needle = "World";
        assert!(!contains(@haystack, @needle));
    }
}