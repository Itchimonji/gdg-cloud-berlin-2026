locals {
  clean_business_unit = replace(var.business_unit, "_", "-")
  clean_project_id    = replace(var.project_id, "_", "-")

  # Adapt core project name (e.g. "gdg-cloud-demo" -> "gdg-cloud-demo-dev")
  env_project_id = (
    endswith(local.clean_project_id, "-${var.env_short}")
    ? local.clean_project_id
    : "${local.clean_project_id}-${var.env_short}"
  )
}

# Ensure the gcf-artifacts repository exists in the deployment region.
# Cloud Functions 1st Gen requires this Docker repository to store built container images.
resource "google_artifact_registry_repository" "gcf_artifacts" {
  project       = local.env_project_id
  location      = var.region
  repository_id = "gcf-artifacts"
  description   = "Repository for Cloud Functions container images"
  format        = "DOCKER"

  depends_on = [
    google_project_service.required_services
  ]
}

module "scheduled_function" {
  source  = "terraform-google-modules/scheduled-function/google"
  version = "~> 6.0"

  project_id                     = local.env_project_id
  region                         = var.region
  job_name                       = "job-${local.clean_business_unit}-${var.env_short}"
  job_schedule                   = var.job_schedule
  topic_name                     = "top-${local.clean_business_unit}-${var.env_short}"
  function_name                  = "fn-${local.clean_business_unit}-${var.env_short}"
  function_entry_point           = var.entry_point
  function_source_directory      = "${path.module}/function_source"
  function_runtime               = var.runtime
  function_service_account_email = google_service_account.function_sa.email

  function_environment_variables = {
    BUCKET_NAME   = var.bucket_name
    ENVIRONMENT   = var.environment
    BUSINESS_UNIT = var.business_unit
  }

  depends_on = [
    google_project_service.required_services,
    google_project_iam_member.gcf_artifact_registry_reader,
    google_project_iam_member.function_sa_artifact_registry_reader,
    google_artifact_registry_repository.gcf_artifacts,
  ]
}
