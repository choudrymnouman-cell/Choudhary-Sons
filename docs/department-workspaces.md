# Department workspaces

New staff use Create an account and receive the pending role. They can sign in to see their waiting status, but cannot access company data. The owner opens Owner console → Accounts, filters Awaiting assignment and chooses a department. Only an owner can assign or change roles. Existing applicant recruitment accounts are preserved.

Owners can open any department from the sidebar or mobile selector. This changes navigation only: their real identity remains the owner and audit records continue to identify them. Staff receive only their department workspace. Role changes and deactivation revoke existing sessions; users sign in again after assignment.

| Role | Workspace |
|---|---|
| Owner | All departments, approvals, account assignment, activity, document vault |
| HR | Employee profiles, attendance, leave, payroll, recruitment, notices |
| Finance | Billing, receipts, vendor payments, expenses, project financials, payroll |
| Procurement | Suppliers, purchase orders, materials, deliveries |
| Stores | Material register, receipts, issues, stock movements |
| Project manager | Projects, BOQ, daily reports, safety records |
| Site supervisor | Attendance, daily reports, incident reporting |
| Estimator | Tender tracking, BOQ, material rates |
| Equipment | Equipment register, fuel and maintenance logs |
| Administration | Workforce records, leave, recruitment, notices |

Backend checks restrict procurement and finance mutations separately. A finance account cannot change BOQ or purchase orders. Procurement cannot retrieve payroll or vendor payments. Global executive totals remain owner-only. Non-owner document downloads and listings are restricted to that user's uploads. Project lookups omit contract values for store, procurement, equipment and site supervisor users.

Owners can assign projects to project managers and site supervisors in Accounts. Unassigned users see no existing projects. Project lists, BOQs, daily reports, safety records, attendance and document access enforce this scope on the server. Assignment changes invalidate existing sessions. Owner access remains unrestricted.

## Validation

The local SQLite test suite passes 26 tests, including signup, assignment, token revocation, role boundaries and existing business workflows. The new-install SQLite migration through 0008 passes. Modified Dart source was parsed with the Dart tree-sitter grammar without syntax errors. Flutter widget navigation tests are included and wired into CI, but not yet executed locally (Flutter SDK unavailable). PostgreSQL migration and Flutter release build must pass CI before deployment.

## Scope and remaining work

This release reorganizes existing working modules; it does not complete the whole ERP roadmap. Richer multi-site inventory, Gantt/milestones, full accounting and tax rules, hardware GPS, attendance geofencing, client portal and external notifications remain separate work. No new automated backup system is added here. Role labels alone must not be represented as completion of those workflows.

Migration 0008 adds project assignments and optional employee work sites. Migration 0007 adds PostgreSQL enum values without changing existing accounts or data. No production database reset is required. New source is not deployed until build and migration checks complete.


## Workflow completion work (not deployed)

- Approved staff accounts can be linked to HR profiles without changing credentials or permissions. HR-created accounts wait for owner assignment. Only the owner can revoke account access.
- Payroll selects employees by name and pre-fills salary; the backend validates periods, non-negative money and net pay. Finance/owner records payments with references; repeated payments are rejected. Leave requests reject overlaps and cannot be reviewed twice or by their requester.
- Project tasks and milestones have dates, progress, status and overdue indicators. Project/site access stays scoped to owner assignments. Closed projects reject progress changes.
- Material requests can be submitted by site/project staff and converted once by procurement into a priced PO with an item line. Existing owner thresholds gate approval. Cancellation is limited to unprocessed requests and the requester/owner.
- Safety inspections can be recorded/listed; owners and assigned project managers can close incidents with corrective actions.
- Equipment includes fuel/service history and current service-due alerts; negative fuel quantities and backwards meter readings are rejected.

Migrations 0009 and 0010 add task and requisition tables without resetting data. These additions do not yet implement full double-entry accounting, multi-site stock balances, client portal, GPS hardware feeds, automated communications or statutory tax configuration.
