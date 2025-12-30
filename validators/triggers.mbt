///|
/// Valid GitHub Actions trigger events
pub let valid_events : Array[String] = [
  "branch_protection_rule", "check_run", "check_suite", "create", "delete",
  "deployment", "deployment_status", "discussion", "discussion_comment",
  "fork", "gollum", "issue_comment", "issues", "label", "merge_group",
  "milestone", "page_build", "public", "pull_request", "pull_request_review",
  "pull_request_review_comment", "pull_request_target", "push",
  "registry_package", "release", "repository_dispatch", "schedule",
  "status", "watch", "workflow_call", "workflow_dispatch", "workflow_run",
]

///|
/// Check if an event name is valid
pub fn is_valid_event(event : String) -> Bool {
  valid_events.contains(event)
}

///|
/// Validate the 'on' section
pub fn validate_triggers(on_node : @yaml.YamlNode, result : @models.ValidationResult) -> @models.ValidationResult {
  match on_node {
    @yaml.YString(event, _, _) => {
      validate_event_name(event, result)
    }
    @yaml.YSequence(events, _, _) => {
      let mut result = result
      let mut i = 0
      while i < events.length() {
        let event = events[i]
        match @parser.get_string(event) {
          Some(e) => result = validate_event_name(e, result)
          None => { result = result.add_error("Event in 'on' array must be a string", None) }
        }
        i = i + 1
      }
      result
    }
    @yaml.YMapping(pairs, _, _) => {
      let mut result = result
      let mut i = 0
      while i < pairs.length() {
        let pair = pairs[i]
        match pair.key {
          @yaml.YString(event, _, _) => {
            result = validate_event_name(event, result)
            // Validate schedule cron expressions
            if event == "schedule" {
              result = validate_schedule_config(pair.value, result)
            }
          }
          _ => { result = result.add_error("Event name in 'on' mapping must be a string", None) }
        }
        i = i + 1
      }
      result
    }
    _ => result.add_error("'on' section has invalid format", None)
  }
}

///|
/// Validate a single event name
fn validate_event_name(event : String, result : @models.ValidationResult) -> @models.ValidationResult {
  if is_valid_event(event) == false {
    result.add_error("Invalid event name: '" + event + "'", None)
  } else {
    result
  }
}

///|
/// Validate schedule configuration
fn validate_schedule_config(node : @yaml.YamlNode, result : @models.ValidationResult) -> @models.ValidationResult {
  match node {
    @yaml.YSequence(items, _, _) => {
      let mut result = result
      let mut i = 0
      while i < items.length() {
        let item = items[i]
        match @parser.get_field(item, "cron") {
          Some(cron_node) => {
            match @parser.get_string(cron_node) {
              Some(cron) => result = validate_cron_syntax(cron, result)
              None => { result = result.add_error("schedule 'cron' must be a string", None) }
            }
          }
          None => { result = result.add_error("schedule entry must have 'cron' field", None) }
        }
        i = i + 1
      }
      result
    }
    _ => result.add_error("schedule must be an array", None)
  }
}

///|
/// Validate cron expression syntax (5 components)
pub fn validate_cron_syntax(cron : String, result : @models.ValidationResult) -> @models.ValidationResult {
  // Split by spaces and count parts
  let mut space_count = 0
  let mut i = 0
  while i < cron.length() {
    if cron[i] == ' ' {
      space_count = space_count + 1
    }
    i = i + 1
  }
  let part_count = space_count + 1

  if part_count != 5 {
    result.add_error(
      "cron expression must have 5 components, got " + Int::to_string(part_count),
      None
    )
  } else {
    result
  }
}

///|
/// Validate triggers against a workflow definition
pub fn validate_workflow_triggers(workflow : @models.WorkflowDefinition) -> @models.ValidationResult {
  let mut result = @models.ValidationResult::new()
  let mut i = 0
  while i < workflow.on.length() {
    let event = workflow.on[i]
    result = validate_event_name(event, result)
    i = i + 1
  }
  result
}
