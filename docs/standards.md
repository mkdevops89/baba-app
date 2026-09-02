# Baba App Engineering Standards

## Project Baseline

Project: baba-app  
Environment: dev  
Region: us-east-1  
ManagedBy: terraform  
Repository: baba-app  

## Resource Naming Convention

All AWS resources should follow:

baba-app-dev-<resource>

Examples:

- baba-app-dev-vpc
- baba-app-dev-eks
- baba-app-dev-ecr
- baba-app-dev-alb
- baba-app-dev-rds

## Required Tags

Project = baba-app  
Environment = dev  
ManagedBy = terraform  
Repository = baba-app