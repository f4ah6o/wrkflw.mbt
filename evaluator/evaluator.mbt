///|
/// Evaluation value type
pub enum Value {
  StringVal(String)
  NumberVal(Int)
  BoolVal(Bool)
  NullVal
} derive(Show)

///|
/// Evaluation context for variables
pub struct EvalContext {
  variables : Map[String, Value]
}

///|
/// Create a new empty context
pub fn EvalContext::new() -> EvalContext {
  { variables: {} }
}

///|
/// Create a context with predefined variables
pub fn EvalContext::with_vars(variables : Map[String, Value]) -> EvalContext {
  { variables, }
}

///|
/// Get a variable from context
pub fn EvalContext::get(self : EvalContext, name : String) -> Value {
  match self.variables.get(name) {
    Some(v) => v
    None => NullVal
  }
}

///|
/// Convert a value to string
pub fn value_to_string(v : Value) -> String {
  match v {
    StringVal(s) => s
    NumberVal(n) => int_to_string(n)
    BoolVal(b) => if b { "true" } else { "false" }
    NullVal => "null"
  }
}

///|
/// Simple evaluation: just substitute variables in the form ${var}
pub fn evaluate_simple(text : String, context : EvalContext) -> String {
  let mut result = text
  let mut pos = 0

  while pos < result.length() {
    // Find "${"
    let start_idx = find_substring(result, "${", pos)

    match start_idx {
      Some(idx) => {
        // Find "}" after "${"
        let expr_start = idx + 2
        let end_idx = find_substring(result, "}", expr_start)

        match end_idx {
          Some(end_pos) => {
            // Extract variable name
            let mut var_name = ""
            let mut i = expr_start
            while i < end_pos {
              var_name = var_name + result[i].to_string()
              i = i + 1
            }

            let value = context.get(var_name)
            let value_str = value_to_string(value)

            // Build new string
            let mut before = ""
            let mut j = 0
            while j < idx {
              before = before + result[j].to_string()
              j = j + 1
            }

            let after_start = end_pos + 1
            let mut after = ""
            let mut k = after_start
            while k < result.length() {
              after = after + result[k].to_string()
              k = k + 1
            }

            result = before + value_str + after
            pos = idx + value_str.length()
          }
          None => {
            pos = expr_start
          }
        }
      }
      None => {
        break
      }
    }
  }

  result
}

///|
/// Find substring in string starting from position
fn find_substring(s : String, sub : String, start : Int) -> Int? {
  let s_len = s.length()
  let sub_len = sub.length()
  let mut pos = start

  while pos + sub_len <= s_len {
    let mut found = true
    let mut i = 0
    while i < sub_len {
      if s[pos + i] != sub[i] {
        found = false
      }
      i = i + 1
    }
    if found {
      return Some(pos)
    }
    pos = pos + 1
  }

  None
}
