///|
/// GitHub Actions workflow definition
pub struct WorkflowDefinition {
  name : String
  on : Array[String]              // Normalized trigger events
  on_raw : @yaml.YamlNode         // Keep raw for detailed validation
  jobs : Map[String, Job]
  env : Map[String, String]
} derive(Show)

///|
/// Create a new workflow definition
pub fn WorkflowDefinition::new(name : String, on : Array[String], jobs : Map[String, Job]) -> WorkflowDefinition {
  {
    name,
    on,
    on_raw: @yaml.YamlNode::null(),
    jobs,
    env: {},
  }
}

///|
/// Create a workflow definition with all fields
pub fn WorkflowDefinition::new_full(
  name : String,
  on : Array[String],
  on_raw : @yaml.YamlNode,
  jobs : Map[String, Job],
  env : Map[String, String]
) -> WorkflowDefinition {
  { name, on, on_raw, jobs, env }
}

///|
/// A job in a workflow
pub struct Job {
  runs_on : Array[String]?        // None for reusable workflows
  needs : Array[String]
  steps : Array[Step]
  env : Map[String, String]
  if_condition : String?
  outputs : Map[String, String]
  uses : String?                  // Reusable workflow reference
  with_inputs : Map[String, String]
} derive(Show)

///|
/// Create a new job
pub fn Job::new() -> Job {
  {
    runs_on: None,
    needs: [],
    steps: [],
    env: {},
    if_condition: None,
    outputs: {},
    uses: None,
    with_inputs: {},
  }
}

///|
/// Create a job with all fields
pub fn Job::new_full(
  runs_on : Array[String]?,
  needs : Array[String],
  steps : Array[Step],
  env : Map[String, String],
  if_condition : String?,
  outputs : Map[String, String],
  uses : String?,
  with_inputs : Map[String, String]
) -> Job {
  { runs_on, needs, steps, env, if_condition, outputs, uses, with_inputs }
}

///|
/// Check if this is a reusable workflow call
pub fn Job::is_reusable_workflow(self : Job) -> Bool {
  self.uses is Some(_)
}

///|
/// A step in a job
pub struct Step {
  id : String?
  name : String?
  uses : String?                  // Action reference
  run : String?                   // Shell command
  with_inputs : Map[String, String]
  env : Map[String, String]
  if_condition : String?
  continue_on_error : Bool
  working_directory : String?
  shell : String?
  timeout_minutes : Int?
} derive(Show)

///|
/// Create a new step
pub fn Step::new() -> Step {
  {
    id: None,
    name: None,
    uses: None,
    run: None,
    with_inputs: {},
    env: {},
    if_condition: None,
    continue_on_error: false,
    working_directory: None,
    shell: None,
    timeout_minutes: None,
  }
}

///|
/// Create a step with all fields
pub fn Step::new_full(
  id : String?,
  name : String?,
  uses : String?,
  run : String?,
  with_inputs : Map[String, String],
  env : Map[String, String],
  if_condition : String?,
  continue_on_error : Bool,
  working_directory : String?,
  shell : String?,
  timeout_minutes : Int?
) -> Step {
  { id, name, uses, run, with_inputs, env, if_condition, continue_on_error, working_directory, shell, timeout_minutes }
}

///|
/// Check if step has an action reference
pub fn Step::has_action(self : Step) -> Bool {
  self.uses is Some(_)
}

///|
/// Check if step has a shell command
pub fn Step::has_run(self : Step) -> Bool {
  self.run is Some(_)
}

///|
/// Information about a resolved action reference
pub struct ActionInfo {
  repository : String
  is_docker : Bool
  is_local : Bool
  version : String?
} derive(Show)

///|
/// Parse action reference into ActionInfo
pub fn ActionInfo::from_reference(action_ref : String) -> ActionInfo {
  let is_docker = action_ref.has_prefix("docker://")
  let is_local = action_ref.has_prefix("./")

  if action_ref.contains("@") {
    let parts = action_ref.split("@")
    let parts_array = parts.to_array()
    let repo = parts_array[0].to_string()
    let version = if parts_array.length() > 1 { Some(parts_array[1].to_string()) } else { None }
    { repository: repo, is_docker, is_local, version }
  } else {
    { repository: action_ref, is_docker, is_local, version: None }
  }
}
