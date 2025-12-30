///|
/// Generators for Step-related data

///|
/// Generate an optional step ID
pub fn gen_step_id() -> @qc.Gen[String?] {
  @qc.one_of([@qc.Gen::spawn().fmap(fn(s) { Some(s) }), @qc.pure(None)])
}

///|
/// Generate an optional step name
pub fn gen_step_name() -> @qc.Gen[String?] {
  @qc.one_of([@qc.Gen::spawn().fmap(fn(s) { Some(s) }), @qc.pure(None)])
}

///|
/// Generate an optional shell command
pub fn gen_run_command() -> @qc.Gen[String?] {
  @qc.one_of([@qc.Gen::spawn().fmap(fn(s) { Some(s) }), @qc.pure(None)])
}

///|
/// Generate an optional uses action reference
pub fn gen_step_uses() -> @qc.Gen[String?] {
  @qc.one_of([gen_action_ref().fmap(fn(s) { Some(s) }), @qc.pure(None)])
}

///|
/// Generate a valid step (with either uses or run, not both)
pub fn gen_valid_step() -> @qc.Gen[@models.Step] {
  @qc.one_of([
    // Step with uses only
    gen_step_id().bind(fn(id) {
      gen_step_name().bind(fn(name) {
        gen_action_ref().fmap(fn(uses) {
          @models.Step::new_full(id, name, Some(uses), None, {}, {}, None, false, None, None, None)
        })
      })
    }),
    // Step with run only
    gen_step_id().bind(fn(id) {
      gen_step_name().bind(fn(name) {
        @qc.Gen::spawn().fmap(fn(run) {
          @models.Step::new_full(id, name, None, Some(run), {}, {}, None, false, None, None, None)
        })
      })
    })
  ])
}

///|
/// Generate an invalid step with both uses and run
pub fn gen_invalid_step_both() -> @qc.Gen[@models.Step] {
  gen_step_id().bind(fn(id) {
    gen_step_name().bind(fn(name) {
      gen_action_ref().bind(fn(uses) {
        @qc.Gen::spawn().fmap(fn(run) {
          @models.Step::new_full(id, name, Some(uses), Some(run), {}, {}, None, false, None, None, None)
        })
      })
    })
  })
}

///|
/// Generate a step with no content (no uses or run)
pub fn gen_invalid_step_no_content() -> @qc.Gen[@models.Step] {
  gen_step_id().bind(fn(id) {
    gen_step_name().fmap(fn(name) {
      @models.Step::new_full(id, name, None, None, {}, {}, None, false, None, None, None)
    })
  })
}

///|
/// Generate any type of step (valid or invalid)
pub fn gen_any_step() -> @qc.Gen[@models.Step] {
  @qc.frequency([(5, gen_valid_step()), (1, gen_invalid_step_both()), (1, gen_invalid_step_no_content())])
}
