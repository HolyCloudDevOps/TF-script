Backend Initialization in AWS (S3/DynamoDB)
===========================================

This script helps you initialize backend resources (S3 and DynamoDB) in AWS for storing and managing Terraform state files with locking mechanisms for both development and production environments.

Prerequisites
-------------

Before running the script, ensure you have the following:

*   An AWS account with non-root access.
    
*   AWS CLI installed and configured.
    
*   Proper permissions to create resources in S3 and DynamoDB.
    
*   Terraform installed (if you're using the resources with Terraform).
    

Setup
-----

1.  **Modify Resource Names**:
    
    *   Open the autobackend.sh script.
        
    *   Customize the resource names (S3 bucket, DynamoDB table) for your specific environment (development or production).
        
2.  export
    ```bash
    export AWS_ACCESS_KEY="AKIA***"
    export AWS_SECRET_ACCESS_KEY="***"
    
4.  **Configure Environment**:
    
    *   Modify the script to set the environment (dev or prod) to deploy the backend resources to the respective environments.
        
    *   export ENV="dev" # or "prod"
        
5.  Run     ./autobackend.sh

    The script will:
    
    *   Create the S3 bucket for storing Terraform state files.
        
    *   Set up the DynamoDB table to manage state locking.
        
    *   Configure resources for the selected environment.
        

Usage
-----

After running the script, you can use the AWS S3 bucket and DynamoDB table as your backend for storing Terraform state. Ensure your Terraform configuration points to the newly created S3 bucket and DynamoDB table for state management and locking.

Example Terraform configuration:
```bash
terraform {
  backend "s3" {
    bucket = "your-s3-bucket-name"
    key    = "path/to/terraform.tfstate"
    region = "us-east-1"
    dynamodb_table = "your-dynamodb-table-name"
    encrypt = true
  }
}
```



Notes
-----

*   Make sure your IAM role has the required permissions to access and manage S3 and DynamoDB.
    
*   The script can be reused for both development and production environments by adjusting the environment variable.
    

Troubleshooting
---------------

*   If you encounter issues with resource creation, check your AWS permissions and ensure you're not hitting any AWS limits.
    
*   Ensure the DynamoDB table is in the same region as the S3 bucket for proper locking functionality.
