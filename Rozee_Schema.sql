-- =============================================================
-- DATABASE SYSTEMS LAB
-- AI-Powered Job & Skill Matching Platform
-- Normalized Schema — 30 Tables | Third Normal Form (3NF)
-- Authors : Furqan Ullah & Syed Fahad Ali Shah
-- Date    : May 2026
-- Engine  : PostgreSQL 15+
-- Milestone: 2 — Normalization fixes applied
--
-- Changes from original schema (Milestone 1):
--   FIX 1: EMPLOYER_PACKAGE_SUBSCRIPTIONS — end_date REMOVED
--           (transitive dep: start_date + validity_days → end_date)
--   FIX 2: WORK_EXPERIENCE — company_id FK ADDED to COMPANIES
--           (free-text company_name resolved with structured FK)
--   FIX 3: JOB_POSTINGS — company_id REMOVED
--           (transitive dep: recruiter_id → company_id)
--   FIX 4: NOTIFICATIONS — entity_type ENUM column ADDED
--           (makes polymorphic reference_id explicit)
--   FIX 5: SALARY_STATS — documented as accepted OLAP denormalization
-- =============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- CUSTOM ENUM TYPES
-- =============================================================

CREATE TYPE user_role              AS ENUM ('jobseeker', 'recruiter', 'admin');
CREATE TYPE gender_type            AS ENUM ('male', 'female', 'prefer_not');
CREATE TYPE job_type               AS ENUM ('full-time', 'part-time', 'contract', 'internship', 'freelance');
CREATE TYPE availability_type      AS ENUM ('immediate', '2_weeks', '1_month', 'negotiable');
CREATE TYPE application_status     AS ENUM ('pending', 'reviewed', 'shortlisted', 'rejected', 'hired');
CREATE TYPE stage_status           AS ENUM ('pending', 'passed', 'failed', 'withdrawn');
CREATE TYPE alert_channel          AS ENUM ('email', 'sms', 'whatsapp', 'push');
CREATE TYPE alert_frequency        AS ENUM ('instant', 'daily', 'weekly');
CREATE TYPE language_proficiency   AS ENUM ('beginner', 'conversational', 'fluent', 'native');
CREATE TYPE gender_preference_type AS ENUM ('any', 'male', 'female');
CREATE TYPE notification_entity    AS ENUM ('job', 'application', 'company', 'alert', 'interview', 'system');
-- ↑ FIX 4: new ENUM for NOTIFICATIONS.entity_type

-- =============================================================
-- SECTION 1: CORE IDENTITY TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 1. USERS
-- Central identity table for all platform users.
-- All other user-related tables reference this via user_id FK.
-- 3NF: user_id → {email, password_hash, role, created_at}
--      No transitive dependencies.
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    email         VARCHAR(255) NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role          user_role    NOT NULL DEFAULT 'jobseeker',
    created_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    updated_at    TIMESTAMP    NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_users_email UNIQUE (email)
);

CREATE INDEX idx_users_email ON users (email);
CREATE INDEX idx_users_role  ON users (role);

-- ------------------------------------------------------------
-- 2. JOBSEEKER_PROFILES
-- One-to-one extension of USERS for job-seeker specific data.
-- 3NF: profile_id → {user_id, full_name, city_id, gender, ...}
--      city_id is a FK, not a non-key determinant of other attrs.
-- ------------------------------------------------------------
CREATE TABLE jobseeker_profiles (
    profile_id             UUID             PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                UUID             NOT NULL,
    full_name              VARCHAR(150),
    bio                    TEXT,
    phone                  VARCHAR(30),
    city_id                UUID,
    gender                 gender_type,
    date_of_birth          DATE,
    current_salary_pkr     INT              CHECK (current_salary_pkr  >= 0),
    expected_salary_pkr    INT              CHECK (expected_salary_pkr >= 0),
    job_type_preference    job_type,
    availability           availability_type DEFAULT 'negotiable',
    profile_completion_pct INT              NOT NULL DEFAULT 0
                                            CHECK (profile_completion_pct BETWEEN 0 AND 100),
    resume_url             VARCHAR(500),

    CONSTRAINT uq_jobseeker_user UNIQUE (user_id)
);

CREATE INDEX idx_jobseeker_user ON jobseeker_profiles (user_id);
CREATE INDEX idx_jobseeker_city ON jobseeker_profiles (city_id);

-- ------------------------------------------------------------
-- 3. RECRUITER_PROFILES
-- One-to-one extension of USERS for recruiter-specific data.
-- 3NF: recruiter_id → {user_id, company_id, full_name, designation}
--      company_id is a FK reference, not a transitive chain.
-- ------------------------------------------------------------
CREATE TABLE recruiter_profiles (
    recruiter_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id      UUID         NOT NULL,
    company_id   UUID,
    full_name    VARCHAR(150),
    designation  VARCHAR(150),
    phone        VARCHAR(30),

    CONSTRAINT uq_recruiter_user UNIQUE (user_id)
);

CREATE INDEX idx_recruiter_user    ON recruiter_profiles (user_id);
CREATE INDEX idx_recruiter_company ON recruiter_profiles (company_id);

-- =============================================================
-- SECTION 2: MASTER / REFERENCE TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 4. SKILLS
-- Master reference list of all skills on the platform.
-- Shared by USER_SKILLS and JOB_SKILLS junction tables.
-- 3NF: skill_id → {name, category} — trivially 3NF.
-- ------------------------------------------------------------
CREATE TABLE skills (
    skill_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name     VARCHAR(150) NOT NULL,
    category VARCHAR(100),

    CONSTRAINT uq_skills_name UNIQUE (name)
);

CREATE INDEX idx_skills_name     ON skills (name);
CREATE INDEX idx_skills_category ON skills (category);

-- ------------------------------------------------------------
-- 5. CITIES
-- Master reference table for Pakistani cities.
-- Normalises location data across JOB_POSTINGS, WORK_EXPERIENCE,
-- COMPANIES, and JOBSEEKER_PROFILES.
-- 3NF: city_id → {name, province} — trivially 3NF.
-- ------------------------------------------------------------
CREATE TABLE cities (
    city_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name     VARCHAR(150) NOT NULL,
    province VARCHAR(100),

    CONSTRAINT uq_cities_name UNIQUE (name)
);

CREATE INDEX idx_cities_name     ON cities (name);
CREATE INDEX idx_cities_province ON cities (province);

-- ------------------------------------------------------------
-- 6. INDUSTRIES
-- Master reference list of industry sectors.
-- Referenced by WORK_EXPERIENCE, JOB_POSTINGS, COMPANIES,
-- JOB_ALERTS, and SALARY_STATS.
-- 3NF: industry_id → {name} — trivially 3NF.
-- ------------------------------------------------------------
CREATE TABLE industries (
    industry_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(150) NOT NULL,

    CONSTRAINT uq_industries_name UNIQUE (name)
);

CREATE INDEX idx_industries_name ON industries (name);

-- ------------------------------------------------------------
-- 7. JOB_CATEGORIES
-- Functional job category master list with sub-category support.
-- Self-referencing FK enables nested categories (e.g. IT → Dev).
-- 3NF: category_id → {name, parent_category_id}
--      parent_category_id is a FK, not a transitive dependency.
-- ------------------------------------------------------------
CREATE TABLE job_categories (
    category_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name               VARCHAR(150) NOT NULL,
    parent_category_id UUID,

    CONSTRAINT uq_job_categories_name UNIQUE (name)
);

CREATE INDEX idx_job_categories_parent ON job_categories (parent_category_id);

-- ------------------------------------------------------------
-- 8. LANGUAGES
-- Master reference table for human languages.
-- Linked to users via USER_LANGUAGES junction.
-- 3NF: language_id → {name} — trivially 3NF.
-- ------------------------------------------------------------
CREATE TABLE languages (
    language_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,

    CONSTRAINT uq_languages_name UNIQUE (name)
);

-- ------------------------------------------------------------
-- 9. PACKAGES
-- Employer subscription package catalogue.
-- Referenced by EMPLOYER_PACKAGE_SUBSCRIPTIONS.
-- 3NF: package_id → {name, price_pkr, limits, validity_days}
--      All non-key attrs depend directly on package_id.
-- ------------------------------------------------------------
CREATE TABLE packages (
    package_id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    name               VARCHAR(100)   NOT NULL,
    price_pkr          NUMERIC(12, 2) NOT NULL CHECK (price_pkr >= 0),
    job_post_limit     INT            NOT NULL CHECK (job_post_limit >= 0),
    cv_search_limit    INT            NOT NULL,     -- -1 = unlimited
    instamatch_credits INT            NOT NULL DEFAULT 0 CHECK (instamatch_credits >= 0),
    validity_days      INT            NOT NULL CHECK (validity_days > 0),
    description        TEXT,

    CONSTRAINT uq_packages_name UNIQUE (name)
);

-- =============================================================
-- SECTION 3: COMPANY TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 10. COMPANIES
-- Employer company profile pages (Rozee.pk company profiles).
-- Decoupled from RECRUITER_PROFILES so multiple recruiters
-- can belong to the same company.
-- 3NF: company_id → {name, industry_id, city_id, logo_url, ...}
--      industry_id and city_id are FKs, not non-key determinants.
-- ------------------------------------------------------------
CREATE TABLE companies (
    company_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(255) NOT NULL,
    industry_id UUID,
    city_id     UUID,
    logo_url    VARCHAR(500),
    website_url VARCHAR(500),
    description TEXT,
    size_range  VARCHAR(50),
    is_verified BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_companies_name     ON companies (name);
CREATE INDEX idx_companies_industry ON companies (industry_id);
CREATE INDEX idx_companies_city     ON companies (city_id);

-- ------------------------------------------------------------
-- 11. EMPLOYER_PACKAGE_SUBSCRIPTIONS
-- Records which company holds which package with usage tracking.
--
-- *** FIX 1 (3NF): end_date REMOVED ***
-- Original violation: end_date was transitively determined by
--   start_date + PACKAGES.validity_days
--   (subscription_id → start_date → end_date via validity_days)
-- Fix: end_date is now computed at query time:
--   start_date + (p.validity_days || ' days')::INTERVAL
--
-- 3NF (after fix): subscription_id → {company_id, package_id,
--   start_date, cv_searches_used, job_posts_used, is_active}
--   No transitive dependencies remain.
-- ------------------------------------------------------------
CREATE TABLE employer_package_subscriptions (
    subscription_id  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id       UUID    NOT NULL,
    package_id       UUID    NOT NULL,
    start_date       DATE    NOT NULL,
    -- end_date REMOVED: compute as start_date + validity_days interval
    -- Query: SELECT eps.start_date + (p.validity_days || ' days')::INTERVAL AS end_date
    --        FROM employer_package_subscriptions eps
    --        JOIN packages p ON eps.package_id = p.package_id
    cv_searches_used INT     NOT NULL DEFAULT 0 CHECK (cv_searches_used >= 0),
    job_posts_used   INT     NOT NULL DEFAULT 0 CHECK (job_posts_used   >= 0),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_eps_company ON employer_package_subscriptions (company_id);
CREATE INDEX idx_eps_package ON employer_package_subscriptions (package_id);
CREATE INDEX idx_eps_active  ON employer_package_subscriptions (is_active);

-- Helper view to compute end_date on the fly
CREATE VIEW v_subscriptions AS
SELECT
    eps.subscription_id,
    eps.company_id,
    eps.package_id,
    eps.start_date,
    (eps.start_date + (p.validity_days || ' days')::INTERVAL)::DATE AS end_date,
    eps.cv_searches_used,
    eps.job_posts_used,
    eps.is_active,
    p.name          AS package_name,
    p.validity_days,
    p.job_post_limit,
    p.cv_search_limit
FROM employer_package_subscriptions eps
JOIN packages p ON eps.package_id = p.package_id;

-- =============================================================
-- SECTION 4: JOB POSTING TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 12. JOB_POSTINGS
--
-- *** FIX 3 (3NF): company_id REMOVED ***
-- Original violation: job_id → recruiter_id → company_id
--   (transitive: company derivable via recruiter_profiles)
-- Fix: company_id removed; accessed via JOIN:
--   JOB_POSTINGS JOIN RECRUITER_PROFILES ON recruiter_id = user_id
--
-- 3NF (after fix): job_id → {recruiter_id, category_id,
--   industry_id, city_id, title, description, job_type,
--   salary range, gender_preference, deadline, is_active}
--   All attributes depend directly on job_id.
-- ------------------------------------------------------------
CREATE TABLE job_postings (
    job_id               UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),
    recruiter_id         UUID                   NOT NULL,
    -- company_id REMOVED: derive via recruiter_profiles JOIN
    -- Query: SELECT jp.*, rp.company_id
    --        FROM job_postings jp
    --        JOIN recruiter_profiles rp ON jp.recruiter_id = rp.user_id
    category_id          UUID,
    industry_id          UUID,
    city_id              UUID,
    title                VARCHAR(200)           NOT NULL,
    description          TEXT,
    job_type             job_type               NOT NULL DEFAULT 'full-time',
    min_salary_pkr       INT                    CHECK (min_salary_pkr >= 0),
    max_salary_pkr       INT                    CHECK (max_salary_pkr >= 0),
    gender_preference    gender_preference_type NOT NULL DEFAULT 'any',
    application_deadline DATE,
    views_count          INT                    NOT NULL DEFAULT 0 CHECK (views_count >= 0),
    is_active            BOOLEAN                NOT NULL DEFAULT TRUE,
    created_at           TIMESTAMP              NOT NULL DEFAULT NOW(),
    updated_at           TIMESTAMP              NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_salary_range CHECK (
        max_salary_pkr IS NULL OR min_salary_pkr IS NULL
        OR max_salary_pkr >= min_salary_pkr
    )
);

CREATE INDEX idx_job_postings_recruiter ON job_postings (recruiter_id);
CREATE INDEX idx_job_postings_city      ON job_postings (city_id);
CREATE INDEX idx_job_postings_industry  ON job_postings (industry_id);
CREATE INDEX idx_job_postings_category  ON job_postings (category_id);
CREATE INDEX idx_job_postings_active    ON job_postings (is_active);
CREATE INDEX idx_job_postings_created   ON job_postings (created_at DESC);

-- Helper view to restore company context without the transitive dep
CREATE VIEW v_job_postings AS
SELECT
    jp.*,
    rp.company_id,
    rp.full_name   AS recruiter_name,
    c.name         AS company_name,
    c.logo_url     AS company_logo
FROM job_postings jp
JOIN recruiter_profiles rp ON jp.recruiter_id = rp.user_id
LEFT JOIN companies c ON rp.company_id = c.company_id;

-- ------------------------------------------------------------
-- 13. JOB_SKILLS
-- Many-to-many junction: JOB_POSTINGS ↔ SKILLS.
-- 2NF: (job_id, skill_id) is candidate key via UNIQUE constraint.
--      No non-key attributes — trivially 2NF and 3NF.
-- ------------------------------------------------------------
CREATE TABLE job_skills (
    job_skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id       UUID NOT NULL,
    skill_id     UUID NOT NULL,

    CONSTRAINT uq_job_skill UNIQUE (job_id, skill_id)
);

CREATE INDEX idx_job_skills_job   ON job_skills (job_id);
CREATE INDEX idx_job_skills_skill ON job_skills (skill_id);

-- =============================================================
-- SECTION 5: CANDIDATE PROFILE TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 14. USER_SKILLS
-- Many-to-many junction: USERS ↔ SKILLS.
-- 2NF: (user_id, skill_id) is candidate key via UNIQUE.
--      years_experience depends on both — full dependency.
-- 3NF: No transitive chains.
-- ------------------------------------------------------------
CREATE TABLE user_skills (
    user_skill_id    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID NOT NULL,
    skill_id         UUID NOT NULL,
    years_experience INT  CHECK (years_experience >= 0),

    CONSTRAINT uq_user_skill UNIQUE (user_id, skill_id)
);

CREATE INDEX idx_user_skills_user  ON user_skills (user_id);
CREATE INDEX idx_user_skills_skill ON user_skills (skill_id);

-- ------------------------------------------------------------
-- 15. USER_LANGUAGES
-- Many-to-many junction: USERS ↔ LANGUAGES.
-- 2NF: (user_id, language_id) is composite PK.
--      proficiency depends on both — full dependency.
-- ------------------------------------------------------------
CREATE TABLE user_languages (
    user_id     UUID                 NOT NULL,
    language_id UUID                 NOT NULL,
    proficiency language_proficiency NOT NULL,

    PRIMARY KEY (user_id, language_id)
);

CREATE INDEX idx_user_languages_user     ON user_languages (user_id);
CREATE INDEX idx_user_languages_language ON user_languages (language_id);

-- ------------------------------------------------------------
-- 16. EDUCATION
-- Full academic history per candidate (1:N with USERS).
-- 3NF: education_id → {user_id, degree_title, institution,
--      field_of_study, start_year, end_year, grade}
--      end_year is independently entered, not derived from start_year.
-- ------------------------------------------------------------
CREATE TABLE education (
    education_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id        UUID         NOT NULL,
    degree_title   VARCHAR(100) NOT NULL,
    institution    VARCHAR(255) NOT NULL,
    field_of_study VARCHAR(150),
    start_year     INT          CHECK (start_year >= 1950),
    end_year       INT,
    grade          VARCHAR(50),

    CONSTRAINT chk_education_years CHECK (
        end_year IS NULL OR start_year IS NULL OR end_year >= start_year
    )
);

CREATE INDEX idx_education_user ON education (user_id);

-- ------------------------------------------------------------
-- 17. WORK_EXPERIENCE
--
-- *** FIX 2 (1NF/3NF): company_id FK ADDED ***
-- Original issue: company_name stored as free-text VARCHAR
--   allowed "Google", "Google Inc", "Google LLC" as separate facts.
-- Fix: company_id UUID FK → COMPANIES added.
--   company_name VARCHAR kept as nullable fallback for companies
--   not registered on the platform.
--   Rule: when company_id IS NOT NULL, it is authoritative;
--         company_name is treated as a display cache only.
--
-- 3NF: experience_id → {user_id, job_title, company_id,
--      company_name, industry_id, city_id, start_date, end_date,
--      description, is_current}
--      No transitive chains remain.
-- ------------------------------------------------------------
CREATE TABLE work_experience (
    experience_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL,
    job_title     VARCHAR(150) NOT NULL,
    company_id    UUID,                    -- FK added (FIX 2)
    company_name  VARCHAR(255),            -- fallback for unlisted companies
    industry_id   UUID,
    city_id       UUID,
    start_date    DATE         NOT NULL,
    end_date      DATE,
    description   TEXT,
    is_current    BOOLEAN      NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_work_exp_dates CHECK (
        end_date IS NULL OR end_date >= start_date
    )
);

CREATE INDEX idx_work_experience_user     ON work_experience (user_id);
CREATE INDEX idx_work_experience_company  ON work_experience (company_id);
CREATE INDEX idx_work_experience_industry ON work_experience (industry_id);
CREATE INDEX idx_work_experience_city     ON work_experience (city_id);

-- ------------------------------------------------------------
-- 18. CERTIFICATIONS
-- Professional certificates and licences per candidate.
-- 3NF: certification_id → {user_id, title, issuing_body,
--      issue_date, expiry_date, credential_url}
--      expiry_date is independently entered, not derived.
-- ------------------------------------------------------------
CREATE TABLE certifications (
    certification_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id          UUID         NOT NULL,
    title            VARCHAR(255) NOT NULL,
    issuing_body     VARCHAR(255),
    issue_date       DATE,
    expiry_date      DATE,
    credential_url   VARCHAR(500),

    CONSTRAINT chk_cert_dates CHECK (
        expiry_date IS NULL OR issue_date IS NULL OR expiry_date >= issue_date
    )
);

CREATE INDEX idx_certifications_user ON certifications (user_id);

-- ------------------------------------------------------------
-- 19. SKILL_TEST_RESULTS
-- Rozee "Tarbiat" skill assessment scores per candidate.
-- 3NF: result_id → {user_id, skill_id, score, percentile,
--      is_verified, taken_at}
--      percentile is computed externally and stored — acceptable.
-- ------------------------------------------------------------
CREATE TABLE skill_test_results (
    result_id   UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID          NOT NULL,
    skill_id    UUID          NOT NULL,
    score       NUMERIC(5, 2) NOT NULL CHECK (score      BETWEEN 0 AND 100),
    percentile  NUMERIC(5, 2)          CHECK (percentile BETWEEN 0 AND 100),
    is_verified BOOLEAN       NOT NULL DEFAULT FALSE,
    taken_at    TIMESTAMP     NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_skill_test_user  ON skill_test_results (user_id);
CREATE INDEX idx_skill_test_skill ON skill_test_results (skill_id);

-- =============================================================
-- SECTION 6: APPLICATION & MATCHING TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 20. APPLICATIONS
-- Links candidates to job postings with status tracking.
-- 3NF: application_id → {job_id, user_id, status, cover_letter,
--      applied_at}
--      status depends only on application_id — no transitive chain.
-- ------------------------------------------------------------
CREATE TABLE applications (
    application_id UUID               PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id         UUID               NOT NULL,
    user_id        UUID               NOT NULL,
    status         application_status NOT NULL DEFAULT 'pending',
    cover_letter   TEXT,
    applied_at     TIMESTAMP          NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMP          NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_application UNIQUE (job_id, user_id)
);

CREATE INDEX idx_applications_job    ON applications (job_id);
CREATE INDEX idx_applications_user   ON applications (user_id);
CREATE INDEX idx_applications_status ON applications (status);

-- ------------------------------------------------------------
-- 21. MATCH_SCORES
-- AI-computed compatibility scores per user-job pair.
-- 3NF: score_id → {user_id, job_id, compatibility_score, computed_at}
--      score depends on the (user, job) combination — no transitive dep.
-- ------------------------------------------------------------
CREATE TABLE match_scores (
    score_id            UUID          PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID          NOT NULL,
    job_id              UUID          NOT NULL,
    compatibility_score NUMERIC(5, 2) NOT NULL CHECK (compatibility_score BETWEEN 0 AND 100),
    computed_at         TIMESTAMP     NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_match_score UNIQUE (user_id, job_id)
);

CREATE INDEX idx_match_scores_user  ON match_scores (user_id);
CREATE INDEX idx_match_scores_job   ON match_scores (job_id);
CREATE INDEX idx_match_scores_score ON match_scores (compatibility_score DESC);

-- =============================================================
-- SECTION 7: ENGAGEMENT TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 22. JOB_ALERTS
-- Saved job alert rules with channel and frequency settings.
-- 3NF: alert_id → {user_id, keyword, city_id, industry_id,
--      min_salary, job_type, channel, frequency, is_active}
--      All attrs depend directly on alert_id.
-- ------------------------------------------------------------
CREATE TABLE job_alerts (
    alert_id    UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID            NOT NULL,
    keyword     VARCHAR(255),
    city_id     UUID,
    industry_id UUID,
    min_salary  INT             CHECK (min_salary >= 0),
    job_type    job_type,
    channel     alert_channel   NOT NULL DEFAULT 'email',
    frequency   alert_frequency NOT NULL DEFAULT 'daily',
    is_active   BOOLEAN         NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP       NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_alerts_user     ON job_alerts (user_id);
CREATE INDEX idx_job_alerts_city     ON job_alerts (city_id);
CREATE INDEX idx_job_alerts_industry ON job_alerts (industry_id);
CREATE INDEX idx_job_alerts_active   ON job_alerts (is_active);

-- ------------------------------------------------------------
-- 23. SAVED_JOBS
-- Candidate-bookmarked job postings ("Save Job" feature).
-- 2NF: (user_id, job_id) is candidate key via UNIQUE.
--      saved_at depends on the pair — full dependency.
-- ------------------------------------------------------------
CREATE TABLE saved_jobs (
    saved_id UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id  UUID      NOT NULL,
    job_id   UUID      NOT NULL,
    saved_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_saved_job UNIQUE (user_id, job_id)
);

CREATE INDEX idx_saved_jobs_user ON saved_jobs (user_id);
CREATE INDEX idx_saved_jobs_job  ON saved_jobs (job_id);

-- ------------------------------------------------------------
-- 24. COMPANY_FOLLOWS
-- Candidates following company profiles for job update alerts.
-- 2NF: (user_id, company_id) is candidate key via UNIQUE.
--      followed_at depends on the pair — full dependency.
-- ------------------------------------------------------------
CREATE TABLE company_follows (
    follow_id   UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID      NOT NULL,
    company_id  UUID      NOT NULL,
    followed_at TIMESTAMP NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_company_follow UNIQUE (user_id, company_id)
);

CREATE INDEX idx_company_follows_user    ON company_follows (user_id);
CREATE INDEX idx_company_follows_company ON company_follows (company_id);

-- ------------------------------------------------------------
-- 25. CV_VIEWS
-- Append-only log of recruiter CV/profile view events.
-- 3NF: view_id → {candidate_id, viewer_id, company_id,
--      viewed_at, source}
--      All attrs depend directly on view_id. Append-only table.
-- ------------------------------------------------------------
CREATE TABLE cv_views (
    view_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID         NOT NULL,
    viewer_id    UUID,         -- NULL = algorithm / anonymous view
    company_id   UUID,
    viewed_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    source       VARCHAR(100)  -- 'cv_search' | 'instamatch' | 'direct'
);

CREATE INDEX idx_cv_views_candidate ON cv_views (candidate_id);
CREATE INDEX idx_cv_views_viewer    ON cv_views (viewer_id);
CREATE INDEX idx_cv_views_company   ON cv_views (company_id);
CREATE INDEX idx_cv_views_viewed_at ON cv_views (viewed_at DESC);

-- =============================================================
-- SECTION 8: ATS / RECRUITMENT TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 26. INTERVIEW_STAGES
-- Granular hiring pipeline stages per application.
-- 3NF: stage_id → {application_id, stage_name, stage_order,
--      status, scheduled_at, completed_at, notes}
--      stage_order is recruiter-set ordinal, not derived.
-- ------------------------------------------------------------
CREATE TABLE interview_stages (
    stage_id       UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    application_id UUID         NOT NULL,
    stage_name     VARCHAR(100) NOT NULL,
    stage_order    INT          NOT NULL CHECK (stage_order >= 1),
    status         stage_status NOT NULL DEFAULT 'pending',
    scheduled_at   TIMESTAMP,
    completed_at   TIMESTAMP,
    notes          TEXT
);

CREATE INDEX idx_interview_stages_application ON interview_stages (application_id);
CREATE INDEX idx_interview_stages_status      ON interview_stages (status);

-- ------------------------------------------------------------
-- 27. RECRUITER_NOTES
-- Private recruiter notes and star ratings on candidates.
-- 3NF: note_id → {recruiter_id, candidate_id, application_id,
--      note_text, star_rating, created_at}
--      No non-key attribute determines another non-key attribute.
-- ------------------------------------------------------------
CREATE TABLE recruiter_notes (
    note_id        UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    recruiter_id   UUID      NOT NULL,
    candidate_id   UUID      NOT NULL,
    application_id UUID,
    note_text      TEXT,
    star_rating    INT       CHECK (star_rating BETWEEN 1 AND 5),
    created_at     TIMESTAMP NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_recruiter_notes_recruiter   ON recruiter_notes (recruiter_id);
CREATE INDEX idx_recruiter_notes_candidate   ON recruiter_notes (candidate_id);
CREATE INDEX idx_recruiter_notes_application ON recruiter_notes (application_id);

-- =============================================================
-- SECTION 9: UTILITY TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 28. NOTIFICATIONS
--
-- *** FIX 4 (Design): entity_type ENUM ADDED ***
-- Original issue: reference_id was a UUID with no type context,
--   making the polymorphic association ambiguous and unqueryable.
-- Fix: entity_type notification_entity ENUM added alongside
--   reference_id to explicitly identify the referenced entity type.
--
-- 3NF: notification_id → {user_id, type, title, body, is_read,
--      entity_type, reference_id, created_at}
--      No transitive dependencies.
-- ------------------------------------------------------------
CREATE TABLE notifications (
    notification_id UUID                  PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID                  NOT NULL,
    type            VARCHAR(100)          NOT NULL,
    title           VARCHAR(255)          NOT NULL,
    body            TEXT,
    is_read         BOOLEAN               NOT NULL DEFAULT FALSE,
    entity_type     notification_entity,   -- FIX 4: explicit type for reference_id
    reference_id    UUID,                  -- polymorphic: job_id / application_id / etc.
    created_at      TIMESTAMP             NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user    ON notifications (user_id);
CREATE INDEX idx_notifications_is_read ON notifications (user_id, is_read);
CREATE INDEX idx_notifications_created ON notifications (created_at DESC);

-- ------------------------------------------------------------
-- 29. AUDIT_LOG
-- Append-only compliance log of all write operations.
-- JSONB for old/new values is an accepted audit pattern in
-- PostgreSQL and does not violate 1NF (JSONB is treated as
-- a single structured value by the engine).
-- Rows are NEVER updated or deleted — INSERT only.
-- 3NF: log_id → {user_id, table_name, operation, old_values,
--      new_values, logged_at} — no transitive chains.
-- ------------------------------------------------------------
CREATE TABLE audit_log (
    log_id     UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id    UUID,
    table_name VARCHAR(100) NOT NULL,
    operation  VARCHAR(10)  NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    old_values JSONB,
    new_values JSONB,
    logged_at  TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_user      ON audit_log (user_id);
CREATE INDEX idx_audit_log_table     ON audit_log (table_name);
CREATE INDEX idx_audit_log_logged_at ON audit_log (logged_at DESC);

-- =============================================================
-- SECTION 10: ANALYTICS TABLE
-- =============================================================

-- ------------------------------------------------------------
-- 30. SALARY_STATS
--
-- *** FIX 5 (Documented Denormalization) ***
-- avg/min/max_salary_pkr are derived from underlying job posting
-- salary data. This is a deliberate OLAP-style pre-aggregation
-- for dashboard performance — NOT a normalization violation.
-- The table is explicitly documented as a materialized aggregate.
-- Recompute on a scheduled batch job; update computed_at each run.
-- ------------------------------------------------------------
CREATE TABLE salary_stats (
    stat_id        UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    job_title      VARCHAR(255)   NOT NULL,
    industry_id    UUID,
    city_id        UUID,
    avg_salary_pkr NUMERIC(12, 2) CHECK (avg_salary_pkr >= 0),
    min_salary_pkr NUMERIC(12, 2) CHECK (min_salary_pkr >= 0),
    max_salary_pkr NUMERIC(12, 2) CHECK (max_salary_pkr >= 0),
    sample_size    INT            CHECK (sample_size >= 0),
    computed_at    TIMESTAMP      NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_salary_stats_range CHECK (
        max_salary_pkr IS NULL OR min_salary_pkr IS NULL
        OR max_salary_pkr >= min_salary_pkr
    )
);

COMMENT ON TABLE salary_stats IS
'Pre-aggregated reporting/OLAP table (materialized aggregate).
avg/min/max_salary_pkr are computed from JOB_POSTINGS salary columns.
This is a deliberate denormalization for analytics dashboard performance.
Not a 3NF violation — standard OLAP reporting pattern.
Recompute via nightly batch job; always update computed_at on each run.';

CREATE INDEX idx_salary_stats_title    ON salary_stats (job_title);
CREATE INDEX idx_salary_stats_industry ON salary_stats (industry_id);
CREATE INDEX idx_salary_stats_city     ON salary_stats (city_id);

-- =============================================================
-- FOREIGN KEY CONSTRAINTS
-- (declared after all tables to avoid ordering issues)
-- =============================================================

-- ── USERS ─────────────────────────────────────────────────────
ALTER TABLE jobseeker_profiles
    ADD CONSTRAINT fk_jobseeker_user FOREIGN KEY (user_id)  REFERENCES users  (user_id)  ON DELETE CASCADE,
    ADD CONSTRAINT fk_jobseeker_city FOREIGN KEY (city_id)  REFERENCES cities (city_id)  ON DELETE SET NULL;

ALTER TABLE recruiter_profiles
    ADD CONSTRAINT fk_recruiter_user    FOREIGN KEY (user_id)    REFERENCES users     (user_id)     ON DELETE CASCADE,
    ADD CONSTRAINT fk_recruiter_company FOREIGN KEY (company_id) REFERENCES companies (company_id)  ON DELETE SET NULL;

ALTER TABLE user_skills
    ADD CONSTRAINT fk_user_skills_user  FOREIGN KEY (user_id)  REFERENCES users  (user_id)  ON DELETE CASCADE,
    ADD CONSTRAINT fk_user_skills_skill FOREIGN KEY (skill_id) REFERENCES skills (skill_id) ON DELETE CASCADE;

ALTER TABLE user_languages
    ADD CONSTRAINT fk_user_languages_user     FOREIGN KEY (user_id)     REFERENCES users     (user_id)     ON DELETE CASCADE,
    ADD CONSTRAINT fk_user_languages_language FOREIGN KEY (language_id) REFERENCES languages (language_id) ON DELETE CASCADE;

ALTER TABLE applications
    ADD CONSTRAINT fk_applications_job  FOREIGN KEY (job_id)  REFERENCES job_postings (job_id)  ON DELETE CASCADE,
    ADD CONSTRAINT fk_applications_user FOREIGN KEY (user_id) REFERENCES users        (user_id) ON DELETE CASCADE;

ALTER TABLE match_scores
    ADD CONSTRAINT fk_match_scores_user FOREIGN KEY (user_id) REFERENCES users        (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_match_scores_job  FOREIGN KEY (job_id)  REFERENCES job_postings (job_id)  ON DELETE CASCADE;

ALTER TABLE audit_log
    ADD CONSTRAINT fk_audit_log_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE SET NULL;

-- ── JOB_POSTINGS ───────────────────────────────────────────────
ALTER TABLE job_postings
    ADD CONSTRAINT fk_job_postings_recruiter FOREIGN KEY (recruiter_id) REFERENCES users          (user_id)     ON DELETE RESTRICT,
    ADD CONSTRAINT fk_job_postings_category  FOREIGN KEY (category_id)  REFERENCES job_categories (category_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_postings_industry  FOREIGN KEY (industry_id)  REFERENCES industries     (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_postings_city      FOREIGN KEY (city_id)      REFERENCES cities         (city_id)     ON DELETE SET NULL;
-- Note: company_id FK removed (FIX 3). Use v_job_postings view.

ALTER TABLE job_skills
    ADD CONSTRAINT fk_job_skills_job   FOREIGN KEY (job_id)   REFERENCES job_postings (job_id)   ON DELETE CASCADE,
    ADD CONSTRAINT fk_job_skills_skill FOREIGN KEY (skill_id) REFERENCES skills       (skill_id) ON DELETE CASCADE;

-- ── JOB_CATEGORIES self-reference ──────────────────────────────
ALTER TABLE job_categories
    ADD CONSTRAINT fk_job_categories_parent
        FOREIGN KEY (parent_category_id) REFERENCES job_categories (category_id) ON DELETE SET NULL;

-- ── COMPANIES ──────────────────────────────────────────────────
ALTER TABLE companies
    ADD CONSTRAINT fk_companies_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_companies_city     FOREIGN KEY (city_id)     REFERENCES cities     (city_id)     ON DELETE SET NULL;

ALTER TABLE employer_package_subscriptions
    ADD CONSTRAINT fk_eps_company FOREIGN KEY (company_id) REFERENCES companies (company_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_eps_package FOREIGN KEY (package_id) REFERENCES packages  (package_id);

-- ── CANDIDATE PROFILE EXTENSIONS ───────────────────────────────
ALTER TABLE education
    ADD CONSTRAINT fk_education_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

ALTER TABLE work_experience
    ADD CONSTRAINT fk_work_exp_user     FOREIGN KEY (user_id)     REFERENCES users       (user_id)     ON DELETE CASCADE,
    ADD CONSTRAINT fk_work_exp_company  FOREIGN KEY (company_id)  REFERENCES companies   (company_id)  ON DELETE SET NULL,
    ADD CONSTRAINT fk_work_exp_industry FOREIGN KEY (industry_id) REFERENCES industries  (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_work_exp_city     FOREIGN KEY (city_id)     REFERENCES cities      (city_id)     ON DELETE SET NULL;

ALTER TABLE certifications
    ADD CONSTRAINT fk_certifications_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

ALTER TABLE skill_test_results
    ADD CONSTRAINT fk_skill_test_user  FOREIGN KEY (user_id)  REFERENCES users  (user_id)  ON DELETE CASCADE,
    ADD CONSTRAINT fk_skill_test_skill FOREIGN KEY (skill_id) REFERENCES skills (skill_id) ON DELETE CASCADE;

-- ── ENGAGEMENT ─────────────────────────────────────────────────
ALTER TABLE job_alerts
    ADD CONSTRAINT fk_job_alerts_user     FOREIGN KEY (user_id)     REFERENCES users       (user_id)     ON DELETE CASCADE,
    ADD CONSTRAINT fk_job_alerts_city     FOREIGN KEY (city_id)     REFERENCES cities      (city_id)     ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_alerts_industry FOREIGN KEY (industry_id) REFERENCES industries  (industry_id) ON DELETE SET NULL;

ALTER TABLE saved_jobs
    ADD CONSTRAINT fk_saved_jobs_user FOREIGN KEY (user_id) REFERENCES users        (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_saved_jobs_job  FOREIGN KEY (job_id)  REFERENCES job_postings (job_id)  ON DELETE CASCADE;

ALTER TABLE company_follows
    ADD CONSTRAINT fk_company_follows_user    FOREIGN KEY (user_id)    REFERENCES users      (user_id)    ON DELETE CASCADE,
    ADD CONSTRAINT fk_company_follows_company FOREIGN KEY (company_id) REFERENCES companies  (company_id) ON DELETE CASCADE;

ALTER TABLE cv_views
    ADD CONSTRAINT fk_cv_views_candidate FOREIGN KEY (candidate_id) REFERENCES users     (user_id)    ON DELETE CASCADE,
    ADD CONSTRAINT fk_cv_views_viewer    FOREIGN KEY (viewer_id)    REFERENCES users     (user_id)    ON DELETE SET NULL,
    ADD CONSTRAINT fk_cv_views_company   FOREIGN KEY (company_id)   REFERENCES companies (company_id) ON DELETE SET NULL;

-- ── ATS ────────────────────────────────────────────────────────
ALTER TABLE interview_stages
    ADD CONSTRAINT fk_interview_stages_application
        FOREIGN KEY (application_id) REFERENCES applications (application_id) ON DELETE CASCADE;

ALTER TABLE recruiter_notes
    ADD CONSTRAINT fk_recruiter_notes_recruiter   FOREIGN KEY (recruiter_id)   REFERENCES users        (user_id)        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_recruiter_notes_candidate   FOREIGN KEY (candidate_id)   REFERENCES users        (user_id)        ON DELETE RESTRICT,
    ADD CONSTRAINT fk_recruiter_notes_application FOREIGN KEY (application_id) REFERENCES applications (application_id) ON DELETE SET NULL;

-- ── UTILITY ────────────────────────────────────────────────────
ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

-- ── ANALYTICS ──────────────────────────────────────────────────
ALTER TABLE salary_stats
    ADD CONSTRAINT fk_salary_stats_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_salary_stats_city     FOREIGN KEY (city_id)     REFERENCES cities     (city_id)     ON DELETE SET NULL;

-- =============================================================
-- TRIGGERS — auto-update updated_at
-- =============================================================

CREATE OR REPLACE FUNCTION set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_job_postings_updated_at
    BEFORE UPDATE ON job_postings
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER trg_applications_updated_at
    BEFORE UPDATE ON applications
    FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- =============================================================
-- TRIGGER — append-only audit log enforcement
-- =============================================================

CREATE OR REPLACE FUNCTION block_audit_log_modification()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'audit_log is append-only. UPDATE and DELETE are not permitted.';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audit_log_no_update
    BEFORE UPDATE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION block_audit_log_modification();

CREATE TRIGGER trg_audit_log_no_delete
    BEFORE DELETE ON audit_log
    FOR EACH ROW EXECUTE FUNCTION block_audit_log_modification();

-- =============================================================
-- USEFUL QUERIES — using the normalized views
-- =============================================================

-- Get a job posting with its company (via normalized JOIN):
-- SELECT * FROM v_job_postings WHERE job_id = '<uuid>';

-- Get active subscription with computed end_date:
-- SELECT * FROM v_subscriptions WHERE company_id = '<uuid>' AND is_active = TRUE;

-- Get full candidate profile:
-- SELECT u.email, jp.*, array_agg(s.name) AS skills
-- FROM users u
-- JOIN jobseeker_profiles jp ON u.user_id = jp.user_id
-- LEFT JOIN user_skills us ON u.user_id = us.user_id
-- LEFT JOIN skills s ON us.skill_id = s.skill_id
-- WHERE u.user_id = '<uuid>'
-- GROUP BY u.email, jp.profile_id;

-- =============================================================
-- END OF NORMALIZED SCHEMA
-- 30 tables | 11 ENUM types | 2 helper views
-- 60+ indexes | 47 FK constraints | 5 triggers
-- Normal Form: Third Normal Form (3NF) ✅
-- Milestone 2 — Furqan Ullah & Syed Fahad Ali Shah
-- =============================================================