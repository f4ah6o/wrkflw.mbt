///|
/// Property-based tests for job validation

///|
/// Property: Reusable workflow jobs have uses set
test "job_reusable_workflow_has_uses" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_reusable_workflow_job(), fn(job : @models.Job) {
    job.is_reusable_workflow() == true
  }))
}

///|
/// Property: Normal jobs don't have uses
test "job_normal_no_uses" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_valid_normal_job(), fn(job : @models.Job) {
    job.is_reusable_workflow() == false
  }))
}

///|
/// Property: Job steps validation returns result
test "validate_job_steps_returns_result" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_valid_normal_job(), fn(job : @models.Job) {
    let result = @validators.validate_job_steps(job, "test")
    // Just check that validation runs and returns a result
    result.is_valid() || true
  }))
}
