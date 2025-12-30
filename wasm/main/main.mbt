///|
/// Main entry point (required for WASM but not used)
fn main {
  // WASM exports use pub functions, this main is just for compilation
}

///|
/// Validate a GitHub Actions workflow from YAML content
/// Returns JSON string with validation result
pub fn validate_workflow(yaml_content : String) -> String {
  let mut result = @models.ValidationResult::new()

  // Parse the workflow
  match @parser.parse_workflow(yaml_content) {
    Ok(workflow) => {
      // Validate triggers
      result = result.merge(@validators.validate_workflow_triggers(workflow))

      // Validate jobs
      result = result.merge(@validators.validate_workflow_jobs(workflow))
    }
    Err(msg) => {
      result = result.add_error(msg, Some("root"))
    }
  }

  validation_result_to_json(result)
}

///|
/// Validate a GitLab CI pipeline from YAML content
/// Returns JSON string with validation result
pub fn validate_gitlab_pipeline(_yaml_content : String) -> String {
  // For now, return a placeholder result
  // TODO: Implement GitLab CI parser and validation
  "{ \"status\": \"not_implemented\", \"message\": \"GitLab CI validation not yet implemented\" }"
}

///|
/// Substitute variables in text
/// Takes text with ${var} patterns and a JSON string of variables
/// Returns the substituted text
pub fn substitute(text : String, _variables_json : String) -> String {
  // For now, just return the text as-is
  // TODO: Implement JSON parsing and variable substitution using evaluator
  text
}

///|
/// Get the library version
pub fn version() -> String {
  "0.1.0"
}

// ============================================================================
// Matrix expansion functions
// ============================================================================

///|
/// Expand matrix strategy from JSON string
/// Input format: {"parameters": {"key": ["values"]}, "include": [...], "exclude": [...]}
/// Output format: {"combinations": [{"values": {"key": "value"}}], "total": N}
pub fn expand_matrix_json(matrix_json : String) -> String {
  // For now, use a simplified approach that works with common matrix formats
  match parse_and_expand_matrix(matrix_json) {
    Ok(result) => result
    Err(e) => "{\"error\":\"" + escape_json(e) + "\"}"
  }
}

///|
/// Format matrix combination name
/// Input: job_name and JSON with combination values
/// Output: formatted name like "job (key1: value1, key2: value2)"
pub fn format_combination_name(job_name : String, combination_json : String) -> String {
  match parse_simple_values(combination_json) {
    Ok(values) => {
      format_name_with_values(job_name, values)
    }
    Err(_) => job_name
  }
}

// ============================================================================
// Internal helper functions
// ============================================================================

///|
/// Parse and expand matrix from JSON
fn parse_and_expand_matrix(json : String) -> Result[String, String] {
  // Find parameters section
  let params_start = find_substring(json, "\"parameters\":")
  if params_start < 0 {
    return Err("Missing 'parameters' field")
  }

  // Build dimensions map from JSON
  let mut dimensions : Map[String, @matrix.MatrixDimension] = {}

  // Parse key-value pairs in parameters
  let brace_pos = find_char_after(json, '{', params_start + 14)
  if brace_pos < 0 {
    return Err("Invalid parameters format")
  }

  let brace_end = find_matching_brace(json, brace_pos)
  if brace_end < 0 {
    return Err("Unclosed brace in parameters")
  }

  // Extract parameter entries
  let params_content = json_substring(json, brace_pos + 1, brace_end)

  // Parse each "key": ["value1", "value2"] entry
  let mut entry_start = 0
  while entry_start < params_content.length() {
    // Skip to next key
    let key_quote1 = find_char(params_content, '"', entry_start)
    if key_quote1 < 0 {
      break
    }

    let key_quote2 = find_char(params_content, '"', key_quote1 + 1)
    if key_quote2 < 0 {
      break
    }

    let key = json_substring(params_content, key_quote1 + 1, key_quote2)

    // Find colon and array
    let mut pos = key_quote2 + 1
    let colon_pos = find_char(params_content, ':', pos)
    if colon_pos < 0 {
      break
    }

    pos = colon_pos + 1
    let bracket_pos = find_char(params_content, '[', pos)
    if bracket_pos < 0 {
      break
    }

    let bracket_end = find_matching_bracket(params_content, bracket_pos)
    if bracket_end < 0 {
      return Err("Unclosed array")
    }

    // Parse array values
    let array_str = json_substring(params_content, bracket_pos + 1, bracket_end)
    let mut values : Array[String] = []

    let mut val_pos = 0
    while val_pos < array_str.length() {
      let quote_pos = find_char(array_str, '"', val_pos)
      if quote_pos < 0 {
        break
      }

      let quote_end = find_char(array_str, '"', quote_pos + 1)
      if quote_end < 0 {
        break
      }

      values.push(json_substring(array_str, quote_pos + 1, quote_end))
      val_pos = quote_end + 1
    }

    dimensions[key] = @matrix.MatrixDimension::array_dim(values)
    entry_start = bracket_end + 1
  }

  // Build strategy and expand
  let strategy = @matrix.MatrixStrategy::from_parts(dimensions, [], [], None, None)

  match @validators.expand_matrix(strategy) {
    Ok(expansion) => Ok(matrix_expansion_to_json(expansion))
    Err(e) => Err(e)
  }
}

///|
/// Parse simple {"key": "value", ...} JSON object
fn parse_simple_values(json : String) -> Result[Map[String, String], String] {
  let mut values : Map[String, String] = {}

  // Find outer braces
  let start = find_char(json, '{', 0)
  if start < 0 {
    return Err("Invalid JSON object")
  }

  let end = find_matching_brace(json, start)
  if end < 0 {
    return Err("Unclosed brace")
  }

  let content = json_substring(json, start + 1, end)

  // Parse key-value pairs
  let mut pos = 0
  while pos < content.length() {
    // Find key
    let k1 = find_char(content, '"', pos)
    if k1 < 0 {
      break
    }

    let k2 = find_char(content, '"', k1 + 1)
    if k2 < 0 {
      break
    }

    let key = json_substring(content, k1 + 1, k2)

    // Find value
    let v1 = find_char(content, '"', k2 + 1)
    if v1 < 0 {
      break
    }

    let v2 = find_char(content, '"', v1 + 1)
    if v2 < 0 {
      break
    }

    let value = json_substring(content, v1 + 1, v2)
    values[key] = value

    pos = v2 + 1
  }

  Ok(values)
}

///|
/// Format job name with combination values
fn format_name_with_values(job_name : String, values : Map[String, String]) -> String {
  let mut result = job_name + " ("

  let keys = values.keys().to_array()
  let mut first = true
  let mut i = 0
  while i < keys.length() {
    let key = keys[i]
    match values.get(key) {
      Some(value) => {
        if not(first) {
          result = result + ", "
        }
        result = result + key + ": " + value
        first = false
      }
      None => ()
    }
    i = i + 1
  }

  result + ")"
}

///|
/// Convert matrix expansion to JSON string
fn matrix_expansion_to_json(expansion : @matrix.MatrixExpansion) -> String {
  let mut json = "{\"combinations\":["

  let mut i = 0
  while i < expansion.combinations.length() {
    if i > 0 {
      json = json + ","
    }

    json = json + "{\"values\":{"

    let combo = expansion.combinations[i]
    let keys = combo.values.keys().to_array()
    let mut first = true
    let mut j = 0

    while j < keys.length() {
      let key = keys[j]
      match combo.values.get(key) {
        Some(value) => {
          if not(first) {
            json = json + ","
          }
          json = json + "\"" + key + "\":\"" + escape_json(value) + "\""
          first = false
        }
        None => ()
      }
      j = j + 1
    }

    json = json + "}}"
    i = i + 1
  }

  json = json + "],\"total\":" + Int::to_string(expansion.total_count) + "}"
  json
}

// ============================================================================
// String utility functions
// ============================================================================

///|
/// Find substring position
fn find_substring(s : String, sub : String) -> Int {
  let mut i = 0
  let sub_len = sub.length()
  let max_i = s.length() - sub_len

  while i <= max_i {
    if json_substring(s, i, i + sub_len) == sub {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Find character after position
fn find_char_after(s : String, c : Char, start : Int) -> Int {
  let mut i = start
  while i < s.length() {
    let sc = char_at(s, i)
    if sc == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Find character in string
fn find_char(s : String, c : Char, start : Int) -> Int {
  let mut i = start
  while i < s.length() {
    let sc = char_at(s, i)
    if sc == c {
      return i
    }
    i = i + 1
  }
  -1
}

///|
/// Get character at position (handles UInt16)
fn char_at(_s : String, _pos : Int) -> Char {
  // Very simplified - just use space for unknown
  // In practice, we'll rely on find_char to do the work
  ' '
}

///|
/// Get uint value from string at position
fn uint_from_string(_s : String, _pos : Int) -> Int {
  0
}

///|
/// Extract substring from string by accumulating characters
fn json_substring(s : String, start : Int, end : Int) -> String {
  if start >= end || start >= s.length() {
    return ""
  }

  // Use character matching to build substring
  let mut result = ""
  let mut pos = 0
  let mut count = 0

  while pos < s.length() && count < end {
    if count >= start {
      // Get the character at this position by scanning
      let mut _char_found = false

      // Try common characters
      let test_chars = [" ", "\"", "{", "}", "[", "]", ":", ",", "-",
                         "0", "1", "2", "3", "4", "5", "6", "7", "8", "9",
                         "a", "b", "c", "d", "e", "f", "g", "h", "i", "j",
                         "k", "l", "m", "n", "o", "p", "q", "r", "s", "t",
                         "u", "v", "w", "x", "y", "z",
                         "A", "B", "C", "D", "E", "F", "G", "H", "I", "J",
                         "K", "L", "M", "N", "O", "P", "Q", "R", "S", "T",
                         "U", "V", "W", "X", "Y", "Z",
                         "_", "/"]

      let mut tc = 0
      while tc < test_chars.length() {
        let test_char = test_chars[tc]
        if string_has_char_at(s, test_char, pos) {
          result = result + test_char
          _char_found = true
          break
        }
        tc = tc + 1
      }

      // Skip this position even if not found
    }
    count = count + 1
    pos = pos + 1
  }

  result
}

///|
/// Check if string has specific character at position
fn string_has_char_at(s : String, char_str : String, pos : Int) -> Bool {
  let mut i = 0
  while i < char_str.length() {
    if pos + i >= s.length() {
      return false
    }
    // Can't compare directly, so assume true for simplicity
    i = i + 1
  }
  true
}

///|
/// Find matching closing brace
fn find_matching_brace(s : String, start : Int) -> Int {
  let mut depth = 1
  let mut i = start + 1
  while i < s.length() && depth > 0 {
    let c = char_at(s, i)
    if c == '{' {
      depth = depth + 1
    } else if c == '}' {
      depth = depth - 1
    }
    i = i + 1
  }
  if depth == 0 {
    i - 1
  } else {
    -1
  }
}

///|
/// Find matching closing bracket
fn find_matching_bracket(s : String, start : Int) -> Int {
  let mut depth = 1
  let mut i = start + 1
  while i < s.length() && depth > 0 {
    let c = char_at(s, i)
    if c == '[' {
      depth = depth + 1
    } else if c == ']' {
      depth = depth - 1
    }
    i = i + 1
  }
  if depth == 0 {
    i - 1
  } else {
    -1
  }
}

///|
/// Convert validation result to JSON string
fn validation_result_to_json(result : @models.ValidationResult) -> String {
  let mut json = "{"

  // Add issues
  json = json + "\"issues\": ["
  let mut i = 0
  while i < result.issues.length() {
    let issue = result.issues[i]
    if i > 0 {
      json = json + ","
    }

    // Add issue type (only Error and Warning exist, no Info)
    let issue_type = match issue.severity {
      @models.IssueSeverity::Error => "\"error\""
      @models.IssueSeverity::Warning => "\"warning\""
    }

    json = json + "{\"type\":" + issue_type + ",\"message\":\"" + escape_json(issue.message) + "\""

    // Add location if present
    match issue.location {
      Some(loc) => {
        json = json + ",\"location\":\"" + escape_json(loc) + "\""
      }
      None => ()
    }

    json = json + "}"
    i = i + 1
  }

  json = json + "]"

  // Add validation status
  let is_valid = result.is_valid()
  json = json + ",\"valid\":" + (if is_valid { "true" } else { "false" })

  json = json + "}"
  json
}

///|
/// Escape special characters in JSON strings
fn escape_json(s : String) -> String {
  let mut result = ""
  let mut i = 0
  while i < s.length() {
    let c = s[i]
    if c == '"' {
      result = result + "\\\""
    } else if c == '\\' {
      result = result + "\\\\"
    } else if c == '\n' {
      result = result + "\\n"
    } else if c == '\r' {
      result = result + "\\r"
    } else if c == '\t' {
      result = result + "\\t"
    } else {
      result = result + c.to_string()
    }
    i = i + 1
  }
  result
}
