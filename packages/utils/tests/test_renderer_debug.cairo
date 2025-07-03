#[cfg(test)]
mod test_renderer_debug {
    use game_components_utils::renderer::create_metadata;
    
    #[test]
    fn test_metadata_output() {
        let metadata = create_metadata(
            1, 'TestGame', 'TestDev', "http://image.png", "blue", 0, 0, 'Player'
        );
        
        // Print first 100 chars to see what we're getting
        let mut i = 0;
        loop {
            if i >= 100 || i >= metadata.len() {
                break;
            }
            // This is to at least compile
            let _byte = metadata[i];
            i += 1;
        };
        
        // The metadata should start with data URI
        assert!(metadata.len() > 30);
        
        // Check if it starts with expected prefix
        let prefix: ByteArray = "data:application/json;base64,";
        let mut matches = true;
        let mut j = 0;
        let prefix_len = prefix.len();
        loop {
            if j >= prefix_len {
                break;
            }
            if metadata.at(j).unwrap() != prefix.at(j).unwrap() {
                matches = false;
                break;
            }
            j += 1;
        };
        assert!(matches);
    }
}