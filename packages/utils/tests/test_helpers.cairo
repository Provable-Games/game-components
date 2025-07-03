#[cfg(test)]
pub fn contains(haystack: @ByteArray, needle: @ByteArray) -> bool {
    if needle.len() == 0 {
        return true;
    }
    if haystack.len() < needle.len() {
        return false;
    }
    
    let mut i = 0;
    loop {
        if i > haystack.len() - needle.len() {
            break false;
        }
        
        let mut j = 0;
        let mut matches = true;
        loop {
            if j >= needle.len() {
                break;
            }
            if haystack.at(i + j).unwrap() != needle.at(j).unwrap() {
                matches = false;
                break;
            }
            j += 1;
        };
        
        if matches {
            break true;
        }
        i += 1;
    }
}