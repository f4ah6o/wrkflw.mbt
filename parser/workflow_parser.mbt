///|
/// Parse workflow from YAML content
pub fn parse_workflow(content : String) -> Result[@models.WorkflowDefinition, String] {
  match @yaml.Parser::from_source(content).parse() {
    Ok(root) => parse_workflow_from_node(root)
    Err(e) => Err("Failed to parse YAML: " + e.message)
  }
}

///|
/// Check if node is a mapping (wrapper to avoid naming conflict)
fn is_mapping_node(node : @yaml.YamlNode) -> Bool {
  match node {
    @yaml.YMapping(_, _, _) => true
    _ => false
  }
}

///|
/// Parse workflow from parsed YamlNode
fn parse_workflow_from_node(root : @yaml.YamlNode) -> Result[@models.WorkflowDefinition, String] {
  if is_mapping_node(root) == false {
    return Err("Workflow root must be a mapping")
  }

  let name = match get_field(root, "name") {
    Some(node) => match get_string(node) {
      Some(s) => s
      None => return Err("'name' must be a string")
    }
    None => return Err("Missing required field 'name'")
  }

  let on_raw = match get_field(root, "on") {
    Some(node) => node
    None => return Err("Missing required field 'on'")
  }

  let on = match normalize_triggers(on_raw) {
    Ok(events) => events
    Err(e) => return Err(e)
  }

  let jobs_node = match get_field(root, "jobs") {
    Some(node) => node
    None => return Err("Missing required field 'jobs'")
  }

  let jobs = match get_mapping_pairs(jobs_node) {
    Some(pairs) => parse_jobs_map(pairs)
    None => return Err("'jobs' must be a mapping")
  }

  let env = match get_field(root, "env") {
    Some(node) => get_string_map(node)
    None => {}
  }

  Ok(@models.WorkflowDefinition::new_full(name, on, on_raw, jobs, env))
}

///|
/// Parse all jobs from mapping pairs
fn parse_jobs_map(pairs : Array[@yaml.YKeyValue]) -> Map[String, @models.Job] {
  let mut jobs_map : Map[String, @models.Job] = {}
  let mut i = 0
  while i < pairs.length() {
    let pair = pairs[i]
    match pair.key {
      @yaml.YString(job_name, _, _) => {
        match parse_job(job_name, pair.value) {
          Ok(job) => jobs_map[job_name] = job
          Err(_) => ()
        }
      }
      _ => ()
    }
    i = i + 1
  }
  jobs_map
}

///|
/// Parse a single job from YamlNode
fn parse_job(name : String, node : @yaml.YamlNode) -> Result[@models.Job, String] {
  if is_mapping_node(node) == false {
    return Err("Job must be a mapping")
  }

  // Check if this is a reusable workflow (has 'uses')
  let uses_opt = match get_field(node, "uses") {
    Some(uses_node) => match get_string(uses_node) {
      Some(s) => Some(s)
      None => return Err("Job 'uses' must be a string")
    }
    None => None
  }

  let runs_on_opt = match uses_opt {
    Some(_) => None  // Reusable workflow, skip runs-on
    None => match get_field(node, "runs-on") {
      Some(ron_node) => Some(get_string_or_array(ron_node))
      None => return Err("Job '" + name + "' must have 'runs-on' field")
    }
  }

  let needs = match get_field(node, "needs") {
    Some(needs_node) => get_string_or_array(needs_node)
    None => []
  }

  let steps = match uses_opt {
    Some(_) => []  // Reusable workflow
    None => match get_field(node, "steps") {
      Some(steps_node) => {
        match get_array(steps_node) {
          Some(step_nodes) => parse_steps_array(step_nodes)
          None => return Err("'steps' must be an array")
        }
      }
      None => return Err("Job '" + name + "' must have 'steps' field")
    }
  }

  let env = match get_field(node, "env") {
    Some(env_node) => get_string_map(env_node)
    None => {}
  }

  let if_condition = match get_field(node, "if") {
    Some(if_node) => get_string(if_node)
    None => None
  }

  let outputs = match get_field(node, "outputs") {
    Some(out_node) => get_string_map(out_node)
    None => {}
  }

  let with_inputs = match get_field(node, "with") {
    Some(with_node) => get_string_map(with_node)
    None => {}
  }

  Ok(@models.Job::new_full(runs_on_opt, needs, steps, env, if_condition, outputs, uses_opt, with_inputs))
}

///|
/// Parse steps from an array of nodes
fn parse_steps_array(step_nodes : Array[@yaml.YamlNode]) -> Array[@models.Step] {
  let mut result : Array[@models.Step] = []
  let mut i = 0
  while i < step_nodes.length() {
    let step_node = step_nodes[i]
    match parse_step(step_node) {
      Ok(step) => result.push(step)
      Err(_) => ()
    }
    i = i + 1
  }
  result
}

///|
/// Parse a single step from YamlNode
fn parse_step(node : @yaml.YamlNode) -> Result[@models.Step, String] {
  if is_mapping_node(node) == false {
    return Err("Step must be a mapping")
  }

  let id = match get_field(node, "id") {
    Some(id_node) => get_string(id_node)
    None => None
  }

  let name = match get_field(node, "name") {
    Some(name_node) => get_string(name_node)
    None => None
  }

  let uses = match get_field(node, "uses") {
    Some(uses_node) => get_string(uses_node)
    None => None
  }

  let run = match get_field(node, "run") {
    Some(run_node) => get_string(run_node)
    None => None
  }

  let with_inputs = match get_field(node, "with") {
    Some(with_node) => get_string_map(with_node)
    None => {}
  }

  let env = match get_field(node, "env") {
    Some(env_node) => get_string_map(env_node)
    None => {}
  }

  let if_condition = match get_field(node, "if") {
    Some(if_node) => get_string(if_node)
    None => None
  }

  let continue_on_error = match get_field(node, "continue-on-error") {
    Some(coe_node) => match get_bool(coe_node) {
      Some(b) => b
      None => false
    }
    None => false
  }

  let working_directory = match get_field(node, "working-directory") {
    Some(wd_node) => get_string(wd_node)
    None => None
  }

  let shell = match get_field(node, "shell") {
    Some(shell_node) => get_string(shell_node)
    None => None
  }

  let timeout_minutes = match get_field(node, "timeout-minutes") {
    Some(tm_node) => get_int(tm_node)
    None => None
  }

  Ok(@models.Step::new_full(id, name, uses, run, with_inputs, env, if_condition, continue_on_error, working_directory, shell, timeout_minutes))
}

///|
/// Normalize trigger events from various formats to Array[String]
pub fn normalize_triggers(on_node : @yaml.YamlNode) -> Result[Array[String], String] {
  match on_node {
    @yaml.YString(event, _, _) => Ok([event])
    @yaml.YSequence(events, _, _) => {
      let result = events.filter_map(fn(e) { get_string(e) })
      if result.length() < events.length() {
        Err("Event in 'on' array must be a string")
      } else {
        Ok(result)
      }
    }
    @yaml.YMapping(pairs, _, _) => {
      let result = pairs.filter_map(fn(pair) {
        match pair.key {
          @yaml.YString(event, _, _) => Some(event)
          _ => None
        }
      })
      if result.length() < pairs.length() {
        Err("Event name in 'on' mapping must be a string")
      } else {
        Ok(result)
      }
    }
    _ => Err("'on' section has invalid format")
  }
}
