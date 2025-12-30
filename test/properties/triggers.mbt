///|
/// Property-based tests for trigger validation

///|
/// Property: Valid events are recognized as valid
test "is_valid_event_valid_events" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_valid_event(), fn(event : String) {
    @validators.is_valid_event(event) == true
  }))
}

///|
/// Property: Invalid events are not recognized as valid
test "is_valid_event_invalid_events" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_invalid_event(), fn(event : String) {
    @validators.is_valid_event(event) == false
  }))
}

///|
/// Property: Valid cron expressions (5 space-separated parts) pass validation
test "validate_cron_syntax_valid" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_cron_expression(), fn(cron : String) {
    let result = @models.ValidationResult::new()
    let validated = @validators.validate_cron_syntax(cron, result)
    validated.is_valid() == true
  }))
}

///|
/// Property: Invalid cron expressions fail validation
test "validate_cron_syntax_invalid" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_invalid_cron(), fn(cron : String) {
    let result = @models.ValidationResult::new()
    let validated = @validators.validate_cron_syntax(cron, result)
    validated.is_valid() == false
  }))
}
