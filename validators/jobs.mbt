///|
/// Validate the jobs section
pub fn validate_jobs(jobs_node : @yaml.YamlNode, result : @models.ValidationResult) -> @models.ValidationResult {
  match @parser.get_mapping_pairs(jobs_node) {
    Some(pairs) => {
      if pairs.is_empty() {
        result.add_error("'jobs' section is empty", None)
      } else {
        // Collect job names for dependency validation
        let mut job_names : Array[String] = []
        let mut i = 0
        while i < pairs.length() {
          let pair = pairs[i]
          match pair.key {
            @yaml.YString(name, _, _) => job_names.push(name)
            _ => { return result.add_error("Job name must be a string", None) }
          }
          i = i + 1
        }
        // Validate each job
        let mut result = result
        let mut i = 0
        while i < pairs.length() {
          let pair = pairs[i]
          match pair.key {
            @yaml.YString(job_name, _, _) => {
              result = validate_job(job_name, pair.value, job_names, result)
            }
            _ => ()
          }
          i = i + 1
        }
        result
      }
    }
    None => result.add_error("'jobs' must be a mapping", None)
  }
}

///|
/// Validate a single job
fn validate_job(job_name : String, node : @yaml.YamlNode, all_job_names : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "'"

  match node {
    @yaml.YMapping(_, _, _) => ()
    _ => return result.add_error("Job '" + job_name + "' must be a mapping", Some(location))
  }

  // Check if this is a reusable workflow (has 'uses')
  let is_reusable = match @parser.get_field(node, "uses") {
    Some(uses_node) => match @parser.get_string(uses_node) {
      Some(_) => true
      None => {
        let result = result.add_error("Job 'uses' must be a string", Some(location))
        return validate_needs_fields(node, job_name, all_job_names, result)
      }
    }
    None => false
  }

  if is_reusable {
    validate_reusable_workflow_job(job_name, node, result)
  } else {
    validate_normal_job(job_name, node, all_job_names, result)
  }
}

///|
/// Validate remaining needs/dependency fields
fn validate_needs_fields(node : @yaml.YamlNode, job_name : String, all_job_names : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  match @parser.get_field(node, "needs") {
    Some(needs_node) => validate_needs(needs_node, job_name, all_job_names, result)
    None => result
  }
}

///|
/// Validate a normal job (not a reusable workflow)
fn validate_normal_job(job_name : String, node : @yaml.YamlNode, all_job_names : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "'"

  // Must have runs-on
  match @parser.get_field(node, "runs-on") {
    None => { return result.add_error("Job '" + job_name + "' must have 'runs-on' field", Some(location)) }
    _ => ()
  }

  let mut result = result

  // Validate needs (dependencies)
  match @parser.get_field(node, "needs") {
    Some(needs_node) => result = validate_needs(needs_node, job_name, all_job_names, result)
    None => ()
  }

  // Must have steps
  match @parser.get_field(node, "steps") {
    Some(steps_node) => {
      match @parser.get_array(steps_node) {
        Some(steps) => {
          if steps.is_empty() {
            result = result.add_error("Job '" + job_name + "' has empty 'steps' array", Some(location))
          }
        }
        None => { result = result.add_error("'steps' must be an array", Some(location)) }
      }
    }
    None => { result = result.add_error("Job '" + job_name + "' must have 'steps' field", Some(location)) }
  }

  result
}

///|
/// Validate a reusable workflow job
fn validate_reusable_workflow_job(job_name : String, node : @yaml.YamlNode, result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "'"
  let mut result = result

  // Validate uses format
  match @parser.get_field(node, "uses") {
    Some(uses_node) => {
      match @parser.get_string(uses_node) {
        Some(uses) => {
          if string_contains(uses, "/") == false {
            result = result.add_error("Reusable workflow reference must contain '/'", Some(location))
          }
        }
        None => ()
      }
    }
    None => ()
  }

  // Reusable workflows should not have runs-on or steps
  match @parser.get_field(node, "runs-on") {
    Some(_) => result = result.add_warning("Reusable workflow should not have 'runs-on'", Some(location))
    None => ()
  }

  match @parser.get_field(node, "steps") {
    Some(_) => result = result.add_warning("Reusable workflow should not have 'steps'", Some(location))
    None => ()
  }

  result
}

///|
/// Validate job dependencies (needs)
fn validate_needs(needs_node : @yaml.YamlNode, job_name : String, all_job_names : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "'"
  let mut result = result

  let deps = match needs_node {
    @yaml.YString(dep, _, _) => [dep]
    @yaml.YSequence(deps_list, _, _) => {
      let mut deps_result : Array[String] = []
      let mut i = 0
      while i < deps_list.length() {
        let dep = deps_list[i]
        match @parser.get_string(dep) {
          Some(d) => deps_result.push(d)
          None => { result = result.add_error("'needs' dependency must be a string", Some(location)) }
        }
        i = i + 1
      }
      deps_result
    }
    _ => {
      return result.add_error("'needs' must be a string or array", Some(location))
    }
  }

  // Check that all dependencies exist
  let mut i = 0
  while i < deps.length() {
    let dep = deps[i]
    if all_job_names.contains(dep) == false {
      result = result.add_error("Job '" + job_name + "' depends on non-existent job '" + dep + "'", Some(location))
    }
    if dep == job_name {
      result = result.add_error("Job '" + job_name + "' cannot depend on itself", Some(location))
    }
    i = i + 1
  }

  result
}

///|
/// Validate jobs from parsed workflow definition
pub fn validate_workflow_jobs(workflow : @models.WorkflowDefinition) -> @models.ValidationResult {
  let mut result = @models.ValidationResult::new()

  if workflow.jobs.is_empty() {
    return result.add_error("'jobs' section is empty", None)
  }

  let job_names = workflow.jobs.keys().to_array()

  let mut i = 0
  while i < job_names.length() {
    let job_name = job_names[i]
    match workflow.jobs.get(job_name) {
      Some(job) => result = validate_parsed_job(job_name, job, job_names, result)
      None => ()
    }
    i = i + 1
  }

  result
}

///|
/// Validate a parsed job
fn validate_parsed_job(job_name : String, job : @models.Job, all_job_names : Array[String], result : @models.ValidationResult) -> @models.ValidationResult {
  let location = "job '" + job_name + "'"
  let mut result = result

  if job.is_reusable_workflow() {
    // Reusable workflow validation
    match job.uses {
      Some(uses) => {
        if string_contains(uses, "/") == false {
          result = result.add_error("Reusable workflow reference must contain '/'", Some(location))
        }
      }
      None => ()
    }
    match job.runs_on {
      Some(_) => result = result.add_warning("Reusable workflow should not have 'runs-on'", Some(location))
      None => ()
    }
    if job.steps.is_empty() == false {
      result = result.add_warning("Reusable workflow should not have 'steps'", Some(location))
    }
  } else {
    // Normal job validation
    match job.runs_on {
      None => result = result.add_error("Job '" + job_name + "' must have 'runs-on' field", Some(location))
      Some(_) => ()
    }
    if job.steps.is_empty() {
      result = result.add_error("Job '" + job_name + "' must have 'steps' field", Some(location))
    }
  }

  // Validate needs
  let mut i = 0
  while i < job.needs.length() {
    let dep = job.needs[i]
    if all_job_names.contains(dep) == false {
      result = result.add_error("Job '" + job_name + "' depends on non-existent job '" + dep + "'", Some(location))
    }
    if dep == job_name {
      result = result.add_error("Job '" + job_name + "' cannot depend on itself", Some(location))
    }
    i = i + 1
  }

  result
}
