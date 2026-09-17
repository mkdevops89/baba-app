# Baba App Phase 09 — EKS Pod Identity Validation Runbook

## Purpose

This runbook captures the validated Phase 09 workload identity implementation for Baba App. It proves that the backend receives a dedicated AWS identity through EKS Pod Identity, while the frontend receives no AWS workload credentials.

## Scope

- Project: `baba-app`
- Environment: `dev`
- Region: `us-east-1`
- EKS cluster: `baba-app-dev-eks`
- Namespace: `baba-app`
- Backend ServiceAccount: `baba-app-backend`
- Frontend ServiceAccount: `baba-app-frontend`
- Backend IAM role: `baba-app-dev-backend-pod-identity`
- Backend IAM policy: `baba-app-dev-backend-secret-read`
- Secret: `baba-app/dev/backend/config`

## Architecture

```text
Backend Pod
  ↓
baba-app-backend ServiceAccount
  ↓
EKS Pod Identity Association
  ↓
baba-app-dev-backend-pod-identity
  ↓
baba-app-dev-backend-secret-read
  ↓
AWS Secrets Manager
  ↓
baba-app/dev/backend/config
```

```text
Frontend Pod
  ↓
baba-app-frontend ServiceAccount
  ↓
No Pod Identity Association
  ↓
No AWS workload credentials
```

## Security Controls

- Dedicated Kubernetes ServiceAccounts for frontend and backend.
- `automountServiceAccountToken: false` retained on application workloads.
- No static AWS access keys in Git, Kubernetes manifests, or Terraform.
- Backend IAM trust limited to `pods.eks.amazonaws.com`.
- Backend permission limited to:
  - `secretsmanager:GetSecretValue`
  - `secretsmanager:DescribeSecret`
- Access restricted to one backend secret.
- Frontend has no Pod Identity association and no AWS role.

---

# Validation Procedure

## 1. Validate Pod Identity Add-on

```bash
aws eks describe-addon \
  --cluster-name baba-app-dev-eks \
  --addon-name eks-pod-identity-agent \
  --region us-east-1 \
  --profile baba-admin \
  --query 'addon.{Status:status,Version:addonVersion}' \
  --output table
```

Expected:

```text
Status: ACTIVE
```

Validated version:

```text
v1.3.10-eksbuild.3
```

## 2. Validate Agent DaemonSet

```bash
kubectl get daemonset \
  eks-pod-identity-agent \
  -n kube-system
```

Validated result:

```text
DESIRED   CURRENT   READY   AVAILABLE
2         2         2       2
```

## 3. Validate Pod Identity Association

```bash
aws eks list-pod-identity-associations \
  --cluster-name baba-app-dev-eks \
  --region us-east-1 \
  --profile baba-admin
```

Expected mapping:

```text
namespace: baba-app
serviceAccount: baba-app-backend
```

Inspect the association:

```bash
aws eks describe-pod-identity-association \
  --cluster-name baba-app-dev-eks \
  --association-id <ASSOCIATION_ID> \
  --region us-east-1 \
  --profile baba-admin \
  --query 'association.{Namespace:namespace,ServiceAccount:serviceAccount,RoleArn:roleArn}' \
  --output table
```

Expected role:

```text
baba-app-dev-backend-pod-identity
```

## 4. Validate IAM Trust

```bash
aws iam get-role \
  --role-name baba-app-dev-backend-pod-identity \
  --profile baba-admin \
  --query 'Role.AssumeRolePolicyDocument' \
  --output json
```

Expected:

```text
Principal: pods.eks.amazonaws.com
Actions:
- sts:AssumeRole
- sts:TagSession
```

## 5. Validate Backend Policy

```bash
aws iam list-attached-role-policies \
  --role-name baba-app-dev-backend-pod-identity \
  --profile baba-admin
```

Expected attached policy:

```text
baba-app-dev-backend-secret-read
```

Inspect it:

```bash
POLICY_ARN=$(aws iam list-attached-role-policies \
  --role-name baba-app-dev-backend-pod-identity \
  --profile baba-admin \
  --query 'AttachedPolicies[0].PolicyArn' \
  --output text)

VERSION_ID=$(aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --profile baba-admin \
  --query 'Policy.DefaultVersionId' \
  --output text)

aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$VERSION_ID" \
  --profile baba-admin \
  --query 'PolicyVersion.Document' \
  --output json
```

Expected actions:

```text
secretsmanager:GetSecretValue
secretsmanager:DescribeSecret
```

Expected resource: one specific backend secret ARN.

## 6. Validate Secret

```bash
aws secretsmanager describe-secret \
  --secret-id baba-app/dev/backend/config \
  --region us-east-1 \
  --profile baba-admin \
  --query '{Name:Name,ARN:ARN}' \
  --output table
```

Expected name:

```text
baba-app/dev/backend/config
```

## 7. Add Demo Value

Use only a harmless validation value:

```bash
aws secretsmanager put-secret-value \
  --secret-id baba-app/dev/backend/config \
  --secret-string '{"BABA_APP_DEMO_CONFIG":"phase09-pod-identity"}' \
  --region us-east-1 \
  --profile baba-admin
```

The demo value is intentionally written outside Terraform so it does not enter Terraform state.

## 8. Restart Backend

```bash
kubectl rollout restart deployment/baba-app-backend \
  -n baba-app

kubectl rollout status deployment/baba-app-backend \
  -n baba-app \
  --timeout=180s
```

Expected:

```text
deployment "baba-app-backend" successfully rolled out
```

## 9. Validate Pod Identity Injection

Find a backend Pod:

```bash
BACKEND_POD=$(kubectl get pods -n baba-app \
  -o name | grep 'baba-app-backend' | head -n 1 | cut -d/ -f2)

echo "$BACKEND_POD"
```

Inspect environment variables:

```bash
kubectl get pod "$BACKEND_POD" \
  -n baba-app \
  -o jsonpath='{range .spec.containers[0].env[*]}{.name}{"="}{.value}{"\n"}{end}'
```

Validated injected values included:

```text
AWS_STS_REGIONAL_ENDPOINTS=regional
AWS_DEFAULT_REGION=us-east-1
AWS_REGION=us-east-1
AWS_CONTAINER_CREDENTIALS_FULL_URI=http://169.254.170.23/v1/credentials
AWS_CONTAINER_AUTHORIZATION_TOKEN_FILE=/var/run/secrets/pods.eks.amazonaws.com/serviceaccount/eks-pod-identity-token
```

Inspect volumes:

```bash
kubectl get pod "$BACKEND_POD" \
  -n baba-app \
  -o jsonpath='{range .spec.volumes[*]}{"volume: "}{.name}{"\n"}{end}{range .spec.containers[0].volumeMounts[*]}{"mount: "}{.name}{" -> "}{.mountPath}{"\n"}{end}'
```

Validated:

```text
volume: eks-pod-identity-token
mount: eks-pod-identity-token -> /var/run/secrets/pods.eks.amazonaws.com/serviceaccount
```

The Pod still had:

```text
automountServiceAccountToken: false
```

The Pod Identity token is a separate projected token specifically for EKS Pod Identity.

---

# Positive Authorization Test

Create:

```bash
code ~/baba-app/09-identity/pod-identity-test.yaml
```

Use:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: backend-pod-identity-test
  namespace: baba-app
spec:
  serviceAccountName: baba-app-backend
  restartPolicy: Never

  containers:
    - name: aws-cli
      image: public.ecr.aws/aws-cli/aws-cli:latest
      command:
        - /bin/sh
        - -c
        - |
          echo "=== STS Identity ==="
          aws sts get-caller-identity

          echo
          echo "=== Secrets Manager Read ==="
          aws secretsmanager get-secret-value \
            --secret-id baba-app/dev/backend/config \
            --region us-east-1 \
            --query SecretString \
            --output text

      env:
        - name: AWS_REGION
          value: us-east-1
```

Run:

```bash
kubectl apply \
  -f ~/baba-app/09-identity/pod-identity-test.yaml

kubectl get pod backend-pod-identity-test \
  -n baba-app \
  -w
```

Expected:

```text
Completed
```

Check logs:

```bash
kubectl logs backend-pod-identity-test \
  -n baba-app
```

Validated result:

```text
STS identity:
assumed-role/baba-app-dev-backend-pod-identity/...

Secret:
{"BABA_APP_DEMO_CONFIG":"phase09-pod-identity"}
```

This proves the backend receives short-lived AWS credentials and can read its designated secret.

---

# Negative Authorization Test

Create:

```bash
code ~/baba-app/09-identity/pod-identity-negative-test.yaml
```

Use:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: frontend-pod-identity-negative-test
  namespace: baba-app
spec:
  serviceAccountName: baba-app-frontend
  restartPolicy: Never

  containers:
    - name: aws-cli
      image: public.ecr.aws/aws-cli/aws-cli:latest
      command:
        - aws
      args:
        - secretsmanager
        - get-secret-value
        - --secret-id
        - baba-app/dev/backend/config
        - --region
        - us-east-1
      env:
        - name: AWS_REGION
          value: us-east-1
```

Run:

```bash
kubectl apply \
  -f ~/baba-app/09-identity/pod-identity-negative-test.yaml

kubectl get pod frontend-pod-identity-negative-test \
  -n baba-app \
  -w
```

Validated status:

```text
Error
```

Check logs:

```bash
kubectl logs \
  frontend-pod-identity-negative-test \
  -n baba-app
```

Validated failure:

```text
NoCredentials: Unable to locate credentials
```

Inspect for Pod Identity injection:

```bash
kubectl get pod frontend-pod-identity-negative-test \
  -n baba-app \
  -o yaml | grep -i -A3 -B3 \
  'AWS_CONTAINER_CREDENTIALS\|AWS_CONTAINER_AUTHORIZATION\|pod-identity'
```

Validated result:

- no backend Pod Identity credential endpoint;
- no authorization token file;
- no backend IAM role delivery.

---

# Cleanup

```bash
kubectl delete pod \
  backend-pod-identity-test \
  frontend-pod-identity-negative-test \
  -n baba-app
```

```bash
rm \
  ~/baba-app/09-identity/pod-identity-test.yaml \
  ~/baba-app/09-identity/pod-identity-negative-test.yaml
```

---

# Troubleshooting

## AWS CLI Test Pod ImagePullBackOff

Initial image:

```yaml
image: public.ecr.aws/aws-cli/aws-cli:2
```

Result:

```text
ErrImagePull
ImagePullBackOff
```

Working test image:

```yaml
image: public.ecr.aws/aws-cli/aws-cli:latest
```

For a permanent validation manifest, pin a tested full version instead of `latest`.

## Incorrect Backend Label Selector

Incorrect:

```bash
-l app=baba-app-backend
```

Correct label:

```text
app.kubernetes.io/name=baba-app-backend
```

Correct command:

```bash
kubectl get pods \
  -n baba-app \
  -l app.kubernetes.io/name=baba-app-backend
```

---

# Validation Results

## IAM-09-004 — Dedicated Workload Identities

**Status: Remediated and Validated**

- backend uses `baba-app-backend`;
- frontend uses `baba-app-frontend`;
- automatic Kubernetes ServiceAccount token mounting disabled;
- application rollouts remained healthy.

## IAM-09-005 — AWS Workload Permission Review

**Status: Validated**

Security decision:

- do not assign AWS permissions unless a workload has a defined need;
- frontend remains without AWS permissions;
- backend receives only the permissions required for the defined Secrets Manager use case.

## IAM-09-006 — EKS Pod Identity Foundation

**Status: Implemented and Validated**

- Pod Identity Agent `ACTIVE`;
- DaemonSet healthy across both worker nodes;
- backend ServiceAccount associated with dedicated IAM role;
- backend Pods receive Pod Identity injection;
- regular Kubernetes ServiceAccount token automount remains disabled.

## IAM-09-007 — Credential Delivery and Least-Privilege Enforcement

**Status: Implemented and Validated**

Backend:

- temporary AWS credentials delivered;
- STS confirmed dedicated backend role;
- designated secret read succeeded;
- no static AWS credentials used.

Frontend:

- no Pod Identity association;
- no AWS credentials injected;
- backend secret retrieval failed with `NoCredentials`.

---

# Interview Talking Point

> I separated the application workloads into dedicated Kubernetes ServiceAccounts and disabled automatic Kubernetes API token mounting. Before assigning AWS permissions, I reviewed whether each workload had a legitimate AWS dependency. The frontend had none, so it received no AWS role. For the backend, I implemented a narrowly scoped Secrets Manager use case using EKS Pod Identity. I installed the Pod Identity Agent, created a dedicated IAM role trusted by `pods.eks.amazonaws.com`, and restricted the role to `GetSecretValue` and `DescribeSecret` for one specific secret. I validated the control positively by proving the backend received short-lived credentials, assumed the correct role, and retrieved the secret. I then performed a negative test using the frontend ServiceAccount, which failed with `NoCredentials`. This demonstrated least privilege and prevented cross-workload identity inheritance.

# Evidence Checklist

- [x] Pod Identity add-on active
- [x] Agent DaemonSet healthy
- [x] Backend association present
- [x] IAM trust restricted to Pod Identity service
- [x] IAM policy restricted to one secret
- [x] Backend Kubernetes token automount disabled
- [x] Pod Identity injected into backend
- [x] STS confirmed backend assumed role
- [x] Backend secret retrieval succeeded
- [x] Frontend received no AWS credentials
- [x] Frontend secret retrieval failed
- [x] Temporary validation Pods removed

## Final State

```text
Backend:
Dedicated Kubernetes ServiceAccount
+ EKS Pod Identity
+ short-lived AWS credentials
+ narrowly scoped IAM policy
+ designated Secrets Manager secret

Frontend:
Dedicated Kubernetes ServiceAccount
+ no Kubernetes API token
+ no EKS Pod Identity
+ no AWS workload credentials
```
