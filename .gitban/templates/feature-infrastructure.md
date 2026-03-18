---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking infrastructure feature development following Infrastructure as Code (IaC) principles, with emphasis on declarative configuration, documentation as code, automated testing, and safe deployment practices.
use_case: Use this for infrastructure features including cloud resource provisioning, container orchestration, CI/CD pipelines, monitoring setup, networking configuration, or infrastructure automation. Enforces IaC best practices, code review, automated testing, and gradual rollout.
patterns_used:
  - section: "Infrastructure Feature Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Infrastructure Context & Design Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Infrastructure Design Decisions"
    pattern: "Pattern 6: Brainstorming Block"
  - section: "Infrastructure Development Phases"
    pattern: "Pattern 9: Phased Task Checklist"
  - section: "IaC Implementation Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Infrastructure Validation & Deployment"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Infrastructure Feature Development Template

**When to use this template:** Use this for developing infrastructure features following Infrastructure as Code (IaC) principles including cloud resource provisioning, container orchestration, CI/CD pipelines, monitoring setup, networking, or infrastructure automation. Enforces declarative configuration, version control, automated testing, and safe deployment practices.

**When NOT to use this template:** Do not use this for application code features (use `feature.md`), infrastructure incidents (use `bug-production.md`), or infrastructure research (use `spike.md`). This template is specifically for planned infrastructure feature development with IaC.

---

## Infrastructure Feature Overview

* **Feature Description:** [Brief description, e.g., "Provision production Kubernetes cluster", "Setup multi-region CDN", "Implement blue-green deployment pipeline"]
* **Infrastructure Component:** [What's being created/modified, e.g., "EKS cluster", "CloudFront distribution", "GitHub Actions workflow"]
* **Cloud Provider/Platform:** [Where this runs, e.g., "AWS (us-east-1, us-west-2)", "GCP (us-central1)", "On-prem Kubernetes", "GitHub Actions"]
* **IaC Tool/Framework:** [What tools used, e.g., "Terraform 1.6", "Pulumi (Python)", "Ansible", "CloudFormation", "Helm charts"]
* **Business Requirement:** [Why this is needed, e.g., "Support 10x traffic growth", "Compliance requirement for multi-region", "Reduce deployment time from 2h to 15min"]
* **Related Work:** [Links, e.g., "Design spike SPIKE-456", "ADR-025 for cloud provider choice", "Architecture diagram in docs/"]
* **Cost Impact:** [Expected cost, e.g., "Est. $500/month", "Cost-neutral (replacing existing)", "One-time: $1000, ongoing: $200/month"]
* **Target Environment:** [Deployment target, e.g., "Production", "Staging + Production", "All environments"]

**Required Checks:**
* [ ] **IaC tool/framework** is specified and version documented.
* [ ] **Cost impact** is estimated and approved [if applicable].
* [ ] **Business requirement** clearly justifies the infrastructure change.

---

## Infrastructure Context & Design Review

Before implementation, review existing infrastructure, architecture patterns, IaC standards, and related documentation.

* [ ] Infrastructure architecture documentation reviewed (network diagrams, service topology).
* [ ] Existing IaC codebase reviewed for patterns and conventions.
* [ ] IaC style guide and team standards reviewed (naming, tagging, module structure).
* [ ] Security and compliance requirements reviewed (encryption, IAM, audit logging).
* [ ] Disaster recovery and backup requirements reviewed.
* [ ] Monitoring and alerting requirements reviewed.
* [ ] Cost optimization best practices reviewed.
* [ ] Similar existing infrastructure reviewed for reusable patterns.

Use the table below to document review findings. Add rows as needed.

| Review Source | Link / Location | Key Findings / Patterns to Follow |
| :--- | :--- | :--- |
| **Architecture Docs** | [e.g., "docs/architecture/aws-infrastructure.md"] | [e.g., "All resources must be tagged with Environment, Owner, CostCenter"] |
| **Existing IaC** | [e.g., "terraform/modules/eks-cluster/"] | [e.g., "Reuse existing EKS module pattern with version pinning"] |
| **Style Guide** | [e.g., "docs/infrastructure/terraform-style-guide.md"] | [e.g., "Use snake_case for resource names, prefix modules with company name"] |
| **Security Requirements** | [e.g., "docs/security/infrastructure-security.md"] | [e.g., "All data at rest must be encrypted, IAM follows least privilege principle"] |
| **DR Requirements** | [e.g., "docs/architecture/disaster-recovery.md"] | [e.g., "RTO: 4 hours, RPO: 1 hour - requires automated backups"] |
| **Monitoring Standards** | [e.g., "docs/observability/monitoring-standards.md"] | [e.g., "All services must expose health endpoints, integrate with Datadog"] |
| **Cost Policies** | [e.g., "docs/infrastructure/cost-optimization.md"] | [e.g., "Use spot instances for non-critical workloads, enable auto-scaling"] |
| **Similar Infrastructure** | [e.g., "terraform/staging-cluster/" or "Link to existing config"] | [e.g., "Staging cluster config can be template for production with increased capacity"] |

---

## Infrastructure Design Decisions

> Use this space for architectural decisions, technology choices, configuration parameters, and design trade-offs.

**Key Design Decisions:**
* [e.g., "Decision: Use EKS managed node groups instead of self-managed for reduced operational overhead"]
* [e.g., "Decision: Multi-AZ deployment with 3 availability zones for high availability"]
* [e.g., "Decision: Use Terraform workspaces for environment separation (dev/staging/prod)"]

**Configuration Parameters:**
* [e.g., "Cluster: 5 nodes (t3.xlarge), auto-scale 5-20 based on CPU >70%"]
* [e.g., "Storage: EBS gp3 volumes, 100GB per node, encrypted with KMS"]
* [e.g., "Networking: Private subnets with NAT gateway, VPC peering to existing network"]

**Security Considerations:**
* [e.g., "IAM: Service accounts with IRSA (IAM Roles for Service Accounts)"]
* [e.g., "Network: Security groups restrict ingress to ALB only, egress to approved endpoints"]
* [e.g., "Secrets: Use AWS Secrets Manager, rotate every 90 days"]

**High Availability & Resilience:**
* [e.g., "Multi-AZ deployment for 99.95% availability SLA"]
* [e.g., "Automated backups to S3 every 6 hours, 30-day retention"]
* [e.g., "Health checks with automatic node replacement on failure"]

**Cost Optimization:**
* [e.g., "Use Savings Plans for baseline capacity, Spot instances for burst capacity (30% cost reduction)"]
* [e.g., "Enable auto-scaling to avoid over-provisioning during low traffic periods"]

**Monitoring & Observability:**
* [e.g., "CloudWatch metrics for cluster health, Datadog for application metrics"]
* [e.g., "Alerts: Node CPU >80%, disk space <20%, pod crash loops"]
* [e.g., "Logging: FluentBit forwarding to CloudWatch Logs, 90-day retention"]

**Dependencies & Prerequisites:**
* [e.g., "Requires: VPC with public/private subnets, Route53 hosted zone, ACM certificate"]
* [e.g., "Depends on: Shared services VPC (already exists), KMS keys for encryption"]

---

## Infrastructure Development Phases

Track the major phases of infrastructure development from design through production deployment.

| Phase / Task | Status / Link to Artifact or Card | Universal Check |
| :--- | :--- | :---: |
| **Architecture Design** | [e.g., "Design doc in docs/architecture/prod-k8s-cluster.md" or "Status: Complete"] | - [ ] Architecture design is documented and reviewed. |
| **IaC Code Development** | [e.g., "Terraform module in terraform/modules/production-cluster/" or "PR #789"] | - [ ] IaC code is written following team conventions. |
| **Code Review** | [e.g., "PR #789 reviewed by Alice (infra team lead)" or "Status: In review"] | - [ ] IaC code is reviewed for correctness, security, and best practices. |
| **Automated Testing** | [e.g., "terratest tests in tests/terraform/cluster_test.go" or "Link to tests"] | - [ ] Automated tests validate infrastructure configuration. |
| **Cost Estimation** | [e.g., "Cost estimate: $500/month (Infracost report)" or "Link to report"] | - [ ] Cost is estimated and within budget. |
| **Security Review** | [e.g., "Security team approved (Checkov passed, manual review complete)" or "Status: Approved"] | - [ ] Security requirements validated (encryption, IAM, network security). |
| **Documentation** | [e.g., "Runbook: docs/runbooks/prod-k8s-cluster.md" or "Link to docs"] | - [ ] Documentation is complete (architecture, runbook, troubleshooting). |
| **Dev/Staging Deployment** | [e.g., "Deployed to staging 2025-01-20" or "Link to staging environment"] | - [ ] Infrastructure is validated in non-production environment. |
| **Production Deployment** | [e.g., "Deployed to production 2025-01-25" or "Link to prod environment"] | - [ ] Infrastructure is deployed to production with monitoring. |
| **Post-Deployment Validation** | [e.g., "All health checks passing, monitoring active" or "Validation report"] | - [ ] Production infrastructure is validated and monitored. |

---

## IaC Implementation Workflow

Follow this workflow to ensure safe, tested, and reviewable infrastructure code following IaC best practices.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write IaC Code** | [e.g., "Created Terraform module in terraform/modules/prod-cluster/" or "Link to commit"] | - [ ] IaC code is declarative, version-controlled, and follows conventions. |
| **2. Write Automated Tests** | [e.g., "Created terratest tests validating cluster config" or "Link to tests"] | - [ ] Automated tests validate infrastructure correctness. |
| **3. Run Static Analysis** | [e.g., "tflint, checkov, and tfsec passed" or "Link to scan results"] | - [ ] Static analysis tools validate security and best practices. |
| **4. Plan (Dry-Run)** | [e.g., "terraform plan shows 45 resources to create" or "Link to plan output"] | - [ ] Plan/dry-run output reviewed for expected changes only. |
| **5. Cost Estimation** | [e.g., "infracost shows $500/month cost" or "Link to cost report"] | - [ ] Cost estimated and approved before apply. |
| **6. Code Review** | [e.g., "PR #789 approved by 2 reviewers" or "Status: Approved"] | - [ ] IaC code reviewed for correctness, security, maintainability. |
| **7. Deploy to Dev/Staging** | [e.g., "Applied to staging environment" or "Link to staging deployment"] | - [ ] Infrastructure deployed to non-production for validation. |
| **8. Validate Deployment** | [e.g., "All resources created, health checks passing" or "Validation report"] | - [ ] Deployed infrastructure validated (health checks, connectivity, functionality). |
| **9. Run Integration Tests** | [e.g., "Integration tests passed (deployed app to cluster successfully)" or "Link to tests"] | - [ ] Integration tests validate infrastructure works end-to-end. |
| **10. Deploy to Production** | [e.g., "Applied to production with approval" or "Link to deployment"] | - [ ] Production deployment executed with proper approval and monitoring. |
| **11. Post-Deployment Validation** | [e.g., "Smoke tests passed, monitoring active, alerts configured" or "Report"] | - [ ] Production infrastructure validated and monitored. |

#### IaC Implementation Notes

> Document infrastructure code structure, modules used, state management, and deployment approach.

**IaC Code Structure:**
```
terraform/
├── modules/
│   └── production-cluster/
│       ├── main.tf          # Resource definitions
│       ├── variables.tf     # Input variables
│       ├── outputs.tf       # Output values
│       └── versions.tf      # Provider version constraints
├── environments/
│   ├── dev/
│   ├── staging/
│   └── production/
│       ├── main.tf          # Environment config
│       ├── backend.tf       # State backend config
│       └── terraform.tfvars # Environment variables
└── tests/
    └── cluster_test.go      # Automated tests
```

**State Management:**
* [e.g., "Terraform state stored in S3 bucket with DynamoDB locking"]
* [e.g., "State encryption enabled, versioning enabled for rollback capability"]
* [e.g., "Separate state files per environment (dev/staging/prod)"]

**Modules & Reusability:**
* [e.g., "Using official AWS EKS module v19.0 with custom wrapper"]
* [e.g., "Created reusable networking module for VPC peering"]

**CI/CD Integration:**
* [e.g., "GitHub Actions workflow runs terraform plan on PR, apply on merge to main"]
* [e.g., "Manual approval required for production deployment"]
* [e.g., "Automated drift detection runs daily, alerts on state drift"]

**Secrets Management:**
* [e.g., "Secrets stored in AWS Secrets Manager, referenced via data source"]
* [e.g., "No hardcoded credentials - use IRSA for authentication"]

---

## Infrastructure Validation & Deployment

| Task | Detail/Link |
| :--- | :--- |
| **IaC Code Location** | [Path, e.g., "terraform/modules/production-cluster/" or GitHub link] |
| **State Backend** | [e.g., "S3: my-company-terraform-state, DynamoDB: terraform-locks"] |
| **Automated Tests** | [e.g., "terratest: 15 tests, all passing" or "Link to test results"] |
| **Static Analysis Results** | [e.g., "tflint: 0 issues, checkov: 0 failures, tfsec: 0 high/critical" or "Link to reports"] |
| **Cost Estimate** | [e.g., "$500/month (infracost report)" or "Link to cost analysis"] |
| **Security Review** | [e.g., "Security team approved 2025-01-18, Checkov passed" or "Link to review"] |
| **Code Review** | [e.g., "PR #789 approved by Alice, Bob" or "Link to PR"] |
| **Staging Deployment** | [e.g., "Deployed to staging 2025-01-20, validated 2025-01-21" or "Link to environment"] |
| **Production Deployment** | [e.g., "Deployed to production 2025-01-25 with approval" or "Link to deployment log"] |
| **Monitoring & Alerts** | [e.g., "Datadog dashboard: prod-cluster-health, 10 alerts configured" or "Link to dashboard"] |
| **Documentation** | [e.g., "Runbook: docs/runbooks/prod-cluster.md, Architecture: docs/architecture/prod-cluster.md"] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Runbook Complete?** | [e.g., "Yes - created runbook with common operations and troubleshooting" or "Link to runbook"] |
| **Monitoring & Alerts?** | [e.g., "Yes - 10 alerts configured, dashboard created" or "Link to dashboard"] |
| **Backup/DR Tested?** | [e.g., "Yes - tested backup restore successfully" or "DR test scheduled for 2025-02-01"] |
| **Cost Optimization Review?** | [e.g., "Yes - using Savings Plans for 30% cost reduction" or "Review in 30 days"] |
| **Documentation As Code?** | [e.g., "Yes - all docs in Git, versioned with infrastructure code" or "Link to docs"] |
| **Team Training?** | [e.g., "Yes - conducted training session 2025-01-26" or "Training scheduled for 2025-02-01"] |
| **Drift Detection?** | [e.g., "Yes - automated daily drift detection with Terraform Cloud" or "Not yet - created INFRA-567"] |
| **Post-Implementation Review?** | [e.g., "Scheduled for 2025-02-15 (30 days post-deployment)" or "Not needed"] |
| **Reusable Patterns Documented?** | [e.g., "Yes - added to team IaC pattern library" or "Link to pattern doc"] |

### Completion Checklist

* [ ] Architecture design is documented and reviewed.
* [ ] IaC code is declarative, version-controlled, and follows team conventions.
* [ ] Automated tests validate infrastructure configuration.
* [ ] Static analysis passed (tflint, checkov, tfsec, or equivalent).
* [ ] Cost estimated and approved (within budget).
* [ ] Security review passed (encryption, IAM, network security validated).
* [ ] Code reviewed by infrastructure team (minimum 2 reviewers).
* [ ] Infrastructure validated in non-production environment (staging).
* [ ] Integration tests passed (end-to-end validation).
* [ ] Production deployment executed with proper approval.
* [ ] Post-deployment validation passed (health checks, smoke tests).
* [ ] Monitoring and alerts configured and active.
* [ ] Runbook documentation complete (operations, troubleshooting, rollback).
* [ ] Architecture documentation updated to reflect new infrastructure.
* [ ] State backend configured with locking and encryption.
* [ ] Backup/disaster recovery tested [if applicable].
* [ ] Documentation as code (all docs versioned with infrastructure code).

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows. You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
