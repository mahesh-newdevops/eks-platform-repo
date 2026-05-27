# ArgoCD Root App Placeholder

This directory exists so the default ArgoCD root app path is present in this repository.

For real workloads or optional platform add-ons, use a separate GitOps repository and set:

```hcl
argocd_root_app_repo_url = "https://github.com/mahesh-newdevops/gitops-platform.git"
argocd_root_app_path     = "argocd"
```
