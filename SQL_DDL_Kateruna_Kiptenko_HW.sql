/* Before implementing the physical database, I optimized the logical model to ensure better performance and alignment with 
 * business requirements. I upgraded primary keys to BIGINT for higher capacity and modern standards, while using SMALLINT 
 * for static lookup tables to minimize storage overhead. In the tables for work experience and placements, I replaced TIMESTAMP 
 * with DATE to save memory, as tracking exact hours is unnecessary for employment history. Choosing appropriate data types 
 * is crucial because wrong types lead to significant risks, such as storage inefficiency, slower query performance due to 
 * improper indexing, and potential data loss or overflow. Moreover, using incorrect types like TEXT for dates prevents the 
 * use of built-in arithmetic functions, complicating data analysis. Additionally, I applied DEFAULT CURRENT_DATE for all 
 * start fields and implemented all required CHECK constraints, specifically ensuring dates are after January 1, 2000 and 
 * restricting job titles to a predefined list relevant to the IT recruitment domain. */

-- CREATE DATABASE recruitment;

/******************************************   Creating tables in the schema   ******************************************/

CREATE SCHEMA IF NOT EXISTS recruitment;

CREATE TABLE IF NOT EXISTS recruitment.people (
	person_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
	full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED, -- new column to fulfill the requirement using generation
	email VARCHAR(100) UNIQUE NOT NULL,
	phone_number VARCHAR(20)
	);

CREATE TABLE IF NOT EXISTS recruitment.companies (
	company_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	company_name VARCHAR(100) UNIQUE NOT NULL,
	email VARCHAR(100) UNIQUE NOT NULL,
	phone_number VARCHAR(20)
	);
	
CREATE TABLE IF NOT EXISTS recruitment.candidates (
	candidate_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	person_id BIGINT NOT NULL
	);

CREATE TABLE IF NOT EXISTS recruitment.representatives (
	representative_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	person_id BIGINT UNIQUE NOT NULL,
	company_id BIGINT NOT NULL
	);

CREATE TABLE IF NOT EXISTS recruitment.locations (
	location_id SMALLINT PRIMARY KEY,
	location_name VARCHAR(100) UNIQUE NOT NULL
	);

CREATE TABLE IF NOT EXISTS recruitment.candidate_preferred_locations (
	candidate_id BIGINT,
	location_id SMALLINT,
	
	PRIMARY KEY(candidate_id, location_id)
	);

CREATE TABLE IF NOT EXISTS recruitment.skills (
	skill_id SMALLINT PRIMARY KEY,
	skill_name VARCHAR(100) UNIQUE NOT NULL
	);

CREATE TABLE IF NOT EXISTS recruitment.candidate_skills (
	candidate_id BIGINT,
	skill_id SMALLINT,
	
	PRIMARY KEY(candidate_id, skill_id)
	);
	
CREATE TABLE IF NOT EXISTS recruitment.jobs (
	job_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	company_id BIGINT NOT NULL,
	location_id SMALLINT, -- can be NULL for remote work
	job_title VARCHAR(100),
	job_description TEXT,
	salary NUMERIC(8, 2) CHECK(salary >= 0)
	);

CREATE TABLE IF NOT EXISTS recruitment.applications (
	application_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	job_id BIGINT NOT NULL,
	candidate_id BIGINT NOT NULL
	);
	
CREATE TABLE IF NOT EXISTS recruitment.statuses (
	status_id SMALLINT PRIMARY KEY,
	status VARCHAR(50) UNIQUE NOT NULL
	);
	
CREATE TABLE IF NOT EXISTS recruitment.application_statuses (
	history_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	application_id BIGINT NOT NULL,
	status_id SMALLINT NOT NULL,
	start_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	end_date TIMESTAMP CHECK(end_date IS NULL OR end_date > start_date)
	);
	
CREATE TABLE IF NOT EXISTS recruitment.interviews (
	interview_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	application_id BIGINT NOT NULL,
	representative_id BIGINT NOT NULL,
	date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP
	);

CREATE TABLE IF NOT EXISTS recruitment.work_experience (
	experience_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	candidate_id BIGINT NOT NULL,
	company_name VARCHAR(100),
	job_title VARCHAR(100) NOT NULL,
	start_date DATE NOT NULL DEFAULT CURRENT_DATE,
	end_date DATE CHECK(end_date IS NULL OR end_date > start_date)
	);
	
CREATE TABLE IF NOT EXISTS recruitment.services (
	service_id SMALLINT PRIMARY KEY,
	service_name VARCHAR(100) UNIQUE NOT NULL,
	service_cost NUMERIC(8, 2) CHECK(service_cost >= 0)
	);

CREATE TABLE IF NOT EXISTS recruitment.candidate_services (
	candidate_service_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	candidate_id BIGINT NOT NULL,
	service_id SMALLINT NOT NULL,
	date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP 
	);

CREATE TABLE IF NOT EXISTS recruitment.placements (
	placement_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	application_id BIGINT UNIQUE NOT NULL,
	start_date DATE NOT NULL DEFAULT CURRENT_DATE,
	end_date DATE CHECK(end_date IS NULL OR end_date > start_date)
	);

-- What kind of incorrect data each constraint helps avoid? What could occur if that constraint were not in place?
/* CHECK (salary >= 0) and CHECK (service_cost >= 0)- Prevents negative monetary values from being stored. 
 *    Without them, a data-entry error would silently corrupt financial reports and salary calculations.
 * CHECK (end_date IS NULL OR end_date > start_date)- Prevents logically impossible date ranges where a period ends before it begins. 
 *    Without it, duration calculations would return negative or nonsensical results.
 * CHECK (start_date >= '2000-01-01')- Blocks clearly erroneous historical dates caused by typos. 
 *    Without it, date-range filters and timeline reports would include noise spanning decades.
 * CHECK (job_title IN ('Developer', 'Analyst', 'Manager', 'Designer'))- Enforces that job titles come only from an approved vocabulary. 
 *    Without it, free-text variants of the same role would fragment reporting and break job-search filtering.
 * UNIQUE (email) on people and companies- Prevents two records from sharing the same email address. 
 *    Without it, email-based lookups would return duplicate rows and notifications would reach the wrong person.
 * NOT NULL on foreign key columns- Ensures every child row is linked to a real parent. 
 *    Without it, orphaned rows would be invisible in joins and silently excluded from every report that depends on that relationship.

-- Why order matters? What error would occur if order is wrong?
/* The order of executing DDL statements is critical due to the hierarchical nature of relational databases and Foreign 
 * Key dependencies. In a schema with relationships, "parent" tables (those being referenced) must be created before 
 * "child" tables (those containing the references). If this sequence is incorrect, PostgreSQL will throw an Undefined 
 * Table or Relation Does Not Exist error because the engine cannot establish a link to a non-existent entity. Also when 
 * cleaning up the database, child tables must be dropped first to avoid Dependency Errors, unless the CASCADE command is 
 * used. Maintaining the correct DDL order ensures structural integrity and allows the entire database schema to be rebuilt 
 * from a single script without manual intervention. */
 
/******************************************   Adding relationships   ******************************************/

/* I apply foreign keys separately by adding them through `ALTER TABLE` statements instead of defining them during table 
 * creation, because this approach allows me to first create all parent tables and then safely establish relationships without 
 * running into dependency errors; it also makes the script more flexible and rerunnable, since constraints can be dropped and 
 * recreated if needed, and helps me better control and document how referential integrity is enforced across the database. */

-- For candidates----------------------------------------------------------------------------------------------
ALTER TABLE recruitment.candidates DROP CONSTRAINT IF EXISTS fk_candidates_people;
ALTER TABLE recruitment.candidates
ADD CONSTRAINT fk_candidates_people
FOREIGN KEY (person_id) REFERENCES recruitment.people(person_id);
-- For representatives-----------------------------------------------------------------------------------------
ALTER TABLE recruitment.representatives DROP CONSTRAINT IF EXISTS fk_representatives_people;
ALTER TABLE recruitment.representatives
ADD CONSTRAINT fk_representatives_people
FOREIGN KEY (person_id) REFERENCES recruitment.people(person_id);

ALTER TABLE recruitment.representatives DROP CONSTRAINT IF EXISTS fk_representatives_companies;
ALTER TABLE recruitment.representatives
ADD CONSTRAINT fk_representatives_companies
FOREIGN KEY (company_id) REFERENCES recruitment.companies(company_id);
-- For interviews-----------------------------------------------------------------------------------------------
ALTER TABLE recruitment.interviews DROP CONSTRAINT IF EXISTS fk_interviews_applications;
ALTER TABLE recruitment.interviews
ADD CONSTRAINT fk_interviews_applications
FOREIGN KEY (application_id) REFERENCES recruitment.applications(application_id);

ALTER TABLE recruitment.interviews DROP CONSTRAINT IF EXISTS fk_interviews_representatives;
ALTER TABLE recruitment.interviews
ADD CONSTRAINT fk_interviews_representatives
FOREIGN KEY (representative_id) REFERENCES recruitment.representatives(representative_id);
-- For applications---------------------------------------------------------------------------------------------
ALTER TABLE recruitment.applications DROP CONSTRAINT IF EXISTS fk_applications_jobs;
ALTER TABLE recruitment.applications
ADD CONSTRAINT fk_applications_jobs
FOREIGN KEY (job_id) REFERENCES recruitment.jobs(job_id);

ALTER TABLE recruitment.applications DROP CONSTRAINT IF EXISTS fk_applications_candidates;
ALTER TABLE recruitment.applications
ADD CONSTRAINT fk_applications_candidates
FOREIGN KEY (candidate_id) REFERENCES recruitment.candidates(candidate_id);
-- For application_statuses-------------------------------------------------------------------------------------
ALTER TABLE recruitment.application_statuses DROP CONSTRAINT IF EXISTS fk_history_applications;
ALTER TABLE recruitment.application_statuses
ADD CONSTRAINT fk_history_applications
FOREIGN KEY (application_id) REFERENCES recruitment.applications(application_id);

ALTER TABLE recruitment.application_statuses DROP CONSTRAINT IF EXISTS fk_history_statuses;
ALTER TABLE recruitment.application_statuses
ADD CONSTRAINT fk_history_statuses
FOREIGN KEY (status_id) REFERENCES recruitment.statuses(status_id);
-- For placements-----------------------------------------------------------------------------------------------
ALTER TABLE recruitment.placements DROP CONSTRAINT IF EXISTS fk_placements_applications;
ALTER TABLE recruitment.placements
ADD CONSTRAINT fk_placements_applications
FOREIGN KEY (application_id) REFERENCES recruitment.applications(application_id);
-- For jobs------------------------------------------------------------------------------------------------------
ALTER TABLE recruitment.jobs DROP CONSTRAINT IF EXISTS fk_jobs_companies;
ALTER TABLE recruitment.jobs
ADD CONSTRAINT fk_jobs_companies
FOREIGN KEY (company_id) REFERENCES recruitment.companies(company_id);

ALTER TABLE recruitment.jobs DROP CONSTRAINT IF EXISTS fk_jobs_locations;
ALTER TABLE recruitment.jobs
ADD CONSTRAINT fk_jobs_locations
FOREIGN KEY (location_id) REFERENCES recruitment.locations(location_id);
-- For candidate_preferred_locations-----------------------------------------------------------------------------
ALTER TABLE recruitment.candidate_preferred_locations DROP CONSTRAINT IF EXISTS fk_preferences_candidates;
ALTER TABLE recruitment.candidate_preferred_locations
ADD CONSTRAINT fk_preferences_candidates
FOREIGN KEY (candidate_id) REFERENCES recruitment.candidates(candidate_id);

ALTER TABLE recruitment.candidate_preferred_locations DROP CONSTRAINT IF EXISTS fk_preferences_locations;
ALTER TABLE recruitment.candidate_preferred_locations
ADD CONSTRAINT fk_preferences_locations
FOREIGN KEY (location_id) REFERENCES recruitment.locations(location_id);
-- For candidate_skills------------------------------------------------------------------------------------------
ALTER TABLE recruitment.candidate_skills DROP CONSTRAINT IF EXISTS fk_ability_candidates;
ALTER TABLE recruitment.candidate_skills
ADD CONSTRAINT fk_ability_candidates
FOREIGN KEY (candidate_id) REFERENCES recruitment.candidates(candidate_id);

ALTER TABLE recruitment.candidate_skills DROP CONSTRAINT IF EXISTS fk_ability_skills;
ALTER TABLE recruitment.candidate_skills
ADD CONSTRAINT fk_ability_skills
FOREIGN KEY (skill_id) REFERENCES recruitment.skills(skill_id);
-- For candidate_services----------------------------------------------------------------------------------------
ALTER TABLE recruitment.candidate_services DROP CONSTRAINT IF EXISTS fk_provision_candidates;
ALTER TABLE recruitment.candidate_services
ADD CONSTRAINT fk_provision_candidates
FOREIGN KEY (candidate_id) REFERENCES recruitment.candidates(candidate_id);

ALTER TABLE recruitment.candidate_services DROP CONSTRAINT IF EXISTS fk_provision_services;
ALTER TABLE recruitment.candidate_services
ADD CONSTRAINT fk_provision_services
FOREIGN KEY (service_id) REFERENCES recruitment.services(service_id);
-- For work_experience--------------------------------------------------------------------------------------------
ALTER TABLE recruitment.work_experience DROP CONSTRAINT IF EXISTS fk_work_experience_candidates;
ALTER TABLE recruitment.work_experience
ADD CONSTRAINT fk_work_experience_candidates
FOREIGN KEY (candidate_id) REFERENCES recruitment.candidates(candidate_id);

-- What happens without foreign keys?
/* Without foreign keys, the database becomes a simple collection of tables with no real connection, which leads to 
 * "orphan records". This lack of control allows users to enter fake IDs or delete important data by mistake, as there 
 * are no automatic rules like "delete everything related" to keep things clean. Ultimately, the data becomes messy 
 * and unreliable because the database engine is no longer double-checking the relationships. */

/******************************************   Adding specific constraints   ******************************************/
-- Time
ALTER TABLE recruitment.interviews DROP CONSTRAINT IF EXISTS interview_date_2000;
ALTER TABLE recruitment.interviews ADD CONSTRAINT interview_date_2000 CHECK (date >= '2000-01-01');

ALTER TABLE recruitment.work_experience DROP CONSTRAINT IF EXISTS work_exp_date_2000;
ALTER TABLE recruitment.work_experience ADD CONSTRAINT work_exp_date_2000 CHECK (start_date >= '2000-01-01');

ALTER TABLE recruitment.candidate_services DROP CONSTRAINT IF EXISTS service_date_2000;
ALTER TABLE recruitment.candidate_services ADD CONSTRAINT service_date_2000 CHECK (date >= '2000-01-01');

ALTER TABLE recruitment.application_statuses DROP CONSTRAINT IF EXISTS status_date_2000;
ALTER TABLE recruitment.application_statuses ADD CONSTRAINT status_date_2000 CHECK (start_date >= '2000-01-01');

ALTER TABLE recruitment.placements DROP CONSTRAINT IF EXISTS placement_date_2000;
ALTER TABLE recruitment.placements ADD CONSTRAINT placement_date_2000 CHECK (start_date >= '2000-01-01');
-- Value from predefined set
ALTER TABLE recruitment.jobs DROP CONSTRAINT IF EXISTS job_position;
ALTER TABLE recruitment.jobs
ADD CONSTRAINT job_position
CHECK (job_title IN ('Developer', 'Analyst', 'Manager', 'Designer'));

/****************************************** Adding record_ts ******************************************/

ALTER TABLE recruitment.people DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.people ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.companies DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.companies ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.candidates DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.candidates ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.representatives DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.representatives ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.applications DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.applications ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.statuses DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.statuses ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.application_statuses DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.application_statuses ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.interviews DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.interviews ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.locations DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.locations ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.candidate_preferred_locations DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.candidate_preferred_locations ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.skills DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.skills ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.candidate_skills DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.candidate_skills ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.work_experience DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.work_experience ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.services DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.services ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.candidate_services DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.candidate_services ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.jobs DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.jobs ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

ALTER TABLE recruitment.placements DROP COLUMN IF EXISTS record_ts;
ALTER TABLE recruitment.placements ADD COLUMN record_ts DATE NOT NULL DEFAULT CURRENT_DATE;

/****************************************** Inserting records ******************************************/

-- PEOPLE
INSERT INTO recruitment.people (first_name, last_name, email, phone_number)
SELECT *
FROM (
VALUES
    ('Olena', 'Marchenko', 'o.marchenko@email.com', '+380501234567'),
    ('Ivan', 'Kovalenko', 'i.kovalenko@email.com', '+380672345678'),
    ('Maria', 'Petrenko', 'm.petrenko@company.ua', '+380631234999'),
    ('Andrii', 'Shevchenko', 'a.shevchenko@email.com', '+380991112233'),
    ('Oksana', 'Bondarenko', 'o.bondarenko@company.ua', '+380661234567')
) AS v(first_name, last_name, email, phone_number)
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.people p WHERE p.email = v.email
)
RETURNING *;

-- COMPANIES
INSERT INTO recruitment.companies (company_name, email, phone_number)
SELECT *
FROM (
VALUES
    ('TechStart UA', 'hr@techstart.ua', '+380441112233'),
    ('FinServ Group', 'careers@finserv.ua', '+380442223344'),
    ('MediaHub', 'jobs@mediahub.com.ua', NULL)
) AS v(company_name, email, phone_number)
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.companies c WHERE c.email = v.email
)
RETURNING *;

-- CANDIDATES 
INSERT INTO recruitment.candidates (person_id)
SELECT p.person_id
FROM recruitment.people p
WHERE p.email IN (
    'o.marchenko@email.com',
    'i.kovalenko@email.com',
    'a.shevchenko@email.com'
)
AND NOT EXISTS (
    SELECT 1 FROM recruitment.candidates c WHERE c.person_id = p.person_id
)
RETURNING *;

-- REPRESENTATIVES 
INSERT INTO recruitment.representatives (person_id, company_id)
SELECT p.person_id, c.company_id
FROM recruitment.people p
JOIN recruitment.companies c 
    ON (p.email = 'm.petrenko@company.ua' AND c.company_name = 'TechStart UA')
    OR (p.email = 'o.bondarenko@company.ua' AND c.company_name = 'FinServ Group')
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.representatives r WHERE r.person_id = p.person_id
)
RETURNING *;

-- LOCATIONS
INSERT INTO recruitment.locations (location_id, location_name)
VALUES
    (1, 'Kyiv'),
    (2, 'Lviv'),
    (3, 'Kharkiv'),
    (4, 'Dnipro')
ON CONFLICT (location_id) DO NOTHING
RETURNING *;

-- SKILLS
INSERT INTO recruitment.skills (skill_id, skill_name)
VALUES
    (1, 'Python'),
    (2, 'PowerBI'),
    (3, 'SQL'),
    (4, 'Figma')
ON CONFLICT (skill_id) DO NOTHING
RETURNING *;

-- JOBS
INSERT INTO recruitment.jobs (company_id, location_id, job_title, job_description, salary)
SELECT c.company_id, l.location_id, v.job_title, v.job_description, v.salary
FROM (VALUES
    ('TechStart UA', 'Lviv', 'Developer', 'Backend Developer role', 45000),
    ('FinServ Group', 'Kyiv', 'Analyst', 'Financial Analyst role', 38000),
    ('MediaHub', NULL, 'Developer', 'Remote DevOps role', 52000)
) AS v(company_name, location_name, job_title, job_description, salary)
JOIN recruitment.companies c ON c.company_name = v.company_name
LEFT JOIN recruitment.locations l ON l.location_name = v.location_name
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.jobs j
    WHERE j.company_id = c.company_id
      AND j.job_title = v.job_title
      AND COALESCE(j.salary,0) = COALESCE(v.salary,0)
)
RETURNING *;

-- APPLICATIONS
WITH target_applications AS (
    SELECT * FROM (VALUES
        ('a.shevchenko@email.com', 'TechStart UA', 'Developer'),
        ('o.marchenko@email.com', 'FinServ Group', 'Analyst')
    ) AS t(email, company, title)
)
INSERT INTO recruitment.applications (job_id, candidate_id)
SELECT j.job_id, c.candidate_id
FROM target_applications ta
JOIN recruitment.people p ON p.email = ta.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
JOIN recruitment.companies comp ON comp.company_name = ta.company
JOIN recruitment.jobs j ON j.company_id = comp.company_id AND j.job_title = ta.title
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.applications a 
    WHERE a.job_id = j.job_id AND a.candidate_id = c.candidate_id
)
RETURNING *;

-- STATUSES
INSERT INTO recruitment.statuses (status_id, status)
VALUES
    (1, 'Submitted'),
    (2, 'Screening'),
    (3, 'Interview Scheduled'),
    (4, 'Offer Extended'),
    (5, 'Rejected'),
    (6, 'Hired')
ON CONFLICT (status_id) DO NOTHING
RETURNING *;

-- APPLICATION_STATUSES
WITH target_application_statuses AS (
    SELECT * FROM (VALUES
        ('a.shevchenko@email.com', 'TechStart UA', 'Developer', 'Screening', '2026-04-04 09:00:00'::timestamp, NULL::timestamp),
        ('o.marchenko@email.com', 'FinServ Group', 'Analyst', 'Hired', '2026-04-06 12:00:00'::timestamp, NULL::timestamp)
    ) AS t(email, company, title, status, start_date, end_date)
)
INSERT INTO recruitment.application_statuses (application_id, status_id, start_date, end_date)
SELECT 
    a.application_id, 
    s.status_id, 
    tas.start_date, 
    tas.end_date
FROM target_application_statuses tas
JOIN recruitment.people p ON p.email = tas.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
JOIN recruitment.companies comp ON comp.company_name = tas.company
JOIN recruitment.jobs j ON j.company_id = comp.company_id AND j.job_title = tas.title
JOIN recruitment.applications a ON a.candidate_id = c.candidate_id AND a.job_id = j.job_id
JOIN recruitment.statuses s ON s.status = tas.status
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.application_statuses aps
    WHERE aps.application_id = a.application_id 
      AND aps.status_id = s.status_id
      AND aps.start_date = tas.start_date
)
RETURNING *;

-- INTERVIEWS
WITH target_interviews AS (
    SELECT * FROM (VALUES
        ('a.shevchenko@email.com', 'TechStart UA', 'Developer', '2026-04-05 19:00:00'::timestamp),
        ('o.marchenko@email.com', 'FinServ Group', 'Analyst', '2026-04-05 16:00:00'::timestamp)
    ) AS t(email, company, title, interview_date)
)
INSERT INTO recruitment.interviews (application_id, representative_id, "date")
SELECT 
    a.application_id, 
    r.representative_id, 
    ti.interview_date
FROM target_interviews ti
JOIN recruitment.people p ON p.email = ti.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
JOIN recruitment.companies comp ON comp.company_name = ti.company
JOIN recruitment.representatives r ON r.company_id = comp.company_id
JOIN recruitment.jobs j ON j.company_id = comp.company_id AND j.job_title = ti.title
JOIN recruitment.applications a ON a.candidate_id = c.candidate_id AND a.job_id = j.job_id
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.interviews i
    WHERE i.application_id = a.application_id 
      AND i.representative_id = r.representative_id
      AND i."date" = ti.interview_date
)
RETURNING *;

-- PLACEMENTS
WITH target_placement AS (
    SELECT * FROM (VALUES
        ('o.marchenko@email.com', 'FinServ Group', 'Analyst', '2026-04-06'::date, NULL::date)
    ) AS t(email, company, title, start_date, end_date)
)
INSERT INTO recruitment.placements (application_id, start_date, end_date)
SELECT 
    a.application_id, 
    tp.start_date, 
    tp.end_date
FROM target_placement tp
JOIN recruitment.people p ON p.email = tp.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
JOIN recruitment.companies comp ON comp.company_name = tp.company
JOIN recruitment.jobs j ON j.company_id = comp.company_id AND j.job_title = tp.title
JOIN recruitment.applications a ON a.candidate_id = c.candidate_id AND a.job_id = j.job_id
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.placements pl
    WHERE pl.application_id = a.application_id
)
RETURNING *;

-- CANDIDATE_SKILLS
WITH target_candidate_skills AS (
    SELECT * FROM (VALUES
        ('i.kovalenko@email.com', 'Figma'),
        ('a.shevchenko@email.com', 'SQL'),
        ('a.shevchenko@email.com', 'Python'),
        ('o.marchenko@email.com', 'SQL'),
        ('o.marchenko@email.com', 'Python'),
        ('o.marchenko@email.com', 'PowerBI')
    ) AS t(email, skill_name)
)
INSERT INTO recruitment.candidate_skills (candidate_id, skill_id)
SELECT 
    c.candidate_id, 
    s.skill_id
FROM target_candidate_skills tcs
JOIN recruitment.people p ON p.email = tcs.email
JOIN recruitment.candidates c ON c.person_id = p.person_id
JOIN recruitment.skills s ON s.skill_name = tcs.skill_name
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.candidate_skills cs
    WHERE cs.candidate_id = c.candidate_id 
      AND cs.skill_id = s.skill_id
)
RETURNING *;
        
-- CANDIDATE_PREFERRED_LOCATIONS
WITH target_preferences AS (
    SELECT * FROM (VALUES
        ('a.shevchenko@email.com', 'Kyiv'),
        ('a.shevchenko@email.com', 'Lviv'),
        ('o.marchenko@email.com', 'Dnipro')
    ) AS t(email, city_name)
)
INSERT INTO recruitment.candidate_preferred_locations (candidate_id, location_id)
SELECT 
    c.candidate_id, 
    l.location_id
FROM target_preferences tp
JOIN recruitment.people p ON p.email = tp.email
JOIN recruitment.candidates c ON c.person_id = p.person_id
LEFT JOIN recruitment.locations l ON l.location_name = tp.city_name
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.candidate_preferred_locations cpl
    WHERE cpl.candidate_id = c.candidate_id 
      AND (cpl.location_id = l.location_id OR (cpl.location_id IS NULL AND l.location_id IS NULL))
)
RETURNING *;

-- WORK_EXPERIENCE
WITH target_experience AS (
    SELECT * FROM (VALUES
        ('i.kovalenko@email.com', 'SoftServe', 'Web-Designer', '2022-01-10'::date, '2023-05-20'::date),
        ('i.kovalenko@email.com', 'GlobalLogic', 'UX/UI Designer', '2023-06-01'::date, NULL::date),
        ('a.shevchenko@email.com', 'EPAM Systems', 'Trainee Java Dev', '2023-09-01'::date, '2024-02-28'::date),
        ('o.marchenko@email.com', 'PrivatBank', 'Junior Analyst', '2021-03-15'::date, '2024-01-10'::date)
    ) AS t(email, company, title, s_date, e_date)
)
INSERT INTO recruitment.work_experience (candidate_id, company_name, job_title, start_date, end_date)
SELECT 
    c.candidate_id, 
    te.company, 
    te.title, 
    te.s_date, 
    te.e_date
FROM target_experience te
JOIN recruitment.people p ON p.email = te.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.work_experience we
    WHERE we.candidate_id = c.candidate_id 
      AND we.company_name = te.company
      AND we.job_title = te.title
)
RETURNING *;

-- SERVICES
INSERT INTO recruitment.services (service_id, service_name, service_cost)
VALUES
    (1, 'CV Review', 1000),
    (2, 'Career Coaching', 1200),
    (3, 'Interview Preparation', 800)
ON CONFLICT (service_id) DO NOTHING
RETURNING *;

-- CANDIDATE_SERVICES
WITH target_candidate_services AS (
    SELECT * FROM (VALUES
        ('i.kovalenko@email.com', 'CV Review', '2026-03-11 14:30:00'::timestamp),
        ('i.kovalenko@email.com', 'Interview Preparation', '2026-03-07 16:00:00'::timestamp)
    ) AS t(email, service_name, service_date)
)
INSERT INTO recruitment.candidate_services (candidate_id, service_id, "date")
SELECT 
    c.candidate_id, 
    s.service_id, 
    tcs.service_date
FROM target_candidate_services tcs
JOIN recruitment.people p ON p.email = tcs.email
JOIN recruitment.candidates c ON p.person_id = c.person_id
JOIN recruitment.services s ON s.service_name = tcs.service_name
WHERE NOT EXISTS (
    SELECT 1 FROM recruitment.candidate_services cs
    WHERE cs.candidate_id = c.candidate_id 
      AND cs.service_id = s.service_id
      AND cs."date" = tcs.service_date
)
RETURNING *;

/* To ensure data consistency and preserve relational integrity, I used dynamic ID retrieval through Subqueries 
 * and CTEs with JOIN operations, allowing the script to find necessary keys based on unique natural attributes 
 * like emails or company names instead of relying on hardcoded identifiers. I implemented WHERE NOT EXISTS clauses 
 * and ON CONFLICT DO NOTHING statements to make the script idempotent, preventing duplicate records and primary 
 * key violations during repeated executions. Relationships are maintained by strictly following the logical 
 * hierarchy, where child records (like interviews or placements) are only inserted after validating their parent 
 * records (applications and candidates) through multi-table joins. */