-- PART 1 ----------------------------------------------------------------------------------------------------------------------------------------------------------
/* TASK 1 ***********************************************************************************************************************************************************
 * The marketing team needs a list of animation movies between 2017 and 2019 to promote family-friendly content in an upcoming season in stores. 
 * Show all animation movies released during this period with rate more than 1, sorted alphabetically 
  *******************************************************************************************************************************************************************/

-- CTE solution
WITH animation_movies AS (
	SELECT f.title
			, f.release_year
			, f.rating
			, f.rental_rate
	FROM public.film f 
	INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
	INNER JOIN public.category c ON fc.category_id = c.category_id 
	WHERE UPPER(c.name) = 'ANIMATION'	   
)
SELECT title
FROM animation_movies
WHERE release_year BETWEEN 2017 AND 2019
	AND rating IN ('G', 'PG', 'PG-13')
	AND rental_rate > 1
ORDER BY title;

/* CTE separates the "what is an animation film" definition from the filtering predicate, improving readability and making the join logic independently testable. 
 * This adds extra syntactic overhead for such a simple query, but can be useful if we often need a list of animation films.*/ 

-- Subquery solution
SELECT title
FROM (
	SELECT f.title
			, f.release_year
			, f.rating
			, f.rental_rate
	FROM public.film f 
	INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
	INNER JOIN public.category c ON fc.category_id = c.category_id 
	WHERE UPPER(c.name) = 'ANIMATION'	   
) AS animation_movies
WHERE release_year BETWEEN 2017 AND 2019
	AND rating IN ('G', 'PG', 'PG-13')
	AND rental_rate > 1
ORDER BY title;

/* Subquery is functionally and semantically identical to the CTE. 
 * It's slightly more compact, but the derived table cannot be referenced more than once and reads less cleanly.*/

-- JOIN solution
SELECT f.title
FROM public.film f 
INNER JOIN public.film_category fc ON f.film_id = fc.film_id 
INNER JOIN public.category c ON fc.category_id = c.category_id 
WHERE UPPER(c.name) = 'ANIMATION'
	AND f.release_year BETWEEN 2017 AND 2019
	AND f.rating IN ('G', 'PG', 'PG-13')
	AND f.rental_rate > 1
ORDER BY f.title;

/* INNER JOIN ensures that only films that have a matching category entry are included.
 * As a result, films without a category assignment are excluded from the result set, which guarantees data consistency.
 * JOIN solution exposes all predicates to the optimizer in a single pass. 
 * It's the most concise form, however the tradeoff is that the boundary between schema traversal and business filtering is less visually distinct. */

/* Production choice: JOIN. 
 * All three plans are equivalent here, so simplicity wins. */

/* TASK 2 ***********************************************************************************************************************************************************
 * The finance department requires a report on store performance to assess profitability and plan resource allocation for stores after March 2017. 
 * Calculate the revenue earned by each rental store after March 2017 (since April) (include columns: address and address2 – as one column, revenue)
 *******************************************************************************************************************************************************************/

-- CTE solution
WITH store_revenue AS (
    SELECT i.store_id 
			, SUM(p.amount) AS revenue
    FROM public.inventory i
    INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
    INNER JOIN public.payment p ON p.rental_id = r.rental_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
)
SELECT (a.address || ' ' || COALESCE(a.address2, '')) AS full_address
		, sr.revenue
FROM public.address a
INNER JOIN public.store s ON s.address_id = a.address_id
INNER JOIN store_revenue sr ON s.store_id = sr.store_id;

/* CTE isolates the aggregation logic cleanly, making the revenue calculation independently readable before it is joined to address data. 
 * Address columns are merged into a single string via concatenation with a space separator; 
 * COALESCE(address2, '') prevents the entire result from becoming NULL when address2 is absent.*/

-- Subquery solution
SELECT (a.address || ' ' || COALESCE(a.address2, '')) AS full_address
		, store_revenue.revenue
FROM public.address a
INNER JOIN public.store s ON s.address_id = a.address_id
INNER JOIN (
    SELECT i.store_id
			, SUM(p.amount) AS revenue
    FROM public.inventory i
    INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
    INNER JOIN public.payment p ON p.rental_id = r.rental_id
    WHERE p.payment_date >= '2017-04-01'
    GROUP BY i.store_id
) AS store_revenue ON s.store_id = store_revenue.store_id;

/* Subquery produces an identical execution plan and is equally valid. 
 * The aggregation subquery is used exactly once, so the CTE's reusability advantage does not apply; 
 * The choice between the two is purely stylistic. */
 
-- JOIN solution
SELECT (a.address || ' ' || COALESCE(a.address2, '')) AS full_address
		, SUM(p.amount) AS revenue
FROM public.address a
INNER JOIN public.store s ON s.address_id = a.address_id 
INNER JOIN public.inventory i ON i.store_id = s.store_id 
INNER JOIN public.rental r ON r.inventory_id = i.inventory_id
INNER JOIN public.payment p ON p.rental_id = r.rental_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, a.address, a.address2;

/* JOIN pushes the aggregation to the outermost GROUP BY (primary key to ensure data integrity and all non-aggregated columns). 
 * That means the engine joins all five tables first and then aggregates, potentially processing a larger intermediate row set compared to pre-aggregating first. 
 * Readable for those familiar with the schema. */

/* Production choice: CTE. 
 * Unlike Task 1, the aggregation here is meaningful enough to warrant isolation. 
 * The CTE first computes revenue per store, then attaches address — explicit and easy to audit, which matters in a finance reporting context. 
 * The JOIN solution's late aggregation is a minor performance risk on larger datasets. */
 
/* TASK 3 ***********************************************************************************************************************************************************
 * The marketing department in our stores aims to identify the most successful actors since 2015 to boost customer interest in their films. 
 * Show top-5 actors by number of movies (released since 2015) they took part in 
 * (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order) 
 *******************************************************************************************************************************************************************/

-- CTE solution
WITH actor_movie_counts AS (
    SELECT fa.actor_id
			, COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
)
SELECT a.first_name
		, a.last_name
		, amc.number_of_movies
FROM public.actor a
INNER JOIN actor_movie_counts amc ON a.actor_id = amc.actor_id
ORDER BY amc.number_of_movies DESC
LIMIT 5;

/* CTE pre-aggregates movie counts per actor before joining to the actor table for name resolution — the same two-stage logic as Task 2. 
 * Keeps the counting concern cleanly separated from the presentation columns, making the query easy to audit or extend. */

-- Subquery solution
SELECT a.first_name
		, a.last_name
		, counts.number_of_movies
FROM public.actor a
INNER JOIN (
    SELECT fa.actor_id
			, COUNT(fa.film_id) AS number_of_movies
    FROM public.film_actor fa
    INNER JOIN public.film f ON fa.film_id = f.film_id
    WHERE f.release_year >= 2015
    GROUP BY fa.actor_id
) AS counts ON a.actor_id = counts.actor_id
ORDER BY counts.number_of_movies DESC
LIMIT 5;

/* Subquery is semantically identical to the CTE and produces the same execution plan. 
 * Since the derived table is referenced only once, the CTE's reusability advantage doesn't apply; the choice is purely stylistic. */

-- JOIN solution
SELECT a.first_name
		, a.last_name
		, COUNT(f.film_id) AS number_of_movies
FROM public.actor a 
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
INNER JOIN public.film f ON fa.film_id = f.film_id 
WHERE f.release_year >= 2015
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY number_of_movies DESC
LIMIT 5;

/* JOIN performs the aggregation after joining all three tables, requiring GROUP BY to include a.first_name and a.last_name alongside a.actor_id. */

/* Production choice: CTE. 
 * As in Task 2, the aggregation is meaningful enough to isolate. 
 * Additionally, I would replace LIMIT 5 (as suggested by the mentors) with FETCH FIRST 5 ROWS WITH TIES to better match the business question, 
 * since there are actors who have starred in the same number of films. */

/* TASK 4 ***********************************************************************************************************************************************************
 * The marketing team needs to track the production trends of Drama, Travel, and Documentary films to inform genre-specific marketing strategies. 
 * Show number of Drama, Travel, Documentary per year 
			(include columns: release_year, number_of_drama_movies, number_of_travel_movies, number_of_documentary_movies), 
			sorted by release year in descending order. 
 * Dealing with NULL values is encouraged. 
 *******************************************************************************************************************************************************************/

-- CTE solution
WITH movie_categories AS (
	SELECT f.release_year
			, c.name
	FROM public.film f
	INNER JOIN public.film_category fc ON fc.film_id = f.film_id 
	INNER JOIN public.category c ON c.category_id = fc.category_id
)
SELECT release_year
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DRAMA') AS number_of_drama_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'TRAVEL') AS number_of_travel_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DOCUMENTARY') AS number_of_documentary_movies
FROM movie_categories
GROUP BY release_year 
ORDER BY release_year DESC;

/* CTE wraps the full join of movies with their categories, then applies the pivot aggregation on top. 
 * The explicit column list avoids pulling unnecessary film columns into the intermediate result, keeping it clean and intentional. 
 * The use of COUNT(*) with FILTER ensures that missing category values do not produce NULLs, as COUNT returns 0 when no rows match the condition. 
 * Therefore, additional NULL handling is not required in this case.*/

-- Subquery solution
SELECT release_year
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DRAMA') AS number_of_drama_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'TRAVEL') AS number_of_travel_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DOCUMENTARY') AS number_of_documentary_movies
FROM (
	SELECT f.release_year
			, c.name
	FROM public.film f
	INNER JOIN public.film_category fc ON fc.film_id = f.film_id 
	INNER JOIN public.category c ON c.category_id = fc.category_id
) AS movie_categories
GROUP BY release_year
ORDER BY release_year DESC;

/* Subquery is structurally and semantically identical to the corrected CTE — both now project the same three columns. 
 * The choice between them is purely stylistic; since the derived table is referenced only once, neither has a reusability over the other. */

-- JOIN solution
SELECT f.release_year 
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DRAMA') AS number_of_drama_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'TRAVEL') AS number_of_travel_movies
		, COUNT(*) FILTER (WHERE UPPER(name) = 'DOCUMENTARY') AS number_of_documentary_movies
FROM public.film f
INNER JOIN public.film_category fc ON fc.film_id = f.film_id 
INNER JOIN public.category c ON c.category_id = fc.category_id
GROUP BY f.release_year 
ORDER BY f.release_year DESC;

/* The JOIN solution is the most concise. */

/* Production choice: JOIN. 
 * The pivot logic via COUNT(*) FILTER is self-documenting regardless of which approach wraps it, 
 * so the extra layering of a CTE or subquery adds no clarity here. */

-- PART 2 ----------------------------------------------------------------------------------------------------------------------------------------------------------
/* TASK 1 ***********************************************************************************************************************************************************
 * The HR department aims to reward top-performing employees in 2017 with bonuses to recognize their contribution to stores revenue. 
 * Show which three employees generated the most revenue in 2017?

 * Assumptions: 
	-staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
	-if staff processed the payment then he works in the same store; 
	-take into account only payment_date.
 *******************************************************************************************************************************************************************/

-- CTE solution
WITH payments_2017 AS (
    SELECT p.staff_id
         , p.payment_id
         , p.payment_date
         , p.amount
         , i.store_id
    FROM public.payment p
    INNER JOIN public.rental r ON p.rental_id = r.rental_id
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id
    WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
),
revenue_per_employee AS (
    SELECT staff_id
         , SUM(amount) AS total_revenue
    FROM payments_2017
    GROUP BY staff_id
)
SELECT s.first_name
     , s.last_name
     , r.total_revenue
     , (
        SELECT p2.store_id
        FROM payments_2017 p2
        WHERE p2.staff_id = r.staff_id
        ORDER BY p2.payment_date DESC, p2.payment_id DESC
        LIMIT 1
       ) AS the_last_store
FROM revenue_per_employee r
INNER JOIN public.staff s ON r.staff_id = s.staff_id
ORDER BY r.total_revenue DESC
LIMIT 3;

/* CTE splits the problem into two named stages: 
 * 	-payments_2017 filters and enriches raw payments with store context by joining through rental to inventory; 
 * 	-revenue_per_employee aggregates total revenue per staff member. 
 * The last store is then resolved in the final SELECT via a correlated subquery against payments_2017 — 
 * ordering by payment_date DESC, payment_id DESC with LIMIT 1 to pinpoint the single most recent transaction and its associated store. 
 * Reusing the already-filtered payments_2017 CTE in both the aggregation and the correlated subquery avoids scanning the full payment table twice, 
 * which is the key structural advantage of this approach over the subquery solution. */

-- Subquery solution
SELECT s.first_name
		, s.last_name
		, SUM(p.amount) AS total_revenue
		, (
        SELECT i.store_id
        FROM public.payment p2
        INNER JOIN public.rental r2 ON p2.rental_id = r2.rental_id
        INNER JOIN public.inventory i ON r2.inventory_id = i.inventory_id
        WHERE p2.staff_id = p.staff_id
			AND EXTRACT(YEAR FROM p2.payment_date) = 2017
        ORDER BY p2.payment_date DESC, p2.payment_id DESC
        LIMIT 1
    	) AS last_store
FROM public.payment p
INNER JOIN public.staff s ON p.staff_id = s.staff_id
WHERE EXTRACT(YEAR FROM p.payment_date) = 2017
GROUP BY p.staff_id, s.first_name, s.last_name
ORDER BY total_revenue DESC
LIMIT 3;

/* Subquery computes total revenue in the outer query and resolves the last store via a correlated subquery 
 * that re-executes against the raw tables for each employee row. 
 * Functionally correct, but the correlated subquery rescans payment, rental, and inventory once per employee rather than working from 
 * a pre-filtered intermediate result, making it less efficient than the CTE approach. */

-- JOIN solution is not feasible here

/* Standard GROUP BY with aggregate functions can compute SUM(amount) across all rows, but cannot isolate a non-aggregated column value — 
 * store_id — that belongs specifically to the row with the maximum payment_date. 
 * There is no pure JOIN mechanism to link an aggregated total with an attribute from a single chronological record without window functions or subqueries.*/

/* Production choice: CTE. 
 * The two-stage CTE is the most efficient and maintainable solution. 
 * Filtering and enriching payments once in payments_2017 and reusing that result for both aggregation and last-store resolution avoids redundant table scans. 
 * Each logical concern is isolated and named, making the tie-breaking logic transparent and auditable. */

/* TASK 2 ***********************************************************************************************************************************************************
 * The management team wants to identify the most popular movies and their target audience age groups to optimize marketing efforts. 
 * Show which 5 movies were rented more than others (number of rentals), and what's the expected age of the audience for these movies? 
 * To determine expected age please use 'Motion Picture Association film rating system' 
 *******************************************************************************************************************************************************************/

-- CTE solution
WITH movie_counts AS  (
	SELECT f.title
			, COUNT(r.rental_id) AS number_of_rentals
			, f.rating
	    FROM public.rental r
	    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
	    INNER JOIN public.film f ON i.film_id = f.film_id 
	    GROUP BY f.film_id, f.title, f.rating
)
SELECT title
		, number_of_rentals
		, CASE rating
	        WHEN 'G' THEN 'General Audiences' 
	        WHEN 'PG' THEN 'Parental Guidance Suggested'
	        WHEN 'PG-13' THEN 'Parents Strongly Cautioned' 
	        WHEN 'R' THEN 'Restricted' 
	        WHEN 'NC-17' THEN 'Adults Only' 
        	ELSE 'Unknown Rating'
    	END AS rating_description
FROM movie_counts
ORDER BY number_of_rentals DESC
LIMIT 5;

/* CTE isolates the aggregation and keeps the CASE expression in the outer query, separating the counting logic from the presentation logic. 
 * This two-stage structure is easy to read and debug — the rental counts can be inspected independently before the rating labels are applied. */

-- Subquery solution
SELECT title
		, number_of_rentals
		, CASE rating
	        WHEN 'G' THEN 'General Audiences' 
	        WHEN 'PG' THEN 'Parental Guidance Suggested'
	        WHEN 'PG-13' THEN 'Parents Strongly Cautioned' 
	        WHEN 'R' THEN 'Restricted' 
	        WHEN 'NC-17' THEN 'Adults Only' 
        	ELSE 'Unknown Rating'
    	END AS rating_description
FROM (
    SELECT f.title
			, COUNT(r.rental_id) AS number_of_rentals
			, f.rating
    FROM public.rental r
    INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
    INNER JOIN public.film f ON i.film_id = f.film_id 
    GROUP BY f.film_id, f.title, f.rating 
) AS movie_counts
ORDER BY number_of_rentals DESC
LIMIT 5;

/* Subquery is structurally identical to the CTE. 
 * The CASE expression is equally readable in both; the only difference is syntactic.
 * Since the derived table is referenced once, there is no reusability advantage to the CTE here.*/ 
 
-- JOIN solution
SELECT f.title
		, COUNT(r.rental_id) AS number_of_rentals
		, CASE f.rating
			WHEN 'G' THEN 'General Audiences' 
			WHEN 'PG' THEN 'Parental Guidance Suggested'
			WHEN 'PG-13' THEN 'Parents Strongly Cautioned' 
			WHEN 'R' THEN 'Restricted' 
			WHEN 'NC-17' THEN 'Adults Only' 
			ELSE 'Unknown Rating'
		END AS rating_description
FROM public.rental r
INNER JOIN public.inventory i ON r.inventory_id = i.inventory_id 
INNER JOIN public.film f ON i.film_id = f.film_id 
GROUP BY f.film_id, f.title, f.rating 
ORDER BY number_of_rentals DESC
LIMIT 5;

/* JOIN merges both the aggregation and the CASE expression into a single query. 
 * The CASE block adds visual length, making it slightly harder to scan, but the execution plan is equivalent. */

/* Production choice: CTE. 
 * The CASE expression is verbose enough that keeping it separate from the aggregation meaningfully improves readability. 
 * The CTE first counts rentals, then label ratings, which is easier to maintain and audit.
 * Additionally, I would replace LIMIT 5 (as suggested by the mentors) with FETCH FIRST 5 ROWS WITH TIES to better match the business question, 
 * since there are movies with the same number of rentals. */
 
-- PART 3 ----------------------------------------------------------------------------------------------------------------------------------------------------------
/* The stores’ marketing team wants to analyze actors' inactivity periods to select those with notable career breaks for targeted promotional campaigns, 
 * highlighting their comebacks or consistent appearances to engage customers with nostalgic or reliable film stars
 * The task can be interpreted in various ways, and here are a few options (provide solutions for each one): */

-- V1: gap between the latest release_year and current year per each actor ******************************************************************************************

-- CTE solution
WITH last_film_year AS (
	SELECT a.actor_id
			, a.first_name
			, a.last_name
			, MAX(f.release_year) AS last_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
)
SELECT first_name,
       last_name,
       EXTRACT(YEAR FROM current_date) - last_year AS gap
FROM last_film_year
ORDER BY gap DESC
LIMIT 5;

/* CTE pre-aggregates the latest film year per actor, then computes the gap in the outer query. */

-- Subquery solution
SELECT first_name
		, last_name
		, EXTRACT(YEAR FROM current_date) - last_year AS gap
FROM (
	SELECT a.actor_id
			, a.first_name
			, a.last_name
			, MAX(f.release_year) AS last_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
    GROUP BY a.actor_id, a.first_name, a.last_name
) AS last_film_year
ORDER BY gap DESC
LIMIT 5;

/* Subquery is structurally and semantically identical to the CTE. 
 * No reusability advantage applies since the derived table is referenced once; the choice is purely stylistic. */

-- JOIN solution
SELECT a.first_name
		, a.last_name
		, ((EXTRACT(YEAR FROM current_date)) - MAX(f.release_year)) AS gap
FROM public.actor a 
INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id 
INNER JOIN public.film f ON fa.film_id = f.film_id 
GROUP BY a.actor_id, a.first_name, a.last_name
ORDER BY gap DESC
LIMIT 5;

/* JOIN computes MAX(release_year) and the gap in a single aggregation step. 
 * Concise and correct, but combining the aggregation and the arithmetic in one expression makes the query marginally harder to read at a glance. */

/* Production choice: CTE. 
 * The gap calculation depends directly on the aggregated last_year value, so making that intermediate result explicit and named improves auditability. 
 * The JOIN solution is equally valid for simpler contexts. */

-- V2: gaps between sequential films per each actor *****************************************************************************************************************

/* Sum of all the gaps between released movies. 
 * The max granularity is one year, so for example, 2020 and 2021 - no gap, 2021, 2023 - one year gap (2022 without release). 
 * 												 — mentor's comment*/

-- CTE solution
WITH actor_years AS (
    SELECT DISTINCT 
		a.actor_id
        , a.first_name
        , a.last_name
        , f.release_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
)
SELECT ay1.first_name
		, ay1.last_name
	    , SUM(
	    	COALESCE(
	            GREATEST(
	                (
	                    SELECT MIN(ay2.release_year)
	                    FROM actor_years ay2
	                    WHERE ay2.actor_id = ay1.actor_id
	                    	AND ay2.release_year > ay1.release_year
	                ) - ay1.release_year - 1,
	                0
	            ),
	            0
	        )
	    ) AS total_gap
FROM actor_years ay1
GROUP BY ay1.actor_id, ay1.first_name, ay1.last_name
ORDER BY total_gap DESC
LIMIT 5;

/* CTE first builds actor_years — a deduplicated set of (actor_id, release_year) pairs, collapsing multiple films per year into a single row. 
 * The outer query then iterates over each row in that set and, for every active year ay1.release_year, fires a correlated subquery to find MIN(ay2.release_year) 
 * where ay2.release_year > ay1.release_year for the same actor — i.e. the immediately next active year. 
 * The difference next_year - current_year - 1 gives the gap in inactive years between those two points. 
 * The COALESCE function handled cases where the subquery returned no future years, while GREATEST ensures that all calculated gaps remain non-negative. 
 * This logic prevents null values from breaking the summation and keeps the final results mathematically consistent.
 * SUM accumulates all such gaps across the actor's full career. 
 * The CTE's named deduplication step makes it easy to inspect the actor_years intermediate result independently before the gap logic runs. */

-- Subquery solution
SELECT ay1.first_name
		, ay1.last_name
	    , SUM(
	        COALESCE(
	            GREATEST(
	                (
	                    SELECT MIN(f2.release_year)
	                    FROM public.film_actor fa2
	                    INNER JOIN public.film f2 ON fa2.film_id = f2.film_id
	                    WHERE fa2.actor_id = ay1.actor_id
	                      AND f2.release_year > ay1.release_year
	                ) - ay1.release_year - 1,
	                0
	            ),
	            0
	        )
	    ) AS total_gap
FROM (
    SELECT DISTINCT 
        a.actor_id
        , a.first_name
        , a.last_name
        , f.release_year
    FROM public.actor a
    INNER JOIN public.film_actor fa ON a.actor_id = fa.actor_id
    INNER JOIN public.film f ON fa.film_id = f.film_id
) ay1
GROUP BY ay1.actor_id, ay1.first_name, ay1.last_name
ORDER BY total_gap DESC
LIMIT 5;

/* Subquery applies identical logic but inlines the deduplication as an anonymous derived table. 
 * The correlated subquery for finding the next active year is the same in both solutions. 
 * The structural difference is purely syntactic — without the named CTE, the deduplication step is less visible, which slightly reduces auditability of 
 * the most important preprocessing step. */

-- JOIN solution is not feasible here

/* It is not possible to completely avoid subqueries in this case because we need to find, for each row, the next minimum release year greater than the current one.
 * This is a correlated operation that depends on the current row, and SQL requires either a subquery, or a window function what is forbidden.
 * A simple JOIN with GROUP BY is not sufficient, as it cannot isolate the immediate next value without additional filtering logic. */

/* Production choice: CTE. 
 * The deduplication step is critical to correctness — without it, multiple films in the same year would produce duplicate rows and inflate gap sums. 
 * Making that step explicit and named in a CTE makes the query significantly easier to audit and debug. 
 * The correlated subquery inside is unavoidable given the constraints, but its behavior is easier to reason about when the input set is 
 * clearly defined by the CTE above it. */
