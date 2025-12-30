///|
/// Validate steps in a job
pub fn validate_steps(steps_node : @yaml.YamlNode, job_name : String, result : @models.ValidationResult) -> @models.ValidationResult {
  match @parser.get_array(steps_node) {
    Some(steps) => {
      if steps.is_empty() {
        let loc = "job '" + job_name + "'"
        result.add_error("Job '" + job_name + "' has empty 'steps' array", Some(loc))
      } else {
        let mut seen_ids : Array[String] = []
        let mut result = result
        let mut i = 0
        while i < steps.length() {
          let step = steps[i]
          let location = "job '" + job_name + "', step " + Int::to_string(i)
          result = validate_step(step, location, seen_ids, result)
          i = i + 1
        }
        result
      }
    }
    None => {
      let loc = "job '" + job_name + "'"
      result.add_error("'steps' must be an array", Some(loc))
    }
  }
}

///|
/// Validate a single step
fn validate_step(step_node : @yaml.YamlNode, location : String, seen_ids : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  match step_node {
    @yaml.YMapping(_, _, _) => ()
    _ => return result.add_error("Step must be a mapping", Some(location))
  }

  let mut result = result
  let mut seen_ids = seen_ids

  // Check for at least one of: name, uses, run
  let has_name = match @parser.get_field(step_node, "name") {
    Some(n) => not(@parser.is_null(n))
    None => false
  }
  let has_uses = match @parser.get_field(step_node, "uses") {
    Some(u) => not(@parser.is_null(u))
    None => false
  }
  let has_run = match @parser.get_field(step_node, "run") {
    Some(r) => not(@parser.is_null(r))
    None => false
  }

  if has_name == false && has_uses == false && has_run == false {
    result = result.add_error("Step must have at least one of 'name', 'uses', or 'run'", Some(location))
  }

  // Cannot have both uses and run
  if has_uses == true && has_run == true {
    result = result.add_error("Step cannot have both 'uses' and 'run'", Some(location))
  }

  // Validate step ID uniqueness
  match @parser.get_field(step_node, "id") {
    Some(id_node) => {
      match @parser.get_string(id_node) {
        Some(id) => {
          if seen_ids.contains(id) {
            result = result.add_error("Duplicate step ID: '" + id + "'", Some(location))
          } else {
            seen_ids.push(id)
          }
        }
        None => { result = result.add_error("Step 'id' must be a string", Some(location)) }
      }
    }
    None => ()
  }

  // Validate action reference if present
  match @parser.get_field(step_node, "uses") {
    Some(uses_node) => {
      match @parser.get_string(uses_node) {
        Some(uses) => result = validate_action_reference(uses, location, result)
        None => ()
      }
    }
    None => ()
  }

  result
}

///|
/// Validate an action reference
pub fn validate_action_reference(action_ref : String, location : String, result : @models.ValidationResult) -> @models.ValidationResult {
  let info = @models.ActionInfo::from_reference(action_ref)

  if info.is_local {
    // Local actions can have any path
    result
  } else if info.is_docker {
    // Docker actions start with docker://
    if action_ref.length() <= 8 {
      result.add_error("Docker action reference is too short", Some(location))
    } else {
      result
    }
  } else {
    // Non-local, non-docker actions must contain /
    if string_contains(action_ref, "/") == false {
      result.add_error("Action reference must contain '/' (format: owner/repo@version)", Some(location))
    } else if info.version is None {
      // Check for version tag
      result.add_warning("Action '" + action_ref + "' is missing version tag (e.g., @v4)", Some(location))
    } else {
      result
    }
  }
}

///|
/// Validate steps from parsed job
pub fn validate_job_steps(job : @models.Job, job_name : String) -> @models.ValidationResult {
  let mut result = @models.ValidationResult::new()
  let mut seen_ids : Array[String] = []

  if job.steps.is_empty() {
    let loc = "job '" + job_name + "'"
    return result.add_error("Job '" + job_name + "' has empty 'steps'", Some(loc))
  }

  let mut i = 0
  while i < job.steps.length() {
    let step = job.steps[i]
    let location = "job '" + job_name + "', step " + Int::to_string(i)
    result = validate_parsed_step(step, location, seen_ids, result)
    i = i + 1
  }

  result
}

///|
/// Validate a parsed step
fn validate_parsed_step(step : @models.Step, location : String, seen_ids : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  let mut result = result
  let mut seen_ids = seen_ids

  // Check for at least one of: name, uses, run
  let has_content = step.name is Some(_) || step.uses is Some(_) || step.run is Some(_)
  if has_content == false {
    result = result.add_error("Step must have at least one of 'name', 'uses', or 'run'", Some(location))
  }

  // Cannot have both uses and run
  if step.uses is Some(_) && step.run is Some(_) {
    result = result.add_error("Step cannot have both 'uses' and 'run'", Some(location))
  }

  // Validate step ID uniqueness
  match step.id {
    Some(id) => {
      if seen_ids.contains(id) {
        result = result.add_error("Duplicate step ID: '" + id + "'", Some(location))
      } else {
        seen_ids.push(id)
      }
    }
    None => ()
  }

  // Validate action reference if present
  match step.uses {
    Some(uses) => result = validate_action_reference(uses, location, result)
    None => ()
  }

  result
}
