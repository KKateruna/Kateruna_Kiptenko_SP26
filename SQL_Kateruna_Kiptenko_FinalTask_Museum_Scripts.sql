-- TASK 3 ---------------------------------------------------------------------------------------------------------------
/* Create a physical database with a separate database and schema and give it an appropriate domain-related name.
 * Create relationships between tables using primary and foreign keys. 
 * Create tables in the correct DDL order: parent tables before child tables to avoid foreign key errors.
 * Use appropriate data types for each column and apply DEFAULT, STORED AS and GENERATED ALWAYS AS columns as required.
 * Use ALTER TABLE to add at least 5 check constraints across the tables to restrict certain values, as example 
 *    		date to be inserted, which must be greater than January 1, 2026
 *    		inserted measured value that cannot be negative
 *    		inserted value that can only be a specific value
 *    		unique
 *    		not null
 * Give meaningful names to your CHECK constraints. */

-- CREATE DATABASE museum;

/******************************************   Creating tables in the schema   ******************************************/

CREATE SCHEMA IF NOT EXISTS museum;

CREATE TABLE IF NOT EXISTS museum.visitors (
	visitor_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
	full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED, -- fulfills the requirement to use STORED
	email VARCHAR(100) UNIQUE NOT NULL,
	phone_number VARCHAR(20) UNIQUE NOT NULL
	);

CREATE TABLE IF NOT EXISTS museum.visits (
	visit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	visitor_id BIGINT NOT NULL, 
	exhibition_id BIGINT NOT NULL,
	visit_date TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
	total_price NUMERIC(8, 2) CHECK(total_price >= 0)
	);

CREATE TABLE IF NOT EXISTS museum.exhibitions (
	exhibition_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	exhibition_name VARCHAR(100) NOT NULL,
	exhibition_description TEXT,
	start_date DATE NOT NULL,
	end_date DATE NOT NULL CHECK(end_date > start_date),
	is_online BOOLEAN NOT NULL DEFAULT FALSE
	);

CREATE TABLE IF NOT EXISTS museum.guides (
	guide_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	first_name VARCHAR(50) NOT NULL,
	last_name VARCHAR(50) NOT NULL,
	full_name VARCHAR(101) GENERATED ALWAYS AS (first_name || ' ' || last_name) STORED, -- fulfills the requirement to use STORED
	email VARCHAR(100) UNIQUE NOT NULL,
	phone_number VARCHAR(20) UNIQUE NOT NULL
	);

CREATE TABLE IF NOT EXISTS museum.exhibition_guides (
	exhibition_id BIGINT,
	guide_id BIGINT,
	
	PRIMARY KEY(exhibition_id, guide_id)
	);
	
CREATE TABLE IF NOT EXISTS museum.exhibition_items (
	exhibition_id BIGINT,
	item_id BIGINT,
	
	PRIMARY KEY(exhibition_id, item_id)
	);
	
CREATE TABLE IF NOT EXISTS museum.inventory (
	inventory_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	item_id BIGINT NOT NULL,
	location VARCHAR(100) NOT NULL
	);

CREATE TABLE IF NOT EXISTS museum.items (
	item_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
	item_name VARCHAR(100) NOT NULL,
	item_description TEXT,
	type_id SMALLINT NOT NULL,
	creation_year SMALLINT
	);

CREATE TABLE IF NOT EXISTS museum.item_types (
	type_id SMALLINT PRIMARY KEY,
	type_name VARCHAR(100) UNIQUE NOT NULL
	);

/**********************************************   Adding relationships   ***********************************************/
-- For visits------------------------------------------------------------------------------------------------------------
ALTER TABLE museum.visits DROP CONSTRAINT IF EXISTS fk_visits_visitors;
ALTER TABLE museum.visits
ADD CONSTRAINT fk_visits_visitors
FOREIGN KEY (visitor_id) REFERENCES museum.visitors(visitor_id);

ALTER TABLE museum.visits DROP CONSTRAINT IF EXISTS fk_visits_exhibitions;
ALTER TABLE museum.visits
ADD CONSTRAINT fk_visits_exhibitions
FOREIGN KEY (exhibition_id) REFERENCES museum.exhibitions(exhibition_id);
-- For exhibition_guides-------------------------------------------------------------------------------------------------
ALTER TABLE museum.exhibition_guides DROP CONSTRAINT IF EXISTS fk_work_exhibition;
ALTER TABLE museum.exhibition_guides
ADD CONSTRAINT fk_work_exhibition
FOREIGN KEY (exhibition_id) REFERENCES museum.exhibitions(exhibition_id);

ALTER TABLE museum.exhibition_guides DROP CONSTRAINT IF EXISTS fk_work_guide;
ALTER TABLE museum.exhibition_guides
ADD CONSTRAINT fk_work_guide
FOREIGN KEY (guide_id) REFERENCES museum.guides(guide_id);
-- For exhibition_items--------------------------------------------------------------------------------------------------
ALTER TABLE museum.exhibition_items DROP CONSTRAINT IF EXISTS fk_show_exhibition;
ALTER TABLE museum.exhibition_items
ADD CONSTRAINT fk_show_exhibition
FOREIGN KEY (exhibition_id) REFERENCES museum.exhibitions(exhibition_id);

ALTER TABLE museum.exhibition_items DROP CONSTRAINT IF EXISTS fk_show_item;
ALTER TABLE museum.exhibition_items
ADD CONSTRAINT fk_show_item
FOREIGN KEY (item_id) REFERENCES museum.items(item_id);
-- For inventory---------------------------------------------------------------------------------------------------------
ALTER TABLE museum.inventory DROP CONSTRAINT IF EXISTS fk_inventory_item;
ALTER TABLE museum.inventory
ADD CONSTRAINT fk_inventory_item
FOREIGN KEY (item_id) REFERENCES museum.items(item_id);
-- For exhibition_items--------------------------------------------------------------------------------------------------
ALTER TABLE museum.items DROP CONSTRAINT IF EXISTS fk_item_type;
ALTER TABLE museum.items
ADD CONSTRAINT fk_item_type
FOREIGN KEY (type_id) REFERENCES museum.item_types(type_id);
/*******************************************   Adding specific constraints   *******************************************/
-- Time
ALTER TABLE museum.visits DROP CONSTRAINT IF EXISTS visit_date_2026;
ALTER TABLE museum.visits ADD CONSTRAINT visit_date_2026 CHECK (visit_date >= '2026-01-01');

ALTER TABLE museum.exhibitions DROP CONSTRAINT IF EXISTS exhibition_date_2026;
ALTER TABLE museum.exhibitions ADD CONSTRAINT exhibition_date_2026 CHECK (start_date >= '2026-01-01');

-- Value from predefined set
ALTER TABLE museum.inventory DROP CONSTRAINT IF EXISTS inventory_location;
ALTER TABLE museum.inventory
ADD CONSTRAINT inventory_location
CHECK (location IN ('Hall A', 'Hall B', 'Hall C', 'Storage', 'Restoration Room'));

-- TASK 4 ---------------------------------------------------------------------------------------------------------------
/* Populate the tables with the sample data generated, ensuring each table has at least 6+ rows 
 * (for a total of 36+ rows in all the tables) for the last 3 months.
 * Create DML scripts for insert your data. 
 * nsure that the DML scripts do not include values for surrogate keys, as these keys should be generated by the database during runtime. 
 * Avoid hardcoding values where possible.
 * Also, ensure that any DEFAULT values required are specified appropriately in the DML scripts.
 * These DML scripts should be designed to successfully adhere to all previously defined constraints. */

/************************************************** Inserting records **************************************************/

-- VISITORS
INSERT INTO museum.visitors (first_name, last_name, email, phone_number)
SELECT *
FROM (
VALUES 
	('GUEST', 'GUEST', 'guest@museum.com', '0000000000'), -- identity for non-registered visitors
	('Robert', 'Smith', 'r.smith@email.com', '+1555010222'),
	('Emily', 'Davis', 'emily.d@email.com', '+1555010333'),
	('Michael', 'Wilson', 'm.wilson@email.com', '+1555010444'),
	('Sophia', 'Brown', 'sophia.b@email.com', '+1555010555'),
	('Daniel', 'Miller', 'd.miller@email.com', '+1555010666')
) AS records(first_name, last_name, email, phone_number)
WHERE NOT EXISTS (
    SELECT 1 FROM museum.visitors v WHERE v.email = records.email
)
RETURNING *;

-- GUIDES
INSERT INTO museum.guides (first_name, last_name, email, phone_number)
SELECT *
FROM (
VALUES 
	('James', 'Anderson', 'j.anderson@museum.org', '+1555090111'),
	('Linda', 'Taylor', 'l.taylor@museum.org', '+1555090222'),
	('William', 'Thomas', 'w.thomas@museum.org', '+1555090333'),
	('Barbara', 'Moore', 'b.moore@museum.org', '+1555090444'),
	('Richard', 'Jackson', 'r.jackson@museum.org', '+1555090555'),
	('Susan', 'White', 's.white@museum.org', '+1555090666')
) AS records(first_name, last_name, email, phone_number)
WHERE NOT EXISTS (
    SELECT 1 FROM museum.guides g WHERE g.email = records.email
)
RETURNING *;

-- EXHIBITIONS
INSERT INTO museum.exhibitions (exhibition_name, exhibition_description, start_date, end_date, is_online)
SELECT *
FROM (
VALUES 
	(
		'Masterpieces of World Art', 
		'This exhibition presents some of the most iconic works of art from different historical periods.', 
		'2026-02-15'::DATE, 
		'2026-04-20'::DATE,
		FALSE
	),
	(
		'History and Science Through Time', 
		'This exhibition explores key historical artifacts and scientific achievements that shaped human civilization.', 
		'2026-02-01'::DATE, 
		'2026-12-31'::DATE, 
		TRUE
	),
	(
		'Ancient Civilizations', 
		'This exhibition focuses on artifacts from ancient cultures, including Egypt, Greece, and Mesopotamia.', 
		'2026-03-10'::DATE, 
		'2026-06-15'::DATE,
		FALSE
	),
	(
		'Innovations and Inventions', 
		'This exhibition presents groundbreaking inventions and technological advancements that changed everyday life.', 
		'2026-04-05'::DATE, 
		'2026-08-01'::DATE,
		FALSE
	),
	(
		'Cultural Heritage and Traditions', 
		'This exhibition showcases objects representing traditions, customs, and everyday life of different cultures.', 
		'2026-05-12'::DATE, 
		'2026-06-12'::DATE, 
		TRUE
	),
	(
		'Art of the Modern Era', 
		'This exhibition highlights artistic movements of the 19th and 20th centuries, including modernism and contemporary art.', 
		'2026-03-01'::DATE, 
		'2026-09-30'::DATE,
		FALSE
	)
) AS records(exhibition_name, exhibition_description, start_date, end_date, is_online)
WHERE NOT EXISTS (
    SELECT 1 FROM museum.exhibitions e WHERE e.exhibition_name = records.exhibition_name
)
RETURNING *;

-- VISITS
INSERT INTO museum.visits (visitor_id, exhibition_id, visit_date, total_price)
SELECT v.visitor_id, e.exhibition_id, records.visit_date::TIMESTAMP, records.total_price
FROM (VALUES
    ('guest@museum.com', 'Masterpieces of World Art', '2026-02-07 12:38:59', 10), -- discounted fare for student category
    ('emily.d@email.com', 'Masterpieces of World Art', '2026-03-12 14:21:16', 15),
    ('sophia.b@email.com', 'Masterpieces of World Art', '2026-04-27 15:17:07', 10),
    ('d.miller@email.com', 'History and Science Through Time', '2026-03-08 09:28:52', 10),
    ('guest@museum.com', 'History and Science Through Time', '2026-04-11 13:42:33', 10),
    ('sophia.b@email.com', 'History and Science Through Time', '2026-04-23 18:09:41', 15)
) AS records(email, exhibition_name, visit_date, total_price)
JOIN museum.visitors v ON v.email = records.email
JOIN museum.exhibitions e ON e.exhibition_name = records.exhibition_name
WHERE NOT EXISTS (
    SELECT 1 FROM museum.visits visit
    WHERE visit.visitor_id = v.visitor_id
      AND visit.exhibition_id = e.exhibition_id
      AND visit.visit_date = records.visit_date::TIMESTAMP
)
RETURNING *;

-- EXHIBITION GUIDES
INSERT INTO museum.exhibition_guides (exhibition_id, guide_id)
SELECT e.exhibition_id, g.guide_id
FROM museum.exhibitions e
INNER JOIN museum.guides g
    ON (e.exhibition_name = 'Masterpieces of World Art' AND g.email = 'j.anderson@museum.org')
    OR (e.exhibition_name = 'Masterpieces of World Art' AND g.email = 'l.taylor@museum.org')
    OR (e.exhibition_name = 'Masterpieces of World Art' AND g.email = 'w.thomas@museum.org')
    OR (e.exhibition_name = 'History and Science Through Time' AND g.email = 'b.moore@museum.org')
    OR (e.exhibition_name = 'History and Science Through Time' AND g.email = 'r.jackson@museum.org')
    OR (e.exhibition_name = 'History and Science Through Time' AND g.email = 's.white@museum.org')
WHERE NOT EXISTS (
    SELECT 1 FROM museum.exhibition_guides eg 
    WHERE eg.exhibition_id = e.exhibition_id
      AND eg.guide_id = g.guide_id
)
RETURNING *;

-- ITEM TYPES
INSERT INTO museum.item_types (type_id, type_name)
VALUES
    (1, 'Artwork'),
    (2, 'Sculpture'),
    (3, 'Photograph'),
    (4, 'Artifact'),
    (5, 'Manuscript'),
    (6, 'Historical Document'),
    (7, 'Jewelry'),
    (8, 'Weapon'),
    (9, 'Ceramic'),
    (10, 'Textile'),
    (11, 'Furniture'),
    (12, 'Coin'),
    (13, 'Fossil'),
    (14, 'Specimen'),
    (15, 'Scientific Instrument'),
    (16, 'Religious Object')
ON CONFLICT (type_id) DO NOTHING
RETURNING *;

-- ITEMS
INSERT INTO museum.items (item_name, item_description, type_id, creation_year)
SELECT *
FROM (
VALUES 
	('Mona Lisa', 'Portrait by Leonardo da Vinci', 1, 1503),
	('David', 'Marble sculpture by Michelangelo', 2, 1504),
	('The Last Supper Sketches', 'Preparatory drawings for The Last Supper', 1, 1495),
	('Rosetta Stone', 'Ancient Egyptian stone used to decipher hieroglyphs', 4, -196),
	('Apollo 11 Command Module Model', 'Replica of the spacecraft used in Apollo 11 mission', 15, 1969),
	('Antikythera Mechanism', 'Ancient Greek analog computer used to predict astronomical positions', 15, -100)
) AS records(item_name, item_description, type_id, creation_year)
WHERE NOT EXISTS (
    SELECT 1 FROM museum.items i WHERE i.item_name = records.item_name
)
RETURNING *;

-- INVENTORY
INSERT INTO museum.inventory (item_id, location)
SELECT i.item_id, records.location
FROM (VALUES
    ('Mona Lisa', 'Hall A'),
	('David', 'Hall A'),
	('The Last Supper Sketches', 'Hall B'),
	('Rosetta Stone', 'Hall C'),
	('Apollo 11 Command Module Model', 'Hall C'),
	('Antikythera Mechanism', 'Hall C')
) AS records(item_name, location)
INNER JOIN museum.items i ON i.item_name = records.item_name
WHERE NOT EXISTS (
    SELECT 1 FROM museum.inventory inv WHERE inv.item_id = i.item_id
)
RETURNING *;

-- EXHIBITION ITEMS
INSERT INTO museum.exhibition_items (exhibition_id, item_id)
SELECT e.exhibition_id, i.item_id
FROM museum.exhibitions e
INNER JOIN museum.items i
    ON (e.exhibition_name = 'Masterpieces of World Art' AND i.item_name = 'Mona Lisa')
    OR (e.exhibition_name = 'Masterpieces of World Art' AND i.item_name = 'David')
    OR (e.exhibition_name = 'Masterpieces of World Art' AND i.item_name = 'The Last Supper Sketches')
    OR (e.exhibition_name = 'History and Science Through Time' AND i.item_name = 'Rosetta Stone')
    OR (e.exhibition_name = 'History and Science Through Time' AND i.item_name = 'Apollo 11 Command Module Model')
    OR (e.exhibition_name = 'History and Science Through Time' AND i.item_name = 'Antikythera Mechanism')
WHERE NOT EXISTS (
    SELECT 1 FROM museum.exhibition_items ei
    WHERE ei.exhibition_id = e.exhibition_id
      AND ei.item_id = i.item_id
)
RETURNING *;

-- TASK 5 ---------------------------------------------------------------------------------------------------------------
/* Create a function that updates data in one of your tables. This function should take the following input arguments:
 * The primary key value of the row you want to update
 * The name of the column you want to update
 * The new value you want to set for the specified column
 * This function should be designed to modify the specified row in the table, updating the specified column with the new value. */


/************************************************   Creating functions   ************************************************/

CREATE OR REPLACE FUNCTION museum.update_exhibition_data(
    p_exhibition_id BIGINT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID 
AS $$
BEGIN
    IF p_column_name NOT IN ('exhibition_name', 'exhibition_description', 'start_date', 'end_date', 'is_online') THEN
        RAISE EXCEPTION 'Column % cannot be updated or does not exist', p_column_name;
    END IF;

    EXECUTE format(
        'UPDATE museum.exhibitions SET %I = %L WHERE exhibition_id = %s',
        p_column_name, 
        p_new_value, 
        p_exhibition_id
    );

    RAISE NOTICE 'Exhibition % updated: % is now %', p_exhibition_id, p_column_name, p_new_value;

EXCEPTION
    WHEN others THEN
        RAISE EXCEPTION 'Failed to update exhibition. Check if the value "%" matches the data type of column "%". Error: %', 
                        p_new_value, p_column_name, SQLERRM;
END;
$$ 
LANGUAGE plpgsql;

SELECT museum.update_exhibition_data(1, 'exhibition_description', 'Updated description for world masterpieces.');
SELECT museum.update_exhibition_data(2, 'end_date', '2027-01-01');
SELECT museum.update_exhibition_data(6, 'is_online', 'true');

/* Create a function that adds a new transaction to your transaction table. 
 * You can define the input arguments and output format. 
 * Make sure all transaction attributes can be set with the function (via their natural keys). 
 * The function does not need to return a value but should confirm the successful insertion of the new transaction. */
CREATE OR REPLACE FUNCTION museum.new_visit(
    p_email VARCHAR(100),
    p_exhibition_name VARCHAR(100),
    p_visit_date TIMESTAMP, 
    p_total_price NUMERIC(8, 2)
)
RETURNS VOID 
AS $$
DECLARE
    v_visitor_id BIGINT;
    v_exhibition_id BIGINT;
BEGIN 
    SELECT visitor_id INTO v_visitor_id 
    FROM museum.visitors 
    WHERE email = p_email;

    IF v_visitor_id IS NULL THEN
        RAISE EXCEPTION 'Visitor with email % not found', p_email;
    END IF;

    SELECT exhibition_id INTO v_exhibition_id 
    FROM museum.exhibitions 
    WHERE exhibition_name = p_exhibition_name;

    IF v_exhibition_id IS NULL THEN
        RAISE EXCEPTION 'Exhibition % not found', p_exhibition_name;
    END IF;

    IF EXISTS (
        SELECT 1 FROM museum.visits 
        WHERE visitor_id = v_visitor_id
          AND exhibition_id = v_exhibition_id
          AND visit_date = p_visit_date
    ) THEN
        RAISE EXCEPTION 'Visit for % to % on % already exists', p_email, p_exhibition_name, p_visit_date;
    END IF;

    INSERT INTO museum.visits (visitor_id, exhibition_id, visit_date, total_price)
    VALUES (v_visitor_id, v_exhibition_id, p_visit_date, p_total_price);

    RAISE NOTICE 'Visit for % to % was successfully inserted', p_email, p_exhibition_name;
END; 
$$
LANGUAGE plpgsql;

SELECT museum.new_visit(
    'emily.d@email.com', 
    'History and Science Through Time', 
    '2026-05-15 14:30:00'::TIMESTAMP, 
    15.50
);
-- TASK 6 ---------------------------------------------------------------------------------------------------------------
/* Create a view that presents analytics for the most recently added quarter in your database. 
 * Ensure that the result excludes irrelevant fields such as surrogate keys and duplicate entries. */

/**************************************************   Creating a view   *************************************************/

CREATE OR REPLACE VIEW museum.analytics_last_qtr AS 
WITH last_quarter_info AS (
    SELECT 
        EXTRACT(YEAR FROM visit_date) AS target_year,
        EXTRACT(QUARTER FROM visit_date) AS target_qtr
    FROM museum.visits
    ORDER BY visit_date DESC
    LIMIT 1
)
SELECT 
    lq.target_year,
    lq.target_qtr,
    -- Total revenue
    SUM(v.total_price) AS total_revenue,
    -- How many total exhibitions were held this quarter?
    COUNT(DISTINCT v.exhibition_id) AS active_exhibitions_count,
    -- What is the total number of visits to the museum?
    COUNT(v.visit_id) AS total_visits,
    -- How many people visited the museum?
    COUNT(DISTINCT v.visitor_id) AS total_unique_visitors,
    -- How many people came to one exhibition on average?
    ROUND(COUNT(v.visit_id)::NUMERIC / NULLIF(COUNT(DISTINCT v.exhibition_id), 0), 2) AS avg_visits_per_exhibition,
    -- How much did the museum earn on average from one exhibition?
    ROUND(SUM(v.total_price)::NUMERIC / NULLIF(COUNT(DISTINCT v.exhibition_id), 0), 2) AS avg_revenue_per_exhibition
FROM museum.visits v
CROSS JOIN last_quarter_info lq
WHERE 
    EXTRACT(YEAR FROM v.visit_date) = lq.target_year
    AND EXTRACT(QUARTER FROM v.visit_date) = lq.target_qtr
GROUP BY lq.target_year, lq.target_qtr;

SELECT * FROM museum.analytics_last_qtr;

-- TASK 7 ---------------------------------------------------------------------------------------------------------------
/* Create a read-only role for the manager. 
 * This role should have permission to perform SELECT queries on the database tables, and also be able to log in. 
 * Please ensure that you adhere to best practices for database security when defining this role. */

/*************************************************   Creating a role   **************************************************/

DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'manager') THEN
        CREATE ROLE manager LOGIN PASSWORD 'managerpassword';
    END IF;
END
$$;

GRANT CONNECT ON DATABASE museum TO manager;
GRANT USAGE ON SCHEMA museum TO manager;
GRANT SELECT ON ALL TABLES IN SCHEMA museum TO manager;

SET ROLE manager; 
SELECT * FROM museum.visits; 
RESET ROLE;