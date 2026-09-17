# Phase 09 Kubernetes RBAC

This directory defines namespace-scoped Kubernetes access for Baba App.

## Roles

### baba-app-developer

Designed for application engineers who need to troubleshoot and manage workloads in the `baba-app` namespace.

Allowed:

- Pods
- Pod logs
- Services
- ConfigMaps
- Deployments
- ReplicaSets

Excluded:

- Secrets
- Roles
- RoleBindings
- ClusterRoles
- ClusterRoleBindings
- Nodes
- Other namespaces

### baba-app-readonly

Designed for auditors, support personnel, or stakeholders who need visibility without modification privileges.

Allowed:

- Get
- List
- Watch
- Pod logs

No write operations are permitted.

## Security Objective

Apply least privilege by separating routine application operations from Kubernetes cluster administration.