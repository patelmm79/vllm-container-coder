# Terraform Infrastructure for vLLM Container

This directory contains Terraform configuration to manage the GCP infrastructure for the vLLM container project.

## What It Manages

- **Artifact Registry Repository**: Docker repository for storing container images
- **GCP APIs**: Enables required APIs (Artifact Registry, Cloud Run, Cloud Build, Secret Manager)
- **IAM Permissions**: Sets up necessary permissions for Cloud Build to access secrets and push images
- **Cleanup Policies**: Automatically removes old/untagged images to save storage costs

## Prerequisites

1. **Install Terraform**: Download from [terraform.io](https://www.terraform.io/downloads)
2. **GCP Authentication**: Authenticate with your GCP account
   ```bash
   gcloud auth application-default login
   ```
3. **Get Project Number**: You'll need your GCP project number
   ```bash
   gcloud projects describe globalbiting-dev --format="value(projectNumber)"
   ```

## Setup

1. **Navigate to terraform directory**:
   ```bash
   cd terraform
   ```

2. **Create `terraform.tfvars` from example**:
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   ```

3. **Edit `terraform.tfvars`** and fill in your project number:
   ```hcl
   project_id          = "globalbiting-dev"
   project_number      = "123456789012"  # Replace with your actual project number
   region              = "us-central1"
   hf_token_secret_id  = "HF_TOKEN"
   ```

4. **Initialize Terraform**:
   ```bash
   terraform init
   ```

5. **Preview changes**:
   ```bash
   terraform plan
   ```

6. **Apply configuration**:
   ```bash
   terraform apply
   ```

## How It Works

The Terraform configuration:
- Reads your `config.env` file to automatically get the repository and service names
- Creates an Artifact Registry repository with the name from `ARTIFACT_REGISTRY_REPO`
- Sets up cleanup policies to keep only the 10 most recent images
- Configures IAM permissions for Cloud Build service account

When you change models in `config.env`, Terraform will automatically:
- Detect the new repository name
- Create/update the repository as needed

## Updating Infrastructure

When you change `config.env` (e.g., switching models):

1. **Review changes**:
   ```bash
   terraform plan
   ```

2. **Apply changes**:
   ```bash
   terraform apply
   ```

## Managing Multiple Repositories

If you want to maintain repositories for multiple models:

1. **Keep all repositories**: The configuration will update to the new repository name but won't delete old ones
2. **Manual cleanup**: Delete old repositories manually if no longer needed:
   ```bash
   gcloud artifacts repositories delete OLD_REPO_NAME --location=us-central1
   ```

## State Management

By default, Terraform stores state locally in `terraform/terraform.tfstate`. For team environments, consider:

1. **Remote State Storage** (uncomment in `main.tf`):
   ```hcl
   backend "gcs" {
     bucket = "your-terraform-state-bucket"
     prefix = "vllm-container/state"
   }
   ```

2. **Create bucket first**:
   ```bash
   gcloud storage buckets create gs://your-terraform-state-bucket --location=us-central1
   ```

3. **Initialize with backend**:
   ```bash
   terraform init -migrate-state
   ```

## Outputs

After applying, Terraform outputs:
- `artifact_registry_url`: Base URL of your repository
- `image_url`: Full URL where your container image will be stored

## Cleanup

To destroy all managed resources:

```bash
terraform destroy
```

**Warning**: This will delete the Artifact Registry repository and all images in it!

## Integration with Cloud Build

The Cloud Build pipeline (`cloudbuild.yaml`) automatically uses the repository created by Terraform. No changes needed to Cloud Build configuration.

## Troubleshooting

### "Project number required"
- Run: `gcloud projects describe globalbiting-dev --format="value(projectNumber)"`
- Add the number to `terraform.tfvars`

### "Repository already exists"
- If you created the repository manually, Terraform can import it:
  ```bash
  terraform import google_artifact_registry_repository.vllm_repo projects/globalbiting-dev/locations/us-central1/repositories/vllm-codeqwen-15-repo
  ```

### "API not enabled"
- Terraform will automatically enable required APIs
- If you see errors, manually enable:
  ```bash
  gcloud services enable artifactregistry.googleapis.com
  gcloud services enable cloudbuild.googleapis.com
  ```
