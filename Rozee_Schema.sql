-- =============================================================
-- DATABASE SYSTEMS LAB
-- AI-Powered Job & Skill Matching Platform
-- Rozee.pk Full Schema — 30 Tables
-- Authors : Furqan Ullah & Syed Fahad Ali Shah
-- Date    : May 2026
-- Engine  : PostgreSQL 15+
-- =============================================================

-- Enable UUID generation
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- =============================================================
-- CUSTOM TYPES (ENUMs)
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

-- =============================================================
-- SECTION 1: ORIGINAL 10 TABLES
-- =============================================================

-- ------------------------------------------------------------
-- 1. USERS
-- ------------------------------------------------------------
CREATE TABLE users (
    user_id       UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
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
-- (city_id, gender, date_of_birth, salary fields,
--  job_type_preference, availability, profile_completion_pct
--  added to match Rozee.pk)
-- ------------------------------------------------------------
CREATE TABLE jobseeker_profiles (
    profile_id              UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id                 UUID        NOT NULL,
    full_name               VARCHAR(150),
    bio                     TEXT,
    phone                   VARCHAR(30),
    city_id                 UUID,                          -- FK added (Rozee location matching)
    gender                  gender_type,                  -- added
    date_of_birth           DATE,                         -- added
    current_salary_pkr      INT         CHECK (current_salary_pkr  >= 0),  -- added
    expected_salary_pkr     INT         CHECK (expected_salary_pkr >= 0),  -- added
    job_type_preference     job_type,                     -- added
    availability            availability_type DEFAULT 'negotiable',        -- added
    profile_completion_pct  INT         NOT NULL DEFAULT 0
                                         CHECK (profile_completion_pct BETWEEN 0 AND 100),

    CONSTRAINT uq_jobseeker_user UNIQUE (user_id)
);

CREATE INDEX idx_jobseeker_user   ON jobseeker_profiles (user_id);
CREATE INDEX idx_jobseeker_city   ON jobseeker_profiles (city_id);

-- ------------------------------------------------------------
-- 3. RECRUITER_PROFILES
-- (company_id, designation added to match Rozee.pk)
-- ------------------------------------------------------------
CREATE TABLE recruiter_profiles (
    recruiter_id  UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID         NOT NULL,
    company_id    UUID,                    -- FK added (Rozee employer linkage)
    full_name     VARCHAR(150),
    designation   VARCHAR(150),            -- added
    phone         VARCHAR(30),

    CONSTRAINT uq_recruiter_user UNIQUE (user_id)
);

CREATE INDEX idx_recruiter_user    ON recruiter_profiles (user_id);
CREATE INDEX idx_recruiter_company ON recruiter_profiles (company_id);

-- ------------------------------------------------------------
-- 4. SKILLS
-- ------------------------------------------------------------
CREATE TABLE skills (
    skill_id  UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    name      VARCHAR(150) NOT NULL,
    category  VARCHAR(100),

    CONSTRAINT uq_skills_name UNIQUE (name)
);

CREATE INDEX idx_skills_name     ON skills (name);
CREATE INDEX idx_skills_category ON skills (category);

-- ------------------------------------------------------------
-- 5. USER_SKILLS
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
-- 6. JOB_POSTINGS
-- (category_id, industry_id, city_id, company_id, job_type,
--  salary range, gender_preference, deadline, views_count
--  added to match Rozee.pk)
-- ------------------------------------------------------------
CREATE TABLE job_postings (
    job_id               UUID                   PRIMARY KEY DEFAULT gen_random_uuid(),
    recruiter_id         UUID                   NOT NULL,
    company_id           UUID,                              -- FK added
    category_id          UUID,                              -- FK added
    industry_id          UUID,                              -- FK added
    city_id              UUID,                              -- FK added
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
        max_salary_pkr IS NULL OR min_salary_pkr IS NULL OR max_salary_pkr >= min_salary_pkr
    )
);

CREATE INDEX idx_job_postings_recruiter ON job_postings (recruiter_id);
CREATE INDEX idx_job_postings_company   ON job_postings (company_id);
CREATE INDEX idx_job_postings_city      ON job_postings (city_id);
CREATE INDEX idx_job_postings_industry  ON job_postings (industry_id);
CREATE INDEX idx_job_postings_category  ON job_postings (category_id);
CREATE INDEX idx_job_postings_active    ON job_postings (is_active);
CREATE INDEX idx_job_postings_created   ON job_postings (created_at DESC);

-- ------------------------------------------------------------
-- 7. JOB_SKILLS
-- ------------------------------------------------------------
CREATE TABLE job_skills (
    job_skill_id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    job_id       UUID NOT NULL,
    skill_id     UUID NOT NULL,

    CONSTRAINT uq_job_skill UNIQUE (job_id, skill_id)
);

CREATE INDEX idx_job_skills_job   ON job_skills (job_id);
CREATE INDEX idx_job_skills_skill ON job_skills (skill_id);

-- ------------------------------------------------------------
-- 8. APPLICATIONS
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
-- 9. MATCH_SCORES
-- ------------------------------------------------------------
CREATE TABLE match_scores (
    score_id            UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id             UUID           NOT NULL,
    job_id              UUID           NOT NULL,
    compatibility_score NUMERIC(5, 2)  NOT NULL CHECK (compatibility_score BETWEEN 0 AND 100),
    computed_at         TIMESTAMP      NOT NULL DEFAULT NOW(),

    CONSTRAINT uq_match_score UNIQUE (user_id, job_id)
);

CREATE INDEX idx_match_scores_user  ON match_scores (user_id);
CREATE INDEX idx_match_scores_job   ON match_scores (job_id);
CREATE INDEX idx_match_scores_score ON match_scores (compatibility_score DESC);

-- ------------------------------------------------------------
-- 10. AUDIT_LOG
-- ------------------------------------------------------------
CREATE TABLE audit_log (
    log_id      UUID      PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID,
    table_name  VARCHAR(100) NOT NULL,
    operation   VARCHAR(10)  NOT NULL CHECK (operation IN ('INSERT','UPDATE','DELETE')),
    old_values  JSONB,
    new_values  JSONB,
    logged_at   TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_log_user      ON audit_log (user_id);
CREATE INDEX idx_audit_log_table     ON audit_log (table_name);
CREATE INDEX idx_audit_log_logged_at ON audit_log (logged_at DESC);

-- =============================================================
-- SECTION 2: REFERENCE / MASTER TABLES (new)
-- =============================================================

-- ------------------------------------------------------------
-- 11. CITIES
-- ------------------------------------------------------------
CREATE TABLE cities (
    city_id   UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name      VARCHAR(150) NOT NULL,
    province  VARCHAR(100),

    CONSTRAINT uq_cities_name UNIQUE (name)
);

CREATE INDEX idx_cities_name     ON cities (name);
CREATE INDEX idx_cities_province ON cities (province);

-- ------------------------------------------------------------
-- 12. INDUSTRIES
-- ------------------------------------------------------------
CREATE TABLE industries (
    industry_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(150) NOT NULL,

    CONSTRAINT uq_industries_name UNIQUE (name)
);

CREATE INDEX idx_industries_name ON industries (name);

-- ------------------------------------------------------------
-- 13. JOB_CATEGORIES
-- ------------------------------------------------------------
CREATE TABLE job_categories (
    category_id        UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name               VARCHAR(150) NOT NULL,
    parent_category_id UUID,                   -- self-reference for sub-categories

    CONSTRAINT uq_job_categories_name UNIQUE (name)
);

CREATE INDEX idx_job_categories_parent ON job_categories (parent_category_id);

-- ------------------------------------------------------------
-- 14. LANGUAGES
-- ------------------------------------------------------------
CREATE TABLE languages (
    language_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    name        VARCHAR(100) NOT NULL,

    CONSTRAINT uq_languages_name UNIQUE (name)
);

-- ------------------------------------------------------------
-- 15. PACKAGES
-- ------------------------------------------------------------
CREATE TABLE packages (
    package_id          UUID            PRIMARY KEY DEFAULT gen_random_uuid(),
    name                VARCHAR(100)    NOT NULL,
    price_pkr           NUMERIC(12, 2)  NOT NULL CHECK (price_pkr >= 0),
    job_post_limit      INT             NOT NULL CHECK (job_post_limit >= 0),
    cv_search_limit     INT             NOT NULL,           -- -1 = unlimited
    instamatch_credits  INT             NOT NULL DEFAULT 0 CHECK (instamatch_credits >= 0),
    validity_days       INT             NOT NULL CHECK (validity_days > 0),
    description         TEXT,

    CONSTRAINT uq_packages_name UNIQUE (name)
);

-- =============================================================
-- SECTION 3: NEW TABLES — CANDIDATE PROFILE EXTENSIONS
-- =============================================================

-- ------------------------------------------------------------
-- 16. EDUCATION
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
-- ------------------------------------------------------------
CREATE TABLE work_experience (
    experience_id UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id       UUID    NOT NULL,
    job_title     VARCHAR(150) NOT NULL,
    company_name  VARCHAR(255) NOT NULL,
    industry_id   UUID,
    city_id       UUID,
    start_date    DATE    NOT NULL,
    end_date      DATE,
    description   TEXT,
    is_current    BOOLEAN NOT NULL DEFAULT FALSE,

    CONSTRAINT chk_work_exp_dates CHECK (
        end_date IS NULL OR end_date >= start_date
    )
);

CREATE INDEX idx_work_experience_user     ON work_experience (user_id);
CREATE INDEX idx_work_experience_industry ON work_experience (industry_id);
CREATE INDEX idx_work_experience_city     ON work_experience (city_id);

-- ------------------------------------------------------------
-- 18. CERTIFICATIONS
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
-- 19. USER_LANGUAGES
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
-- 20. SKILL_TEST_RESULTS
-- ------------------------------------------------------------
CREATE TABLE skill_test_results (
    result_id   UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID           NOT NULL,
    skill_id    UUID           NOT NULL,
    score       NUMERIC(5, 2)  NOT NULL CHECK (score     BETWEEN 0 AND 100),
    percentile  NUMERIC(5, 2)           CHECK (percentile BETWEEN 0 AND 100),
    is_verified BOOLEAN        NOT NULL DEFAULT FALSE,
    taken_at    TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_skill_test_user  ON skill_test_results (user_id);
CREATE INDEX idx_skill_test_skill ON skill_test_results (skill_id);

-- =============================================================
-- SECTION 4: NEW TABLES — COMPANIES & PACKAGES
-- =============================================================

-- ------------------------------------------------------------
-- 21. COMPANIES
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
-- 22. EMPLOYER_PACKAGE_SUBSCRIPTIONS
-- ------------------------------------------------------------
CREATE TABLE employer_package_subscriptions (
    subscription_id  UUID    PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id       UUID    NOT NULL,
    package_id       UUID    NOT NULL,
    start_date       DATE    NOT NULL,
    end_date         DATE    NOT NULL,
    cv_searches_used INT     NOT NULL DEFAULT 0 CHECK (cv_searches_used >= 0),
    job_posts_used   INT     NOT NULL DEFAULT 0 CHECK (job_posts_used   >= 0),
    is_active        BOOLEAN NOT NULL DEFAULT TRUE,

    CONSTRAINT chk_subscription_dates CHECK (end_date >= start_date)
);

CREATE INDEX idx_emp_pkg_company ON employer_package_subscriptions (company_id);
CREATE INDEX idx_emp_pkg_package ON employer_package_subscriptions (package_id);
CREATE INDEX idx_emp_pkg_active  ON employer_package_subscriptions (is_active);

-- =============================================================
-- SECTION 5: NEW TABLES — JOB ENGAGEMENT
-- =============================================================

-- ------------------------------------------------------------
-- 23. JOB_ALERTS
-- ------------------------------------------------------------
CREATE TABLE job_alerts (
    alert_id    UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id     UUID           NOT NULL,
    keyword     VARCHAR(255),
    city_id     UUID,
    industry_id UUID,
    min_salary  INT            CHECK (min_salary >= 0),
    job_type    job_type,
    channel     alert_channel  NOT NULL DEFAULT 'email',
    frequency   alert_frequency NOT NULL DEFAULT 'daily',
    is_active   BOOLEAN        NOT NULL DEFAULT TRUE,
    created_at  TIMESTAMP      NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_job_alerts_user      ON job_alerts (user_id);
CREATE INDEX idx_job_alerts_city      ON job_alerts (city_id);
CREATE INDEX idx_job_alerts_industry  ON job_alerts (industry_id);
CREATE INDEX idx_job_alerts_active    ON job_alerts (is_active);

-- ------------------------------------------------------------
-- 24. SAVED_JOBS
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
-- 25. COMPANY_FOLLOWS
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
-- 26. CV_VIEWS
-- ------------------------------------------------------------
CREATE TABLE cv_views (
    view_id      UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    candidate_id UUID         NOT NULL,
    viewer_id    UUID,                    -- NULL = algorithm/anonymous view
    company_id   UUID,
    viewed_at    TIMESTAMP    NOT NULL DEFAULT NOW(),
    source       VARCHAR(100)            -- 'cv_search', 'instamatch', 'direct'
);

CREATE INDEX idx_cv_views_candidate ON cv_views (candidate_id);
CREATE INDEX idx_cv_views_viewer    ON cv_views (viewer_id);
CREATE INDEX idx_cv_views_company   ON cv_views (company_id);
CREATE INDEX idx_cv_views_viewed_at ON cv_views (viewed_at DESC);

-- =============================================================
-- SECTION 6: NEW TABLES — RECRUITMENT / ATS
-- =============================================================

-- ------------------------------------------------------------
-- 27. INTERVIEW_STAGES
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
-- 28. RECRUITER_NOTES
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

-- ------------------------------------------------------------
-- 29. NOTIFICATIONS
-- ------------------------------------------------------------
CREATE TABLE notifications (
    notification_id UUID         PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID         NOT NULL,
    type            VARCHAR(100) NOT NULL,
    title           VARCHAR(255) NOT NULL,
    body            TEXT,
    is_read         BOOLEAN      NOT NULL DEFAULT FALSE,
    reference_id    UUID,
    created_at      TIMESTAMP    NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notifications_user     ON notifications (user_id);
CREATE INDEX idx_notifications_is_read  ON notifications (user_id, is_read);
CREATE INDEX idx_notifications_created  ON notifications (created_at DESC);

-- =============================================================
-- SECTION 7: NEW TABLES — ANALYTICS
-- =============================================================

-- ------------------------------------------------------------
-- 30. SALARY_STATS
-- ------------------------------------------------------------
CREATE TABLE salary_stats (
    stat_id         UUID           PRIMARY KEY DEFAULT gen_random_uuid(),
    job_title       VARCHAR(255)   NOT NULL,
    industry_id     UUID,
    city_id         UUID,
    avg_salary_pkr  NUMERIC(12, 2) CHECK (avg_salary_pkr >= 0),
    min_salary_pkr  NUMERIC(12, 2) CHECK (min_salary_pkr >= 0),
    max_salary_pkr  NUMERIC(12, 2) CHECK (max_salary_pkr >= 0),
    sample_size     INT            CHECK (sample_size >= 0),
    computed_at     TIMESTAMP      NOT NULL DEFAULT NOW(),

    CONSTRAINT chk_salary_stats_range CHECK (
        max_salary_pkr IS NULL OR min_salary_pkr IS NULL OR max_salary_pkr >= min_salary_pkr
    )
);

CREATE INDEX idx_salary_stats_title    ON salary_stats (job_title);
CREATE INDEX idx_salary_stats_industry ON salary_stats (industry_id);
CREATE INDEX idx_salary_stats_city     ON salary_stats (city_id);

-- =============================================================
-- FOREIGN KEY CONSTRAINTS
-- (added after all tables exist to avoid ordering issues)
-- =============================================================

-- USERS references
ALTER TABLE jobseeker_profiles
    ADD CONSTRAINT fk_jobseeker_user    FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_jobseeker_city    FOREIGN KEY (city_id)    REFERENCES cities (city_id);

ALTER TABLE recruiter_profiles
    ADD CONSTRAINT fk_recruiter_user    FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_recruiter_company FOREIGN KEY (company_id) REFERENCES companies (company_id);

ALTER TABLE user_skills
    ADD CONSTRAINT fk_user_skills_user  FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_user_skills_skill FOREIGN KEY (skill_id)   REFERENCES skills (skill_id) ON DELETE CASCADE;

ALTER TABLE applications
    ADD CONSTRAINT fk_applications_job  FOREIGN KEY (job_id)     REFERENCES job_postings (job_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_applications_user FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE CASCADE;

ALTER TABLE match_scores
    ADD CONSTRAINT fk_match_scores_user FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_match_scores_job  FOREIGN KEY (job_id)     REFERENCES job_postings (job_id) ON DELETE CASCADE;

ALTER TABLE audit_log
    ADD CONSTRAINT fk_audit_log_user    FOREIGN KEY (user_id)    REFERENCES users (user_id) ON DELETE SET NULL;

-- JOB_POSTINGS references
ALTER TABLE job_postings
    ADD CONSTRAINT fk_job_postings_recruiter FOREIGN KEY (recruiter_id) REFERENCES users (user_id),
    ADD CONSTRAINT fk_job_postings_company   FOREIGN KEY (company_id)   REFERENCES companies (company_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_postings_category  FOREIGN KEY (category_id)  REFERENCES job_categories (category_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_postings_industry  FOREIGN KEY (industry_id)  REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_postings_city      FOREIGN KEY (city_id)      REFERENCES cities (city_id) ON DELETE SET NULL;

ALTER TABLE job_skills
    ADD CONSTRAINT fk_job_skills_job   FOREIGN KEY (job_id)   REFERENCES job_postings (job_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_job_skills_skill FOREIGN KEY (skill_id) REFERENCES skills (skill_id) ON DELETE CASCADE;

-- JOB_CATEGORIES self-reference
ALTER TABLE job_categories
    ADD CONSTRAINT fk_job_categories_parent FOREIGN KEY (parent_category_id) REFERENCES job_categories (category_id) ON DELETE SET NULL;

-- COMPANIES references
ALTER TABLE companies
    ADD CONSTRAINT fk_companies_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_companies_city     FOREIGN KEY (city_id)     REFERENCES cities (city_id) ON DELETE SET NULL;

ALTER TABLE employer_package_subscriptions
    ADD CONSTRAINT fk_eps_company FOREIGN KEY (company_id) REFERENCES companies (company_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_eps_package FOREIGN KEY (package_id) REFERENCES packages (package_id);

-- Candidate profile extension references
ALTER TABLE education
    ADD CONSTRAINT fk_education_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

ALTER TABLE work_experience
    ADD CONSTRAINT fk_work_exp_user     FOREIGN KEY (user_id)     REFERENCES users (user_id)      ON DELETE CASCADE,
    ADD CONSTRAINT fk_work_exp_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_work_exp_city     FOREIGN KEY (city_id)     REFERENCES cities (city_id)     ON DELETE SET NULL;

ALTER TABLE certifications
    ADD CONSTRAINT fk_certifications_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

ALTER TABLE user_languages
    ADD CONSTRAINT fk_user_languages_user     FOREIGN KEY (user_id)     REFERENCES users (user_id)     ON DELETE CASCADE,
    ADD CONSTRAINT fk_user_languages_language FOREIGN KEY (language_id) REFERENCES languages (language_id) ON DELETE CASCADE;

ALTER TABLE skill_test_results
    ADD CONSTRAINT fk_skill_test_user  FOREIGN KEY (user_id)  REFERENCES users (user_id)  ON DELETE CASCADE,
    ADD CONSTRAINT fk_skill_test_skill FOREIGN KEY (skill_id) REFERENCES skills (skill_id) ON DELETE CASCADE;

-- Engagement references
ALTER TABLE job_alerts
    ADD CONSTRAINT fk_job_alerts_user     FOREIGN KEY (user_id)     REFERENCES users (user_id)        ON DELETE CASCADE,
    ADD CONSTRAINT fk_job_alerts_city     FOREIGN KEY (city_id)     REFERENCES cities (city_id)       ON DELETE SET NULL,
    ADD CONSTRAINT fk_job_alerts_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL;

ALTER TABLE saved_jobs
    ADD CONSTRAINT fk_saved_jobs_user FOREIGN KEY (user_id) REFERENCES users (user_id)        ON DELETE CASCADE,
    ADD CONSTRAINT fk_saved_jobs_job  FOREIGN KEY (job_id)  REFERENCES job_postings (job_id)  ON DELETE CASCADE;

ALTER TABLE company_follows
    ADD CONSTRAINT fk_company_follows_user    FOREIGN KEY (user_id)    REFERENCES users (user_id)       ON DELETE CASCADE,
    ADD CONSTRAINT fk_company_follows_company FOREIGN KEY (company_id) REFERENCES companies (company_id) ON DELETE CASCADE;

ALTER TABLE cv_views
    ADD CONSTRAINT fk_cv_views_candidate FOREIGN KEY (candidate_id) REFERENCES users (user_id) ON DELETE CASCADE,
    ADD CONSTRAINT fk_cv_views_viewer    FOREIGN KEY (viewer_id)    REFERENCES users (user_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_cv_views_company   FOREIGN KEY (company_id)   REFERENCES companies (company_id) ON DELETE SET NULL;

-- ATS references
ALTER TABLE interview_stages
    ADD CONSTRAINT fk_interview_stages_application FOREIGN KEY (application_id) REFERENCES applications (application_id) ON DELETE CASCADE;

ALTER TABLE recruiter_notes
    ADD CONSTRAINT fk_recruiter_notes_recruiter   FOREIGN KEY (recruiter_id)   REFERENCES users (user_id),
    ADD CONSTRAINT fk_recruiter_notes_candidate   FOREIGN KEY (candidate_id)   REFERENCES users (user_id),
    ADD CONSTRAINT fk_recruiter_notes_application FOREIGN KEY (application_id) REFERENCES applications (application_id) ON DELETE SET NULL;

ALTER TABLE notifications
    ADD CONSTRAINT fk_notifications_user FOREIGN KEY (user_id) REFERENCES users (user_id) ON DELETE CASCADE;

-- Analytics references
ALTER TABLE salary_stats
    ADD CONSTRAINT fk_salary_stats_industry FOREIGN KEY (industry_id) REFERENCES industries (industry_id) ON DELETE SET NULL,
    ADD CONSTRAINT fk_salary_stats_city     FOREIGN KEY (city_id)     REFERENCES cities (city_id) ON DELETE SET NULL;

-- =============================================================
-- AUTO-UPDATE updated_at TRIGGER
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
-- END OF SCHEMA
-- 30 tables | 3 ENUM types | 7 remaining custom types
-- 60+ indexes | 45+ FK constraints | 3 auto-update triggers
-- =============================================================
