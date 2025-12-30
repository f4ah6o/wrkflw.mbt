///|
/// Generators for action references and ActionInfo testing

///|
/// Generate a valid GitHub owner string
pub fn gen_owner() -> @qc.Gen[String] {
  @qc.one_of([
    @qc.pure("owner"), @qc.pure("testorg"), @qc.pure("myorg"),
    @qc.pure("example"), @qc.pure("demo"), @qc.pure("company")
  ])
}

///|
/// Generate a valid GitHub repository name string
pub fn gen_repo_name() -> @qc.Gen[String] {
  @qc.one_of([
    @qc.pure("repo"), @qc.pure("my-repo"), @qc.pure("test-repo"),
    @qc.pure("demo-repo"), @qc.pure("action"), @qc.pure("workflow")
  ])
}

///|
/// Generate a valid version string (v1, v2.0, main, SHA, etc.)
pub fn gen_version() -> @qc.Gen[String] {
  @qc.one_of([@qc.pure("v1"), @qc.pure("v2"), @qc.pure("v3"), @qc.pure("v4"),
    @qc.pure("v1.0"), @qc.pure("v2.0"), @qc.pure("v3.1"),
    @qc.pure("v1.2.3"), @qc.pure("v2.5.1"), @qc.pure("v4.2.0"),
    @qc.pure("main"), @qc.pure("master"), @qc.pure("develop")])
}

///|
/// Generate a standard GitHub Actions action reference (owner/repo@version)
pub fn gen_action_ref() -> @qc.Gen[String] {
  @qc.Gen::bind(gen_owner(), fn(owner) {
    @qc.Gen::bind(gen_repo_name(), fn(repo) {
      gen_version().fmap(fn(version) {
        owner + "/" + repo + "@" + version
      })
    })
  })
}

///|
/// Generate a Docker action reference (docker://image)
pub fn gen_docker_ref() -> @qc.Gen[String] {
  @qc.one_of([
    @qc.pure("docker://alpine"), @qc.pure("docker://ubuntu"),
    @qc.pure("docker://node"), @qc.pure("docker://python")
  ])
}

///|
/// Generate a local action reference (./path/to/action)
pub fn gen_local_ref() -> @qc.Gen[String] {
  @qc.one_of([
    @qc.pure("./actions/my-action"), @qc.pure("./local/action"),
    @qc.pure("./scripts/run"), @qc.pure("./.github/actions/deploy")
  ])
}

///|
/// Generate an action reference without version (owner/repo)
pub fn gen_action_ref_no_version() -> @qc.Gen[String] {
  @qc.Gen::bind(gen_owner(), fn(owner) {
    @qc.Gen::fmap(gen_repo_name(), fn(repo) { owner + "/" + repo })
  })
}

///|
/// Generate an invalid action reference (malformed)
pub fn gen_invalid_action_ref() -> @qc.Gen[String] {
  @qc.one_of([
    gen_repo_name(),  // Just repo name, no owner
    @qc.Gen::fmap(gen_repo_name(), fn(s) { s + "@" }),
    @qc.Gen::fmap(gen_repo_name(), fn(s) { "@" + s })
  ])
}

///|
/// Generate any type of action reference (valid, docker, local, invalid)
pub fn gen_any_action_ref() -> @qc.Gen[String] {
  @qc.frequency([(5, gen_action_ref()), (1, gen_docker_ref()),
    (1, gen_local_ref()), (2, gen_action_ref_no_version()), (1, gen_invalid_action_ref())])
}
