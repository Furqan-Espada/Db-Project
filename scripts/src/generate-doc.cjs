const {
  Document, Packer, Paragraph, TextRun, Table, TableRow, TableCell,
  Header, Footer, AlignmentType, HeadingLevel, BorderStyle, WidthType,
  ShadingType, VerticalAlign, PageNumber, LevelFormat, TabStopType, TabStopPosition
} = require('docx');
const fs = require('fs');

const C = {
  navy:     '1F3864',
  blue:     '2E75B6',
  lightBlue:'D9E2F3',
  altRow:   'EEF3FA',
  white:    'FFFFFF',
  border:   'ADB9CA',
  sub:      '2F5597',
  text:     '1A1A1A',
  muted:    '5A5A5A',
  green:    '375623',
  greenBg:  'E2EFDA',
  red:      '7B0D0D',
  redBg:    'FCE4D6',
  amber:    '7B5E00',
  amberBg:  'FFF2CC',
};

const bdr = { style: BorderStyle.SINGLE, size: 1, color: C.border };
const bdrs = { top: bdr, bottom: bdr, left: bdr, right: bdr };

function cell(text, opts = {}) {
  const { bold=false, shade=null, align=AlignmentType.LEFT, size=19,
          color=C.text, width=null, italic=false } = opts;
  return new TableCell({
    borders: bdrs, verticalAlign: VerticalAlign.CENTER,
    shading: shade ? { fill: shade, type: ShadingType.CLEAR } : undefined,
    width: width ? { size: width, type: WidthType.DXA } : undefined,
    margins: { top: 80, bottom: 80, left: 120, right: 120 },
    children: [new Paragraph({ alignment: align,
      children: [new TextRun({ text, bold, size, color, font: 'Arial', italic })] })]
  });
}
function hcell(text, w) {
  return cell(text, { bold:true, shade:C.lightBlue, size:19, color:C.navy, width:w });
}
function mkTable(headers, rows, widths) {
  const total = widths.reduce((a,b)=>a+b,0);
  return new Table({
    width: { size: total, type: WidthType.DXA }, columnWidths: widths,
    rows: [
      new TableRow({ tableHeader:true,
        children: headers.map((h,i)=>hcell(h, widths[i])) }),
      ...rows.map((row, ri) =>
        new TableRow({ children: row.map((v, ci) => {
          const shade = ri%2===1 ? C.altRow : C.white;
          if (typeof v === 'object' && v._type === 'CELL') return v.cell;
          return cell(String(v), { shade, width: widths[ci], size: 18 });
        })})
      )
    ]
  });
}

function h1(t) {
  return new Paragraph({ heading: HeadingLevel.HEADING_1,
    spacing: { before:360, after:180 },
    border: { bottom:{ style:BorderStyle.SINGLE, size:6, color:C.blue, space:6 } },
    children:[new TextRun({ text:t, bold:true, size:36, color:C.navy, font:'Arial' })] });
}
function h2(t) {
  return new Paragraph({ heading:HeadingLevel.HEADING_2,
    spacing:{ before:260, after:120 },
    children:[new TextRun({ text:t, bold:true, size:28, color:C.sub, font:'Arial' })] });
}
function h3(t) {
  return new Paragraph({ heading:HeadingLevel.HEADING_3,
    spacing:{ before:200, after:80 },
    children:[new TextRun({ text:t, bold:true, size:24, color:C.blue, font:'Arial' })] });
}
function para(t, opts={}) {
  const { bold=false, size=20, color=C.text, spacing={before:60,after:60}, italic=false } = opts;
  return new Paragraph({ spacing,
    children:[new TextRun({ text:t, bold, size, color, font:'Arial', italic })] });
}
function sp(b=120) { return new Paragraph({ spacing:{before:b,after:0}, children:[new TextRun('')] }); }
function pb() { return new Paragraph({ pageBreakBefore:true, children:[new TextRun('')] }); }

function bullet(t, opts={}) {
  const { size=20, color=C.text, bold=false } = opts;
  return new Paragraph({ spacing:{before:50,after:50},
    numbering:{ reference:'bullets', level:0 },
    children:[new TextRun({ text:t, size, color, font:'Arial', bold })] });
}

// ── COMPARISON TABLE (existing vs rozee) ─────────────────────
const compRows = [
  ['USERS','✅ Exists','Core identity table — present','–'],
  ['JOBSEEKER_PROFILES','✅ Exists','Job seeker extended profile','–'],
  ['RECRUITER_PROFILES','✅ Exists','Recruiter extended profile','–'],
  ['SKILLS','✅ Exists','Master skill reference','–'],
  ['USER_SKILLS','✅ Exists','User–Skill many-to-many junction','–'],
  ['JOB_POSTINGS','✅ Exists','Job listings','–'],
  ['JOB_SKILLS','✅ Exists','Job–Skill many-to-many junction','–'],
  ['APPLICATIONS','✅ Exists','Application tracking','–'],
  ['MATCH_SCORES','✅ Exists','AI compatibility scores','–'],
  ['AUDIT_LOG','✅ Exists','Write-operation log','–'],
  ['EDUCATION','❌ Missing','Candidate degree, institution, year — Rozee shows full education history','ADD'],
  ['WORK_EXPERIENCE','❌ Missing','Past job titles, companies, duration — Rozee CV has full experience timeline','ADD'],
  ['CERTIFICATIONS','❌ Missing','Professional certificates & licences (e.g. PMP, AWS) — visible on Rozee profiles','ADD'],
  ['LANGUAGES','❌ Missing','Language proficiency (e.g. Urdu, English) — listed on Rozee CV','ADD'],
  ['USER_LANGUAGES','❌ Missing','Junction: user ↔ language with proficiency level','ADD'],
  ['INDUSTRIES','❌ Missing','Industry master list (e.g. Banking, IT, Healthcare) — Rozee filters by industry','ADD'],
  ['JOB_CATEGORIES','❌ Missing','Functional job-category list (e.g. Marketing, Engineering) — Rozee categorizes postings','ADD'],
  ['CITIES','❌ Missing','City/location master table (300+ cities on Rozee) for structured location data','ADD'],
  ['COMPANIES','❌ Missing','Employer company profiles — Rozee has dedicated company pages with logo, about, size','ADD'],
  ['JOB_ALERTS','❌ Missing','Saved alert rules (keyword, city, salary) + channel (email/SMS/WhatsApp) — Rozee feature','ADD'],
  ['SAVED_JOBS','❌ Missing','Candidate-saved/bookmarked job postings — Rozee "Save Job" feature','ADD'],
  ['COMPANY_FOLLOWS','❌ Missing','Candidates following companies to get updates — Rozee "Follow Company" feature','ADD'],
  ['RECRUITER_NOTES','❌ Missing','Per-candidate notes & star ratings left by recruiters — Rozee employer dashboard','ADD'],
  ['INTERVIEW_STAGES','❌ Missing','Pipeline stages beyond shortlisted/rejected (e.g. Phone Screen, HR Round, Offer) — Rozee ATS','ADD'],
  ['NOTIFICATIONS','❌ Missing','In-app & push notification log (alert triggers, application updates) — Rozee real-time alerts','ADD'],
  ['PACKAGES','❌ Missing','Employer subscription packages (Bronze/Silver/Gold/Platinum) — Rozee paid plans','ADD'],
  ['EMPLOYER_PACKAGE_SUBSCRIPTIONS','❌ Missing','Records which company holds which package and its validity period','ADD'],
  ['CV_VIEWS','❌ Missing','Log of recruiter CV views — Rozee shows candidates who viewed their profile','ADD'],
  ['SKILL_TEST_RESULTS','❌ Missing','Tarbiat/skill-test scores per candidate per skill — Rozee "Tarbiat" assessments','ADD'],
  ['SALARY_STATS','❌ Missing','Aggregated salary data by role/city/industry — Rozee salary statistics feature','ADD'],
];

function statusCell(text, ri) {
  const shade = text.startsWith('✅')
    ? C.greenBg
    : text.startsWith('❌') ? C.redBg
    : (ri%2===1 ? C.altRow : C.white);
  const color = text.startsWith('✅') ? C.green : text.startsWith('❌') ? C.red : C.text;
  return cell(text, { shade, color, size:18, width:1400 });
}
function actionCell(text, ri) {
  const shade = text==='ADD' ? C.amberBg : (ri%2===1?C.altRow:C.white);
  const color = text==='ADD' ? C.amber : C.muted;
  return cell(text, { shade, color, bold:text==='ADD', size:18, width:700 });
}

// Build comparison table manually (custom cell colors per row)
function buildCompTable() {
  const widths = [2200, 1400, 3460, 700];
  const total = widths.reduce((a,b)=>a+b,0);
  return new Table({
    width:{size:total, type:WidthType.DXA}, columnWidths:widths,
    rows:[
      new TableRow({ tableHeader:true, children:[
        hcell('Table Name', widths[0]), hcell('Status', widths[1]),
        hcell('Rozee.pk Requirement', widths[2]), hcell('Action', widths[3])
      ]}),
      ...compRows.map((row, ri) => new TableRow({ children:[
        cell(row[0], { shade: ri%2===1?C.altRow:C.white, width:widths[0], size:18, bold: row[3]==='ADD' }),
        statusCell(row[1], ri),
        cell(row[3]==='ADD' ? row[2] : row[2], { shade: ri%2===1?C.altRow:C.white, width:widths[2], size:18 }),
        actionCell(row[3], ri),
      ]}))
    ]
  });
}

// ── NEW TABLE DEFINITIONS ─────────────────────────────────────
const newTables = [
  {
    name: 'EDUCATION',
    purpose: 'Stores the full academic history of each job seeker. Rozee.pk displays multiple education entries on candidate profiles (degree, institution, field, graduation year). This is a one-to-many extension of JOBSEEKER_PROFILES.',
    columns: [
      ['education_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The candidate who holds this qualification'],
      ['degree_title','VARCHAR(100)','NOT NULL','E.g. BSc Computer Science, MBA, Matric'],
      ['institution','VARCHAR(255)','NOT NULL','Name of university, college, or school'],
      ['field_of_study','VARCHAR(150)','NULLABLE','Major or specialisation'],
      ['start_year','INT','CHECK (≥ 1950)','Year studies began'],
      ['end_year','INT','NULLABLE, CHECK (≥ start_year)','Graduation year; NULL if ongoing'],
      ['grade','VARCHAR(50)','NULLABLE','CGPA, percentage, or division'],
    ],
    pk:'education_id', fk:['user_id → USERS(user_id) ON DELETE CASCADE'],
    rel:'1:N — USERS → EDUCATION (one candidate, many degrees)'
  },
  {
    name: 'WORK_EXPERIENCE',
    purpose: 'Stores the full professional work history of a candidate. Rozee.pk CV builder requires job title, company, industry, and duration for each past role. Essential for experience-level filtering and AI matching.',
    columns: [
      ['experience_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The candidate who held this role'],
      ['job_title','VARCHAR(150)','NOT NULL','Title of the position held'],
      ['company_name','VARCHAR(255)','NOT NULL','Employer name'],
      ['industry_id','UUID','FK → INDUSTRIES, NULLABLE','Industry sector of the employer'],
      ['city_id','UUID','FK → CITIES, NULLABLE','Work location city'],
      ['start_date','DATE','NOT NULL','Employment start date'],
      ['end_date','DATE','NULLABLE','Employment end date; NULL if current job'],
      ['description','TEXT','NULLABLE','Role summary for TF-IDF pipeline'],
      ['is_current','BOOLEAN','DEFAULT FALSE','Flags ongoing employment'],
    ],
    pk:'experience_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','industry_id → INDUSTRIES(industry_id)','city_id → CITIES(city_id)'],
    rel:'1:N — USERS → WORK_EXPERIENCE'
  },
  {
    name: 'CERTIFICATIONS',
    purpose: 'Tracks professional certifications and licences held by candidates. Rozee.pk displays these on the candidate CV (e.g. PMP, AWS Certified, CFA). Structured storage enables filtering by certification type.',
    columns: [
      ['certification_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','Certificate holder'],
      ['title','VARCHAR(255)','NOT NULL','Name of the certification (e.g. AWS Solutions Architect)'],
      ['issuing_body','VARCHAR(255)','NULLABLE','Organisation that issued the certificate'],
      ['issue_date','DATE','NULLABLE','Date of issuance'],
      ['expiry_date','DATE','NULLABLE','Expiry date; NULL if no expiry'],
      ['credential_url','VARCHAR(500)','NULLABLE','Verification link'],
    ],
    pk:'certification_id', fk:['user_id → USERS(user_id) ON DELETE CASCADE'],
    rel:'1:N — USERS → CERTIFICATIONS'
  },
  {
    name: 'LANGUAGES',
    purpose: 'Master reference table of human languages available on the platform. Rozee.pk allows candidates to list language proficiencies on their CV (Urdu, English, Arabic, etc.).',
    columns: [
      ['language_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(100)','UK, NOT NULL','Language name (e.g. English, Urdu, Arabic)'],
    ],
    pk:'language_id', fk:[],
    rel:'M:N source — linked via USER_LANGUAGES junction'
  },
  {
    name: 'USER_LANGUAGES',
    purpose: 'Junction table resolving the many-to-many relationship between users and languages. Stores proficiency level per language per user.',
    columns: [
      ['user_id','UUID','PK (composite), FK → USERS','The candidate'],
      ['language_id','UUID','PK (composite), FK → LANGUAGES','The language'],
      ['proficiency','ENUM(\'beginner\',\'conversational\',\'fluent\',\'native\')','NOT NULL','Self-assessed language level'],
    ],
    pk:'(user_id, language_id) — composite',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','language_id → LANGUAGES(language_id)'],
    rel:'M:N — USERS ↔ LANGUAGES via USER_LANGUAGES'
  },
  {
    name: 'INDUSTRIES',
    purpose: 'Master reference list of industry sectors. Rozee.pk has over 20 industry filters (Banking, IT, Healthcare, FMCG, etc.). Used for filtering job postings, work experience records, and company profiles.',
    columns: [
      ['industry_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(150)','UK, NOT NULL','Industry name (e.g. Information Technology, Banking & Finance)'],
    ],
    pk:'industry_id', fk:[],
    rel:'Referenced by WORK_EXPERIENCE, JOB_POSTINGS, COMPANIES'
  },
  {
    name: 'JOB_CATEGORIES',
    purpose: 'Master reference list of functional job categories. Rozee.pk categorises postings by function (e.g. Accounts / Finance, Engineering, Sales & Marketing). Enables category-based search and filtering.',
    columns: [
      ['category_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(150)','UK, NOT NULL','Functional category (e.g. Software Development, Human Resources)'],
      ['parent_category_id','UUID','FK → JOB_CATEGORIES, NULLABLE','Supports sub-category nesting (e.g. IT → Software Dev)'],
    ],
    pk:'category_id',
    fk:['parent_category_id → JOB_CATEGORIES(category_id)'],
    rel:'Self-referencing 1:N for sub-categories; referenced by JOB_POSTINGS'
  },
  {
    name: 'CITIES',
    purpose: 'Master reference table for Pakistani cities and locations. Rozee.pk supports 300+ cities in its location filters. Normalising cities prevents free-text duplication ("Isb" vs "Islamabad") and enables structured location queries.',
    columns: [
      ['city_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(150)','NOT NULL','City name (e.g. Lahore, Karachi, Islamabad)'],
      ['province','VARCHAR(100)','NULLABLE','Province or region (e.g. Punjab, Sindh, KPK)'],
    ],
    pk:'city_id', fk:[],
    rel:'Referenced by JOB_POSTINGS, WORK_EXPERIENCE, COMPANIES, JOBSEEKER_PROFILES'
  },
  {
    name: 'COMPANIES',
    purpose: 'Dedicated company profile table. Rozee.pk has individual company pages with logo, description, industry, size, and active job count. Decoupling company data from RECRUITER_PROFILES supports multiple recruiters per company.',
    columns: [
      ['company_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(255)','NOT NULL','Official company name'],
      ['industry_id','UUID','FK → INDUSTRIES, NULLABLE','Primary industry sector'],
      ['city_id','UUID','FK → CITIES, NULLABLE','Headquarters location'],
      ['logo_url','VARCHAR(500)','NULLABLE','Company logo storage path'],
      ['website_url','VARCHAR(500)','NULLABLE','Official website'],
      ['description','TEXT','NULLABLE','Company "About" text'],
      ['size_range','VARCHAR(50)','NULLABLE','E.g. 1–10, 51–200, 1000+ employees'],
      ['is_verified','BOOLEAN','DEFAULT FALSE','Rozee CNIC/NTN-verified employer badge'],
      ['created_at','TIMESTAMP','DEFAULT NOW()','Profile creation timestamp'],
    ],
    pk:'company_id',
    fk:['industry_id → INDUSTRIES(industry_id)','city_id → CITIES(city_id)'],
    rel:'1:N — COMPANIES → RECRUITER_PROFILES; 1:N — COMPANIES → JOB_POSTINGS'
  },
  {
    name: 'JOB_ALERTS',
    purpose: 'Stores saved job alert rules configured by candidates. Rozee.pk allows users to set up keyword + location + salary alerts delivered via email, SMS, or WhatsApp push notification.',
    columns: [
      ['alert_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The candidate who created the alert'],
      ['keyword','VARCHAR(255)','NULLABLE','Job title or skill keyword trigger'],
      ['city_id','UUID','FK → CITIES, NULLABLE','Location filter for the alert'],
      ['industry_id','UUID','FK → INDUSTRIES, NULLABLE','Industry filter'],
      ['min_salary','INT','NULLABLE, CHECK (≥ 0)','Minimum salary threshold'],
      ['job_type','ENUM(\'full-time\',\'part-time\',\'contract\',\'internship\')','NULLABLE','Employment type filter'],
      ['channel','ENUM(\'email\',\'sms\',\'whatsapp\',\'push\')','NOT NULL, DEFAULT email','Delivery channel'],
      ['frequency','ENUM(\'instant\',\'daily\',\'weekly\')','NOT NULL, DEFAULT daily','Alert frequency'],
      ['is_active','BOOLEAN','DEFAULT TRUE','Allows pausing without deleting'],
      ['created_at','TIMESTAMP','DEFAULT NOW()','Alert creation timestamp'],
    ],
    pk:'alert_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','city_id → CITIES(city_id)','industry_id → INDUSTRIES(industry_id)'],
    rel:'1:N — USERS → JOB_ALERTS'
  },
  {
    name: 'SAVED_JOBS',
    purpose: 'Records jobs bookmarked by candidates for later review. Rozee.pk "Save Job" feature allows candidates to build a shortlist without applying immediately.',
    columns: [
      ['saved_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The saving candidate'],
      ['job_id','UUID','FK → JOB_POSTINGS, NOT NULL','The bookmarked posting'],
      ['saved_at','TIMESTAMP','DEFAULT NOW()','Timestamp of the save action'],
    ],
    pk:'saved_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','job_id → JOB_POSTINGS(job_id) ON DELETE CASCADE'],
    rel:'M:N (resolved) — USERS ↔ JOB_POSTINGS via SAVED_JOBS; UNIQUE(user_id, job_id)'
  },
  {
    name: 'COMPANY_FOLLOWS',
    purpose: 'Tracks candidates who follow company profiles to receive job update notifications. Rozee.pk "Follow Company" feature delivers alerts when a followed company posts new openings.',
    columns: [
      ['follow_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The following candidate'],
      ['company_id','UUID','FK → COMPANIES, NOT NULL','The followed company'],
      ['followed_at','TIMESTAMP','DEFAULT NOW()','Follow action timestamp'],
    ],
    pk:'follow_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','company_id → COMPANIES(company_id) ON DELETE CASCADE'],
    rel:'M:N (resolved) — USERS ↔ COMPANIES; UNIQUE(user_id, company_id)'
  },
  {
    name: 'RECRUITER_NOTES',
    purpose: 'Stores private per-candidate notes and star ratings written by recruiters during CV review. Rozee.pk employer dashboard allows recruiters to annotate candidates and rate them (1–5 stars) for internal use.',
    columns: [
      ['note_id','UUID','PK','Auto-generated identifier'],
      ['recruiter_id','UUID','FK → USERS, NOT NULL','The recruiter leaving the note'],
      ['candidate_id','UUID','FK → USERS, NOT NULL','The candidate being annotated'],
      ['application_id','UUID','FK → APPLICATIONS, NULLABLE','Optional link to a specific application'],
      ['note_text','TEXT','NULLABLE','Free-text private note'],
      ['star_rating','INT','NULLABLE, CHECK (1–5)','Recruiter quality rating for this candidate'],
      ['created_at','TIMESTAMP','DEFAULT NOW()','Note creation timestamp'],
    ],
    pk:'note_id',
    fk:['recruiter_id → USERS(user_id)','candidate_id → USERS(user_id)','application_id → APPLICATIONS(application_id)'],
    rel:'N:N annotation — USERS (recruiter) × USERS (candidate)'
  },
  {
    name: 'INTERVIEW_STAGES',
    purpose: 'Tracks granular hiring pipeline stages per application beyond simple pending/shortlisted/rejected. Rozee.pk ATS shows stages: Applied → Reviewed → Shortlisted → Phone Screen → HR Interview → Technical → Offer → Hired.',
    columns: [
      ['stage_id','UUID','PK','Auto-generated identifier'],
      ['application_id','UUID','FK → APPLICATIONS, NOT NULL','The application moving through the pipeline'],
      ['stage_name','VARCHAR(100)','NOT NULL','E.g. Phone Screen, Technical Interview, Offer Extended'],
      ['stage_order','INT','NOT NULL, CHECK (≥ 1)','Ordering of stages within the pipeline'],
      ['status','ENUM(\'pending\',\'passed\',\'failed\',\'withdrawn\')','NOT NULL, DEFAULT pending','Outcome at this stage'],
      ['scheduled_at','TIMESTAMP','NULLABLE','Interview or stage scheduled datetime'],
      ['completed_at','TIMESTAMP','NULLABLE','Actual completion datetime'],
      ['notes','TEXT','NULLABLE','Interviewer feedback notes'],
    ],
    pk:'stage_id',
    fk:['application_id → APPLICATIONS(application_id) ON DELETE CASCADE'],
    rel:'1:N — APPLICATIONS → INTERVIEW_STAGES'
  },
  {
    name: 'NOTIFICATIONS',
    purpose: 'Stores all in-app and push notification events sent to users. Rozee.pk sends real-time alerts for application updates, new matching jobs, interview schedules, and company news.',
    columns: [
      ['notification_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','Notification recipient'],
      ['type','VARCHAR(100)','NOT NULL','E.g. new_match, application_update, interview_invite, alert_triggered'],
      ['title','VARCHAR(255)','NOT NULL','Short notification headline'],
      ['body','TEXT','NULLABLE','Full notification message body'],
      ['is_read','BOOLEAN','DEFAULT FALSE','Read/unread status'],
      ['reference_id','UUID','NULLABLE','Optional FK to related entity (job_id, application_id, etc.)'],
      ['created_at','TIMESTAMP','DEFAULT NOW()','Notification dispatch timestamp'],
    ],
    pk:'notification_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE'],
    rel:'1:N — USERS → NOTIFICATIONS'
  },
  {
    name: 'PACKAGES',
    purpose: 'Master catalogue of employer subscription packages. Rozee.pk sells Bronze, Silver, Gold, and Platinum plans with different posting limits, CV search quotas, and InstaMatch credits.',
    columns: [
      ['package_id','UUID','PK','Auto-generated identifier'],
      ['name','VARCHAR(100)','UK, NOT NULL','E.g. Bronze, Silver, Gold, Platinum, Basic'],
      ['price_pkr','NUMERIC(12,2)','NOT NULL','Listed price in Pakistani Rupees'],
      ['job_post_limit','INT','NOT NULL','Maximum number of active job postings allowed'],
      ['cv_search_limit','INT','NOT NULL','CV database search quota (use -1 for unlimited)'],
      ['instamatch_credits','INT','DEFAULT 0','Number of InstaMatch algorithm runs included'],
      ['validity_days','INT','NOT NULL','Package duration in days'],
      ['description','TEXT','NULLABLE','Package feature description'],
    ],
    pk:'package_id', fk:[],
    rel:'1:N source — referenced by EMPLOYER_PACKAGE_SUBSCRIPTIONS'
  },
  {
    name: 'EMPLOYER_PACKAGE_SUBSCRIPTIONS',
    purpose: 'Records which company holds which active package and tracks usage. Links companies to purchased packages with validity and quota tracking.',
    columns: [
      ['subscription_id','UUID','PK','Auto-generated identifier'],
      ['company_id','UUID','FK → COMPANIES, NOT NULL','The purchasing company'],
      ['package_id','UUID','FK → PACKAGES, NOT NULL','The purchased package tier'],
      ['start_date','DATE','NOT NULL','Subscription activation date'],
      ['end_date','DATE','NOT NULL','Subscription expiry date (start_date + validity_days)'],
      ['cv_searches_used','INT','DEFAULT 0','Running count of CV searches consumed'],
      ['job_posts_used','INT','DEFAULT 0','Running count of active job postings used'],
      ['is_active','BOOLEAN','DEFAULT TRUE','FALSE when expired or cancelled'],
    ],
    pk:'subscription_id',
    fk:['company_id → COMPANIES(company_id)','package_id → PACKAGES(package_id)'],
    rel:'M:N resolved — COMPANIES ↔ PACKAGES (with usage tracking)'
  },
  {
    name: 'CV_VIEWS',
    purpose: 'Logs every instance of a recruiter viewing a candidate CV/profile. Rozee.pk notifies candidates when their profile is viewed and shows a "Who viewed my CV" summary — a key engagement feature.',
    columns: [
      ['view_id','UUID','PK','Auto-generated identifier'],
      ['candidate_id','UUID','FK → USERS, NOT NULL','The candidate whose CV was viewed'],
      ['viewer_id','UUID','FK → USERS, NULLABLE','The recruiter who viewed (NULL for anonymous/algorithm views)'],
      ['company_id','UUID','FK → COMPANIES, NULLABLE','Company context of the recruiter'],
      ['viewed_at','TIMESTAMP','DEFAULT NOW()','Exact view timestamp'],
      ['source','VARCHAR(100)','NULLABLE','How the view was triggered: cv_search, instamatch, direct'],
    ],
    pk:'view_id',
    fk:['candidate_id → USERS(user_id)','viewer_id → USERS(user_id)','company_id → COMPANIES(company_id)'],
    rel:'Many views per candidate; many views per recruiter — append-only log'
  },
  {
    name: 'SKILL_TEST_RESULTS',
    purpose: 'Stores results of Rozee.pk "Tarbiat" skill assessments taken by candidates. Verified test scores appear on candidate profiles as trust signals for recruiters.',
    columns: [
      ['result_id','UUID','PK','Auto-generated identifier'],
      ['user_id','UUID','FK → USERS, NOT NULL','The candidate who took the test'],
      ['skill_id','UUID','FK → SKILLS, NOT NULL','The skill being assessed'],
      ['score','NUMERIC(5,2)','NOT NULL, CHECK (0–100)','Percentage score achieved'],
      ['percentile','NUMERIC(5,2)','NULLABLE, CHECK (0–100)','Score percentile vs all test takers'],
      ['taken_at','TIMESTAMP','DEFAULT NOW()','Test completion timestamp'],
      ['is_verified','BOOLEAN','DEFAULT FALSE','Rozee-verified badge flag'],
    ],
    pk:'result_id',
    fk:['user_id → USERS(user_id) ON DELETE CASCADE','skill_id → SKILLS(skill_id)'],
    rel:'M:N resolved — USERS ↔ SKILLS with test score payload'
  },
  {
    name: 'SALARY_STATS',
    purpose: 'Stores aggregated salary statistics by role, industry, and city. Rozee.pk publicly shows salary insights (average, min, max) by job title — this table powers those reports.',
    columns: [
      ['stat_id','UUID','PK','Auto-generated identifier'],
      ['job_title','VARCHAR(255)','NOT NULL','Standardised job title for the stat'],
      ['industry_id','UUID','FK → INDUSTRIES, NULLABLE','Industry sector filter'],
      ['city_id','UUID','FK → CITIES, NULLABLE','Geographic filter'],
      ['avg_salary_pkr','NUMERIC(12,2)','NULLABLE','Average monthly salary in PKR'],
      ['min_salary_pkr','NUMERIC(12,2)','NULLABLE','Minimum reported salary'],
      ['max_salary_pkr','NUMERIC(12,2)','NULLABLE','Maximum reported salary'],
      ['sample_size','INT','NULLABLE','Number of data points used'],
      ['computed_at','TIMESTAMP','DEFAULT NOW()','Last aggregation run timestamp'],
    ],
    pk:'stat_id',
    fk:['industry_id → INDUSTRIES(industry_id)','city_id → CITIES(city_id)'],
    rel:'Reporting table — no FK from core entities into this table'
  },
];

function buildTableBlock(t) {
  const widths = [1500, 2000, 1900, 3960];
  const rows = t.columns.map(([col,type,constr,desc]) => [col, type, constr, desc]);
  return [
    h3(t.name),
    para(t.purpose, { size:19, color:C.muted }),
    sp(80),
    mkTable(['Column','Data Type','Constraints','Description'], rows, widths),
    sp(100),
    para('Keys & Relationships:', { bold:true, size:19 }),
    bullet(`Primary Key: ${t.pk}`, { size:18 }),
    ...t.fk.map(f => bullet(`Foreign Key: ${f}`, { size:18 })),
    para(`Relationship: ${t.rel}`, { size:18, color:C.muted, italic:true, spacing:{before:80,after:80} }),
    sp(180),
  ];
}

// ── UPDATED TABLES (just the modified columns) ─────────────────
const updatedTablesNote = [
  {
    table: 'JOBSEEKER_PROFILES',
    additions: [
      ['city_id','UUID','FK → CITIES, NULLABLE','Current city of residence — used in Rozee location-based job matching'],
      ['gender','ENUM(\'male\',\'female\',\'prefer_not\')','NULLABLE','Gender field present on Rozee registration/profile'],
      ['date_of_birth','DATE','NULLABLE','Age-based filtering used by some Rozee employers'],
      ['current_salary_pkr','INT','NULLABLE, CHECK (≥ 0)','Current monthly salary — Rozee salary expectation data'],
      ['expected_salary_pkr','INT','NULLABLE, CHECK (≥ 0)','Expected salary — key Rozee job-seeker field'],
      ['job_type_preference','ENUM(\'full-time\',\'part-time\',\'contract\',\'internship\')','NULLABLE','Preferred employment type'],
      ['availability','ENUM(\'immediate\',\'2_weeks\',\'1_month\',\'negotiable\')','NULLABLE, DEFAULT negotiable','Notice period / availability'],
      ['profile_completion_pct','INT','CHECK (0–100), DEFAULT 0','Profile completeness score shown on Rozee dashboard'],
    ]
  },
  {
    table: 'RECRUITER_PROFILES',
    additions: [
      ['company_id','UUID','FK → COMPANIES, NULLABLE','Links recruiter to their company profile page'],
      ['designation','VARCHAR(150)','NULLABLE','Recruiter job title within the company (e.g. HR Manager)'],
    ]
  },
  {
    table: 'JOB_POSTINGS',
    additions: [
      ['category_id','UUID','FK → JOB_CATEGORIES, NULLABLE','Functional category (e.g. Software Dev, Accounts)'],
      ['industry_id','UUID','FK → INDUSTRIES, NULLABLE','Industry sector of the role'],
      ['city_id','UUID','FK → CITIES, NULLABLE','Structured location FK replacing free-text location field'],
      ['company_id','UUID','FK → COMPANIES, NULLABLE','Posting linked to verified company profile'],
      ['job_type','ENUM(\'full-time\',\'part-time\',\'contract\',\'internship\',\'freelance\')','NOT NULL, DEFAULT full-time','Employment type — Rozee job type filter'],
      ['min_salary_pkr','INT','NULLABLE, CHECK (≥ 0)','Minimum offered salary'],
      ['max_salary_pkr','INT','NULLABLE, CHECK (≥ min_salary)','Maximum offered salary'],
      ['gender_preference','ENUM(\'any\',\'male\',\'female\')','DEFAULT any','Rozee allows gender-specific postings'],
      ['application_deadline','DATE','NULLABLE','Application closing date — Rozee posting expiry'],
      ['views_count','INT','DEFAULT 0','Number of times the posting was viewed — Rozee engagement metric'],
    ]
  },
];

function buildUpdatedBlock(u) {
  const widths = [1600, 2100, 1900, 3760];
  const rows = u.additions.map(([col,type,constr,desc]) => [col,type,constr,desc]);
  return [
    h3(u.table + '  (columns to ADD)'),
    mkTable(['New Column','Data Type','Constraints','Description'], rows, widths),
    sp(200),
  ];
}

// ── DOCUMENT ──────────────────────────────────────────────────
const doc = new Document({
  numbering: { config:[{ reference:'bullets', levels:[{
    level:0, format:LevelFormat.BULLET, text:'•', alignment:AlignmentType.LEFT,
    style:{ paragraph:{ indent:{ left:720, hanging:360 } } }
  }]}] },
  styles: {
    default:{ document:{ run:{ font:'Arial', size:20, color:C.text } } },
    paragraphStyles:[
      { id:'Heading1', name:'Heading 1', basedOn:'Normal', next:'Normal',
        run:{ size:36, bold:true, font:'Arial', color:C.navy },
        paragraph:{ spacing:{ before:360, after:180 }, outlineLevel:0 } },
      { id:'Heading2', name:'Heading 2', basedOn:'Normal', next:'Normal',
        run:{ size:28, bold:true, font:'Arial', color:C.sub },
        paragraph:{ spacing:{ before:260, after:120 }, outlineLevel:1 } },
      { id:'Heading3', name:'Heading 3', basedOn:'Normal', next:'Normal',
        run:{ size:24, bold:true, font:'Arial', color:C.blue },
        paragraph:{ spacing:{ before:200, after:80 }, outlineLevel:2 } },
    ]
  },
  sections:[{
    properties:{ page:{
      size:{ width:12240, height:15840 },
      margin:{ top:1080, right:900, bottom:1080, left:900 }
    }},
    headers:{ default: new Header({ children:[
      new Paragraph({
        border:{ bottom:{ style:BorderStyle.SINGLE, size:4, color:C.blue, space:6 } },
        spacing:{ before:0, after:120 },
        children:[new TextRun({ text:'DB Systems Lab  |  AI Job & Skill Matching Platform  |  Rozee.pk Comparison', size:16, color:C.muted, font:'Arial' })]
      })
    ]})},
    footers:{ default: new Footer({ children:[
      new Paragraph({
        border:{ top:{ style:BorderStyle.SINGLE, size:4, color:C.blue, space:6 } },
        spacing:{ before:120, after:0 },
        tabStops:[{ type:TabStopType.RIGHT, position:TabStopPosition.MAX }],
        children:[
          new TextRun({ text:'Furqan Ullah & Syed Fahad Ali Shah', size:16, color:C.muted, font:'Arial' }),
          new TextRun({ text:'\tPage ', size:16, color:C.muted, font:'Arial' }),
          new TextRun({ children:[PageNumber.CURRENT], size:16, color:C.muted, font:'Arial' }),
        ]
      })
    ]})},
    children:[

      // ── Cover ───────────────────────────────────────────────
      sp(1600),
      new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:0,after:200},
        children:[new TextRun({ text:'DATABASE SYSTEMS LAB', bold:true, size:52, color:C.navy, font:'Arial' })] }),
      new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:0,after:200},
        border:{ bottom:{ style:BorderStyle.SINGLE, size:8, color:C.blue, space:12 } },
        children:[new TextRun({ text:'AI-Powered Job & Skill Matching Platform', bold:true, size:36, color:C.blue, font:'Arial' })] }),
      sp(200),
      new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:0,after:120},
        children:[new TextRun({ text:'Rozee.pk Comparative Analysis', size:30, color:C.sub, font:'Arial', bold:true })] }),
      new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:0,after:480},
        children:[new TextRun({ text:'Missing Tables & Schema Expansion', size:24, color:C.muted, font:'Arial', italic:true })] }),
      sp(300),
      ...[
        ['Project','AI-Powered Job & Skill Matching Platform'],
        ['Document','Rozee.pk Gap Analysis & Missing Tables'],
        ['Student 1','Furqan Ullah'],
        ['Student 2','Syed Fahad Ali Shah'],
        ['Program','Database Systems'],
        ['Date','May 2026'],
      ].map(([label,value]) =>
        new Paragraph({ alignment:AlignmentType.CENTER, spacing:{before:80,after:80},
          children:[
            new TextRun({ text:`${label}:   `, bold:true, size:22, color:C.navy, font:'Arial' }),
            new TextRun({ text:value, size:22, color:C.text, font:'Arial' }),
          ]})
      ),

      pb(),

      // ── Section 1: Comparison ───────────────────────────────
      h1('1.  Comparison: Your Tables vs Rozee.pk'),
      para('The table below maps every table in your current schema against the features and data entities present on Rozee.pk. Tables marked ❌ Missing are required to achieve functional parity with Rozee.pk and must be added to the schema. Tables marked ✅ Exist are already present in your design.'),
      sp(120),
      // Legend
      new Paragraph({ spacing:{before:60,after:60}, children:[
        new TextRun({ text:'Legend:   ', bold:true, size:19, font:'Arial', color:C.navy }),
        new TextRun({ text:'✅ Exists  ', size:19, font:'Arial', color:C.green }),
        new TextRun({ text:'❌ Missing — must be added  ', size:19, font:'Arial', color:C.red }),
        new TextRun({ text:'ADD = action required', size:19, font:'Arial', color:C.amber }),
      ]}),
      sp(100),
      buildCompTable(),
      sp(200),
      para('Summary: Your original schema contained 10 tables. After comparing with Rozee.pk, 20 additional tables are required (10 entirely new tables + 3 existing tables need new columns added). The expanded schema will contain 30 tables total.', { bold:false, size:19, color:C.muted, italic:true }),

      pb(),

      // ── Section 2: New Tables ────────────────────────────────
      h1('2.  New Tables to Add'),
      para('The following 20 tables are missing from your schema and are needed to match Rozee.pk functionality. Each table includes all columns, data types, constraints, and relationship descriptions.'),
      sp(160),

      ...newTables.flatMap(t => buildTableBlock(t)),

      pb(),

      // ── Section 3: Updated Tables ────────────────────────────
      h1('3.  Columns to Add to Existing Tables'),
      para('In addition to the brand-new tables, three of your existing tables require new columns to match Rozee.pk data requirements. Only the additional columns are listed below — all original columns remain unchanged.'),
      sp(160),

      ...updatedTablesNote.flatMap(u => buildUpdatedBlock(u)),

      pb(),

      // ── Section 4: Updated Relationships ─────────────────────
      h1('4.  Updated Relationship Summary'),
      para('The expanded schema introduces new foreign key links and modifies existing tables. The complete updated relationship map is shown below.'),
      sp(120),
      mkTable(
        ['Relationship Type','From','To','Via / Notes'],
        [
          ['1:N','USERS','EDUCATION','user_id FK'],
          ['1:N','USERS','WORK_EXPERIENCE','user_id FK'],
          ['1:N','USERS','CERTIFICATIONS','user_id FK'],
          ['M:N','USERS ↔ LANGUAGES','USER_LANGUAGES','Junction with proficiency ENUM'],
          ['1:N','USERS','JOB_ALERTS','user_id FK'],
          ['M:N','USERS ↔ JOB_POSTINGS','SAVED_JOBS','Junction; UNIQUE(user_id, job_id)'],
          ['M:N','USERS ↔ COMPANIES','COMPANY_FOLLOWS','Junction; UNIQUE(user_id, company_id)'],
          ['N:N annotation','USERS (recruiter) × USERS (candidate)','RECRUITER_NOTES','Dual FK + optional application_id'],
          ['1:N','APPLICATIONS','INTERVIEW_STAGES','application_id FK'],
          ['1:N','USERS','NOTIFICATIONS','user_id FK'],
          ['1:N','COMPANIES','JOB_POSTINGS','company_id FK'],
          ['1:N','COMPANIES','RECRUITER_PROFILES','company_id FK'],
          ['1:N','COMPANIES','EMPLOYER_PACKAGE_SUBSCRIPTIONS','company_id FK'],
          ['1:N','PACKAGES','EMPLOYER_PACKAGE_SUBSCRIPTIONS','package_id FK'],
          ['1:N','USERS','CV_VIEWS (as candidate)','candidate_id FK'],
          ['1:N','USERS','CV_VIEWS (as viewer)','viewer_id FK'],
          ['M:N resolved','USERS ↔ SKILLS','SKILL_TEST_RESULTS','score + percentile payload'],
          ['Ref','JOB_POSTINGS → INDUSTRIES','industry_id FK','Via INDUSTRIES master table'],
          ['Ref','JOB_POSTINGS → JOB_CATEGORIES','category_id FK','Via JOB_CATEGORIES master table'],
          ['Ref','JOB_POSTINGS → CITIES','city_id FK','Via CITIES master table'],
          ['Ref','WORK_EXPERIENCE → INDUSTRIES','industry_id FK','Via INDUSTRIES master table'],
          ['Self-ref','JOB_CATEGORIES → JOB_CATEGORIES','parent_category_id','Sub-category nesting'],
          ['Reporting','SALARY_STATS','INDUSTRIES, CITIES','Aggregated; no reverse FK'],
        ],
        [1200, 2200, 2200, 3760]
      ),

      sp(200),
      para('All existing relationships from the original 10-table schema remain unchanged. The additions above are purely additive and do not break any existing constraints or FK references.', { size:19, color:C.muted, italic:true }),
    ]
  }]
});

Packer.toBuffer(doc).then(buf => {
  fs.writeFileSync('/home/runner/workspace/Rozee_Comparison_Missing_Tables.docx', buf);
  console.log('Done');
});
