///|
/// Generators for workflow-related data (events, cron, etc.)

///|
/// All valid GitHub Actions webhook event names
pub fn valid_events() -> Array[String] {
  [
    "push", "pull_request", "workflow_dispatch", "workflow_call",
    "schedule", "release", "create", "delete", "fork", "watch",
    "check_run", "check_suite", "deployment", "deployment_status",
    "issue_comment", "issues", "label", "milestone", "page_build",
    "public", "pull_request_review", "pull_request_review_comment",
    "pull_request_target", "registry_package", "repository_dispatch",
    "status", "workflow_run", "merge_group", "discussion", "discussion_comment",
    "branch_protection_rule", "gollum"
  ]
}

///|
/// Generate a valid GitHub Actions event name
pub fn gen_valid_event() -> @qc.Gen[String] {
  let events = valid_events()
  @qc.int_bound(events.length()).fmap(fn(i) { events[i] })
}

///|
/// Generate an invalid event name
pub fn gen_invalid_event() -> @qc.Gen[String] {
  @qc.Gen::spawn().fmap(fn(_i : Int) { "invalid_" + _i.to_string() })
}

///|
/// Generate a valid cron expression (5 space-separated parts)
pub fn gen_cron_expression() -> @qc.Gen[String] {
  @qc.Gen::spawn().bind(fn(_m : Int) {
    @qc.Gen::spawn().bind(fn(_h : Int) {
      @qc.Gen::spawn().bind(fn(_d : Int) {
        @qc.Gen::spawn().bind(fn(_mn : Int) {
          @qc.Gen::spawn().fmap(fn(_dw : Int) {
            let minute = (_m % 60).to_string()
            let hour = (_h % 24).to_string()
            let day = (_d % 31 + 1).to_string()
            let month = (_mn % 12 + 1).to_string()
            let dow = (_dw % 7).to_string()
            minute + " " + hour + " " + day + " " + month + " " + dow
          })
        })
      })
    })
  })
}

///|
/// Generate an invalid cron expression (wrong number of components)
pub fn gen_invalid_cron() -> @qc.Gen[String] {
  @qc.one_of([
    // 4 components
    @qc.Gen::spawn().bind(fn(_a : Int) {
      @qc.Gen::spawn().bind(fn(_b : Int) {
        @qc.Gen::spawn().bind(fn(_c : Int) {
          @qc.Gen::spawn().fmap(fn(_d : Int) {
            (_a % 60).to_string() + " " + (_b % 24).to_string() + " " + (_c % 31 + 1).to_string() + " " + (_d % 12 + 1).to_string()
          })
        })
      })
    }),
    // 6 components
    @qc.Gen::spawn().bind(fn(_a : Int) {
      @qc.Gen::spawn().bind(fn(_b : Int) {
        @qc.Gen::spawn().bind(fn(_c : Int) {
          @qc.Gen::spawn().bind(fn(_d : Int) {
            @qc.Gen::spawn().bind(fn(_e : Int) {
              @qc.Gen::spawn().fmap(fn(_f : Int) {
                (_a % 60).to_string() + " " + (_b % 24).to_string() + " " + (_c % 31 + 1).to_string() + " " + (_d % 12 + 1).to_string() + " " + (_e % 7).to_string() + " " + (_f % 60).to_string()
              })
            })
          })
        })
      })
    })
  ])
}

///|
/// Generate a workflow name
pub fn gen_workflow_name() -> @qc.Gen[String] {
  @qc.Gen::spawn()
}

///|
/// Generate a job name
pub fn gen_job_name() -> @qc.Gen[String] {
  @qc.Gen::spawn()
}
