terraform {
  required_version = ">= 1.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Optional: Configure remote state storage in GCS
  # Uncomment and configure after creating the bucket manually
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "vllm-container/state"
  # }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# Read configuration from config.env
locals {
  config = {
    for line in split("\n", file("${path.module}/../config.env")) :
    split("=", line)[0] => split("=", line)[1]
    if length(regexall("^[A-Z_]+=.+", line)) > 0
  }

  artifact_registry_repo  = local.config["ARTIFACT_REGISTRY_REPO"]
  artifact_registry_image = local.config["ARTIFACT_REGISTRY_IMAGE"]
  service_name           = local.config["SERVICE_NAME"]
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "vllm_repo" {
  location      = var.region
  repository_id = local.artifact_registry_repo
  description   = "Docker repository for vLLM container images (${local.artifact_registry_image})"
  format        = "DOCKER"

  # Optional: Configure cleanup policies
  cleanup_policies {
    id     = "keep-recent-images"
    action = "KEEP"

    most_recent_versions {
      keep_count = 10
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"

    condition {
      tag_state = "UNTAGGED"
      older_than = "604800s" # 7 days
    }
  }
}

# Enable required APIs
resource "google_project_service" "artifact_registry" {
  service            = "artifactregistry.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_run" {
  service            = "run.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "cloud_build" {
  service            = "cloudbuild.googleapis.com"
  disable_on_destroy = false
}

resource "google_project_service" "secret_manager" {
  service            = "secretmanager.googleapis.com"
  disable_on_destroy = false
}

# IAM binding for Cloud Build to access Secret Manager
resource "google_secret_manager_secret_iam_member" "cloudbuild_hf_token" {
  secret_id = var.hf_token_secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# IAM binding for Cloud Build to push to Artifact Registry
resource "google_artifact_registry_repository_iam_member" "cloudbuild_writer" {
  project    = var.project_id
  location   = google_artifact_registry_repository.vllm_repo.location
  repository = google_artifact_registry_repository.vllm_repo.name
  role       = "roles/artifactregistry.writer"
  member     = "serviceAccount:${var.project_number}@cloudbuild.gserviceaccount.com"
}

# Output the repository URL
output "artifact_registry_url" {
  description = "Full URL of the Artifact Registry repository"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.vllm_repo.repository_id}"
}

output "image_url" {
  description = "Full image URL for the container"
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.vllm_repo.repository_id}/${local.artifact_registry_image}"
}
