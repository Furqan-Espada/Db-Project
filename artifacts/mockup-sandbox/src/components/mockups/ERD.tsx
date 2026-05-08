import { useState } from "react";

type Col = { name: string; type: string; key?: "PK" | "FK" | "PK,FK" };
type TableDef = { name: string; isNew: boolean; columns: Col[] };
type GroupDef = { label: string; color: string; border: string; bg: string; tables: TableDef[] };

const GROUPS: GroupDef[] = [
  {
    label: "Core / Identity",
    color: "#60a5fa",
    border: "#1d4ed8",
    bg: "#0f1e38",
    tables: [
      {
        name: "USERS", isNew: false,
        columns: [
          { name: "user_id", type: "UUID", key: "PK" },
          { name: "email", type: "VARCHAR(255)" },
          { name: "password_hash", type: "VARCHAR" },
          { name: "role", type: "ENUM" },
          { name: "created_at", type: "TIMESTAMP" },
          { name: "updated_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "AUDIT_LOG", isNew: false,
        columns: [
          { name: "log_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "table_name", type: "VARCHAR" },
          { name: "operation", type: "VARCHAR" },
          { name: "old_values", type: "JSONB" },
          { name: "new_values", type: "JSONB" },
          { name: "logged_at", type: "TIMESTAMP" },
        ],
      },
    ],
  },
  {
    label: "Profiles",
    color: "#4ade80",
    border: "#166534",
    bg: "#0a1f12",
    tables: [
      {
        name: "JOBSEEKER_PROFILES", isNew: false,
        columns: [
          { name: "profile_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "full_name", type: "VARCHAR(150)" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "gender", type: "ENUM" },
          { name: "date_of_birth", type: "DATE" },
          { name: "current_salary_pkr", type: "INT" },
          { name: "expected_salary_pkr", type: "INT" },
          { name: "job_type_preference", type: "ENUM" },
          { name: "availability", type: "ENUM" },
          { name: "profile_completion_pct", type: "INT" },
        ],
      },
      {
        name: "RECRUITER_PROFILES", isNew: false,
        columns: [
          { name: "recruiter_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "company_id", type: "UUID", key: "FK" },
          { name: "full_name", type: "VARCHAR(150)" },
          { name: "designation", type: "VARCHAR(150)" },
          { name: "phone", type: "VARCHAR(30)" },
        ],
      },
    ],
  },
  {
    label: "Skills & Matching",
    color: "#a78bfa",
    border: "#4c1d95",
    bg: "#140d2a",
    tables: [
      {
        name: "SKILLS", isNew: false,
        columns: [
          { name: "skill_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(150)" },
          { name: "category", type: "VARCHAR(100)" },
        ],
      },
      {
        name: "USER_SKILLS", isNew: false,
        columns: [
          { name: "user_skill_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "skill_id", type: "UUID", key: "FK" },
          { name: "years_experience", type: "INT" },
        ],
      },
      {
        name: "MATCH_SCORES", isNew: false,
        columns: [
          { name: "score_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "job_id", type: "UUID", key: "FK" },
          { name: "compatibility_score", type: "NUMERIC" },
          { name: "computed_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "SKILL_TEST_RESULTS", isNew: true,
        columns: [
          { name: "result_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "skill_id", type: "UUID", key: "FK" },
          { name: "score", type: "NUMERIC(5,2)" },
          { name: "percentile", type: "NUMERIC(5,2)" },
          { name: "is_verified", type: "BOOLEAN" },
          { name: "taken_at", type: "TIMESTAMP" },
        ],
      },
    ],
  },
  {
    label: "Jobs & Applications",
    color: "#fbbf24",
    border: "#78350f",
    bg: "#1a1200",
    tables: [
      {
        name: "JOB_POSTINGS", isNew: false,
        columns: [
          { name: "job_id", type: "UUID", key: "PK" },
          { name: "recruiter_id", type: "UUID", key: "FK" },
          { name: "company_id", type: "UUID", key: "FK" },
          { name: "category_id", type: "UUID", key: "FK" },
          { name: "industry_id", type: "UUID", key: "FK" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "title", type: "VARCHAR(200)" },
          { name: "job_type", type: "ENUM" },
          { name: "min_salary_pkr", type: "INT" },
          { name: "max_salary_pkr", type: "INT" },
          { name: "gender_preference", type: "ENUM" },
          { name: "application_deadline", type: "DATE" },
          { name: "views_count", type: "INT" },
          { name: "is_active", type: "BOOLEAN" },
          { name: "created_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "JOB_SKILLS", isNew: false,
        columns: [
          { name: "job_skill_id", type: "UUID", key: "PK" },
          { name: "job_id", type: "UUID", key: "FK" },
          { name: "skill_id", type: "UUID", key: "FK" },
        ],
      },
      {
        name: "APPLICATIONS", isNew: false,
        columns: [
          { name: "application_id", type: "UUID", key: "PK" },
          { name: "job_id", type: "UUID", key: "FK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "status", type: "ENUM" },
          { name: "cover_letter", type: "TEXT" },
          { name: "applied_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "SAVED_JOBS", isNew: true,
        columns: [
          { name: "saved_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "job_id", type: "UUID", key: "FK" },
          { name: "saved_at", type: "TIMESTAMP" },
        ],
      },
    ],
  },
  {
    label: "Candidate Profile Extensions",
    color: "#f87171",
    border: "#7f1d1d",
    bg: "#1f0a0a",
    tables: [
      {
        name: "EDUCATION", isNew: true,
        columns: [
          { name: "education_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "degree_title", type: "VARCHAR(100)" },
          { name: "institution", type: "VARCHAR(255)" },
          { name: "field_of_study", type: "VARCHAR(150)" },
          { name: "start_year", type: "INT" },
          { name: "end_year", type: "INT" },
          { name: "grade", type: "VARCHAR(50)" },
        ],
      },
      {
        name: "WORK_EXPERIENCE", isNew: true,
        columns: [
          { name: "experience_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "job_title", type: "VARCHAR(150)" },
          { name: "company_name", type: "VARCHAR(255)" },
          { name: "industry_id", type: "UUID", key: "FK" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "start_date", type: "DATE" },
          { name: "end_date", type: "DATE" },
          { name: "description", type: "TEXT" },
          { name: "is_current", type: "BOOLEAN" },
        ],
      },
      {
        name: "CERTIFICATIONS", isNew: true,
        columns: [
          { name: "certification_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "title", type: "VARCHAR(255)" },
          { name: "issuing_body", type: "VARCHAR(255)" },
          { name: "issue_date", type: "DATE" },
          { name: "expiry_date", type: "DATE" },
          { name: "credential_url", type: "VARCHAR(500)" },
        ],
      },
    ],
  },
  {
    label: "Languages",
    color: "#34d399",
    border: "#064e3b",
    bg: "#061a12",
    tables: [
      {
        name: "LANGUAGES", isNew: true,
        columns: [
          { name: "language_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(100)" },
        ],
      },
      {
        name: "USER_LANGUAGES", isNew: true,
        columns: [
          { name: "user_id", type: "UUID", key: "PK,FK" },
          { name: "language_id", type: "UUID", key: "PK,FK" },
          { name: "proficiency", type: "ENUM" },
        ],
      },
    ],
  },
  {
    label: "Reference / Master Tables",
    color: "#38bdf8",
    border: "#0c4a6e",
    bg: "#050e1a",
    tables: [
      {
        name: "INDUSTRIES", isNew: true,
        columns: [
          { name: "industry_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(150)" },
        ],
      },
      {
        name: "JOB_CATEGORIES", isNew: true,
        columns: [
          { name: "category_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(150)" },
          { name: "parent_category_id", type: "UUID", key: "FK" },
        ],
      },
      {
        name: "CITIES", isNew: true,
        columns: [
          { name: "city_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(150)" },
          { name: "province", type: "VARCHAR(100)" },
        ],
      },
    ],
  },
  {
    label: "Companies & Packages",
    color: "#fb923c",
    border: "#7c2d12",
    bg: "#1a0d05",
    tables: [
      {
        name: "COMPANIES", isNew: true,
        columns: [
          { name: "company_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(255)" },
          { name: "industry_id", type: "UUID", key: "FK" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "logo_url", type: "VARCHAR(500)" },
          { name: "website_url", type: "VARCHAR(500)" },
          { name: "description", type: "TEXT" },
          { name: "size_range", type: "VARCHAR(50)" },
          { name: "is_verified", type: "BOOLEAN" },
          { name: "created_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "PACKAGES", isNew: true,
        columns: [
          { name: "package_id", type: "UUID", key: "PK" },
          { name: "name", type: "VARCHAR(100)" },
          { name: "price_pkr", type: "NUMERIC(12,2)" },
          { name: "job_post_limit", type: "INT" },
          { name: "cv_search_limit", type: "INT" },
          { name: "instamatch_credits", type: "INT" },
          { name: "validity_days", type: "INT" },
        ],
      },
      {
        name: "EMPLOYER_PACKAGE_SUBSCRIPTIONS", isNew: true,
        columns: [
          { name: "subscription_id", type: "UUID", key: "PK" },
          { name: "company_id", type: "UUID", key: "FK" },
          { name: "package_id", type: "UUID", key: "FK" },
          { name: "start_date", type: "DATE" },
          { name: "end_date", type: "DATE" },
          { name: "cv_searches_used", type: "INT" },
          { name: "job_posts_used", type: "INT" },
          { name: "is_active", type: "BOOLEAN" },
        ],
      },
    ],
  },
  {
    label: "Engagement & Alerts",
    color: "#e879f9",
    border: "#701a75",
    bg: "#1a0820",
    tables: [
      {
        name: "JOB_ALERTS", isNew: true,
        columns: [
          { name: "alert_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "keyword", type: "VARCHAR(255)" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "industry_id", type: "UUID", key: "FK" },
          { name: "min_salary", type: "INT" },
          { name: "job_type", type: "ENUM" },
          { name: "channel", type: "ENUM" },
          { name: "frequency", type: "ENUM" },
          { name: "is_active", type: "BOOLEAN" },
          { name: "created_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "COMPANY_FOLLOWS", isNew: true,
        columns: [
          { name: "follow_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "company_id", type: "UUID", key: "FK" },
          { name: "followed_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "NOTIFICATIONS", isNew: true,
        columns: [
          { name: "notification_id", type: "UUID", key: "PK" },
          { name: "user_id", type: "UUID", key: "FK" },
          { name: "type", type: "VARCHAR(100)" },
          { name: "title", type: "VARCHAR(255)" },
          { name: "body", type: "TEXT" },
          { name: "is_read", type: "BOOLEAN" },
          { name: "reference_id", type: "UUID" },
          { name: "created_at", type: "TIMESTAMP" },
        ],
      },
    ],
  },
  {
    label: "Recruitment / ATS",
    color: "#f472b6",
    border: "#831843",
    bg: "#1a0812",
    tables: [
      {
        name: "INTERVIEW_STAGES", isNew: true,
        columns: [
          { name: "stage_id", type: "UUID", key: "PK" },
          { name: "application_id", type: "UUID", key: "FK" },
          { name: "stage_name", type: "VARCHAR(100)" },
          { name: "stage_order", type: "INT" },
          { name: "status", type: "ENUM" },
          { name: "scheduled_at", type: "TIMESTAMP" },
          { name: "completed_at", type: "TIMESTAMP" },
          { name: "notes", type: "TEXT" },
        ],
      },
      {
        name: "RECRUITER_NOTES", isNew: true,
        columns: [
          { name: "note_id", type: "UUID", key: "PK" },
          { name: "recruiter_id", type: "UUID", key: "FK" },
          { name: "candidate_id", type: "UUID", key: "FK" },
          { name: "application_id", type: "UUID", key: "FK" },
          { name: "note_text", type: "TEXT" },
          { name: "star_rating", type: "INT (1–5)" },
          { name: "created_at", type: "TIMESTAMP" },
        ],
      },
      {
        name: "CV_VIEWS", isNew: true,
        columns: [
          { name: "view_id", type: "UUID", key: "PK" },
          { name: "candidate_id", type: "UUID", key: "FK" },
          { name: "viewer_id", type: "UUID", key: "FK" },
          { name: "company_id", type: "UUID", key: "FK" },
          { name: "viewed_at", type: "TIMESTAMP" },
          { name: "source", type: "VARCHAR(100)" },
        ],
      },
    ],
  },
  {
    label: "Analytics",
    color: "#94a3b8",
    border: "#334155",
    bg: "#0d1117",
    tables: [
      {
        name: "SALARY_STATS", isNew: true,
        columns: [
          { name: "stat_id", type: "UUID", key: "PK" },
          { name: "job_title", type: "VARCHAR(255)" },
          { name: "industry_id", type: "UUID", key: "FK" },
          { name: "city_id", type: "UUID", key: "FK" },
          { name: "avg_salary_pkr", type: "NUMERIC(12,2)" },
          { name: "min_salary_pkr", type: "NUMERIC(12,2)" },
          { name: "max_salary_pkr", type: "NUMERIC(12,2)" },
          { name: "sample_size", type: "INT" },
          { name: "computed_at", type: "TIMESTAMP" },
        ],
      },
    ],
  },
];

const KEY_COLORS: Record<string, { bg: string; text: string }> = {
  PK:    { bg: "#854d0e", text: "#fde047" },
  FK:    { bg: "#1e3a5f", text: "#93c5fd" },
  "PK,FK": { bg: "#4a1d96", text: "#c4b5fd" },
};

function TableCard({ table, accentColor }: { table: TableDef; accentColor: string }) {
  return (
    <div style={{
      background: "#111827",
      border: `1.5px solid ${table.isNew ? "#7f1d1d" : "#1e3a5f"}`,
      borderRadius: 8,
      overflow: "hidden",
      minWidth: 220,
      flex: "0 0 auto",
      boxShadow: "0 2px 8px rgba(0,0,0,0.4)",
    }}>
      {/* Table header */}
      <div style={{
        background: table.isNew ? "#3a0f0f" : "#0f1e38",
        borderBottom: `2px solid ${accentColor}`,
        padding: "8px 12px",
        display: "flex",
        alignItems: "center",
        gap: 8,
      }}>
        <span style={{
          fontSize: 11,
          fontWeight: 800,
          color: accentColor,
          letterSpacing: "0.5px",
          fontFamily: "monospace",
        }}>
          {table.name}
        </span>
        {table.isNew && (
          <span style={{
            fontSize: 9,
            fontWeight: 700,
            background: "#7f1d1d",
            color: "#fca5a5",
            padding: "1px 5px",
            borderRadius: 3,
            marginLeft: "auto",
          }}>NEW</span>
        )}
      </div>
      {/* Columns */}
      <div>
        {table.columns.map((col, i) => (
          <div key={col.name} style={{
            display: "flex",
            alignItems: "center",
            padding: "3px 10px",
            background: i % 2 === 0 ? "#111827" : "#0f1724",
            gap: 6,
            borderBottom: "1px solid #1f2937",
          }}>
            {col.key && (
              <span style={{
                fontSize: 8,
                fontWeight: 700,
                padding: "1px 4px",
                borderRadius: 3,
                background: KEY_COLORS[col.key].bg,
                color: KEY_COLORS[col.key].text,
                whiteSpace: "nowrap",
                flexShrink: 0,
              }}>{col.key}</span>
            )}
            <span style={{
              fontSize: 11,
              color: col.key ? "#e5e7eb" : "#9ca3af",
              fontFamily: "monospace",
              flex: 1,
              minWidth: 0,
              overflow: "hidden",
              textOverflow: "ellipsis",
              whiteSpace: "nowrap",
            }}>{col.name}</span>
            <span style={{
              fontSize: 10,
              color: "#4b5563",
              fontFamily: "monospace",
              whiteSpace: "nowrap",
              flexShrink: 0,
            }}>{col.type}</span>
          </div>
        ))}
      </div>
    </div>
  );
}

const RELATIONSHIPS = [
  { from: "USERS", to: "JOBSEEKER_PROFILES", label: "1:1", type: "profile" },
  { from: "USERS", to: "RECRUITER_PROFILES", label: "1:1", type: "profile" },
  { from: "USERS", to: "USER_SKILLS", label: "1:N" },
  { from: "USERS", to: "APPLICATIONS", label: "1:N" },
  { from: "USERS", to: "MATCH_SCORES", label: "1:N" },
  { from: "USERS", to: "AUDIT_LOG", label: "1:N" },
  { from: "USERS", to: "EDUCATION", label: "1:N" },
  { from: "USERS", to: "WORK_EXPERIENCE", label: "1:N" },
  { from: "USERS", to: "CERTIFICATIONS", label: "1:N" },
  { from: "USERS", to: "USER_LANGUAGES", label: "M:N via" },
  { from: "USERS", to: "JOB_ALERTS", label: "1:N" },
  { from: "USERS", to: "SAVED_JOBS", label: "M:N via" },
  { from: "USERS", to: "COMPANY_FOLLOWS", label: "M:N via" },
  { from: "USERS", to: "NOTIFICATIONS", label: "1:N" },
  { from: "USERS", to: "SKILL_TEST_RESULTS", label: "1:N" },
  { from: "USERS", to: "CV_VIEWS", label: "1:N" },
  { from: "SKILLS", to: "USER_SKILLS", label: "1:N" },
  { from: "SKILLS", to: "JOB_SKILLS", label: "1:N" },
  { from: "SKILLS", to: "SKILL_TEST_RESULTS", label: "1:N" },
  { from: "JOB_POSTINGS", to: "JOB_SKILLS", label: "1:N" },
  { from: "JOB_POSTINGS", to: "APPLICATIONS", label: "1:N" },
  { from: "JOB_POSTINGS", to: "MATCH_SCORES", label: "1:N" },
  { from: "JOB_POSTINGS", to: "SAVED_JOBS", label: "1:N" },
  { from: "APPLICATIONS", to: "INTERVIEW_STAGES", label: "1:N" },
  { from: "APPLICATIONS", to: "RECRUITER_NOTES", label: "1:N" },
  { from: "COMPANIES", to: "RECRUITER_PROFILES", label: "1:N" },
  { from: "COMPANIES", to: "JOB_POSTINGS", label: "1:N" },
  { from: "COMPANIES", to: "COMPANY_FOLLOWS", label: "1:N" },
  { from: "COMPANIES", to: "EMPLOYER_PACKAGE_SUBSCRIPTIONS", label: "1:N" },
  { from: "COMPANIES", to: "CV_VIEWS", label: "1:N" },
  { from: "PACKAGES", to: "EMPLOYER_PACKAGE_SUBSCRIPTIONS", label: "1:N" },
  { from: "CITIES", to: "JOBSEEKER_PROFILES", label: "Ref" },
  { from: "CITIES", to: "JOB_POSTINGS", label: "Ref" },
  { from: "CITIES", to: "WORK_EXPERIENCE", label: "Ref" },
  { from: "CITIES", to: "COMPANIES", label: "Ref" },
  { from: "CITIES", to: "JOB_ALERTS", label: "Ref" },
  { from: "CITIES", to: "SALARY_STATS", label: "Ref" },
  { from: "INDUSTRIES", to: "WORK_EXPERIENCE", label: "Ref" },
  { from: "INDUSTRIES", to: "JOB_POSTINGS", label: "Ref" },
  { from: "INDUSTRIES", to: "COMPANIES", label: "Ref" },
  { from: "INDUSTRIES", to: "JOB_ALERTS", label: "Ref" },
  { from: "INDUSTRIES", to: "SALARY_STATS", label: "Ref" },
  { from: "JOB_CATEGORIES", to: "JOB_POSTINGS", label: "Ref" },
  { from: "JOB_CATEGORIES", to: "JOB_CATEGORIES", label: "Self-ref" },
  { from: "LANGUAGES", to: "USER_LANGUAGES", label: "1:N" },
];

export default function ERD() {
  const [activeTable, setActiveTable] = useState<string | null>(null);
  const [showRels, setShowRels] = useState(false);

  const relatedTables = activeTable
    ? new Set(
        RELATIONSHIPS
          .filter(r => r.from === activeTable || r.to === activeTable)
          .flatMap(r => [r.from, r.to])
      )
    : null;

  const activeRels = activeTable
    ? RELATIONSHIPS.filter(r => r.from === activeTable || r.to === activeTable)
    : [];

  const totalTables = GROUPS.reduce((a, g) => a + g.tables.length, 0);
  const newCount = GROUPS.reduce((a, g) => a + g.tables.filter(t => t.isNew).length, 0);

  return (
    <div style={{ background: "#0a0f1a", minHeight: "100vh", fontFamily: "Arial, sans-serif", color: "#e2e8f0" }}>
      {/* Header */}
      <div style={{
        background: "linear-gradient(135deg, #1F3864 0%, #2E75B6 100%)",
        padding: "18px 28px 14px",
        borderBottom: "3px solid #2E75B6",
      }}>
        <div style={{ fontSize: 18, fontWeight: 800, color: "#fff", letterSpacing: 0.3 }}>
          DATABASE SYSTEMS LAB — AI Job &amp; Skill Matching Platform
        </div>
        <div style={{ fontSize: 12, color: "#D9E2F3", marginTop: 3, marginBottom: 12 }}>
          Entity Relationship Diagram &nbsp;·&nbsp; Furqan Ullah &amp; Syed Fahad Ali Shah &nbsp;·&nbsp; May 2026
        </div>
        <div style={{ display: "flex", gap: 24, flexWrap: "wrap", alignItems: "center" }}>
          {[
            { label: "Total Tables", value: totalTables, color: "#60a5fa" },
            { label: "Original Tables", value: totalTables - newCount, color: "#4ade80" },
            { label: "New Tables Added", value: newCount, color: "#f87171" },
            { label: "Relationships", value: RELATIONSHIPS.length + "+", color: "#c084fc" },
          ].map(s => (
            <div key={s.label} style={{ display: "flex", alignItems: "center", gap: 6 }}>
              <span style={{ fontSize: 20, fontWeight: 800, color: s.color }}>{s.value}</span>
              <span style={{ fontSize: 11, color: "#94a3b8" }}>{s.label}</span>
            </div>
          ))}
        </div>
      </div>

      {/* Toolbar */}
      <div style={{
        background: "#111827",
        borderBottom: "1px solid #1f2937",
        padding: "8px 28px",
        display: "flex",
        gap: 12,
        alignItems: "center",
        flexWrap: "wrap",
      }}>
        <div style={{ display: "flex", gap: 16 }}>
          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "#9ca3af" }}>
            <span style={{ display: "inline-block", width: 10, height: 10, borderRadius: 2, background: "#0f1e38", border: "2px solid #3b82f6" }} />
            Original table
          </span>
          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "#9ca3af" }}>
            <span style={{ display: "inline-block", width: 10, height: 10, borderRadius: 2, background: "#3a0f0f", border: "2px solid #ef4444" }} />
            New table
          </span>
          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "#9ca3af" }}>
            <span style={{ display: "inline-block", fontSize: 9, fontWeight: 800, background: "#854d0e", color: "#fde047", padding: "0 4px", borderRadius: 2 }}>PK</span>
            Primary Key
          </span>
          <span style={{ display: "flex", alignItems: "center", gap: 5, fontSize: 12, color: "#9ca3af" }}>
            <span style={{ display: "inline-block", fontSize: 9, fontWeight: 800, background: "#1e3a5f", color: "#93c5fd", padding: "0 4px", borderRadius: 2 }}>FK</span>
            Foreign Key
          </span>
        </div>
        <div style={{ marginLeft: "auto", display: "flex", gap: 8, alignItems: "center" }}>
          <span style={{ fontSize: 12, color: "#6b7280" }}>Click any table to highlight its relationships</span>
          <button
            onClick={() => setShowRels(!showRels)}
            style={{
              padding: "4px 12px", borderRadius: 6, fontSize: 12, cursor: "pointer",
              border: "1px solid #2E75B6", background: showRels ? "#2E75B6" : "transparent",
              color: showRels ? "#fff" : "#7bb3e8",
            }}
          >
            {showRels ? "Hide" : "Show"} All Relationships
          </button>
          {activeTable && (
            <button
              onClick={() => setActiveTable(null)}
              style={{
                padding: "4px 12px", borderRadius: 6, fontSize: 12, cursor: "pointer",
                border: "1px solid #374151", background: "transparent", color: "#9ca3af",
              }}
            >
              Clear Selection
            </button>
          )}
        </div>
      </div>

      {/* Active table relationships panel */}
      {activeTable && (
        <div style={{
          background: "#0f1724",
          borderBottom: "1px solid #1f2937",
          padding: "10px 28px",
          display: "flex",
          alignItems: "flex-start",
          gap: 16,
          flexWrap: "wrap",
        }}>
          <span style={{ fontSize: 13, fontWeight: 700, color: "#60a5fa", whiteSpace: "nowrap", marginTop: 2 }}>
            {activeTable} relationships:
          </span>
          <div style={{ display: "flex", gap: 8, flexWrap: "wrap" }}>
            {activeRels.map((r, i) => (
              <span key={i} style={{
                fontSize: 11, padding: "3px 10px", borderRadius: 20,
                background: "#1e2d45", border: "1px solid #2E75B6", color: "#93c5fd",
                cursor: "pointer",
              }}
                onClick={() => setActiveTable(r.from === activeTable ? r.to : r.from)}
              >
                <span style={{ color: "#fbbf24", fontWeight: 700 }}>{r.label}</span>
                {" → "}
                {r.from === activeTable ? r.to : r.from}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* All Relationships Panel */}
      {showRels && (
        <div style={{
          background: "#0c111b",
          borderBottom: "1px solid #1f2937",
          padding: "12px 28px",
          maxHeight: 200,
          overflowY: "auto",
        }}>
          <div style={{ fontSize: 12, color: "#6b7280", marginBottom: 8, fontWeight: 700 }}>All {RELATIONSHIPS.length} Relationships</div>
          <div style={{ display: "flex", flexWrap: "wrap", gap: 6 }}>
            {RELATIONSHIPS.map((r, i) => (
              <span key={i} style={{
                fontSize: 11, padding: "2px 8px", borderRadius: 4,
                background: "#111827", border: "1px solid #1f2937", color: "#9ca3af",
                whiteSpace: "nowrap",
              }}>
                <span style={{ color: "#4ade80" }}>{r.from}</span>
                <span style={{ color: "#fbbf24", margin: "0 4px" }}>—{r.label}→</span>
                <span style={{ color: "#60a5fa" }}>{r.to}</span>
              </span>
            ))}
          </div>
        </div>
      )}

      {/* Main ERD */}
      <div style={{ padding: "20px 28px", overflowX: "auto" }}>
        <div style={{ display: "flex", flexDirection: "column", gap: 16, minWidth: 900 }}>
          {GROUPS.map(group => (
            <div key={group.label} style={{
              background: group.bg,
              border: `1.5px solid ${group.border}`,
              borderRadius: 10,
              overflow: "hidden",
            }}>
              {/* Group header */}
              <div style={{
                background: `${group.border}88`,
                borderBottom: `1px solid ${group.border}`,
                padding: "7px 16px",
                display: "flex",
                alignItems: "center",
                gap: 10,
              }}>
                <div style={{ width: 8, height: 8, borderRadius: "50%", background: group.color }} />
                <span style={{ fontSize: 12, fontWeight: 800, color: group.color, letterSpacing: 1, textTransform: "uppercase" }}>
                  {group.label}
                </span>
                <span style={{ fontSize: 11, color: "#6b7280", marginLeft: 4 }}>
                  ({group.tables.length} {group.tables.length === 1 ? "table" : "tables"})
                </span>
              </div>
              {/* Tables in group */}
              <div style={{ padding: "12px 16px", display: "flex", gap: 12, flexWrap: "wrap" }}>
                {group.tables.map(table => (
                  <div
                    key={table.name}
                    onClick={() => setActiveTable(activeTable === table.name ? null : table.name)}
                    style={{
                      cursor: "pointer",
                      opacity: relatedTables && !relatedTables.has(table.name) ? 0.3 : 1,
                      outline: activeTable === table.name ? `2px solid ${group.color}` : "none",
                      outlineOffset: 2,
                      borderRadius: 10,
                      transition: "opacity 0.2s, transform 0.1s",
                      transform: activeTable === table.name ? "scale(1.02)" : "scale(1)",
                    }}
                  >
                    <TableCard table={table} accentColor={group.color} />
                  </div>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}
