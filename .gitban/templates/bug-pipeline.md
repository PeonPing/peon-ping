---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the systematic investigation and resolution of data pipeline errors, synchronization issues, data quality problems, and integration failures.
use_case: Use this for data pipeline bugs that require methodical troubleshooting, root cause analysis, and verification. Best for issues affecting ETL processes, data synchronization, integration failures, or data quality problems.
patterns_used:
  - section: "Pipeline Issue Overview"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Pipeline Documentation Review"
    pattern: "Pattern 2: Structured Review"
  - section: "Troubleshooting Investigation"
    pattern: "Pattern 3: Iterative Log"
  - section: "Resolution Workflow"
    pattern: "Pattern 4: Process Workflow"
  - section: "Validation & Closeout"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Bug: [Pipeline Issue Title]

**When to use this template:** Use this for data pipeline errors, synchronization issues, data quality problems, or integration failures. This is a systematic troubleshooting and resolution template - not a bug report. Best for issues that require investigation, root cause analysis, and verification.

**When NOT to use this template:** This is a specialized template for pipeline-specific issues. For general bugs use `bug.md`, for UI bugs use `bug-ui.md`, for production incidents requiring immediate response use `bug-production.md`, or if you're stuck on an issue use `spike-troubleshooting.md`.

---

## Pipeline Issue Overview

* **Pipeline/Integration:** [e.g., User Events ETL, Order Sync Service, Analytics Data Lake]
* **Affected System(s):** [e.g., PostgreSQL → Kafka → Snowflake, API Gateway → Internal Service]
* **Error Signature:** [e.g., "Record count mismatch", "Duplicate key violation", "Timeout after 30s"]
* **Impact Scope:** [e.g., 1,200 records failed (0.3% of daily volume), Downstream reports stale by 6 hours]
* **First Observed:** [e.g., 2025-01-15 14:23 UTC]
* **Related Ticket(s):** [e.g., Link to incident ticket, monitoring alert]

**Required Checks:**
* [ ] **Pipeline/Integration** is identified above.
* [ ] **Error Signature** is documented.
* [ ] **Impact Scope** is quantified.

---

## Pipeline Documentation Review

First, confirm the minimum required documentation has been reviewed for context.

* [ ] `Pipeline Architecture Diagram` reviewed.
* [ ] `Data Schema Documentation` reviewed.
* [ ] `Previous Incidents / Postmortems` reviewed.
* [ ] `Monitoring Dashboards / Logs` reviewed.

Use the table below to log findings. Add rows for other document types as needed.

| Document Type | Link / Location | Key Findings / Action Required |
| :--- | :--- | :--- |
| **Architecture Diagram** | [Link] | [e.g., "Shows 3-stage ETL with Redis cache layer"] |
| **Schema Docs** | [Link] | [e.g., "Column 'user_id' is NOT NULL but upstream allows nulls"] |
| **Previous Incidents** | [Link] | [e.g., "Similar issue in Q3 2024 - fixed by adding retry logic"] |
| **Monitoring Logs** | [Link] | [e.g., "CloudWatch shows 500 errors starting at 14:20 UTC"] |
| **Runbook (if exists)** | [Link] | [e.g., "Runbook exists but outdated - missing new Kafka topic"] |
| **ADR (New)** | **N/A** (Action Item) | [e.g., "**Finding:** This fix requires changing retry strategy. **Action:** Must write new ADR."] |
| **Other Doc Type** | [Link] | [Findings...] |

---

## Troubleshooting Investigation

| Iteration # | Hypothesis | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., Hypothesis: Upstream API is returning null values] | [e.g., Test: Query last 100 source records] | [e.g., Outcome: Confirmed - 12 records have null user_id] |
| **2** | [Hypothesis...] | [Test...] | [Outcome...] |

---
#### Iteration 1: [Hypothesis Summary]

**Hypothesis:** [e.g., Problem assumption: The upstream API is returning null values for user_id field.]

**Test/Action Taken:** [e.g., Diagnostic action: Queried last 100 records from source API endpoint. Checked application logs for validation errors.]

**Outcome:** [e.g., Result: Confirmed - 12 out of 100 records contain null user_id values. Error started after upstream service deployed version 2.3.0 on 2025-01-15 14:15 UTC.]

**Supporting Evidence:**
```
[Paste relevant log snippets, query results, or stack traces here]
```

---
#### Iteration 2: [Hypothesis Summary]

**Hypothesis:** [Hypothesis...]

**Test/Action Taken:** [Action...]

**Outcome:** [Outcome...]

**Supporting Evidence:**
```
[Evidence...]
```

*(Copy and paste the 'Iteration N' block above for each subsequent test cycle.)*

---

## Root Cause Analysis

**Root Cause:** [e.g., Upstream service v2.3.0 introduced a bug where optional fields are sent as null instead of being omitted. Our pipeline expects either a valid value or field absence, but not explicit nulls.]

**Why It Wasn't Caught Earlier:** [e.g., Integration tests only covered happy path. No tests for null handling in optional fields.]

**Blast Radius:** [e.g., Affects all ETL jobs consuming this API. Estimated 1,200 records failed validation across 3 pipelines.]

---

## Resolution Workflow

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Test** | [e.g., Link to test commit or Test file: `tests/test_null_handling.py`] | - [ ] A failing test is committed that reproduces the bug. |
| **2. Implement Fix** | [e.g., Summary: Added null coalescing in transformation layer] | - [ ] Code changes are complete and committed. |
| **3. Verify Test Passes** | [e.g., Test Run ID or CI build link] | - [ ] The original failing test now passes. |
| **4. Run Full Regression** | [e.g., Link to full test suite run] | - [ ] Full regression suite passed (no new failures). |
| **5. Deploy to Staging** | [e.g., Deployed to staging on 2025-01-16 10:00 UTC] | - [ ] Fix is deployed and verified in staging environment. |
| **6. Production Deploy** | [e.g., Deployed to prod on 2025-01-16 15:00 UTC] | - [ ] Fix is deployed to production. |
| **7. Monitor & Verify** | [e.g., Monitored for 24 hours - no errors] | - [ ] Production metrics confirm issue is resolved. |

#### Fix Implementation Details (optional)

> Paste the **failing test code** and/or **fix implementation** here for review and documentation.

```python
# Example failing test
def test_null_user_id_handling():
    # This test reproduces the bug
    raw_data = {"user_id": None, "event": "click"}
    result = transform_event(raw_data)
    assert result is not None  # Should handle gracefully
```

```python
# Example fix
def transform_event(raw_data):
    # Coalesce null to default or skip
    user_id = raw_data.get("user_id") or "UNKNOWN"
    return {"user_id": user_id, "event": raw_data["event"]}
```

---

## Validation & Closeout

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | [e.g., Link to PR #456] |
| **Data Quality Check** | [e.g., Verified 100% success rate for 24 hours post-deploy] |
| **Monitoring Alert** | [e.g., Updated alert threshold - link to monitoring config] |
| **Backfill Required?** | [e.g., Yes - backfilled 1,200 failed records on 2025-01-17] |
| **Final Artifact** | [e.g., Link to postmortem doc or ADR] |


### Follow-up & Lessons Learned

| Topic | Status / Action Required |
| :--- | :--- |
| **Postmortem Required?** | [e.g., Yes - P1 data quality issue affecting downstream reports] |
| **Integration Tests Gap** | [e.g., Created new ticket `TEST-789` to add null handling tests] |
| **Upstream Service Fix** | [e.g., Opened ticket `EXT-123` with Platform team to fix null behavior] |
| **Monitoring Improvements** | [e.g., Created new ticket `MON-456` to add data quality metrics] |
| **Runbook Update** | [e.g., Yes - updated runbook with null handling section] |

### Completion Checklist

* [ ] Root cause was documented in detail.
* [ ] All pipeline tests are passing.
* [ ] PR was approved and merged.
* [ ] Fix is deployed to production.
* [ ] Production metrics confirm resolution (monitored for at least 24 hours).
* [ ] Data backfill completed (if required).
* [ ] Monitoring alerts updated (if required).
* [ ] Documentation/runbook is updated.
* [ ] Follow-up actions are documented with ticket links.
* [ ] Associated ticket is closed.

---

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
