///|
/// Severity level for validation issues
pub enum IssueSeverity {
  Error
  Warning
} derive(Eq, Show)

///|
/// A single validation issue
pub struct ValidationIssue {
  severity : IssueSeverity
  message : String
  location : String?
} derive(Eq, Show)

///|
/// Create an error issue
pub fn ValidationIssue::error(message : String, location? : String) -> ValidationIssue {
  { severity: Error, message, location }
}

///|
/// Create a warning issue
pub fn ValidationIssue::warning(message : String, location? : String) -> ValidationIssue {
  { severity: Warning, message, location }
}

///|
/// Validation result accumulator
pub struct ValidationResult {
  issues : Array[ValidationIssue]
} derive(Show)

///|
/// Create a new empty validation result
pub fn ValidationResult::new() -> ValidationResult {
  { issues: [] }
}

///|
/// Check if validation passed (no errors)
pub fn ValidationResult::is_valid(self : ValidationResult) -> Bool {
  self.issues.iter().all(fn(issue) { issue.severity != Error })
}

///|
/// Get all issues
pub fn ValidationResult::get_issues(self : ValidationResult) -> Array[ValidationIssue] {
  self.issues
}

///|
/// Get number of issues
pub fn ValidationResult::issue_count(self : ValidationResult) -> Int {
  self.issues.length()
}

///|
/// Add an error to the result
pub fn ValidationResult::add_error(self : ValidationResult, message : String, location : String?) -> ValidationResult {
  match location {
    Some(loc) => { issues: self.issues + [ValidationIssue::{ severity: IssueSeverity::Error, message, location: Some(loc) }] }
    None => { issues: self.issues + [ValidationIssue::{ severity: IssueSeverity::Error, message, location: None }] }
  }
}

///|
/// Add a warning to the result
pub fn ValidationResult::add_warning(self : ValidationResult, message : String, location : String?) -> ValidationResult {
  match location {
    Some(loc) => { issues: self.issues + [ValidationIssue::{ severity: IssueSeverity::Warning, message, location: Some(loc) }] }
    None => { issues: self.issues + [ValidationIssue::{ severity: IssueSeverity::Warning, message, location: None }] }
  }
}

///|
/// Merge another validation result into this one
pub fn ValidationResult::merge(self : ValidationResult, other : ValidationResult) -> ValidationResult {
  { issues: self.issues + other.issues }
}
