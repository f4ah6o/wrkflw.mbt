///|
/// Property-based tests for ActionInfo

///|
/// Property: Docker actions always have is_docker = true
test "action_info_docker_prefix_detection" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_docker_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.is_docker == true && info.is_local == false
  }))
}

///|
/// Property: Local actions always have is_local = true
test "action_info_local_prefix_detection" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_local_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.is_local == true && info.is_docker == false
  }))
}

///|
/// Property: Standard refs have is_docker = false and is_local = false
test "action_info_standard_ref_not_docker_or_local" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_action_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.is_docker == false && info.is_local == false
  }))
}

///|
/// Property: Version extraction works correctly (@ present = Some version)
test "action_info_version_extraction" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_action_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.version is Some(_)
  }))
}

///|
/// Property: Refs without @ have no version
test "action_info_no_version_without_at" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_action_ref_no_version(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.version == None
  }))
}

///|
/// Property: Standard action refs contain / in repository
test "action_info_standard_ref_has_slash" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_action_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.repository.contains("/")
  }))
}

///|
/// Property: Docker refs preserve the full reference in repository
test "action_info_docker_repository_preserved" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_docker_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.repository == ref
  }))
}

///|
/// Property: Local refs preserve the full reference in repository
test "action_info_local_repository_preserved" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_local_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    info.repository == ref
  }))
}

///|
/// Property: Version is Some when ref contains @
test "action_info_at_sign_implies_version" {
  @qc.quick_check(@qc.forall(@test_arbitraries.gen_any_action_ref(), fn(ref : String) {
    let info = @models.ActionInfo::from_reference(ref)
    let has_at = ref.contains("@")
    let has_version = info.version is Some(_)
    has_at == has_version
  }))
}
