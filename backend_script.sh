#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Catch errors in pipelines

# Define environments
ENVIRONMENTS=("dev" "prod")

# Function to clean up resources if something goes wrong
cleanup() {
  echo "An error occurred. Rolling back created resources..."
  terraform -chdir="$WORKING_DIR" destroy -auto-approve || echo "Cleanup failed. Please check the resources manually."
  rm -rf "$WORKING_DIR"
  exit 1
}

# Trap any error and call the cleanup function
trap cleanup ERR

# Loop through each environment
for ENV in "${ENVIRONMENTS[@]}"; do
  echo "🚀 Setting up environment: $ENV"

  # Step 1: Create a new working directory for backend resources
  WORKING_DIR="backend-$ENV"

  # Create the backend resources directory if it doesn't exist
  if [ ! -d "$WORKING_DIR" ]; then
    echo "Creating new directory for backend resources: $WORKING_DIR"
    mkdir "$WORKING_DIR"
  fi

  # Step 2: Define unique bucket and table names for each environment
  S3_BUCKET="tf-backend-3762t761253476-${ENV}"
  DYNAMODB_TABLE="terraform-locks-${ENV}"

  # Ensure bucket name is valid (all lowercase, no special chars)
  S3_BUCKET=$(echo "$S3_BUCKET" | tr '[:upper:]' '[:lower:]')

  echo "Creating main.tf for initializing backend resources for ${ENV} environment..."
  cat > "$WORKING_DIR/main.tf" <<EOF
provider "aws" {
  region = "us-east-1"
}

resource "aws_s3_bucket" "backend" {
  bucket = "${S3_BUCKET}"
}

resource "aws_s3_bucket_versioning" "versioning_backend" {
  bucket = aws_s3_bucket.backend.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_dynamodb_table" "terraform_locks" {
  name           = "${DYNAMODB_TABLE}"
  billing_mode   = "PROVISIONED"
  read_capacity  = 1
  write_capacity = 1
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }
}

output "s3_bucket_name" {
  value = aws_s3_bucket.backend.id
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.terraform_locks.name
}
EOF

  # Step 3: Initialize and apply backend resources
  echo "Initializing and applying backend resources for ${ENV}..."
  terraform -chdir="$WORKING_DIR" init
  terraform -chdir="$WORKING_DIR" apply -auto-approve

  # Step 4: Create backend.tf with the correct S3 bucket and DynamoDB table
  echo "📝 Оновлення backend-${ENV}.tf..."
  cat > "$WORKING_DIR/backend-${ENV}.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${S3_BUCKET}"
    key            = "${ENV}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "${DYNAMODB_TABLE}"
    encrypt        = true
  }
}
EOF

  # Step 5: Reinitialize Terraform backend
  echo "Reinitializing the backend for ${ENV}..."
  terraform -chdir="$WORKING_DIR" init -reconfigure -upgrade

  # Step 6: Cleanup local files
  echo "Removing the local terraform state and main.tf..."
  rm -f "$WORKING_DIR/terraform.tfstate" "$WORKING_DIR/terraform.tfstate.backup" "$WORKING_DIR/main.tf"

  # Step 7: Create outputs.tf to store backend outputs
  echo "⏳ Create outputs.tf to store backend outputs..."
  S3_BUCKET_OUTPUT=$(terraform -chdir="$WORKING_DIR" output -raw s3_bucket_name)
  DYNAMODB_TABLE_OUTPUT=$(terraform -chdir="$WORKING_DIR" output -raw dynamodb_table_name)
  echo "Creating outputs.tf file..."
  cat > "$WORKING_DIR/outputs.tf" <<EOF
output "s3_bucket_name" {
  value = "${S3_BUCKET_OUTPUT}"
}

output "dynamodb_table_name" {
  value = "${DYNAMODB_TABLE_OUTPUT}"
}
EOF

  echo "Backend outputs stored in outputs.tf for ${ENV} environment."
  echo "✅ Environment $ENV successfully configured!"
done

echo "All environments (${ENVIRONMENTS[@]}) have been set up successfully!"
