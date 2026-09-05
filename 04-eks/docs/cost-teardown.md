# Phase 04 - Cost Teardown

## Purpose

This document defines the controlled cost-teardown procedure for Phase 04 of Baba App.

The Phase 04 Amazon EKS environment is intentionally treated as an ephemeral development environment. After the cluster, workloads, security controls, and validation are complete, the EKS-specific resources can be removed to reduce ongoing AWS costs while preserving the Phase 03 foundation.

The goal is to remove only the resources introduced for Phase 04 and avoid accidentally destroying the shared networking, ECR, Terraform state, and other foundational resources.

---

## Cost Management Objective

The teardown is designed to remove:

- Amazon EKS control plane
- EKS managed node group
- Worker EC2 instances
- EKS-specific IAM relationships created by the EKS module

while retaining the Phase 03 foundation, including:

- VPC
- Public subnets
- Private subnets
- Internet Gateway
- NAT Gateway
- Route tables
- Security groups
- Amazon ECR repositories
- ECR KMS key
- VPC Flow Logs
- CloudWatch log group for VPC Flow Logs
- Terraform remote state infrastructure

---

## Important Warning

Do not run a full Terraform destroy from the development environment.

Do not use:

```text
terraform destroy
```

A full destroy would attempt to remove the Phase 03 infrastructure in addition to the EKS resources.

Phase 04 teardown should target only:

```text
module.eks
```

The targeted operation is being used here as a controlled development-environment teardown strategy because the EKS module shares the same Terraform state as the Phase 03 infrastructure.

---

## Why Teardown Is Required

Amazon EKS introduces several billable resources.

Primary Phase 04 cost drivers include:

- EKS control plane
- EC2 worker nodes

The worker nodes remain billable while the managed node group is active.

Destroying the EKS module after validation reduces these costs while keeping the Terraform code available for future reprovisioning.

---

## Resources That Will Remain Billable

Destroying only `module.eks` does not reduce the AWS environment to zero cost.

Phase 03 resources remain active.

The most important remaining cost driver is the NAT Gateway.

Additional charges may also continue for:

- NAT Gateway hourly usage
- NAT Gateway data processing
- CloudWatch Logs storage and ingestion
- KMS requests
- ECR image storage
- Other retained AWS services depending on usage

If additional cost reduction is required, Phase 03 infrastructure should be reviewed separately rather than being destroyed as part of the Phase 04 teardown.

---

## Pre-Teardown Validation

Before destroying EKS, confirm that Phase 04 has been fully validated and committed to source control.

Recommended checks:

```bash
git status
```

```bash
git diff --check
```

Confirm that the Phase 04 documentation and manifests are present.

Expected repository areas include:

```text
03-terraform/modules/eks/
04-eks/
```

Confirm that local-sensitive values such as administrative `/32` CIDRs are not present in tracked files.

Example validation:

```bash
git grep "<local-public-ip>"
```

The command should not return a tracked-file match.

---

## Confirm Application Health

Before teardown, verify the environment is healthy.

Check Deployments:

```bash
kubectl get deployments -n baba-app
```

Expected:

```text
baba-app-backend    2/2
baba-app-frontend   2/2
```

Check pods:

```bash
kubectl get pods -n baba-app
```

Expected final application state:

```text
4 pods Running
0 Restarts
```

Check Services:

```bash
kubectl get services -n baba-app
```

Both application services should be:

```text
ClusterIP
```

---

## Confirm No External Load Balancers

Phase 04 uses ClusterIP Services and does not intentionally create an AWS Load Balancer.

Confirm:

```bash
kubectl get services -A
```

Review the output for any Service with:

```text
TYPE=LoadBalancer
```

If a LoadBalancer Service exists, remove it before destroying the EKS cluster so that Kubernetes has an opportunity to delete the associated AWS load-balancer resources.

Also review Ingress resources:

```bash
kubectl get ingress -A
```

Phase 04 should not require any Ingress resource.

---

## Delete Kubernetes Application Resources

Before destroying the EKS infrastructure, remove the application resources from the cluster.

Delete the frontend and backend manifests:

```bash
kubectl delete -f 04-eks/manifests/frontend/
```

```bash
kubectl delete -f 04-eks/manifests/backend/
```

Then delete the Baba App namespace:

```bash
kubectl delete -f 04-eks/manifests/namespaces/baba-app.yaml
```

Alternatively, once the application resources are no longer needed, the namespace itself can be deleted:

```bash
kubectl delete namespace baba-app
```

Use one namespace-deletion method, not both.

---

## Validate Workload Removal

Verify that the application namespace has been removed:

```bash
kubectl get namespace baba-app
```

Expected result:

```text
NotFound
```

Confirm that no Baba App workloads remain:

```bash
kubectl get all -A | grep baba-app
```

This should return no application resources.

---

## Navigate to the Terraform Environment

Change to the Phase 03 development Terraform environment:

```bash
cd ~/baba-app/03-terraform/environments/dev
```

Confirm the active AWS SSO session if necessary:

```bash
aws sts get-caller-identity --profile baba-admin
```

If the SSO session has expired:

```bash
aws sso login --profile baba-admin
```

---

## Initialize Terraform

Run:

```bash
terraform init
```

This confirms the Terraform backend and providers are available before planning the destroy operation.

---

## Review Current Terraform State

Before destroying anything, review the EKS resources currently tracked by Terraform:

```bash
terraform state list | grep module.eks
```

The output should contain only the resources managed by the EKS module.

Examples may include:

```text
module.eks.aws_eks_cluster.this
module.eks.aws_eks_node_group.this
module.eks.aws_iam_role.cluster
module.eks.aws_iam_role.node
module.eks.aws_iam_role_policy_attachment.cluster_policy
module.eks.aws_iam_role_policy_attachment.worker_node_policy
module.eks.aws_iam_role_policy_attachment.ecr_read_only
module.eks.aws_iam_role_policy_attachment.cni_policy
```

Exact resource names depend on the Terraform module implementation.

---

## Create a Targeted Destroy Plan

Do not destroy immediately.

First review a targeted destroy plan:

```bash
terraform plan -destroy -target=module.eks
```

The plan should show only EKS-related resources being destroyed.

Do not continue if the plan includes Phase 03 resources such as:

- VPC
- Subnets
- NAT Gateway
- Internet Gateway
- ECR repositories
- VPC Flow Logs
- Terraform state bucket
- KMS resources unrelated to EKS

If unexpected resources appear, stop and review the Terraform dependency graph before proceeding.

---

## Execute the Targeted EKS Destroy

After confirming the destroy plan contains only the intended EKS resources, run:

```bash
terraform destroy -target=module.eks
```

Review the final Terraform confirmation carefully.

Only approve the destroy if the resources listed are EKS-specific.

---

## Expected Teardown Impact

The targeted destroy should remove the Phase 04 infrastructure, including:

- EKS cluster
- Managed node group
- Worker EC2 instances
- EKS cluster IAM role
- EKS node IAM role
- EKS-related IAM policy attachments

Phase 03 infrastructure should remain intact.

---

## Verify EKS Removal in AWS

After Terraform completes, verify the cluster no longer exists.

Run:

```bash
aws eks describe-cluster   --name baba-app-dev-eks   --region us-east-1   --profile baba-admin
```

Expected result:

```text
ResourceNotFoundException
```

Verify the managed node group is gone:

```bash
aws eks list-nodegroups   --cluster-name baba-app-dev-eks   --region us-east-1   --profile baba-admin
```

If the cluster has already been removed, AWS may return a not-found response.

---

## Verify Worker EC2 Instances

Check for worker nodes associated with the EKS environment.

Example:

```bash
aws ec2 describe-instances   --region us-east-1   --profile baba-admin   --filters     "Name=tag:eks:cluster-name,Values=baba-app-dev-eks"     "Name=instance-state-name,Values=pending,running,stopping,stopped"   --query 'Reservations[].Instances[].InstanceId'
```

No active EKS worker-node instances should remain.

---

## Verify Terraform State

After teardown, confirm the EKS module resources are no longer tracked:

```bash
terraform state list | grep module.eks
```

Expected:

```text
No output
```

Then run:

```bash
terraform plan
```

The normal plan should confirm that Terraform would recreate the EKS resources if the module remains enabled in configuration.

This is expected because the environment is intentionally torn down while the Infrastructure as Code remains committed.

---

## Important Terraform Behavior After Teardown

Because the EKS configuration remains in Terraform, a future:

```bash
terraform apply
```

will attempt to recreate the EKS environment.

This is intentional for a reproducible portfolio environment.

Before running Terraform in the future, review the plan carefully to ensure that recreating EKS is actually desired.

---

## Kubernetes Context After Teardown

The local kubeconfig may still contain a context for the deleted cluster.

List contexts:

```bash
kubectl config get-contexts
```

If desired, remove the stale context after confirming the cluster has been destroyed.

The exact context name can be retrieved using:

```bash
kubectl config current-context
```

Do not remove a context until you are certain it belongs to the deleted development cluster.

---

## ECR Images After EKS Teardown

The Baba App container images should remain in Amazon ECR.

This is intentional.

Retaining the images allows the application to be redeployed later without rebuilding immediately.

The ECR repositories remain managed by Phase 03.

---

## Terraform Remote State After Teardown

The Terraform remote-state infrastructure should remain intact.

This includes the S3 backend and associated encryption configuration.

Keeping remote state ensures Terraform retains an accurate record of the Phase 03 environment after EKS is removed.

---

## Reprovisioning EKS Later

When Phase 04 infrastructure is needed again:

```bash
cd ~/baba-app/03-terraform/environments/dev
```

Authenticate:

```bash
aws sso login --profile baba-admin
```

Review:

```bash
terraform plan
```

Then provision:

```bash
terraform apply
```

After the EKS cluster is available, update kubeconfig:

```bash
aws eks update-kubeconfig   --region us-east-1   --name baba-app-dev-eks   --profile baba-admin
```

Then redeploy the Kubernetes manifests:

```bash
kubectl apply -f 04-eks/manifests/namespaces/
kubectl apply -f 04-eks/manifests/backend/
kubectl apply -f 04-eks/manifests/frontend/
```

Because the images are pinned by SHA256 digest and retained in ECR, the same validated artifacts can be redeployed.

---

## Cost Teardown Checklist

Before teardown:

- [ ] Phase 04 implementation complete
- [ ] Application validation complete
- [ ] Security scans complete
- [ ] Checkov passes
- [ ] Trivy passes
- [ ] Phase 04 documentation created
- [ ] Git changes reviewed
- [ ] Phase 04 committed to source control
- [ ] No external LoadBalancer Services remain

Kubernetes cleanup:

- [ ] Frontend resources deleted
- [ ] Backend resources deleted
- [ ] Baba App namespace deleted
- [ ] No Baba App Kubernetes resources remain

Terraform teardown:

- [ ] AWS SSO authenticated
- [ ] Terraform initialized
- [ ] EKS resources reviewed in state
- [ ] Targeted destroy plan reviewed
- [ ] Only `module.eks` selected for destruction
- [ ] Targeted destroy completed

Post-teardown:

- [ ] EKS cluster no longer exists
- [ ] Managed node group removed
- [ ] Worker EC2 instances removed
- [ ] `module.eks` resources absent from Terraform state
- [ ] Phase 03 infrastructure remains available
- [ ] ECR repositories remain available
- [ ] Terraform remote state remains available

---

## Cost Management Outcome

The Phase 04 cost strategy separates infrastructure lifecycle from source-code lifecycle.

The EKS environment can be destroyed when it is not actively being used while the following remain preserved:

```text
Terraform configuration
Kubernetes manifests
Security controls
Validation documentation
Container images
Phase 03 infrastructure
```

This makes the environment reproducible without paying continuously for EKS resources during periods when the portfolio environment is not being demonstrated or developed.

The Phase 04 teardown procedure is therefore both a cost-management control and an Infrastructure as Code validation exercise.
