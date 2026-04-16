-- TASK 1 -------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************
 * Create a view called 'sales_revenue_by_category_qtr' that shows the film category and total sales revenue for the current quarter and year. 
 * The view should only display categories with at least one sale in the current quarter.
 * Note: make it dynamic - when the next quarter begins, it automatically considers that as the current quarter.
 * Explain in the comment how you determine:
 *		current quarter
 *		current year
 *		why only categories with sales appear
 *		how zero-sales categories are excluded
 * Also, please indicate how you verified that view is working correctly.
 * Provide example of data that should NOT appear.
 **********************************************************************************************************************************************/ 
/* Why this logic is used, how the result is calculated? 
 * Since the payment table does not show categories, the code uses INNER JOINs to build a bridge through other tables (rental, inventory, and 
 * film_category). Then the EXTRACT function compares the date of each payment with the CURRENT_DATE. The GROUP BY command separates the results 
 * by category name, and SUM adds up all the payments for each one to get the total revenue.*/
CREATE OR REPLACE VIEW public.sales_revenue_by_category_qtr AS 
	SELECT c.name, SUM(p.amount) AS total_sales_revenue
	FROM public.category c 
	INNER JOIN public.film_category fc ON c.category_id = fc.category_id
	INNER JOIN public.inventory i ON fc.film_id = i.film_id
	INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
	INNER JOIN public.payment p ON r.rental_id = p.rental_id
	WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM CURRENT_DATE) AND 
		EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM CURRENT_DATE)
	-- WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM '2017-06-01'::DATE) AND 
	--	 EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM '2017-06-01'::DATE)	
	GROUP BY c.name;

SELECT * FROM public.sales_revenue_by_category_qtr;
/* 1. Current Year & Quarter: Determined dynamically using EXTRACT(YEAR FROM CURRENT_DATE) and EXTRACT(QUARTER FROM CURRENT_DATE).
 * 2. Why only categories with sales appear: I used INNER JOINs across all tables (category -> film_category -> inventory -> rental -> payment). 
 * 		A category will only be included if there is a matching record in the 'payment' table for the specified period.
 * 3. How zero-sales categories are excluded: Because of INNER JOIN, any category that doesn't have associated payments within the current 
 * 		quarter is automatically filtered out before the SUM() aggregation occurs.
 * 4. Verification: Since the database lacks data for 2026, verification was done by temporarily replacing CURRENT_DATE with a date '2017-06-01' 
 * 		to ensure the view return expected results.
 * 
 * Data that shouldn't appear:
 * - Sales from previous years or quarters
 * - Categories with zero total revenue
 * - Films that were rented but never paid for */
 
-- TASK 2 -------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************
 * Create a query language function called 'get_sales_revenue_by_category_qtr' that accepts one parameter representing the current quarter and 
 * year and returns the same result as the 'sales_revenue_by_category_qtr' view.
 * Explain in the comment:
 * 		why parameter is needed
 * 		what happens if:
 * 			invalid quarter is passed
 * 			no data exists
 **********************************************************************************************************************************************/ 
/* Why this logic is used, how the result is calculated? 
 * Unlike the previous view, this logic uses a target_date parameter, which allows the user to look up sales for both the current period and past 
 * dates. The INNER JOIN links the financial data in the payment table to the specific genre names in the category table. So the function connects 
 * five tables (category, film_category, inventory, rental, and payment), then the logic uses EXTRACT to compare the year and quarter of the 
 * payment_date with the year and quarter of the target_date. If no date is provided, the function uses CURRENT_DATE by default. The GROUP BY clause 
 * organizes the filtered results by category name, and SUM(p.amount) calculates the total earnings for each group during that specific time frame. */
CREATE OR REPLACE FUNCTION public.get_sales_revenue_by_category_qtr(target_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (category TEXT, total_sales_revenue NUMERIC)
AS $$
SELECT c.name, SUM(p.amount) AS total_sales_revenue
FROM public.category c 
INNER JOIN public.film_category fc ON c.category_id = fc.category_id
INNER JOIN public.inventory i ON fc.film_id = i.film_id
INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
INNER JOIN public.payment p ON r.rental_id = p.rental_id
WHERE EXTRACT(YEAR FROM p.payment_date) = EXTRACT(YEAR FROM target_date) AND 
	EXTRACT(QUARTER FROM p.payment_date) = EXTRACT(QUARTER FROM target_date)
GROUP BY c.name;
$$
LANGUAGE sql;

SELECT * FROM public.get_sales_revenue_by_category_qtr(DATE '2017-06-01');
SELECT * FROM public.get_sales_revenue_by_category_qtr(DATE '2026-06-01');
SELECT * FROM public.get_sales_revenue_by_category_qtr();
SELECT * FROM public.get_sales_revenue_by_category_qtr(NULL);
/* 1. Why parameter is needed: The parameter target_date makes the logic reusable for any specific quarter and year by passing a date from 
 * 		that period.
 * 2. What happens if an invalid quarter is passed: Since the function uses the DATE type, PostgreSQL will raise a syntax error for an 
 * 		invalid date format before the function even executes, ensuring data integrity.
 * 3. What happens if no data exists: If the provided date belongs to a quarter with no sales transactions, the INNER JOINs will fail to 
 * 		find matching records, and the function will return an empty result set. If the function is executed without arguments, it defaults 
 * 		to the current date and returns an empty set due to the absence of sales records for the year 2026. If a NULL value is passed as an 
 * 		input, the function produces no rows because the filtering criteria cannot be satisfied by undefined data.*/

-- TASK 3 -------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************
 * Create a function that takes a country as an input parameter and returns the most popular film in that specific country. 
 * The function should format the result set as follows:
 * 		Query (example):select * from core.most_popular_films_by_countries(array['Afghanistan','Brazil','United States']);
 * 
 * Explain in the comment:
 * 		how 'most popular' is defined: by rentals / by revenue / by count
 * 		how ties are handled
 * 		what happens if country has no data
 **********************************************************************************************************************************************/ 
/* Why this logic is used, how the result is calculated? 
 * The function links eight different tables to trace a path from the film title to the country where the customer lives. The GROUP BY clause 
 * gathers data by country and film title, while COUNT(*) calculates the total number of rentals for each movie. The ORDER BY clause then sorts 
 * these results so that the films with the highest number of rentals appear at the top for each country. The DISTINCT ON (country.country) 
 * command ensures that the final table only shows one record for each country. */
CREATE OR REPLACE FUNCTION public.most_popular_films_by_countries(countries TEXT[])
RETURNS TABLE ("Country" TEXT,
			   "Film" TEXT,
			   "Rating" mpaa_rating,
		  	   "Language" BPCHAR(20),
			   "Length" SMALLINT,
			   "Year" YEAR)
AS $$
BEGIN 
	IF countries IS NULL OR array_length(countries, 1) IS NULL THEN
        RAISE EXCEPTION 'The countries array cannot be NULL or empty.';
    END IF;

	RETURN QUERY
	SELECT DISTINCT ON (country.country)
		country.country,
		f.title,
		f.rating,
		l.name,
		f.length,
		f.release_year
	FROM public.film f
	INNER JOIN public.language l ON f.language_id = l.language_id
	INNER JOIN public.inventory i ON f.film_id = i.film_id
	INNER JOIN public.rental r ON i.inventory_id = r.inventory_id
	INNER JOIN public.customer c ON r.customer_id = c.customer_id
	INNER JOIN public.address a ON c.address_id = a.address_id
	INNER JOIN public.city ON a.city_id = city.city_id
	INNER JOIN public.country ON city.country_id = country.country_id
	WHERE UPPER() = ANY(SELECT UPPER(x) FROM UNNEST() AS x)
	GROUP BY country.country, f.title, f.rating, l.name, f.length, f.release_year
	ORDER BY country.country, COUNT(*) DESC, f.title ASC;
END; 
$$
LANGUAGE plpgsql;

SELECT * FROM public.most_popular_films_by_countries(ARRAY['Afghanistan','Brazil','United States']);
SELECT * FROM public.most_popular_films_by_countries(ARRAY['Neverland']);
SELECT * FROM public.most_popular_films_by_countries(ARRAY['Neverland','Brazil','United States']);
SELECT * FROM public.most_popular_films_by_countries(NULL);
SELECT * FROM public.most_popular_films_by_countries(ARRAY[]::TEXT[]);
/* 1. How 'most popular' is defined: It is defined by the COUNT of rentals. 
 * 		The function calculates how many times each film was rented by customers in the specified countries.
 * 2. How ties are handled: If multiple films have the same maximum rental count in a country, the 'ORDER BY ... f.title ASC' clause 
 * 		ensures that the film which comes first alphabetically by its title is selected.
 * 3. What happens if a country has no data: If a country provided in the array doesnєt exist in the database or has no rental records, 
 * 		it will simply be excluded from the result set. If no data is found for any of the provided countries, the function returns an 
 * 		empty table. */

-- TASK 4 -------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************
 * Create a function that generates a list of movies available in stock based on a partial title match (e.g., movies containing the word 
 * 'love' in their title). The titles of these movies are formatted as '%...%', and if a movie with the specified title is not in stock, 
 * return a message indicating that it was not found. The function should produce the result set in the following format (note: the 'row_num'
 * field is an automatically generated counter field, starting from 1 and incrementing for each entry, e.g., 1, 2, ..., 100, 101, ...).
 * 		Query (example):select * from core.films_in_stock_by_title('%love%');
 * 
 * Explain in the comment:
 * 		how pattern matching works (ILIKE, %)
 * 		how you ensure performance: which part of your query may become slow on large data
 * 		how your implementation minimizes unnecessary data processing
 * 		case sensitivity
 * 		what happens if:
 * 			multiple matches
 * 			no matches
 **********************************************************************************************************************************************/
/* In the words of the mentor, if the task itself says nothing about which customer we must return, let’s agree that this should be “the most 
 * recent client”. So the objective of this function is to display a list of films currently available for rent while providing data about their 
 * most recent customer */

/* Why this logic is used, how the result is calculated? 
 * The process begins by linking the film catalog to the inventory and filtering results using the ILIKE operator for flexible, title searches. 
 * To ensure accurate "in-stock" status, the function implements a subquery with a NOT EXISTS clause that excludes any inventory items currently 
 * tied to an active rental where the return date is missing. Within this filtered set, the logic applies DISTINCT ON (film_id) combined with a 
 * descending sort on the rental date to isolate only one movie. Then the system utilizes the ROW_NUMBER() OVER() window function to assign a 
 * sequential index to every record. Finally, the function checks if no available copies match the specified pattern or if all matching films are 
 * currently rented out. */
CREATE OR REPLACE FUNCTION public.films_in_stock_by_title(target_title TEXT)
RETURNS TABLE ("Row number" BIGINT,
			   "Film title" TEXT,
		  	   "Language" BPCHAR(20),
			   "Customer name" TEXT,
			   "Rental date" TIMESTAMPTZ)
AS $$
DECLARE
	v_row   RECORD;
	v_num   BIGINT := 0;
BEGIN 
	IF NOT EXISTS (
		SELECT 1
		FROM public.film f
		INNER JOIN public.inventory i ON f.film_id = i.film_id
		WHERE f.title ILIKE target_title
		AND NOT EXISTS (
			SELECT 1 FROM public.rental r2
			WHERE r2.inventory_id = i.inventory_id
			AND r2.return_date IS NULL
		)
	) THEN
		RAISE NOTICE 'No movies found for pattern %.', target_title;
		RETURN;
	END IF;

	FOR v_row IN
		SELECT DISTINCT ON (f.film_id)
			   f.title,
			   l.name AS lang_name,
			   c.first_name || ' ' || c.last_name AS cust_name,
			   r.rental_date AS last_rental
		FROM public.film f
		INNER JOIN public.language l ON f.language_id = l.language_id
		INNER JOIN public.inventory i ON f.film_id = i.film_id
		LEFT JOIN public.rental r ON i.inventory_id = r.inventory_id
		LEFT JOIN public.customer c ON r.customer_id = c.customer_id
		WHERE f.title ILIKE target_title
		AND NOT EXISTS (
		      SELECT 1 FROM public.rental r2 
		      WHERE r2.inventory_id = i.inventory_id 
		      AND r2.return_date IS NULL
		  )
		ORDER BY f.film_id, r.rental_date DESC
	LOOP
		v_num            := v_num + 1;
		"Row number"     := v_num;
		"Film title"     := v_row.title;
		"Language"       := v_row.lang_name;
		"Customer name"  := v_row.cust_name;
		"Rental date"    := v_row.last_rental;
		RETURN NEXT;
	END LOOP;
END; 
$$
LANGUAGE plpgsql;

SELECT * FROM public.films_in_stock_by_title('%love%');
SELECT * FROM public.films_in_stock_by_title('Ma_rix%');
SELECT * FROM public.films_in_stock_by_title('%neverland%');
/* 1. How pattern matching works: ILIKE is used for case-insensitive text comparison, meaning it does not distinguish between uppercase and 
 * 		lowercase letters, while % represents any sequence of characters.
 * 2. Performance & Optimization: The main performance issue in this query is the use of ILIKE, especially with wildcard patterns such as %love%, 
 * 		which may lead to a full table scan and slow execution on large datasets. However, the system applies the title filter before joining all 
 * 		tables, this reduces the amount of data processed during the JOIN and ROW_NUMBER stages. To make this faster, we could create an index on 
 * 		the title column.
 * 3. Case sensitivity: I used ILIKE instead of LIKE to ensure the search is case-insensitive, matching 'LOVE', 'Love', and 'love' equally.
 * 4. Handling scenarios:
 * - Multiple matches: ROW_NUMBER() OVER() generates a unique incrementing ID for every found row.
 * - No matches: The IF NOT FOUND block triggers a RAISE NOTICE to inform the user that no movies were found.*/
-- TASK 5 -------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************
 * Create a procedure language function called 'new_movie' that takes a movie title as a parameter and inserts a new movie with the given 
 * title in the film table. The function should generate a new unique film ID, set the rental rate to 4.99, the rental duration to three days, 
 * the replacement cost to 19.99. The release year and language are optional and by default should be current year and Klingon respectively. 
 * The function should also verify that the language exists in the 'language' table. 
 * The function must prevent inserting duplicate movie titles and raise an exception if duplicate exists.
 * Ensure that no such function has been created before; if so, replace it.
 * 
 * 
 * Explain in the comment:
 * 		how you generate unique ID
 * 		how you ensure no duplicates
 * 		what happens if movie already exists
 * 		how you validate language existence
 * 		what happens if insertion fails
 * 		how consistency is preserved
 **********************************************************************************************************************************************/
/* In the words of the mentor, if language is not exist your function should insert new language to the table and then proceed working with 
 * insert new film. So the function first attempts to retrieve the ID of the specified language. If the language is not found, it is automatically 
 * inserted into the language table to ensure the film insertion can proceed without failure.*/ 

/* Why this logic is used, how the result is calculated? 
 * After the "language problem", the system checks if the movie title is already in the database and if it isn't, the function inserts the movie 
 * details, such as the title, year, and language ID, while using standard prices for rental costs. Finally, the function sends a message to confirm 
 * that the movie was added and if a new language was created during the process. */
CREATE OR REPLACE FUNCTION public.new_movie(
    p_title TEXT, 
    p_year YEAR DEFAULT EXTRACT(YEAR FROM CURRENT_DATE)::INTEGER, 
    p_lang TEXT DEFAULT 'Klingon'
)
RETURNS VOID 
AS $$
DECLARE
    lang_id INTEGER;
    v_title TEXT := UPPER(p_title);   -- Converts movie title to UPPERCASE for database consistency
    v_lang TEXT := INITCAP(p_lang);  -- Formats language name to Title Case 
BEGIN 
    SELECT language_id INTO lang_id 
    FROM public.language 
    WHERE name = v_lang;

    IF lang_id IS NULL THEN
        INSERT INTO public.language (name) 
        VALUES (v_lang) 
        RETURNING language_id INTO lang_id;
        RAISE NOTICE 'New language % was added to the database.', v_lang;
    END IF;

    IF EXISTS (SELECT 1 FROM public.film WHERE title = v_title) THEN
        RAISE EXCEPTION 'Movie title % already exists.', v_title;
    END IF;

    INSERT INTO public.film (
        title, 
        rental_rate, 
        rental_duration, 
        replacement_cost, 
        release_year, 
        language_id
    )
    VALUES (v_title, 4.99, 3, 19.99, p_year, lang_id);

    RAISE NOTICE 'Movie % successfully inserted!', v_title;
END; 
$$
LANGUAGE plpgsql;

-- Successful insertion with all parameters
SELECT public.new_movie('Interstellar', 2014, 'English');

-- Successful default language and movie insertion
SELECT public.new_movie('The Drama');

-- Expected error (Duplicate title)
SELECT public.new_movie('Interstellar', 2014, 'English');

SELECT * FROM public.film WHERE INITCAP(title) IN ('Interstellar', 'The Drama');
SELECT * FROM public.language;
/* 1. Unique identifier generation: The primary key film_id is managed automatically by the database engine because of SERIAL type. By omitting 
 * 		this field from the insert statement, the system utilizes an internal sequence to assign a unique, incremental identifier to each record.
 *
 * 2. Duplicate prevention & conflict handling: The function checks if the film title already exists by IF EXISTS (SELECT 1 FROM public.film 
 * 		WHERE title = p_title) command. If the title is found in the film table, the function stops and shows an error message.
 *
 * 3. Language validation: If the language is not found, the function automatically creates a new record in the public.language table.
 *
 * 4. Error handling during insertion: If the insert operation fails due to constraint violations (such as not null or check constraints), the 
 * 		database engine will automatically trigger a system-level exception, ensuring that incomplete or invalid data is never committed.
 * 
 * 5. Preservation of transactional consistency: All steps happen as one single task. If any part of the function fails, no changes are saved to 
 * 		the database, keeping the data safe and correct.
 */