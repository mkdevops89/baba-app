terraform {
  backend "s3" {
    bucket       = "baba-app-dev-terraform-state-406312601212"
    key          = "environments/dev/terraform.tfstate"
    region       = "us-east-1"
    encrypt      = true
    use_lockfile = true

    kms_key_id = "arn:aws:kms:us-east-1:406312601212:key/6ebf8690-f47b-47d9-be76-8f76a9f70bc2"
  }
}