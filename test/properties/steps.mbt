///|
/// Property-based tests for step validation

///|
/// Property: Local action references should pass format validation
test "validate_action_local_ref_passes" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_local_ref(), fn(ref : String) {
    let result = @models.ValidationResult::new()
    let validated = @validators.validate_action_reference(ref, "test", result)
    let issues = validated.get_issues()
    issues.length() == 0 || issues.iter().all(fn(i) { not(i.message.contains("must contain '/'")) })
  }))
}

///|
/// Property: ActionInfo parsing is consistent with validation logic
test "action_info_consistency_with_validation" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_any_action_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    let has_docker_prefix = ref.has_prefix("docker://")
    let has_local_prefix = ref.has_prefix("./")
    info.is_docker == has_docker_prefix && info.is_local == has_local_prefix
  }))
}

///|
/// Property: Valid action references have proper format
test "valid_action_ref_format" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_action_ref(), fn(ref : String) {
    @validators.is_valid_action_format(ref) == true
  }))
}
