///|
/// Generators for Job-related data

///|
/// Generate an optional runs-on array
pub fn gen_runs_on() -> @qc.Gen[Array[String]?] {
  @qc.one_of([@qc.Gen::spawn().fmap(fn(arr) { Some(arr) }), @qc.pure(None)])
}

///|
/// Generate a needs array (job dependencies)
pub fn gen_needs() -> @qc.Gen[Array[String]] {
  @qc.Gen::spawn()
}

///|
/// Generate a valid normal job (without steps - those are added separately)
pub fn gen_valid_normal_job() -> @qc.Gen[@models.Job] {
  gen_runs_on().bind(fn(runs_on_opt) {
    gen_needs().fmap(fn(needs) {
      let runs_on = match runs_on_opt {
        Some(arr) => arr
        None => ["ubuntu-latest"]
      }
      @models.Job::new_full(Some(runs_on), needs, [], {}, None, {}, None, {})
    })
  })
}

///|
/// Generate a reusable workflow job
pub fn gen_reusable_workflow_job() -> @qc.Gen[@models.Job] {
  gen_needs().bind(fn(needs) {
    gen_action_ref().fmap(fn(uses) {
      @models.Job::new_full(None, needs, [], {}, None, {}, Some(uses), {})
    })
  })
}

///|
/// Generate any type of job
pub fn gen_any_job() -> @qc.Gen[@models.Job] {
  @qc.one_of([gen_valid_normal_job(), gen_reusable_workflow_job()])
}
