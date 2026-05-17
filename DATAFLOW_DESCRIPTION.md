# Milestone 3 — Dataflow Description
## AI-Powered Job & Skill Matching Platform
**Authors:** Furqan Ullah & Syed Fahad Ali Shah | **Date:** May 2026

---

## 1. Overview

Data in this platform flows across four logical phases:

```
[Registration & Profile Building]
        ↓
[Job Posting & Discovery]
        ↓
[Matching, Application & ATS]
        ↓
[Analytics, Notifications & Audit]
```

Each phase is described below with the tables involved, the direction of data flow, and any computed/derived artefacts.

---

## 2. Phase 1 — Registration & Profile Building

### 2.1 User Registration
- A new record is inserted into **USERS** with a hashed password and a role (`jobseeker`, `recruiter`, or `admin`).
- The `created_at` / `updated_at` timestamps are set automatically via the `set_updated_at` trigger.

### 2.2 Jobseeker Profile
- After registration, a jobseeker fills in their profile → row inserted into **JOBSEEKER_PROFILES** (FK → USERS).
- City chosen from **CITIES** master table (FK → CITIES).
- Skills selected from **SKILLS** master → rows inserted into **USER_SKILLS** junction (FK → USERS + SKILLS).
- Languages selected → rows inserted into **USER_LANGUAGES** (FK → USERS + LANGUAGES).
- Education history → rows inserted into **EDUCATION** (FK → USERS).
- Work history → rows inserted into **WORK_EXPERIENCE** (FK → USERS; optionally FK → COMPANIES when employer is on-platform; FK → CITIES + INDUSTRIES).
- Certifications → rows inserted into **CERTIFICATIONS** (FK → USERS).
- Skill assessments (Tarbiat tests) → results stored in **SKILL_TEST_RESULTS** (FK → USERS + SKILLS).

### 2.3 Recruiter & Company Profile
- Recruiter registers → **USERS** row (role = `recruiter`).
- Company created or claimed → **COMPANIES** row (FK → INDUSTRIES + CITIES).
- Recruiter linked to company → **RECRUITER_PROFILES** (FK → USERS + COMPANIES).
- Company purchases a package → **EMPLOYER_PACKAGE_SUBSCRIPTIONS** (FK → COMPANIES + PACKAGES).
  - `end_date` is **not stored**; computed at query time as `start_date + validity_days`.

---

## 3. Phase 2 — Job Posting & Discovery

### 3.1 Job Posting Creation
- Recruiter posts a job → row inserted into **JOB_POSTINGS** (FK → USERS as recruiter; FK → JOB_CATEGORIES + INDUSTRIES + CITIES).
- Required skills tagged → rows inserted into **JOB_SKILLS** junction (FK → JOB_POSTINGS + SKILLS).
- `company_id` is **not stored** in JOB_POSTINGS; it is resolved at read time via **v_job_postings** view (JOIN with RECRUITER_PROFILES → COMPANIES).
- `job_posts_used` counter in EMPLOYER_PACKAGE_SUBSCRIPTIONS is incremented.

### 3.2 Job Discovery by Candidates
- Candidates browse/search job listings (reads from JOB_POSTINGS + v_job_postings).
- Each job view → `views_count` incremented on the JOB_POSTINGS row.
- Candidate bookmarks a job → row inserted into **SAVED_JOBS** (FK → USERS + JOB_POSTINGS).
- Candidate follows a company → row inserted into **COMPANY_FOLLOWS** (FK → USERS + COMPANIES).
- Candidate sets job alert rules → row inserted into **JOB_ALERTS** (FK → USERS; optional FK → CITIES + INDUSTRIES).

---

## 4. Phase 3 — Matching, Application & ATS

### 4.1 AI Matching Engine
- The matching engine reads JOBSEEKER_PROFILES, USER_SKILLS, SKILL_TEST_RESULTS, and JOB_SKILLS.
- Computes a compatibility score per (candidate, job) pair → row upserted into **MATCH_SCORES** (FK → USERS + JOB_POSTINGS).
- High-score matches trigger the InstaMatch feature → notifications sent (see Phase 4).
- Recruiter CV search consumes a `cv_search_limit` credit → `cv_searches_used` incremented in EMPLOYER_PACKAGE_SUBSCRIPTIONS.
- Every CV/profile view event is logged to **CV_VIEWS** (FK → USERS as candidate/viewer; FK → COMPANIES).

### 4.2 Application Submission
- Candidate applies to a job → row inserted into **APPLICATIONS** (FK → JOB_POSTINGS + USERS).
  - Unique constraint prevents duplicate applications per (job, candidate) pair.
- `status` starts as `pending`.

### 4.3 Recruiter ATS Workflow
- Recruiter reviews application → `status` updated on **APPLICATIONS** (trigger updates `updated_at`).
- Recruiter creates interview stages → rows inserted into **INTERVIEW_STAGES** (FK → APPLICATIONS).
  - Stages progress through `pending → passed/failed/withdrawn`.
- Recruiter adds internal notes/ratings → rows inserted into **RECRUITER_NOTES** (FK → USERS as recruiter + candidate; FK → APPLICATIONS).

---

## 5. Phase 4 — Notifications, Analytics & Audit

### 5.1 Notification Dispatch
- System events (application status change, new match, interview scheduled, job alerts firing) generate rows in **NOTIFICATIONS** (FK → USERS).
- `entity_type` ENUM column identifies what `reference_id` points to (job, application, interview, etc.) — resolving the polymorphic reference safely.
- Alert dispatch channel (email / SMS / WhatsApp / push) is read from **JOB_ALERTS**.

### 5.2 Analytics — Salary Stats
- A nightly batch job aggregates salary data from JOB_POSTINGS (`min_salary_pkr`, `max_salary_pkr`) grouped by `job_title + industry_id + city_id`.
- Results are written into **SALARY_STATS** (computed `avg / min / max`; `computed_at` updated each run).
- This is a deliberate OLAP denormalisation — not a 3NF violation.

### 5.3 Audit Logging
- Every significant INSERT / UPDATE / DELETE across key tables is captured by application-layer hooks into **AUDIT_LOG**.
- Stores `old_values` and `new_values` as JSONB snapshots.
- Two triggers (`trg_audit_log_no_update`, `trg_audit_log_no_delete`) enforce append-only immutability.

---

## 6. Data Flow Diagram (Text)

```
MASTER TABLES                    IDENTITY TABLES
──────────────                   ───────────────
cities          ──FK──►  jobseeker_profiles ◄──FK── users ──FK──► recruiter_profiles
industries      ──FK──►  work_experience                              │
skills          ──FK──►  user_skills                                  ▼
languages       ──FK──►  user_languages                          companies ──FK──► employer_package_subscriptions ◄── packages
job_categories  ──FK──►  education                                    │
packages        ──FK──►  certifications                               │
                          skill_test_results                          │
                                │                                     │
                                ▼                                     ▼
                           MATCH_SCORES ◄──── (AI engine) ──────► job_postings ◄──FK── job_skills
                                │                                     │
                                ▼                                     ▼
                           applications ──FK──► interview_stages   saved_jobs
                                │                                  company_follows
                                ▼                                  cv_views
                           recruiter_notes                         job_alerts
                                │
                                ▼
                         NOTIFICATIONS ─────────────────────────► audit_log
                                                                   salary_stats (nightly batch)
```

---

## 7. Synthetic Data Summary

| Table                          | Rows |
|-------------------------------|------|
| cities                         | 15   |
| industries                     | 12   |
| skills                         | 30   |
| languages                      | 9    |
| job_categories                 | 16   |
| packages                       | 4    |
| users                          | 83   |
| companies                      | 20   |
| recruiter_profiles             | 20   |
| jobseeker_profiles             | 60   |
| employer_package_subscriptions | 20   |
| job_postings                   | 80   |
| job_skills                     | 294  |
| user_skills                    | 305  |
| user_languages                 | 121  |
| education                      | 87   |
| work_experience                | 118  |
| certifications                 | 40   |
| skill_test_results             | 73   |
| applications                   | 182  |
| match_scores                   | 177  |
| job_alerts                     | 45   |
| saved_jobs                     | 126  |
| company_follows                | 97   |
| cv_views                       | 200  |
| interview_stages               | 230  |
| recruiter_notes                | 60   |
| notifications                  | 150  |
| audit_log                      | 100  |
| salary_stats                   | 20   |
| **TOTAL**                      | **3,174** |

---

## 8. Data Generation Method

All synthetic data was generated using **Python 3 + Faker** library with a fixed random seed (`42`) for reproducibility.

**Key constraints respected during generation:**
- All UUID primary keys are generated with `uuid.uuid4()`.
- Foreign key values are sampled only from previously generated parent tables.
- Unique constraints (e.g., one application per jobseeker-job pair) are enforced via Python `set` deduplication before CSV write.
- Date constraints respected: `end_date >= start_date`, `expiry_date >= issue_date`, etc.
- Pakistani city names, company names, and phone numbers (format `+92-3xx-xxxxxxx`) are realistic.
- Salary ranges are plausible for the Pakistani job market (PKR 30,000–300,000).

**To regenerate:** `python generate_data.py`

---

*Milestone 3 — Furqan Ullah & Syed Fahad Ali Shah*
