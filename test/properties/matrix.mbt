///|
/// Unit tests for matrix validation and expansion

///|
/// Test: Simple 2x2 matrix expansion
test "matrix_simple_2x2_expansion" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    os: [ubuntu-20.04, ubuntu-22.04]\n    node: [14, 16]\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match @validators.expand_matrix(strategy) {
                  Ok(expansion) => {
                    // 2 x 2 = 4 combinations
                    expansion.total_count == 4
                  }
                  Err(_) => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: Matrix validation - empty dimension
test "matrix_validation_empty_dimension" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let strategy = @matrix.MatrixStrategy::from_parts(
      { "os": @matrix.MatrixDimension::array_dim([]) },
      [],
      [],
      None,
      None
    )

    let result = @validators.validate_matrix(strategy)
    // Should have error for empty dimension (not valid)
    !result.is_valid()
  }))
}

///|
/// Test: Matrix validation - no dimensions
test "matrix_validation_no_dimensions" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let strategy = @matrix.MatrixStrategy::from_parts(
      {},
      [],
      [],
      None,
      None
    )

    let result = @validators.validate_matrix(strategy)
    // Should have warning for no dimensions but still be valid (no errors)
    result.is_valid()
  }))
}

///|
/// Test: Matrix combination values
test "matrix_combination_values" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let mut values : Map[String, String] = {}
    values["os"] = "ubuntu-20.04"
    values["node"] = "14"

    let combo = @matrix.MatrixCombination::from_values(values, 0)

    let os_ok = match combo.get("os") {
      Some(value) => value == "ubuntu-20.04"
      None => false
    }

    let node_ok = match combo.get("node") {
      Some(value) => value == "14"
      None => false
    }

    os_ok && node_ok
  }))
}

///|
/// Test: Single dimension matrix
test "matrix_single_dimension" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    version: [1, 2, 3]\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match @validators.expand_matrix(strategy) {
                  Ok(expansion) => {
                    expansion.total_count == 3
                  }
                  Err(_) => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: Number dimension parsing
test "matrix_number_dimension" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    version: [1, 2, 3]\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match strategy.dimensions.get("version") {
                  Some(@matrix.MatrixDimension::NumberDim(arr)) => {
                    arr.length() == 3
                  }
                  _ => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: Matrix override creation
test "matrix_override_creation" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let mut values : Map[String, String] = {}
    values["os"] = "ubuntu-22.04"
    values["node"] = "16"

    let override = @matrix.MatrixOverride::from_values(values)

    match override.values.get("os") {
      Some(v) => v == "ubuntu-22.04"
      None => false
    }
  }))
}

///|
/// Test: Matrix expansion from parts
test "matrix_expansion_from_parts" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let mut combos : Array[@matrix.MatrixCombination] = []

    let mut values1 : Map[String, String] = {}
    values1["os"] = "ubuntu-20.04"
    values1["node"] = "14"
    combos.push(@matrix.MatrixCombination::from_values(values1, 0))

    let mut values2 : Map[String, String] = {}
    values2["os"] = "ubuntu-20.04"
    values2["node"] = "16"
    combos.push(@matrix.MatrixCombination::from_values(values2, 1))

    let expansion = @matrix.MatrixExpansion::from_combinations(combos, 2)

    expansion.total_count == 2 && expansion.combinations.length() == 2
  }))
}

///|
/// Test: Empty matrix combination
test "matrix_empty_combination" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let combo = @matrix.MatrixCombination::from_values({}, 0)

    match combo.get("anything") {
      Some(_) => false
      None => true
    }
  }))
}

///|
/// Test: Matrix with include
test "matrix_with_include" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    os: [ubuntu-20.04]\n    node: [14]\n    include:\n      - os: ubuntu-22.04\n        node: 16\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match @validators.expand_matrix(strategy) {
                  Ok(expansion) => {
                    // 1 base + 1 include = 2
                    expansion.total_count == 2
                  }
                  Err(_) => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: Matrix with exclude
test "matrix_with_exclude" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    os: [ubuntu-20.04, ubuntu-22.04]\n    node: [14, 16]\n    exclude:\n      - os: ubuntu-20.04\n        node: 14\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match @validators.expand_matrix(strategy) {
                  Ok(expansion) => {
                    // 4 - 1 excluded = 3
                    expansion.total_count == 3
                  }
                  Err(_) => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: String dimension parsing
test "matrix_string_dimension" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    os: [ubuntu-20.04, ubuntu-22.04]\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match strategy.dimensions.get("os") {
                  Some(@matrix.MatrixDimension::ArrayDim(arr)) => {
                    arr.length() == 2
                  }
                  _ => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}

///|
/// Test: Matrix expansion product correctness
test "matrix_expansion_product_correctness" {
  @qc.quick_check(@qc.forall(@qc.pure(()), fn(_ : Unit) {
    let yaml = "strategy:\n  matrix:\n    os: [a, b]\n    version: [1, 2, 3]\n"

    let root = @yaml.Parser::from_source(yaml).parse()
    match root {
      Ok(node) => {
        match node {
          @yaml.YMapping(pairs, _, _) => {
            let strategy_node = pairs[0].value
            match @validators.parse_matrix(strategy_node) {
              Ok(strategy) => {
                match @validators.expand_matrix(strategy) {
                  Ok(expansion) => {
                    // 2 x 3 = 6 combinations
                    expansion.total_count == 6 && expansion.combinations.length() == 6
                  }
                  Err(_) => false
                }
              }
              Err(_) => false
            }
          }
          _ => false
        }
      }
      Err(_) => false
    }
  }))
}
