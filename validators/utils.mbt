///|
/// Helper: check if string contains substring
pub fn string_contains(s : String, sub : String) -> Bool {
  if sub.length() > s.length() {
    return false
  }
  if sub.length() == 0 {
    return true
  }
  let max_i = s.length() - sub.length()
  let mut i = 0
  while i <= max_i {
    let mut found = true
    let mut j = 0
    while j < sub.length() {
      if s[i + j] != sub[j] {
        found = false
        j = sub.length()  // break
      } else {
        j = j + 1
      }
    }
    if found == true {
      return true
    }
    i = i + 1
  }
  false
}
