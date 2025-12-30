///|
/// Matrix strategy for GitHub Actions
pub struct MatrixStrategy {
  dimensions : Map[String, MatrixDimension]
  include_list : Array[MatrixOverride]
  exclude : Array[MatrixOverride]
  fail_fast : Bool?
  max_parallel : Int?
} derive(Show)

///|
/// A single matrix dimension (e.g., os: [ubuntu-20.04, ubuntu-22.04])
pub enum MatrixDimension {
  ArrayDim(Array[String])
  OneDim(Array[String])  // [1, 2, 3] is shorthand for array
  NumberDim(Array[Int])
} derive(Show)

///|
/// Matrix override for include/exclude
pub struct MatrixOverride {
  values : Map[String, String]
} derive(Show)

///|
/// Expanded matrix combination
pub struct MatrixCombination {
  values : Map[String, String]
  index : Int
} derive(Show)

///|
/// Result of matrix expansion
pub struct MatrixExpansion {
  combinations : Array[MatrixCombination]
  total_count : Int
} derive(Show)

///|
/// Create a new empty matrix strategy
pub fn MatrixStrategy::new() -> MatrixStrategy {
  {
    dimensions: {},
    include_list: [],
    exclude: [],
    fail_fast: None,
    max_parallel: None
  }
}

///|
/// Create a new matrix override
pub fn MatrixOverride::new() -> MatrixOverride {
  { values: {} }
}

///|
/// Create a new matrix combination
pub fn MatrixCombination::new(index : Int) -> MatrixCombination {
  { values: {}, index }
}

///|
/// Create a new matrix expansion
pub fn MatrixExpansion::new(combinations : Array[MatrixCombination]) -> MatrixExpansion {
  {
    combinations,
    total_count: combinations.length()
  }
}

///|
/// Maximum allowed matrix combinations (GitHub Actions limit)
pub const MAX_MATRIX_COMBINATIONS : Int = 256

///|
/// Create ArrayDim constructor
pub fn MatrixDimension::array_dim(arr : Array[String]) -> MatrixDimension {
  ArrayDim(arr)
}

///|
/// Create NumberDim constructor
pub fn MatrixDimension::number_dim(arr : Array[Int]) -> MatrixDimension {
  NumberDim(arr)
}

///|
/// Create OneDim constructor
pub fn MatrixDimension::one_dim(arr : Array[String]) -> MatrixDimension {
  OneDim(arr)
}

///|
/// Create MatrixStrategy from parts
pub fn MatrixStrategy::from_parts(
  dimensions : Map[String, MatrixDimension],
  include_list : Array[MatrixOverride],
  exclude : Array[MatrixOverride],
  fail_fast : Bool?,
  max_parallel : Int?
) -> MatrixStrategy {
  { dimensions, include_list, exclude, fail_fast, max_parallel }
}

///|
/// Create MatrixOverride from values
pub fn MatrixOverride::from_values(values : Map[String, String]) -> MatrixOverride {
  { values, }
}

///|
/// Create MatrixCombination from values and index
pub fn MatrixCombination::from_values(values : Map[String, String], index : Int) -> MatrixCombination {
  { values, index }
}

///|
/// Create MatrixExpansion from combinations
pub fn MatrixExpansion::from_combinations(combinations : Array[MatrixCombination], total : Int) -> MatrixExpansion {
  { combinations, total_count: total }
}

///|
/// Add a dimension to the override
pub fn MatrixOverride::add(self : MatrixOverride, key : String, value : String) -> MatrixOverride {
  let mut new_values = self.values
  new_values[key] = value
  { values: new_values }
}

///|
/// Add a dimension to the combination
pub fn MatrixCombination::add(self : MatrixCombination, key : String, value : String) -> MatrixCombination {
  let mut new_values = self.values
  new_values[key] = value
  { values: new_values, index: self.index }
}

///|
/// Get a value from combination
pub fn MatrixCombination::get(self : MatrixCombination, key : String) -> String? {
  self.values.get(key)
}

///|
/// Convert combination to map
pub fn MatrixCombination::to_map(self : MatrixCombination) -> Map[String, String] {
  self.values
}
