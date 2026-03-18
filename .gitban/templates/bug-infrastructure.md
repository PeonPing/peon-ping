---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the process of investigating and fixing infrastructure and data pipeline bugs using Infrastructure as Code (IaC) practices.
use_case: Use this for infrastructure and data pipeline bug fixes where the team is expected to implement fixes via IaC (Terraform, Pulumi, CloudFormation, etc.). If the team is not currently using IaC, this template will guide the creation of an IaC implementation plan. DO NOT use this for application-level bugs or bugs in non-infrastructure systems.
patterns_used:
  - section: "When to Use This Template"
    pattern: "Guidance Header"
  - section: "Bug Overview & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Pipeline Documentation Review"
    pattern: "Pattern 2: Structured Review (Doc Review)"
  - section: "Impact Assessment"
    pattern: "Custom Section"
  - section: "Environment & Data State"
    pattern: "Custom Section"
  - section: "Root Cause Investigation"
    pattern: "Pattern 3: Iterative Log (Troubleshooting)"
  - section: "Solution Design & IaC Implementation"
    pattern: "Pattern 4: Process Workflow (TDD Fix)"
  - section: "Testing & Verification"
    pattern: "Custom Section"
  - section: "Validation & Finalization"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Infrastructure Bug Fix Template

## When to Use This Template

**USE THIS TEMPLATE FOR:**
- Data pipeline failures (ETL/ELT, streaming, batch processing)
- Infrastructure service degradation or outages
- Resource provisioning or configuration bugs
- Networking, storage, or compute infrastructure issues
- IaC drift or configuration management problems
- Data quality issues caused by infrastructure

**DO NOT USE THIS TEMPLATE FOR:**
- Application code bugs (use `bug.md` instead)
- Feature requests or enhancements (use `feature.md`)
- Exploratory infrastructure work (use `spike.md`)
- Non-infrastructure bugs (web UI, API logic, etc.)

**ASSUMPTION:** Your team uses or will use Infrastructure as Code (IaC). If not currently using IaC, this template includes a section to plan IaC adoption as part of the fix.

---

## Bug Overview & Context

* **Ticket/Alert ID:** [e.g., INFRA-4567 or PagerDuty Alert #8901]
* **Affected Pipeline/Service:** [e.g., "customer-events-streaming-pipeline" or "s3-to-redshift-batch-loader"]
* **Severity:** [e.g., P0 - Data Loss, P1 - Degraded Performance, P2 - Minor Issue]
* **Discovery Date/Time:** [e.g., 2025-11-19 14:32 UTC]
* **Reporter:** [e.g., Monitoring Alert or Team Member Name]

**Required Checks:**
* [ ] Ticket/Alert ID is linked above
* [ ] Affected pipeline/service is clearly identified
* [ ] Severity level is assigned based on impact assessment

---

## Pipeline Documentation Review

Review existing infrastructure documentation to understand the system before debugging.

* [ ] `README.md` or pipeline documentation reviewed
* [ ] IaC codebase (Terraform/Pulumi/etc.) reviewed
* [ ] Data schema or contract documentation reviewed
* [ ] Runbook or incident playbook reviewed
* [ ] Previous postmortems or related incident tickets reviewed

Use the table below to log findings from documentation review. Add rows as needed.

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **Pipeline README** | [Link] | [e.g., "Documentation outdated - missing v2.3 schema changes"] |
| **IaC Code** | [Link] | [e.g., "Terraform state shows drift in IAM roles"] |
| **Data Schema** | [Link] | [e.g., "Schema version mismatch between source and sink"] |
| **Runbook** | [Link] | [e.g., "Runbook covers error handling but not this failure mode"] |
| **Previous Incidents** | [Link] | [e.g., "Similar issue occurred 3 months ago, fixed with manual config change (not in IaC!)"] |
| **IaC Status** | **N/A** (Assessment) | [e.g., "**Finding:** Team is NOT using IaC for this pipeline. **Action:** Must create IaC implementation plan (see section below)."] |

---

## Impact Assessment

Document the blast radius and business impact of this bug.

| Impact Category | Severity | Details |
| :--- | :--- | :--- |
| **Data Loss** | [High/Medium/Low/None] | [e.g., "100K events lost during 2-hour outage"] |
| **Data Quality** | [High/Medium/Low/None] | [e.g., "Incorrect timestamps on 500K records"] |
| **System Availability** | [High/Medium/Low/None] | [e.g., "Pipeline down for 4 hours"] |
| **Downstream Impact** | [High/Medium/Low/None] | [e.g., "BI dashboards showing stale data"] |
| **SLA Breach** | [Yes/No] | [e.g., "Yes - 99.9% uptime SLA breached"] |
| **Customer Impact** | [High/Medium/Low/None] | [e.g., "Customer-facing analytics delayed by 6 hours"] |

**Business Justification for Priority:**
[Explain why this bug has the assigned priority level based on the impact assessment above. e.g., "P0 because data loss affects billing accuracy and violates compliance requirements."]

---

## Environment & Data State

Capture detailed environment and data state information to enable reproduction and debugging.

### Infrastructure Environment

| Component | Value | Notes |
| :--- | :--- | :--- |
| **Cloud Provider** | [e.g., AWS, GCP, Azure] | [e.g., "us-east-1 region"] |
| **IaC Tool** | [e.g., Terraform 1.6.3, Pulumi, CloudFormation, **NONE**] | [If NONE, note in "IaC Status" above] |
| **Pipeline Framework** | [e.g., Apache Airflow 2.7.1, AWS Glue, dbt 1.6] | [Version is critical] |
| **Compute Resources** | [e.g., ECS Fargate, Lambda, Kubernetes] | [Instance types, memory, CPU] |
| **Storage** | [e.g., S3, GCS, Redshift, Snowflake] | [Buckets, databases, schemas] |
| **Networking** | [e.g., VPC, Subnets, Security Groups] | [Relevant network config] |

### Data State

| Data Aspect | Value | Notes |
| :--- | :--- | :--- |
| **Data Source** | [e.g., Kafka topic, S3 bucket, API endpoint] | [Connection details] |
| **Data Volume** | [e.g., 10M records/day] | [Scale at time of bug] |
| **Data Format** | [e.g., JSON, Parquet, Avro] | [Schema version if applicable] |
| **Time Range** | [e.g., 2025-11-19 00:00 - 06:00 UTC] | [When bug occurred] |
| **Bad Data Sample** | [Link to S3/file] | [Example of corrupted/failed data] |

### Steps to Reproduce

Provide detailed, numbered steps to recreate the bug in a test environment.

**Prerequisites:**
* [e.g., Access to staging environment]
* [e.g., Test dataset loaded in S3 bucket `s3://test-bucket/bug-repro/`]
* [e.g., IaC codebase checked out locally]

**Reproduction Steps:**
1. [e.g., Deploy pipeline to staging using `terraform apply -var-file=staging.tfvars`]
2. [e.g., Trigger pipeline with test dataset: `airflow dags trigger customer_events_pipeline`]
3. [e.g., Wait for pipeline to process batch (approx 10 minutes)]
4. [e.g., Observe failure in Airflow UI - task `transform_events` fails with error: "NullPointerException in timestamp parsing"]
5. [e.g., Check CloudWatch logs: ERROR in `events-transformer` Lambda function]

**Expected Behavior:**
[e.g., "Pipeline should successfully transform all events and load to Redshift with valid timestamps."]

**Actual Behavior:**
[e.g., "Pipeline fails during transformation step with NullPointerException. 100K events are not loaded to Redshift."]

**Reproduction Rate:**
[e.g., "100% - fails every time with this test dataset" or "Intermittent - fails ~30% of the time"]

**Error Messages / Stack Traces:**
```
[Paste exact error message and stack trace here]
```

---

## Root Cause Investigation

Use this section to systematically investigate the root cause. Document each hypothesis, test, and finding.

| Iteration # | Hypothesis | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., Hypothesis: Lambda function timeout is too short] | [e.g., Test: Increased timeout from 60s to 300s] | [e.g., Outcome: Rejected - still fails] |
| **2** | [e.g., Hypothesis: Timestamp field contains nulls] | [e.g., Test: Queried raw data for null timestamps] | [e.g., Outcome: Confirmed - 0.1% of records have null timestamps] |
| **3** | [e.g., Hypothesis: Code doesn't handle null timestamps] | [e.g., Test: Reviewed Lambda code - no null check] | [e.g., Outcome: Confirmed - root cause identified] |

---

#### Iteration 1: [Hypothesis Summary]

**Hypothesis:** [e.g., Lambda function is timing out due to large batch size]

**Test/Action Taken:** [e.g., Increased Lambda timeout from 60s to 300s in Terraform config, redeployed, retested]

**Outcome:** [e.g., Rejected - pipeline still fails with same error, timeout is not the issue]

---

#### Iteration 2: [Hypothesis Summary]

**Hypothesis:** [e.g., Raw data contains null timestamp values that are not handled]

**Test/Action Taken:** [e.g., Queried S3 raw data with Athena: `SELECT COUNT(*) FROM events WHERE timestamp IS NULL` - result: 1,234 records out of 1.2M]

**Outcome:** [e.g., Confirmed - 0.1% of records have null timestamps]

---

#### Iteration 3: [Hypothesis Summary]

**Hypothesis:** [e.g., Lambda transformation code does not handle null timestamps gracefully]

**Test/Action Taken:** [e.g., Reviewed `events-transformer` Lambda code - found timestamp parsing logic has no null check, throws NullPointerException]

**Outcome:** [e.g., Confirmed - this is the root cause. Code needs defensive null handling.]

---

### Root Cause Summary

**Root Cause:**
[Provide a clear, concise summary of the root cause once identified. e.g., "The `events-transformer` Lambda function does not handle null timestamp values in the raw data. When a null timestamp is encountered, the parsing logic throws a NullPointerException, causing the entire batch to fail and preventing data from loading to Redshift."]

**Code/Config Location:**
[e.g., "File: `lambda/events-transformer/handler.py`, Line: 142"]

**Why This Happened:**
[e.g., "Null timestamps were not part of the original data contract. Recent upstream changes introduced these null values without updating our transformation logic or data validation."]

---

## Solution Design & IaC Implementation

### Fix Strategy

[Describe the high-level approach to fix the bug. e.g., "Add null timestamp handling to Lambda transformation logic. If timestamp is null, set to a default sentinel value (e.g., Unix epoch 0) or filter out the record based on business rules. Implement fix via IaC by updating Lambda function code in Terraform module."]

**Rollback Plan:**
[e.g., "If fix causes new issues, rollback to previous Lambda version using Terraform state rollback: `terraform apply -var='lambda_version=v1.2.3'`"]

---

### IaC Implementation Workflow

This workflow enforces IaC best practices for infrastructure bug fixes. All changes must be made via IaC code, tested, and deployed through IaC tooling.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Test** | [e.g., Link to test case or test script] | - [ ] Test that reproduces the bug is committed |
| **2. Update IaC Code** | [e.g., Summary: Updated Lambda function code in `terraform/modules/events-transformer/`] | - [ ] IaC code changes are complete (Terraform/Pulumi/etc.) |
| **3. Test in Staging** | [e.g., Deployed to staging with `terraform apply`, test passed] | - [ ] Fix validated in staging environment via IaC deployment |
| **4. Code Review** | [e.g., Link to PR] | - [ ] IaC code review approved |
| **5. Deploy to Production** | [e.g., Deployed to prod with `terraform apply -var-file=prod.tfvars`] | - [ ] Production deployment complete via IaC |
| **6. Regression Testing** | [e.g., Link to test run] | - [ ] Full regression suite passed in production |

#### IaC Code Changes

> Paste relevant IaC code changes here (Terraform HCL, Pulumi code, CloudFormation YAML, etc.)

```hcl
// Example: Terraform module update
resource "aws_lambda_function" "events_transformer" {
  function_name = "events-transformer"
  handler       = "handler.transform_events"
  runtime       = "python3.11"

  # Updated code with null timestamp handling
  filename      = "lambda/events-transformer-v1.3.0.zip"
  source_code_hash = filebase64sha256("lambda/events-transformer-v1.3.0.zip")

  timeout = 300
  memory_size = 1024
}
```

---

### If Team Is NOT Using IaC (optional)

**[CONDITIONAL SECTION - Only fill this out if your team is not currently using IaC for this pipeline]**

If your team is not using IaC, you MUST NOT implement this bug fix with manual infrastructure changes. Instead, use gitban to plan an IaC implementation.

**Action Required:**
* [ ] Create a new gitban card (type: `chore` or `spike`) to plan IaC adoption for this pipeline
* [ ] Card title: [e.g., "Implement IaC for customer-events-streaming-pipeline"]
* [ ] Card ID: [e.g., C0001 or spike-iac-customer-events]
* [ ] Link to card: [Link to gitban card]

**Temporary Manual Fix (If Absolutely Necessary):**
If business urgency requires a manual hotfix before IaC implementation:
* [ ] Document manual fix steps below
* [ ] Create follow-up card to implement fix properly via IaC
* [ ] Follow-up card ID: [e.g., C0002]

**Manual Fix Steps:**
1. [e.g., SSH to production Lambda environment]
2. [e.g., Update handler.py with null check]
3. [e.g., Redeploy Lambda manually via AWS Console]

**WARNING:** Manual fixes create configuration drift and technical debt. The follow-up IaC card is MANDATORY.

---

## Testing & Verification

Plan comprehensive testing to ensure the fix works and doesn't introduce regressions.

### Test Plan

| Test Type | Description | Status | Notes |
| :--- | :--- | :--- | :--- |
| **Bug Reproduction** | [e.g., Run original repro steps with test dataset] | - [ ] Pass | [e.g., "Must fail before fix, pass after fix"] |
| **Null Timestamp Handling** | [e.g., Test with 100% null timestamps] | - [ ] Pass | [e.g., "Edge case - all records null"] |
| **Mixed Data** | [e.g., Test with 50% null, 50% valid timestamps] | - [ ] Pass | [e.g., "Realistic scenario"] |
| **Data Quality Check** | [e.g., Verify output data schema and values] | - [ ] Pass | [e.g., "Check Redshift for correct records"] |
| **Regression - Happy Path** | [e.g., Test with 100% valid data (no nulls)] | - [ ] Pass | [e.g., "Ensure we didn't break existing logic"] |
| **Performance** | [e.g., Test with 10M record batch] | - [ ] Pass | [e.g., "Ensure fix doesn't degrade performance"] |
| **IaC Validation** | [e.g., Run `terraform plan` and `terraform validate`] | - [ ] Pass | [e.g., "IaC syntax and logic are correct"] |

### Verification Checklist

* [ ] Bug is no longer reproducible with original test case
* [ ] All test cases in test plan above pass
* [ ] IaC deployment succeeded in staging
* [ ] IaC deployment succeeded in production
* [ ] Manual testing confirms fix in production
* [ ] Monitoring/alerts confirm pipeline is healthy
* [ ] No new errors introduced (check logs)

---

## Validation & Finalization

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | [Link to PR] |
| **IaC Review** | [Link to Terraform/IaC PR] |
| **Staging Validation** | [Verified by Name/Date] |
| **Production Validation** | [Verified by Name/Date] |
| **Monitoring** | [Link to dashboard showing healthy metrics] |

### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Postmortem Required?** | [e.g., Yes (P0 data loss) or No (P2 minor issue)] |
| **IaC Adoption Status** | [e.g., Complete or In Progress (card CHORE-123)] |
| **Data Contract Update** | [e.g., Yes - need to formalize null handling in upstream contract] |
| **Monitoring Gaps** | [e.g., Created ticket INFRA-999 to add null timestamp alert] |
| **Upstream Bug** | [e.g., Contacted Team X about null timestamp source] |
| **Documentation Update** | [e.g., Updated runbook with null timestamp handling notes] |

### Completion Checklist

* [ ] Root cause is fully understood and documented
* [ ] Fix is implemented via IaC (or IaC adoption card is created)
* [ ] All tests pass (bug repro, edge cases, regression)
* [ ] IaC code review is approved
* [ ] Fix is deployed to production via IaC
* [ ] Production validation confirms fix works
* [ ] Monitoring confirms pipeline health
* [ ] Postmortem completed (if required)
* [ ] Follow-up actions documented (gitban cards created)
* [ ] Associated ticket is closed

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
