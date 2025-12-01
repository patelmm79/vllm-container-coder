variable "project_id" {
  description = "GCP Project ID"
  type        = string
  default     = "globalbiting-dev"
}

variable "project_number" {
  description = "GCP Project Number (required for service account IAM)"
  type        = string
  # You can find this by running: gcloud projects describe globalbiting-dev --format="value(projectNumber)"
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "hf_token_secret_id" {
  description = "Secret Manager secret ID for Hugging Face token"
  type        = string
  default     = "HF_TOKEN"
}
