///|
/// Parse matrix strategy from YAML node
pub fn parse_matrix(strategy_node : @yaml.YamlNode) -> Result[@matrix.MatrixStrategy, String] {
  match strategy_node {
    @yaml.YMapping(pairs, _, _) => {
      let mut dimensions : Map[String, @matrix.MatrixDimension] = {}
      let mut include_list : Array[@matrix.MatrixOverride] = []
      let mut exclude_list : Array[@matrix.MatrixOverride] = []
      let mut fail_fast : Bool? = None
      let mut max_parallel : Int? = None

      let mut i = 0
      while i < pairs.length() {
        let pair = pairs[i]
        match pair.key {
          @yaml.YString(key, _, _) => {
            match key {
              "matrix" => {
              match parse_matrix_body(pair.value) {
                Ok((dims, inc, exc)) => {
                  dimensions = dims
                  include_list = inc
                  exclude_list = exc
                }
                Err(e) => return Err("Invalid matrix: " + e)
              }
            }
            "fail-fast" => {
              match get_bool(pair.value) {
                Some(b) => fail_fast = Some(b)
                None => return Err("'fail-fast' must be a boolean")
              }
            }
            "max-parallel" => {
              match get_int_from_node(pair.value) {
                Some(n) => max_parallel = Some(n)
                None => return Err("'max-parallel' must be an integer")
              }
            }
            _ => ()  // Ignore unknown keys
          }
          }
          _ => return Err("Strategy keys must be strings")
        }
        i = i + 1
      }

      Ok(@matrix.MatrixStrategy::from_parts(dimensions, include_list, exclude_list, fail_fast, max_parallel))
    }
    _ => Err("Strategy must be a mapping")
  }
}

///|
/// Parse matrix body (dimensions, include, exclude)
fn parse_matrix_body(node : @yaml.YamlNode) -> Result[(Map[String, @matrix.MatrixDimension], Array[@matrix.MatrixOverride], Array[@matrix.MatrixOverride]), String] {
  match node {
    @yaml.YMapping(pairs, _, _) => {
      let mut dimensions : Map[String, @matrix.MatrixDimension] = {}
      let mut include_list : Array[@matrix.MatrixOverride] = []
      let mut exclude_list : Array[@matrix.MatrixOverride] = []

      let mut i = 0
      while i < pairs.length() {
        let pair = pairs[i]
        match pair.key {
          @yaml.YString(key, _, _) => {
            match key {
              "include" => {
              match parse_matrix_overrides(pair.value) {
                Ok(overrides) => include_list = overrides
                Err(e) => return Err("Invalid 'include': " + e)
              }
            }
            "exclude" => {
              match parse_matrix_overrides(pair.value) {
                Ok(overrides) => exclude_list = overrides
                Err(e) => return Err("Invalid 'exclude': " + e)
              }
            }
            _ => {
              // Regular dimension
              match parse_matrix_dimension(pair.value) {
                Ok(dim) => dimensions[key] = dim
                Err(e) => return Err("Invalid dimension '" + key + "': " + e)
              }
            }
          }
          }
          _ => return Err("Matrix keys must be strings")
        }
        i = i + 1
      }

      Ok((dimensions, include_list, exclude_list))
    }
    _ => Err("Matrix body must be a mapping")
  }
}

///|
/// Parse a single matrix dimension
fn parse_matrix_dimension(node : @yaml.YamlNode) -> Result[@matrix.MatrixDimension, String] {
  match node {
    @yaml.YSequence(items, _, _) => {
      // Try to parse as numbers first
      let mut numbers : Array[Int] = []
      let mut strings : Array[String] = []
      let mut all_numbers = true

      let mut i = 0
      while i < items.length() {
        match items[i] {
          @yaml.YNumber(num_str, _) => {
            match parse_int(num_str) {
              Some(n) => numbers.push(n)
              None => {
                strings.push(num_str)
                all_numbers = false
              }
            }
          }
          @yaml.YString(s, _, _) => {
            strings.push(s)
            all_numbers = false
          }
          _ => {
            strings.push(get_string_from_node(items[i]))
            all_numbers = false
          }
        }
        i = i + 1
      }

      if all_numbers && numbers.length() > 0 {
        Ok(@matrix.MatrixDimension::number_dim(numbers))
      } else if strings.length() > 0 {
        Ok(@matrix.MatrixDimension::array_dim(strings))
      } else {
        Err("Dimension array cannot be empty")
      }
    }
    @yaml.YNumber(num_str, _) => {
      // Single number, treat as one-element array
      match parse_int(num_str) {
        Some(n) => Ok(@matrix.MatrixDimension::number_dim([n]))
        None => Err("Invalid number format")
      }
    }
    @yaml.YString(s, _, _) => {
      // Single string, treat as one-element array
      Ok(@matrix.MatrixDimension::array_dim([s]))
    }
    _ => Err("Dimension must be an array or scalar value")
  }
}

///|
/// Parse matrix overrides (for include/exclude)
fn parse_matrix_overrides(node : @yaml.YamlNode) -> Result[Array[@matrix.MatrixOverride], String] {
  match node {
    @yaml.YSequence(items, _, _) => {
      let mut result : Array[@matrix.MatrixOverride] = []

      let mut i = 0
      while i < items.length() {
        match parse_single_override(items[i]) {
          Ok(ov) => result.push(ov)
          Err(e) => return Err(e)
        }
        i = i + 1
      }

      Ok(result)
    }
    @yaml.YMapping(_, _, _) => {
      // Single override
      match parse_single_override(node) {
        Ok(ov) => Ok([ov])
        Err(e) => Err(e)
      }
    }
    _ => Err("Overrides must be an array or mapping")
  }
}

///|
/// Parse a single matrix override
fn parse_single_override(node : @yaml.YamlNode) -> Result[@matrix.MatrixOverride, String] {
  match node {
    @yaml.YMapping(pairs, _, _) => {
      let mut values : Map[String, String] = {}

      let mut i = 0
      while i < pairs.length() {
        let pair = pairs[i]
        match pair.key {
          @yaml.YString(key, _, _) => {
            let value_str = get_string_from_node(pair.value)
            values[key] = value_str
          }
          _ => return Err("Override keys must be strings")
        }
        i = i + 1
      }

      Ok(@matrix.MatrixOverride::from_values(values))
    }
    _ => Err("Override must be a mapping")
  }
}

///|
/// Expand matrix strategy into all combinations
pub fn expand_matrix(strategy : @matrix.MatrixStrategy) -> Result[@matrix.MatrixExpansion, String] {
  // Get all dimension names
  let dim_names = get_dimension_names(strategy.dimensions)

  // Generate base combinations from dimensions
  let base_combos = generate_combinations(strategy.dimensions, dim_names)

  // Apply excludes
  let mut after_excludes = base_combos
  let mut i = 0
  while i < strategy.exclude.length() {
    let excl = strategy.exclude[i]
    after_excludes = after_excludes.filter(fn(combo) { not_matches_override(combo, excl) })
    i = i + 1
  }

  // Apply includes
  let mut result = after_excludes
  let mut next_index = after_excludes.length()
  i = 0
  while i < strategy.include.length() {
    let inc = strategy.include[i]
    let mut new_combo = @matrix.MatrixCombination::from_values({}, next_index)
    let mut j = 0
    while j < dim_names.length() {
      let name = dim_names[j]
      match inc.values.get(name) {
        Some(value) => {
          let mut new_values = new_combo.values
          new_values[name] = value
          new_combo = @matrix.MatrixCombination::from_values(new_values, new_combo.index)
        }
        None => ()
      }
      j = j + 1
    }
    result.push(new_combo)
    next_index = next_index + 1
    i = i + 1
  }

  // Check total count
  if result.length() > @matrix.MAX_MATRIX_COMBINATIONS {
    return Err("Matrix has " + int_to_string(result.length()) + " combinations, exceeds maximum of " + int_to_string(@matrix.MAX_MATRIX_COMBINATIONS))
  }

  Ok(@matrix.MatrixExpansion::from_combinations(result, result.length()))
}

///|
/// Generate all combinations from dimensions
fn generate_combinations(dimensions : Map[String, @matrix.MatrixDimension], dim_names : Array[String]) -> Array[@matrix.MatrixCombination] {
  if dim_names.length() == 0 {
    return []
  }

  // Get values for each dimension
  let dim_values : Array[Array[String]] = []
  let mut i = 0
  while i < dim_names.length() {
    let name = dim_names[i]
    match dimensions.get(name) {
      Some(dim) => {
        dim_values.push(dimension_to_strings(dim))
      }
      None => {
        dim_values.push([])
      }
    }
    i = i + 1
  }

  // Generate Cartesian product
  cartesian_product(dim_values, dim_names)
}

///|
/// Convert dimension to string array
fn dimension_to_strings(dim : @matrix.MatrixDimension) -> Array[String] {
  match dim {
    @matrix.MatrixDimension::ArrayDim(arr) => arr
    @matrix.MatrixDimension::OneDim(arr) => arr
    @matrix.MatrixDimension::NumberDim(arr) => {
      let mut result : Array[String] = []
      let mut i = 0
      while i < arr.length() {
        result.push(int_to_string(arr[i]))
        i = i + 1
      }
      result
    }
  }
}

///|
/// Generate Cartesian product of arrays
fn cartesian_product(arrays : Array[Array[String]], names : Array[String]) -> Array[@matrix.MatrixCombination] {
  if arrays.length() == 0 {
    return []
  }

  // Start with first array
  let mut result : Array[@matrix.MatrixCombination] = []
  let first = arrays[0]
  let mut i = 0
  while i < first.length() {
    let mut values : Map[String, String] = {}
    values[names[0]] = first[i]
    result.push(@matrix.MatrixCombination::from_values(values, i))
    i = i + 1
  }

  // Multiply with remaining arrays
  let mut arr_idx = 1
  while arr_idx < arrays.length() {
    let mut new_result : Array[@matrix.MatrixCombination] = []
    let arr = arrays[arr_idx]
    let mut combo_idx = 0

    let mut i = 0
    while i < result.length() {
      let base_combo = result[i]
      let mut j = 0
      while j < arr.length() {
        let mut new_values : Map[String, String] = {}
        // Copy all values from base combo
        let mut k = 0
        while k < arr_idx {
          match base_combo.values.get(names[k]) {
            Some(value) => new_values[names[k]] = value
            None => ()
          }
          k = k + 1
        }
        new_values[names[arr_idx]] = arr[j]
        new_result.push(@matrix.MatrixCombination::from_values(new_values, combo_idx))
        combo_idx = combo_idx + 1
        j = j + 1
      }
      i = i + 1
    }

    result = new_result
    arr_idx = arr_idx + 1
  }

  result
}

///|
/// Check if combination matches an exclude override
fn not_matches_override(combo : @matrix.MatrixCombination, excl_override : @matrix.MatrixOverride) -> Bool {
  let override_keys = get_map_keys(excl_override.values)

  // If override has no keys, it doesn't match anything
  if override_keys.length() == 0 {
    return true
  }

  // Check if all override values match the combination
  let mut i = 0
  while i < override_keys.length() {
    let key = override_keys[i]
    match excl_override.values.get(key) {
      Some(override_value) => {
        match combo.values.get(key) {
          Some(combo_value) => {
            if override_value != combo_value {
              return true  // Mismatch, not a match
            }
          }
          None => return true  // Key not in combo, not a match
        }
      }
      None => ()
    }
    i = i + 1
  }

  // All override values matched
  false
}

///|
/// Get dimension names as array
fn get_dimension_names(dimensions : Map[String, @matrix.MatrixDimension]) -> Array[String] {
  dimensions.keys().to_array()
}

///|
/// Get map keys as array
fn get_map_keys(values : Map[String, String]) -> Array[String] {
  values.keys().to_array()
}

///|
/// Validate matrix strategy
pub fn validate_matrix(strategy : @matrix.MatrixStrategy) -> @models.ValidationResult {
  let mut result = @models.ValidationResult::new()

  // Check if there are any dimensions
  if strategy.dimensions.length() == 0 {
    result = result.add_warning("Matrix has no dimensions", Some("matrix"))
  }

  // Check each dimension
  let dim_keys = strategy.dimensions.keys().to_array()
  let mut i = 0
  while i < dim_keys.length() {
    let name = dim_keys[i]
    match strategy.dimensions.get(name) {
      Some(dim) => {
        match dim {
          @matrix.MatrixDimension::ArrayDim(arr) => {
            if arr.length() == 0 {
              result = result.add_error("Dimension '" + name + "' is empty", Some("matrix." + name))
            } else if arr.length() > 256 {
              result = result.add_warning("Dimension '" + name + "' has " + int_to_string(arr.length()) + " values, may cause issues", Some("matrix." + name))
            }
          }
          @matrix.MatrixDimension::NumberDim(arr) => {
            if arr.length() == 0 {
              result = result.add_error("Dimension '" + name + "' is empty", Some("matrix." + name))
            }
          }
          @matrix.MatrixDimension::OneDim(arr) => {
            if arr.length() == 0 {
              result = result.add_error("Dimension '" + name + "' is empty", Some("matrix." + name))
            }
          }
        }
      }
      None => ()
    }
    i = i + 1
  }

  // Validate max-parallel
  match strategy.max_parallel {
    Some(n) => {
      if n < 1 {
        result = result.add_warning("'max-parallel' must be at least 1", Some("strategy.max-parallel"))
      }
    }
    None => ()
  }

  result
}

///|
/// Int to string conversion
fn int_to_string(n : Int) -> String {
  if n < 0 {
    return "-" + int_to_string(0 - n)
  }
  if n == 0 {
    return "0"
  }

  let mut chars : Array[String] = []
  let mut num = n

  while num > 0 {
    let digit = num % 10
    // Convert digit 0-9 to character '0'-'9'
    let char_code = '0'.to_int() + digit
    chars.push(uint_to_string(char_code))
    num = num / 10
  }

  let mut result = ""
  let mut i = chars.length() - 1
  while i >= 0 {
    result = result + chars[i]
    i = i - 1
  }

  result
}

///|
/// Convert uint to single character string
fn uint_to_string(n : Int) -> String {
  let mut result = ""
  // Build string from single character
  result = result + unsafe_uint_to_char(n)
  result
}

///|
/// Unsafe conversion from uint to char
fn unsafe_uint_to_char(n : Int) -> String {
  if n >= 0 && n <= 127 {
    // ASCII range
    let mut result = ""
    // Use character literal directly
    match n {
      48 => "0"
      49 => "1"
      50 => "2"
      51 => "3"
      52 => "4"
      53 => "5"
      54 => "6"
      55 => "7"
      56 => "8"
      57 => "9"
      _ => ""
    }
  } else {
    ""
  }
}

///|
/// Parse int from string
fn parse_int(s : String) -> Int? {
  let mut result = 0
  let mut i = 0
  let mut is_negative = false

  if s.length() > 0 && s[0] == '-' {
    is_negative = true
    i = i + 1
  }

  while i < s.length() {
    let c = s[i]
    if c >= '0' && c <= '9' {
      result = result * 10 + (c.to_int() - '0'.to_int())
    } else {
      return None
    }
    i = i + 1
  }

  Some(if is_negative { 0 - result } else { result })
}

///|
/// Get string from node or convert to string
fn get_string_from_node(node : @yaml.YamlNode) -> String {
  match node {
    @yaml.YString(s, _, _) => s
    @yaml.YNumber(s, _) => s
    @yaml.YBool(b, _) => if b { "true" } else { "false" }
    @yaml.YNull => "null"
    _ => ""
  }
}

///|
/// Get bool from node
fn get_bool(node : @yaml.YamlNode) -> Bool? {
  match node {
    @yaml.YBool(b, _) => Some(b)
    @yaml.YString(s, _, _) => {
      if s == "true" || s == "True" || s == "TRUE" {
        Some(true)
      } else if s == "false" || s == "False" || s == "FALSE" {
        Some(false)
      } else {
        None
      }
    }
    _ => None
  }
}

///|
/// Get int from node
fn get_int_from_node(node : @yaml.YamlNode) -> Int? {
  match node {
    @yaml.YNumber(s, _) => parse_int(s)
    @yaml.YString(s, _, _) => parse_int(s)
    _ => None
  }
}
