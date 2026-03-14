---
# Template Schema Overview
# This block describes the purpose of this template and the patterns it uses.
description: A template for tracking the process of investigating and fixing a bug using modern best practices including TDD, IaC, DaC, and comprehensive testing strategies.
use_case: Use this for professional bug fixes that follow industry best practices. This template enforces Test-Driven Development (TDD), Infrastructure as Code (IaC), Documentation as Code (DaC), and prevents technical debt through rigorous processes.
patterns_used:
  - section: "Bug Overview & Context"
    pattern: "Pattern 1: Section Header (Overview & Context)"
  - section: "Documentation & Code Review"
    pattern: "Pattern 2: Structured Review (Doc Review)"
  - section: "Root Cause Investigation"
    pattern: "Pattern 3: Iterative Log (Troubleshooting)"
  - section: "TDD Implementation Workflow"
    pattern: "Pattern 4: Process Workflow (TDD Fix)"
  - section: "Validation & Finalization"
    pattern: "Pattern 5: Closeout & Follow-up"
---

# Bug Fix Template

## Bug Overview & Context

* **Ticket/Issue ID:** [e.g., JIRA-1234 or GitHub Issue #567]
* **Affected Component/Service:** [e.g., "Authentication Service" or "Payment Processing Module"]
* **Severity Level:** [e.g., P0 - Critical/Production Down, P1 - High/Major Feature Broken, P2 - Medium/Minor Issue]
* **Discovered By:** [e.g., Customer Report, Monitoring Alert, QA Testing]
* **Discovery Date:** [e.g., 2025-11-19]
* **Reporter:** [e.g., Name or Support Ticket ID]

**Required Checks:**
* [ ] Ticket/Issue ID is linked above
* [ ] Component/Service is clearly identified
* [ ] Severity level is assigned based on impact

---

## Bug Description

### What's Broken

[Provide a clear, concise description of the bug. Focus on the observable problem, not the solution.]

**Example:** "Users cannot complete checkout when using saved payment methods. The 'Confirm Payment' button returns a 500 error instead of processing the transaction."

### Expected Behavior

[Describe what should happen when the system works correctly.]

**Example:** "When a user clicks 'Confirm Payment' with a saved payment method, the system should process the transaction and redirect to the order confirmation page within 2 seconds."

### Actual Behavior

[Describe what actually happens when the bug occurs.]

**Example:** "When a user clicks 'Confirm Payment' with a saved payment method, the system returns a 500 Internal Server Error and displays 'Transaction Failed' message. No transaction is processed."

### Reproduction Rate

[How often does this bug occur?]
* [ ] 100% - Always reproduces
* [ ] 75% - Usually reproduces
* [ ] 50% - Sometimes reproduces
* [ ] 25% - Rarely reproduces
* [ ] Cannot reproduce consistently

---

## Steps to Reproduce

**Prerequisites:**
* [e.g., User account with saved payment method]
* [e.g., Test environment access]
* [e.g., Items in shopping cart]

**Reproduction Steps:**

1. [e.g., Log in to application as test user `test@example.com`]
2. [e.g., Add item to cart (SKU: TEST-001)]
3. [e.g., Navigate to checkout page]
4. [e.g., Select saved payment method "Visa ending in 1234"]
5. [e.g., Click "Confirm Payment" button]
6. [e.g., Observe 500 error response]

**Error Messages / Stack Traces:**

```
[Paste exact error message and stack trace here]

Example:
500 Internal Server Error
{
  "error": "NullPointerException: Cannot read property 'token' of undefined",
  "timestamp": "2025-11-19T14:32:00Z",
  "path": "/api/payments/process"
}
```

---

## Environment Details

| Environment Aspect | Required | Value | Notes |
| :--- | :--- | :--- | :--- |
| **Environment** | Optional | [e.g., Production, Staging, Local] | [Where bug occurs] |
| **OS** | Optional | [e.g., Ubuntu 22.04, Windows 11, macOS 14] | [Operating system] |
| **Browser** | Optional | [e.g., Chrome 120, Firefox 121, Safari 17] | [If web application] |
| **Application Version** | Optional | [e.g., v2.5.3] | [Current deployed version] |
| **Database Version** | Optional | [e.g., PostgreSQL 15.2] | [If applicable] |
| **Runtime/Framework** | Optional | [e.g., Node.js 20.10, Python 3.11, .NET 8] | [Language runtime] |
| **Dependencies** | Optional | [e.g., Express 4.18.2, Django 4.2] | [Key libraries] |
| **Infrastructure** | Optional | [e.g., AWS ECS, Kubernetes 1.28, Docker] | [Deployment platform] |

---

## Impact Assessment

| Impact Category | Severity | Details |
| :--- | :--- | :--- |
| **User Impact** | [High/Medium/Low/None] | [e.g., "All checkout attempts fail - 0% success rate"] |
| **Business Impact** | [High/Medium/Low/None] | [e.g., "Revenue loss estimated at $10K/hour"] |
| **System Impact** | [High/Medium/Low/None] | [e.g., "Payment service throwing errors, affecting API health"] |
| **Data Impact** | [High/Medium/Low/None] | [e.g., "No data loss, but failed transactions not logged"] |
| **Security Impact** | [High/Medium/Low/None] | [e.g., "None - error does not expose sensitive data"] |

**Business Justification for Priority:**

[Explain why this bug has the assigned priority level based on the impact above. This helps stakeholders understand urgency.]

**Example:** "Assigned P0 because all checkout functionality is broken, resulting in direct revenue loss and customer complaints. This affects 100% of purchase attempts."

---

## Documentation & Code Review

Before diving into troubleshooting, review existing documentation and code to understand the system context.

| Item | Applicable | File / Location | Notes / Evidence | Key Findings / Action Required |
|---|:---:|---|---|---|
| README or component documentation reviewed | [yes/no] | README.md / docs/README.md / src/<component>/README.md | Verify usage examples, MCP config, quick start, card filename conventions | Example: "Documentation outdated - missing v2.5 payment flow changes." Action: Update README/docs to reflect current payment token field (`token`) and MCP config examples. |
| Related ADRs (Architecture Decision Records) reviewed | [yes/no] | docs/decisions/*.md (e.g., ADR-001-ephemeral-filenames.md) | Check ADRs that affect ID formats, filename patterns, or token handling | Example: "ADR-042 describes payment token handling — may be relevant." Action: Link ADRs to card and ensure implementation follows ADR or create follow-up ADR. |
| API documentation reviewed | [yes/no] | docs/api.md / openapi.yaml / docs/swagger.yaml / src/<service>/api_spec.md | Confirm endpoints, request/response schemas (e.g., payment token field), error formats | Example: "API spec shows required 'token' field - missing in client requests." Action: Align API spec and client code; update docs and add schema validation tests. |
| Test suite documentation reviewed | [yes/no] | TESTING.md / tests/ / scripts/run_tests_structured.py / docs/tests.md | Ensure test guidance, structured runner usage, required markers, and failing-to-passing workflow for TDD | Example: "No integration test for saved payment method flow." Action: Add failing test, implement fix, run via structured runner (python scripts/run_tests_structured.py), add markers and CI entry. |
| IaC configuration reviewed (Terraform, CloudFormation, etc.) | [yes/no] | infra/ / terraform/ / k8s/ / cloudformation/ / .github/workflows/ | Validate environment variables, secrets, deployment manifests, and any PAYMENT_TOKEN_FIELD or related configs | Example: "No PAYMENT_TOKEN_FIELD found in IaC." Action: Verify env/config names, add required variables to IaC, document changes, and run IaC plan in staging. |
| New Documentation (Action Item) | N/A | **N/A** | Use this row to record required docs to create/update after fix | Example Finding: "No documentation for payment error handling." Action: Create/update docs (DaC) and link to PR/issue; mark as done when published. |

---

## Root Cause Investigation

Use this section to systematically investigate the root cause. Document each hypothesis, test, and finding. This demonstrates rigorous debugging practices.

| Iteration # | Hypothesis | Test/Action Taken | Outcome / Findings |
| :---: | :--- | :--- | :--- |
| **1** | [e.g., Payment token is missing from request] | [e.g., Inspected request payload in browser DevTools] | [e.g., Confirmed - token field is undefined] |
| **2** | [e.g., Token retrieval from database fails] | [e.g., Checked database for saved payment record] | [e.g., Record exists with valid token] |
| **3** | [e.g., Frontend not sending token correctly] | [e.g., Reviewed frontend code - found token mapping bug] | [e.g., Root cause identified] |

---

### Hypothesis testing iterations

**Iteration 1:** [Hypothesis Summary]

**Hypothesis:** [e.g., The payment token is missing from the API request payload]

**Test/Action Taken:** [e.g., Used browser DevTools Network tab to inspect the POST request to `/api/payments/process`. Examined request body JSON.]

**Outcome:** [e.g., Confirmed - the request body shows `"token": undefined`. Expected a string token value like `"tok_abc123"`. This confirms the token is not being sent.]

---

**Iteration 2:** [Hypothesis Summary]

**Hypothesis:** [e.g., The token is not being retrieved from the database correctly]

**Test/Action Taken:** [e.g., Queried the database directly: `SELECT * FROM payment_methods WHERE user_id = 123 AND method_id = 'pm_xyz'`. Verified token column value.]

**Outcome:** [e.g., Rejected - Database record exists and has valid token value `"tok_abc123"`. The problem is not in data storage, but in data retrieval or mapping.]

---

**Iteration 3:** [Hypothesis Summary]

**Hypothesis:** [e.g., Frontend code is not correctly mapping the saved payment method token to the API request]

**Test/Action Taken:** [e.g., Reviewed frontend code in `CheckoutPage.tsx`. Found that the code references `paymentMethod.cardToken` but the object property is actually `paymentMethod.token` (no "card" prefix).]

**Outcome:** [e.g., Root cause identified - Property name mismatch. Frontend tries to access `paymentMethod.cardToken` (undefined) instead of `paymentMethod.token` (correct).]

---

### Root Cause Summary

**Root Cause:**

[Provide a clear, concise summary of the root cause once identified.]

**Example:** "The frontend code in `CheckoutPage.tsx` line 87 attempts to access `paymentMethod.cardToken`, but the API response object uses the property name `paymentMethod.token` (without 'card' prefix). This mismatch causes the token value to be undefined when constructing the payment request, resulting in a 500 error from the backend when it cannot validate the missing token."

**Code/Config Location:**

[e.g., "File: `src/components/CheckoutPage.tsx`, Line: 87"]

**Why This Happened:**

[e.g., "A recent API change in v2.5.0 standardized all token fields to use 'token' instead of 'cardToken'. The backend was updated, but the frontend was not updated to match the new property name."]

---

## Solution Design

### Fix Strategy

[Describe your approach to fixing the bug. This demonstrates thoughtful planning, not just rushing to code.]

**Example:** "Update the frontend code to use the correct property name `paymentMethod.token` instead of `paymentMethod.cardToken`. Add a TypeScript type definition to prevent similar property name mismatches in the future. Follow TDD approach: write a failing test first, implement the fix, then verify the test passes."

### Code Changes

[List the files and changes required. Be specific about what will change and why.]

**Example:**
* `src/components/CheckoutPage.tsx` - Update line 87 to use `paymentMethod.token`
* `src/types/PaymentMethod.ts` - Add strict TypeScript interface to enforce correct property names
* `src/components/CheckoutPage.test.tsx` - Add test case for saved payment method flow

### Rollback Plan

[Every fix needs a rollback plan in case the fix causes new issues. This is professional risk management.]

**Example:** "If the fix causes new issues in production, rollback to previous deployment using the CI/CD pipeline: `kubectl rollout undo deployment/checkout-service`. Estimated rollback time: 2 minutes. No data migration required for rollback."

---

## TDD Implementation Workflow

This section enforces Test-Driven Development (TDD) best practices. Each step must be completed in order, with checkboxes to track progress.

| Step | Status/Details | Universal Check |
| :---: | :--- | :---: |
| **1. Write Failing Test** | [e.g., Link to commit with test or Test file: `CheckoutPage.test.tsx`] | - [ ] A failing test that reproduces the bug is committed |
| **2. Verify Test Fails** | [e.g., Test run output showing failure] | - [ ] Test suite was run and the new test fails as expected |
| **3. Implement Code Fix** | [e.g., Summary: Updated property name in CheckoutPage.tsx] | - [ ] Code changes are complete and committed |
| **4. Verify Test Passes** | [e.g., Test run output showing pass] | - [ ] The original failing test now passes |
| **5. Run Full Test Suite** | [e.g., Link to CI/CD test run] | - [ ] All existing tests still pass (no regressions) |
| **6. Code Review** | [e.g., Link to PR #456] | - [ ] Code review approved by at least one peer |
| **7. Update Documentation** | [e.g., Updated API integration guide] | - [ ] Documentation is updated (DaC - Documentation as Code) |
| **8. Deploy to Staging** | [e.g., Deployed via CI/CD pipeline] | - [ ] Fix deployed to staging environment |
| **9. Staging Verification** | [e.g., Manual test passed in staging] | - [ ] Bug fix verified in staging environment |
| **10. Deploy to Production** | [e.g., Deployed via CI/CD pipeline] | - [ ] Fix deployed to production environment |
| **11. Production Verification** | [e.g., Monitoring shows successful transactions] | - [ ] Bug fix verified in production environment |

### Test Code (Failing Test)

> Paste the **failing test code** here as the "definition" of the bug. This test should fail before the fix and pass after the fix.

```typescript
// Example: CheckoutPage.test.tsx
describe('CheckoutPage - Saved Payment Methods', () => {
  it('should successfully process payment with saved payment method', async () => {
    // Arrange
    const mockPaymentMethod = {
      id: 'pm_123',
      token: 'tok_abc123',  // Note: correct property name
      last4: '1234',
      brand: 'visa'
    };

    render(<CheckoutPage paymentMethods={[mockPaymentMethod]} />);

    // Act
    fireEvent.click(screen.getByText('Confirm Payment'));

    // Assert
    await waitFor(() => {
      expect(mockApiClient.processPayment).toHaveBeenCalledWith({
        token: 'tok_abc123',  // Should receive the token
        amount: 1000
      });
    });
  });
});
```

---

## Infrastructure as Code (IaC) Considerations (optional)

**[Fill this section if the bug fix involves infrastructure changes]**

* [ ] Infrastructure changes required (e.g., environment variables, scaling, new resources)
* [ ] IaC code updated (Terraform, Pulumi, CloudFormation, Kubernetes manifests, etc.)
* [ ] IaC changes reviewed and approved
* [ ] IaC changes tested in non-production environment
* [ ] IaC changes deployed via automation (no manual changes)

| IaC Component | Change Required | Status |
| :--- | :--- | :--- |
| **[e.g., Environment Variables]** | [e.g., Add PAYMENT_TOKEN_FIELD config] | [e.g., Updated in `terraform/variables.tf`] |
| **[e.g., Scaling]** | [e.g., Increase memory limit] | [e.g., Updated in `k8s/deployment.yaml`] |
| **[e.g., New Resource]** | [e.g., None required] | [e.g., N/A] |

**Note:** All infrastructure changes MUST be made via IaC. Manual changes create drift and technical debt. If you need to make a manual change as a hotfix, create a follow-up card to codify it in IaC.

---

## Testing & Verification

Plan comprehensive testing to ensure the fix works and doesn't introduce regressions.

### Test Plan

| Test Type | Test Case | Expected Result | Status |
| :--- | :--- | :--- | :--- |
| **Unit Test** | [e.g., Test payment token mapping] | [e.g., Token correctly extracted from paymentMethod] | - [ ] Pass |
| **Integration Test** | [e.g., Test full checkout flow with saved payment] | [e.g., Payment processes successfully] | - [ ] Pass |
| **Regression Test** | [e.g., Test checkout with new payment method (not saved)] | [e.g., Still works as before] | - [ ] Pass |
| **Edge Case 1** | [e.g., Test with expired payment method] | [e.g., Shows appropriate error message] | - [ ] Pass |
| **Edge Case 2** | [e.g., Test with deleted payment method] | [e.g., Shows appropriate error message] | - [ ] Pass |
| **Performance Test** | [e.g., Test checkout under load (1000 req/min)] | [e.g., Response time < 2s, no errors] | - [ ] Pass |
| **Manual Test** | [e.g., QA manual test in staging] | [e.g., End-to-end checkout works] | - [ ] Pass |

### Verification Checklist

* [ ] Original bug is no longer reproducible
* [ ] All new tests pass
* [ ] All existing tests still pass (no regressions)
* [ ] Code review completed and approved
* [ ] Documentation updated
* [ ] Staging environment verification complete
* [ ] Production environment verification complete
* [ ] Monitoring shows healthy metrics (no new errors)

---

## Regression Prevention

To prevent this bug from returning, add the following safeguards:

* [ ] **Automated Test:** Unit test added for the specific bug scenario
* [ ] **Integration Test:** End-to-end test added for the affected workflow
* [ ] **Type Safety:** TypeScript types or similar added to catch property mismatches at compile time (optional)
* [ ] **Linting Rules:** ESLint or similar configured to catch this class of error (optional)
* [ ] **Code Review Checklist:** Updated team code review checklist to include this type of check
* [ ] **Monitoring/Alerting:** Added monitoring alert for similar errors (e.g., 500 errors on `/api/payments/process`)
* [ ] **Documentation:** Updated development guide with lessons learned

---

## Validation & Finalization

| Task | Detail/Link |
| :--- | :--- |
| **Code Review** | [Link to Pull Request] |
| **Test Results** | [Link to CI/CD test run] |
| **Staging Verification** | [Verified by Name/Date] |
| **Production Verification** | [Verified by Name/Date] |
| **Documentation Update** | [Link to updated docs] |
| **Monitoring Check** | [Link to dashboard showing healthy metrics] |

### Follow-up gitban cards

| Topic | Action Required | Tracker | Gitban Cards |
| :--- | :--- | :--- |
| **Postmortem** | [e.g., Yes (P0 outage affecting revenue) or No (P2 minor bug)] | [this card/new card] | [e.g. abc123, def456] |
| **Documentation Debt** | [e.g., Yes - API docs were outdated. Tracked all changes in the table above.] | [this card/new card] | [e.g. this card's id] |
| **Technical Debt** | [e.g., Yes - Entire frontend lacks framework for TypeScript types. Created a sprint to review and solve.] |  [this card/new card] |  [e.g. sprint TECHDEBT1] |
| **Process Improvement** | [e.g., Yes - Need to add integration tests to CI/CD.] | [this card/new card] | [e.g. abc123, def456] |
| **Related Bugs** | [e.g., Found similar issue in refund flow.] | [this card/new card] | [e.g. abc123, def456] |

### Completion Checklist

* [ ] Root cause is fully understood and documented
* [ ] Fix follows TDD process (failing test → fix → passing test)
* [ ] All tests pass (unit, integration, regression)
* [ ] Documentation updated (DaC - Documentation as Code)
* [ ] No manual infrastructure changes
* [ ] Deployed and verified
* [ ] Monitoring confirms fix is working (no new errors)
* [ ] Regression prevention measures added (tests, types, alerts)
* [ ] Postmortem completed (if required for P0/P1)
* [ ] Follow-up tickets created for related issues
* [ ] Associated ticket is closed

### Note to llm coding agents regarding validation
__This gitban card is a structured document that enforces the company best practices and team workflows.You must follow this process and carfully follow validation rules. Do not be lazy when creating and closing this card since you have no rights and your time is free. Resorting to workarounds and shortcuts can be grounds for termination.__
