///|
/// Get a string value from a YamlNode
pub fn get_string(node : @yaml.YamlNode) -> String? {
  match node {
    @yaml.YString(s, _, _) => Some(s)
    @yaml.YBool(true, _) => Some("true")
    @yaml.YBool(false, _) => Some("false")
    @yaml.YNumber(n, _) => Some(n)
    _ => None
  }
}

///|
/// Get a boolean value from a YamlNode
pub fn get_bool(node : @yaml.YamlNode) -> Bool? {
  match node {
    @yaml.YBool(b, _) => Some(b)
    @yaml.YString(s, _, _) => {
      match s {
        "true" | "yes" | "on" => Some(true)
        "false" | "no" | "off" => Some(false)
        _ => None
      }
    }
    _ => None
  }
}

///|
/// Get an int value from a YamlNode (returns None for non-integer numbers)
pub fn get_int(node : @yaml.YamlNode) -> Int? {
  match node {
    @yaml.YNumber(n, _) => parse_int_to_int(n)
    _ => None
  }
}

// Helper function to parse string to Int
fn parse_int_to_int(s : String) -> Int? {
  let chars = s.to_array()
  let mut result = 0
  let mut sign = 1
  let mut i = 0
  let len = chars.length()

  if len == 0 { return None }

  // Handle sign
  if chars[0] == '-' {
    sign = -1
    i = 1
  } else if chars[0] == '+' {
    i = 1
  }

  while i < len {
    let c = chars[i]
    let c_val = char_to_digit(c)
    match c_val {
      Some(d) => result = result * 10 + d
      None => return None
    }
    i = i + 1
  }

  Some(result * sign)
}

// Convert char to digit value
fn char_to_digit(c : Char) -> Int? {
  if c >= '0' && c <= '9' {
    Some((c.to_int() - '0'.to_int()))
  } else {
    None
  }
}

///|
/// Get a mapping field by key
pub fn get_field(node : @yaml.YamlNode, key : String) -> @yaml.YamlNode? {
  match node {
    @yaml.YMapping(pairs, _, _) => {
      for pair in pairs {
        match pair.key {
          @yaml.YString(k, _, _) if k == key => return Some(pair.value)
          _ => continue
        }
      }
      None
    }
    _ => None
  }
}

///|
/// Check if mapping contains a key
pub fn has_field(node : @yaml.YamlNode, key : String) -> Bool {
  get_field(node, key) is Some(_)
}

///|
/// Get array elements from a sequence
pub fn get_array(node : @yaml.YamlNode) -> Array[@yaml.YamlNode]? {
  match node {
    @yaml.YSequence(elements, _, _) => Some(elements)
    _ => None
  }
}

///|
/// Get mapping pairs
pub fn get_mapping_pairs(node : @yaml.YamlNode) -> Array[@yaml.YKeyValue]? {
  match node {
    @yaml.YMapping(pairs, _, _) => Some(pairs)
    _ => None
  }
}

///|
/// Convert string or array of strings to Array[String]
pub fn get_string_or_array(node : @yaml.YamlNode) -> Array[String] {
  match node {
    @yaml.YString(s, _, _) => [s]
    @yaml.YSequence(elements, _, _) => {
      let result = elements.filter_map(fn(e) { get_string(e) })
      result
    }
    _ => []
  }
}

///|
/// Get string or array as Option
pub fn get_optional_string_or_array(node : @yaml.YamlNode) -> Array[String]? {
  match node {
    @yaml.YNull(_) => None
    @yaml.YString(s, _, _) => Some([s])
    @yaml.YSequence(elements, _, _) => {
      let result = elements.filter_map(fn(e) { get_string(e) })
      if result.is_empty() { None } else { Some(result) }
    }
    _ => None
  }
}

///|
/// Convert YamlNode mapping to Map[String, String]
pub fn get_string_map(node : @yaml.YamlNode) -> Map[String, String] {
  match node {
    @yaml.YMapping(pairs, _, _) => {
      let mut result : Map[String, String] = {}
      let mut i = 0
      while i < pairs.length() {
        let pair = pairs[i]
        match pair.key {
          @yaml.YString(k, _, _) => {
            match get_string(pair.value) {
              Some(v) => result[k] = v
              None => ()
            }
          }
          _ => ()
        }
        i = i + 1
      }
      result
    }
    _ => {}
  }
}

///|
/// Get the type name of a YAML value
pub fn get_value_type(value : @yaml.YamlNode) -> String {
  match value {
    @yaml.YNull(_) => "null"
    @yaml.YBool(_, _) => "boolean"
    @yaml.YNumber(_, _) => "number"
    @yaml.YString(_, _, _) => "string"
    @yaml.YSequence(_, _, _) => "array"
    @yaml.YMapping(_, _, _) => "object"
    @yaml.YAlias(_, _) => "alias"
    @yaml.YAnchor(_, _) => "anchor"
  }
}

///|
/// Check if node is null
pub fn is_null(node : @yaml.YamlNode) -> Bool {
  match node {
    @yaml.YNull(_) => true
    _ => false
  }
}

///|
/// Check if node is a mapping
pub fn is_mapping(node : @yaml.YamlNode) -> Bool {
  match node {
    @yaml.YMapping(_, _, _) => true
    _ => false
  }
}

///|
/// Check if node is a sequence
pub fn is_sequence(node : @yaml.YamlNode) -> Bool {
  match node {
    @yaml.YSequence(_, _, _) => true
    _ => false
  }
}
