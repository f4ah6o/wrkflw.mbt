///|
/// Validate a GitHub Actions workflow from YAML content
pub fn validate_workflow_content(content : String) -> Result[@models.ValidationResult, String] {
  match @yaml.Parser::from_source(content).parse() {
    Ok(root) => validate_workflow_node(root)
    Err(e) => Err("Failed to parse YAML: " + e.message)
  }
}

///|
/// Validate a parsed workflow YamlNode
fn validate_workflow_node(root : @yaml.YamlNode) -> Result[@models.ValidationResult, String] {
  let mut result = @models.ValidationResult::new()

  // Check root is a mapping
  match root {
    @yaml.YMapping(_, _, _) => ()
    _ => { return Ok(result.add_error("Workflow root must be a mapping", None)) }
  }

  // Check required fields
  match @parser.get_field(root, "name") {
    None => { result = result.add_error("Missing required field 'name'", None) }
    _ => ()
  }

  match @parser.get_field(root, "on") {
    None => { result = result.add_error("Missing required field 'on'", None) }
    Some(on_node) => {
      result = @validators.validate_triggers(on_node, result)
    }
  }

  match @parser.get_field(root, "jobs") {
    None => { result = result.add_error("Missing required field 'jobs'", None) }
    Some(jobs_node) => {
      result = @validators.validate_jobs(jobs_node, result)
    }
  }

  Ok(result)
}

///|
/// Validate a parsed workflow definition
pub fn validate_workflow(workflow : @models.WorkflowDefinition) -> @models.ValidationResult {
  let mut result = @models.ValidationResult::new()

  // Validate triggers
  let trigger_result = @validators.validate_workflow_triggers(workflow)
  result = result.merge(trigger_result)

  // Validate jobs
  let jobs_result = @validators.validate_workflow_jobs(workflow)
  result = result.merge(jobs_result)

  // Validate steps for each job
  let job_names = workflow.jobs.keys().to_array()
  let mut i = 0
  while i < job_names.length() {
    let job_name = job_names[i]
    match workflow.jobs.get(job_name) {
      Some(job) => {
        let steps_result = @validators.validate_job_steps(job, job_name)
        result = result.merge(steps_result)
      }
      None => ()
    }
    i = i + 1
  }

  result
}

///|
/// Parse workflow from YAML content
pub fn parse_workflow(content : String) -> Result[@models.WorkflowDefinition, String] {
  @parser.parse_workflow(content)
}

///|
/// Validate and parse workflow from YAML content
pub fn validate_and_parse(content : String) -> Result[@models.WorkflowDefinition, @models.ValidationResult] {
  let workflow = match @parser.parse_workflow(content) {
    Ok(w) => w
    Err(e) => {
      let result = @models.ValidationResult::new()
      return Err(result.add_error(e, None))
    }
  }

  let validation = validate_workflow(workflow)
  if validation.is_valid() {
    Ok(workflow)
  } else {
    Err(validation)
  }
}
