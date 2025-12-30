///|
/// Validate an action reference with detailed error messages
pub fn validate_action_reference_detailed(action_ref : String, job_name : String, step_idx : Int, result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "', step " + Int::to_string(step_idx)
  validate_action_reference(action_ref, location, result)
}

///|
/// Check if action reference format is valid (without adding to result)
pub fn is_valid_action_format(action_ref : String) -> Bool {
  let info = @models.ActionInfo::from_reference(action_ref)

  if info.is_local {
    return true
  }

  if info.is_docker {
    return action_ref.length() > 8
  }

  // Must contain /
  string_contains(action_ref, "/")
}

///|
/// Get well-known action reference with version
pub fn suggest_action_version(action_ref : String) -> String? {
  let info = @models.ActionInfo::from_reference(action_ref)

  match info.version {
    Some(_) => None
    None => {
      // Suggest v4 for common actions
      match info.repository {
        "actions/checkout" => Some(info.repository + "@v4")
        "actions/setup-node" => Some(info.repository + "@v4")
        "actions/setup-python" => Some(info.repository + "@v5")
        "actions/setup-go" => Some(info.repository + "@v5")
        "actions/upload-artifact" => Some(info.repository + "@v4")
        "actions/download-artifact" => Some(info.repository + "@v4")
        _ => Some(info.repository + "@v4")
      }
    }
  }
}
