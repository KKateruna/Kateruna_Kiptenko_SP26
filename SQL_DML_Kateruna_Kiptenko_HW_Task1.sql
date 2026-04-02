-- TASK 1 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Choose your real top-3 favorite movies (released in different years, belong to different genres) and add them to the 'film' table 
 * (films with the title Film1, Film2, etc - will not be taken into account and grade will be reduced by 20%).
 * Fill in rental rates with 4.99, 9.99 and 19.99 and rental durations with 1, 2 and 3 weeks respectively.
 **********************************************************************************************************************************************************/ 
BEGIN;

WITH inserted_films AS (
	INSERT INTO public.film (
	    title, description, release_year, language_id, original_language_id, rental_duration, 
	    rental_rate, length, replacement_cost, rating, last_update, special_features
	) -- film_fulltext is excluded because it's maintained automatically by a trigger
	SELECT 
	    nf.title, 
	    nf.description, 
	    nf.release_year, 
	    l1.language_id, 
	    l2.language_id,
	    nf.rent_dur, 
	    nf.rent_rate, 
	    nf.len, 
	    nf.rep_cost, 
	    nf.rate, 
	    CURRENT_TIMESTAMP, -- last_update requires type timestamp
	    nf.features
	FROM (
	    VALUES 
	    ('CATCH ME IF YOU CAN', 
	    	'A crime comedy_drama the most successful bank robber in the history of the U.S.', 
	    	2002, 
	    	7, -- rental_duration = 1 week (in days)
	    	4.99, 
	    	141, 
	    	25.99, 
	    	'PG-13'::mpaa_rating,
	    	'ITALIAN',
	    	'ENGLISH',
	    	ARRAY['Trailers', 'Behind the Scenes']::text[]
	    ),
	    ('GONE WITH THE WIND', 
	    	'An epic historical romance about American Civil War and Scarlett O''Hara.', 
	    	1939, 
	    	14, 
	    	9.99, 
	    	221, 
	    	26.99, 
	    	'G'::mpaa_rating,
	    	'ENGLISH',
	    	'ENGLISH', 
	    	ARRAY['Commentaries', 'Deleted Scenes']::text[]
	    ),
	    ('INTERSTELLAR', 
	    	"An epic science fiction film about humanity' extinction in the near future", 
	    	2014, 
	    	21, 
	    	19.99, 
	    	169, 
	    	29.99, 
	    	'PG-13'::mpaa_rating,
	    	'FRENCH',
	    	'ENGLISH',
	    	ARRAY['Trailers', 'Behind the Scenes', 'Commentaries']::text[]
	    )
	) AS nf(title, description, release_year, rent_dur, 
		rent_rate, len, rep_cost, rate, lang_name, orig_lang_name, features)
	INNER JOIN public.language l1 ON UPPER(l1.name) = nf.lang_name
	INNER JOIN public.language l2 ON UPPER(l2.name) = nf.orig_lang_name
	WHERE NOT EXISTS (
	    SELECT 1 FROM public.film f 
	    WHERE f.title = nf.title 
	    	AND f.release_year = nf.release_year
	)
	RETURNING *
 )
INSERT INTO public.film_category (film_id, category_id, last_update)
SELECT 
    f.film_id, 
    c.category_id, 
    CURRENT_TIMESTAMP
FROM (
    VALUES 
	    ('CATCH ME IF YOU CAN', 'Drama'),
	    ('GONE WITH THE WIND', 'Classics'),
	    ('INTERSTELLAR', 'Sci-Fi')
) AS mapping(title, cat_name)
	INNER JOIN public.film f ON UPPER(f.title) = UPPER(mapping.title)
	INNER JOIN public.category c ON UPPER(c.name) = UPPER(mapping.cat_name) 
ON CONFLICT (film_id, category_id) DO NOTHING
RETURNING *;

COMMIT;

-- Checking the results
SELECT title, name
FROM public.film f
	INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
	INNER JOIN public.category c ON fc.category_id = c.category_id 
WHERE f.title IN ('CATCH ME IF YOU CAN', 'GONE WITH THE WIND', 'INTERSTELLAR');

/* REFERENTIAL INTEGRITY:
 * 	- language_id and original_language_id are resolved by joining against the 'language'
 * 	  table (l1 and l2), so an invalid language name causes the row to be silently excluded
 * 	  rather than inserted with a NULL or wrong FK value.
 * 	- film_category.film_id is populated via a join back to 'film' by title immediately
 * 	  after the film insert, ensuring the FK always references a row that exists in the
 * 	  same transaction.
 * 	- category_id is resolved by joining against 'category', preventing orphaned references.
 *
 * DUPLICATE PREVENTION:
 * The WHERE NOT EXISTS clause on the film insert checks the combination of (title,
 * release_year), which is sufficient to distinguish films that share a title but were
 * released in different years (confirmed at QA session). 
 * The ON CONFLICT DO NOTHING clause on the film_category insert guards against re-running 
 * the script and inserting a duplicate (film_id, category_id) pair, which has a unique constraint.
 */

/**********************************************************************************************************************************************************
 * Add the real actors who play leading roles in your favorite movies to the 'actor' and 'film_actor' tables (6 or more actors in total).  
 * Actors with the name Actor1, Actor2, etc - will not be taken into account and grade will be reduced by 20%. 
 * You must decide how to identify actors that already exist in the system and how to avoid duplicates.
 *********************************************************************************************************************************************************/
BEGIN;

WITH inserted_actors AS (
	INSERT INTO public.actor (first_name, last_name, last_update) 
	SELECT 
	    na.first_name, 
	    na.last_name, 
	    CURRENT_TIMESTAMP -- last_update has a data type timestamp
	FROM (
	    VALUES 
		    ('LEONARDO', 'DICAPRIO'),
		    ('TOM', 'HANKS'),
		    ('CHRISTOPHER', 'WALKEN'),
		    ('VIVIEN', 'LEIGH'),
		    ('CLARK', 'GABLE'),
		    ('MATTHEW', 'MCCONAUGHEY'),
		    ('JESSICA', 'CHASTAIN')
	) AS na(first_name, last_name)
	WHERE NOT EXISTS (
	    SELECT 1 FROM public.actor a
	    WHERE a.first_name = na.first_name 
	    	AND a.last_name = na.last_name 
	)
	RETURNING *
 )
INSERT INTO public.film_actor (actor_id, film_id, last_update)
SELECT 
	a.actor_id,
    f.film_id, 
    CURRENT_TIMESTAMP
FROM (
    VALUES 
	    ('LEONARDO', 'DICAPRIO', 'CATCH ME IF YOU CAN'),
	    ('TOM', 'HANKS', 'CATCH ME IF YOU CAN'),
	    ('CHRISTOPHER', 'WALKEN', 'CATCH ME IF YOU CAN'),
	    ('VIVIEN', 'LEIGH', 'GONE WITH THE WIND'),
	    ('CLARK', 'GABLE', 'GONE WITH THE WIND'),
	    ('MATTHEW', 'MCCONAUGHEY', 'INTERSTELLAR'),
	    ('JESSICA', 'CHASTAIN', 'INTERSTELLAR')
) AS mapping(first_name, last_name, title)
	INNER JOIN public.actor a ON UPPER(a.first_name) = UPPER(mapping.first_name)
		AND UPPER(a.last_name) = UPPER(mapping.last_name)
	INNER JOIN public.film f ON UPPER(f.title) = mapping.title
ON CONFLICT (actor_id, film_id) DO NOTHING
RETURNING *;

COMMIT;

-- Checking the results
SELECT f.title, a.first_name, a.last_name 
FROM public.film f
	INNER JOIN public.film_actor fa ON f.film_id = fa.film_id
	INNER JOIN public.actor a ON fa.actor_id = a.actor_id
WHERE f.title IN ('CATCH ME IF YOU CAN', 'GONE WITH THE WIND', 'INTERSTELLAR');

/* REFERENTIAL INTEGRITY:
 * 	- actor_id values in film_actor are sourced by joining against the 'actor' table on
 * 	  (first_name, last_name), so they always reference existing rows — whether newly
 * 	  inserted in the same CTE or already present in the database.
 * 	- film_id values are resolved by joining against 'film' on title, ensuring no orphaned
 * 	  references to non-existent films.
 * 	- Both joins use INNER JOIN, meaning a row is only inserted into film_actor if both
 * 	  the actor and the film are found; no NULL FKs can be introduced.
 *
 * DUPLICATE PREVENTION:
 * The WHERE NOT EXISTS on the actor insert checks (first_name, last_name), which is the
 * agreed-upon unique identifier for actors (confirmed at QA session). 
 * The ON CONFLICT DO NOTHING on film_actor relies on the primary key (actor_id, film_id),
 * preventing the same actor from being linked to the same film twice when the script is re-executed.
 */
/**********************************************************************************************************************************************************
 * Add your favorite movies to any store's inventory.
 *********************************************************************************************************************************************************/
BEGIN;

INSERT INTO public.inventory (film_id, store_id, last_update)
SELECT 
	f.film_id, 
	s.store_id, 
	CURRENT_TIMESTAMP
FROM (
	VALUES
		('CATCH ME IF YOU CAN', '47 MySakila Drive'),
	    ('GONE WITH THE WIND', '47 MySakila Drive'),
	    ('INTERSTELLAR', '47 MySakila Drive')
) AS mapping(title, address)
	INNER JOIN public.film f ON UPPER(f.title) = mapping.title
	INNER JOIN public.address a ON mapping.address = a.address 
	INNER JOIN public.store s ON a.address_id = s.address_id 
WHERE NOT EXISTS (
	    SELECT 1 FROM public.inventory i 
	    WHERE i.film_id = f.film_id  
	    	AND i.store_id = s.store_id 
	)
RETURNING *;

COMMIT;

-- Checking the results
SELECT f.title, s.store_id, a.address 
FROM public.inventory i
	JOIN public.film f ON i.film_id = f.film_id
	JOIN public.store s ON i.store_id = s.store_id
	JOIN public.address a ON s.address_id = a.address_id
WHERE f.title IN ('CATCH ME IF YOU CAN', 'GONE WITH THE WIND', 'INTERSTELLAR');

/* REFERENTIAL INTEGRITY:
 * 	- film_id is resolved by joining 'film' on title.
 * 	- store_id is resolved by joining 'store' through 'address' on the street address string,
 * 	  ensuring the FK points to an actual store rather than being hard-coded.
 * 	- Both joins are INNER JOINs, so a row is only inserted when all references can be
 * 	  satisfied; no NULL FKs are possible.
 *
 * DUPLICATE PREVENTION:
 * The WHERE NOT EXISTS clause checks (film_id, store_id), preventing the same film from
 * being added to the same store's inventory more than once if the script is re-run.
 * The check intentionally excludes inventory_id so it correctly blocks re-insertion of
 * the same (film, store) combination regardless of which slot would be assigned.
 */

/**********************************************************************************************************************************************************
 * Alter any existing customer in the database with at least 43 rental and 43 payment records. 
 * Change their personal data to yours (first name, last name, address, etc.). 
 * You can use any existing address from the "address" table. 
 * Please do not perform any updates on the "address" table, as this can impact multiple records with the same address.
 *********************************************************************************************************************************************************/
-- Searching for a target customer
SELECT * 
FROM (
	SELECT c.first_name, 
		c.last_name, 
		count(DISTINCT r.rental_id) AS rentals, 
		count(DISTINCT p.payment_id) AS payments
	FROM public.customer c
	INNER JOIN public.rental r ON c.customer_id = r.customer_id 
	INNER JOIN public.payment p ON c.customer_id = p.customer_id 
	GROUP BY c.customer_id
) 
WHERE rentals >= 43 AND payments >= 43; -- Finding MARY SMITH

BEGIN;

UPDATE public.customer c
SET first_name = 'KATERUNA',
	last_name = 'KIPTENKO',
	email = 'kipt.kate@gmail.com',
	address_id = (SELECT address_id FROM public.address WHERE address = '47 MySakila Drive' LIMIT 1),
	last_update = CURRENT_TIMESTAMP
WHERE c.first_name = 'MARY' AND c.last_name = 'SMITH' 
RETURNING *;

COMMIT;

/* REFERENTIAL INTEGRITY:
 * The new address_id is sourced directly from the 'address' table via a subquery, so
 * the FK constraint on customer.address_id is always satisfied. The 'address' table
 * itself is not modified (per task requirement), preserving all other records that
 * share the same address row.
 *
 * DUPLICATE PREVENTION:
 * The WHERE clause identifies the customer by (first_name, last_name) — the
 * QA-confirmed unique identifier for customers — so exactly one row is targeted.
 */

/**********************************************************************************************************************************************************
 * Remove any records related to you (as a customer) from all tables except 'Customer' and 'Inventory'
 *********************************************************************************************************************************************************/
-- Checking what will be deleted (requirement)
SELECT * 
FROM public.payment
WHERE customer_id = (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'KATERUNA' AND last_name = 'KIPTENKO'
);

BEGIN;

DELETE FROM public.payment
WHERE customer_id IN (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'KATERUNA' AND last_name = 'KIPTENKO'
)
RETURNING *;

DELETE FROM public.rental
WHERE customer_id IN (
    SELECT customer_id 
    FROM public.customer 
    WHERE first_name = 'KATERUNA' AND last_name = 'KIPTENKO'
)
RETURNING *;

COMMIT;

/* SAFE DELETION:
 * Deletion order respects the FK dependency chain: payment → rental → (customer, kept).
 * 'payment' rows are removed first, eliminating all references to 'rental'; only then
 * are 'rental' rows safely removed. 'customer' and 'inventory' are explicitly excluded
 * from deletion per the task requirement, so no FK violations arise from those tables.
 * 
 * NO UNINTENDED DATA LOSS:
 * Deletions are scoped to a specific customer using a subquery that resolves
 * customer_id by unique identifiers (first_name, last_name).
 * A preliminary SELECT is executed before DELETE to verify affected rows.
 * This guarantees that only intended records are removed.
 */

/**********************************************************************************************************************************************************
 * Rent you favorite movies from the store they are in and pay for them (add corresponding records to the database to represent this activity)
 * (Note: to insert the payment_date into the table payment, you can create a new partition (see the scripts to install the training database )
 * or add records for the first half of 2017)
 *********************************************************************************************************************************************************/
CREATE TABLE IF NOT EXISTS payment_p2026_03 PARTITION OF public.payment
FOR VALUES FROM ('2026-03-01 00:00:00+03') TO ('2026-04-01 00:00:00+03');

-- A new partition is created to accommodate payment records dated in March 2026.

BEGIN;

WITH inserted_rentals AS (
    INSERT INTO public.rental (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
    SELECT 
        '2026-03-23 10:00:00'::timestamp,
        i.inventory_id, 
        c.customer_id, 
        '2026-03-29 18:00:00'::timestamp,
        (SELECT MIN(staff_id) FROM public.staff), -- This random choosing method was suggested by a mentor
        CURRENT_TIMESTAMP
    FROM (
        VALUES
            ('CATCH ME IF YOU CAN', 'KATERUNA', 'KIPTENKO'),
            ('GONE WITH THE WIND', 'KATERUNA', 'KIPTENKO'),
            ('INTERSTELLAR', 'KATERUNA', 'KIPTENKO')
    ) AS mapping(title, f_name, l_name)
    INNER JOIN public.film f ON UPPER(f.title) = mapping.title
    INNER JOIN public.inventory i ON i.inventory_id = (
        SELECT MIN(i2.inventory_id)
        FROM public.inventory i2
        WHERE i2.film_id = f.film_id
    )
    INNER JOIN public.customer c ON mapping.f_name = c.first_name AND mapping.l_name = c.last_name
    WHERE NOT EXISTS (
        SELECT 1 FROM public.rental r
        WHERE r.rental_date = '2026-03-23 10:00:00'::timestamp
          AND r.inventory_id = i.inventory_id
          AND r.customer_id = c.customer_id 
    )
    RETURNING *
)
INSERT INTO public.payment (customer_id, staff_id, rental_id, amount, payment_date)
SELECT 
	ir.customer_id,
	ir.staff_id,
	ir.rental_id,
	f.rental_rate,
	'2026-03-23 10:00:00'::timestamp
FROM inserted_rentals ir
INNER JOIN public.inventory i ON ir.inventory_id = i.inventory_id
INNER JOIN public.film f ON i.film_id = f.film_id
RETURNING *;

COMMIT;

-- Checking the results
SELECT 
    c.first_name,
    c.last_name,
    f.title,
    r.rental_date,
    r.return_date,
    p.amount ,
    p.payment_date,
    s.first_name
FROM public.customer c
JOIN public.rental r ON c.customer_id = r.customer_id
JOIN public.payment p ON r.rental_id = p.rental_id
JOIN public.inventory i ON r.inventory_id = i.inventory_id
JOIN public.film f ON i.film_id = f.film_id
JOIN public.staff s ON r.staff_id = s.staff_id
WHERE c.first_name = 'KATERUNA' AND c.last_name = 'KIPTENKO'
ORDER BY r.rental_date DESC;

/* REFERENTIAL INTEGRITY:
 * 	- rental.inventory_id is resolved by a correlated subquery against 'inventory' filtered
 * 	  by film_id, guaranteeing the FK references an actual inventory row.
 * 	- rental.customer_id is resolved by joining 'customer' on (first_name, last_name).
 * 	- rental.staff_id is assigned as MIN(staff_id) from the 'staff' table, ensuring the FK
 * 	  always points to an existing staff member without hard-coding an ID.
 * 	- payment.rental_id, payment.customer_id, and payment.staff_id are all sourced from the
 * 	  RETURNING clause of the rental insert, guaranteeing consistency between both tables.
 * 	- payment.amount is taken from film.rental_rate via a join through 'inventory', ensuring
 * 	  the charged amount matches the film's configured rate.
 *
 * DUPLICATE PREVENTION:
 * The WHERE NOT EXISTS clause on the rental insert checks the combination of
 * (rental_date, inventory_id, customer_id), preventing the same customer from renting
 * the same inventory copy at the same timestamp twice. The check is intentionally narrow
 * so that legitimate re-rentals of the same film on a different date are still permitted.
 */



/* WHY INSERT INTO ... SELECT:
 * INSERT ... SELECT is used instead of INSERT ... VALUES to allow dynamic data retrieval
 * and integration with existing tables via JOINs.
 * This approach avoids hardcoding IDs, ensures referential integrity,
 * and makes the script more flexible and reusable.
 * It also allows filtering (e.g., WHERE NOT EXISTS) to prevent duplicates
 * during insertion.
 * 
 * WHY A SEPARATE TRANSACTION IS USED FOR EACH LOGICAL OPERATION?
 * Each transaction groups statements that form a single, indivisible business action —
 * inserting a film with its category, adding actors with their film links, stocking
 * inventory, updating a customer record, deleting history, or recording a rental with
 * its payment. Keeping operations in separate transactions limits the blast radius of a
 * failure: if the rental/payment transaction fails, for example, the film, actor, and
 * inventory data committed earlier are not affected. Merging unrelated operations into
 * one large transaction would make partial failures harder to diagnose and recover from,
 * and would hold locks on multiple tables for longer than necessary.
 *
 * WHAT HAPPENS IF A TRANSACTION FAILS?
 * PostgreSQL aborts the transaction at the point of failure and automatically invalidates
 * all statements issued after the most recent BEGIN. No partial writes are visible to
 * other sessions; the database state is identical to what it was before the BEGIN.
 *
 * WHETHER ROLLBACK IS POSSIBLE AND WHAT DATA WOULD BE AFFECTED?
 * Yes — any DML (INSERT, UPDATE, DELETE) executed inside a BEGIN/COMMIT block is fully
 * reversible until COMMIT is issued. An explicit ROLLBACK, or the implicit rollback that
 * follows an error, discards all pending changes within that transaction only. Data
 * committed by earlier transactions in the script is not touched.
 */