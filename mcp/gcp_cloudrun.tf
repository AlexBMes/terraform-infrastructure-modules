
//noinspection HILUnresolvedReference
data "google_project" "default" {
  project_id = lookup(local.cloudrun, "project_id", "")
}

data "google_container_registry_image" "default"{
  name = lookup(local.cloudrun_specs, "image_name", "")
  project = data.google_project.default.project_id
}

//noinspection HILUnresolvedReference
resource "google_cloud_run_service" "self" {
  count = local.cloudrun == {} ? 0 : 1
  location = local.cloudrun.location_id
  name     = local.cloudrun_specs.name
  project  = data.google_project.default.project_id
  template {
    spec{
      //noinspection HILUnresolvedReference
      containers {
        image = data.google_container_registry_image.default.image_url
        //noinspection HILUnresolvedReference
        dynamic "env"{
          for_each = lookup(local.cloudrun_specs, "environment_vars", {})
          content {
            name  = env.key
            value = env.value
          }
        }
      }
    }
    //noinspection HILUnresolvedReference
    metadata {
      name        = length(local.cloudrun_specs.metadata) > 0 ? lookup(local.cloudrun_specs.metadata, "name", null): null
      annotations = length(local.cloudrun_specs.metadata) > 0 ? lookup(local.cloudrun_specs.metadata, "annotations", null) : null
    }
  }
  dynamic "traffic" {
    for_each = local.cloudrun_traffic
    //noinspection HILUnresolvedReference
    content{
      percent = lookup(traffic.value, "percent", null)
      revision_name = lookup(traffic.value, "revision_name", null)
      latest_revision = lookup(traffic.value, "revision_name", null) == null ? true : false
    }
  }

}

data "google_iam_policy" "noauth" {
  binding {
    role = "roles/run.invoker"
    members = ["allUsers"]
  }
}

data "google_iam_policy" "auth" {
  //noinspection HILUnresolvedReference
  binding {
    role = "roles/${lookup(local.cloudrun_iam, "role", "" )}"
    members = local.cloudrun_iam_members
  }
}

//noinspection HILUnresolvedReference
resource "google_cloud_run_service_iam_policy" "policy" {
  count       = lookup(local.cloudrun_iam, "replace_policy", true) ? 1 : 0
  location    = google_cloud_run_service.self[0].location
  project     = google_cloud_run_service.self[0].project
  service     = google_cloud_run_service.self[0].name

  policy_data = local.cloudrun_specs.auth ? data.google_iam_policy.auth.policy_data : data.google_iam_policy.noauth.policy_data
}

//noinspection HILUnresolvedReference
resource "google_cloud_run_service_iam_binding" "binding" {
  count    = local.cloudrun_specs.auth ? (lookup(local.cloudrun_iam,"binding", false ) ? 1 : 0) : 0
  project  = google_cloud_run_service.self[0].project
  location = google_cloud_run_service.self[0].location
  members  = local.cloudrun_iam_members
  role     = "roles/${lookup(local.cloudrun_iam, "role", "" )}"

  service  = google_cloud_run_service.self[0].name
}

//noinspection HILUnresolvedReference
resource "google_cloud_run_service_iam_member" "member" {
  count    = local.cloudrun_specs.auth ? (lookup(local.cloudrun_iam,"add_member", null ) == null ? 0 : 1) : 0
  project  = google_cloud_run_service.self[0].project
  location = google_cloud_run_service.self[0].location
  member   = lookup(local.cloudrun_iam,"add_member", null ) == null ? "" : "${local.cloudrun_iam.add_member.member_type}:${local.cloudrun_iam.add_member.member}"
  role     = lookup(local.cloudrun_iam,"add_member", null ) == null ? "" : "roles/${local.cloudrun_iam.add_member.role}"

  service = google_cloud_run_service.self[0].name
}

//noinspection HILUnresolvedReference
resource "google_cloud_run_domain_mapping" "default" {
  count = lookup(local.cloudrun_specs, "domain", null) == null ? 0 : 1
  location = google_cloud_run_service.self[0].location
  name = lookup(local.cloudrun_specs, "domain", "")
  metadata {
    namespace = google_cloud_run_service.self[0].project
  }
  spec {
    route_name = google_cloud_run_service.self[0].name
  }
}


