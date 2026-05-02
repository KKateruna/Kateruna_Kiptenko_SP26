-- TASK 1 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Create a query to produce a sales report highlighting the top customers with the highest sales across different sales channels. 
 * This report should list the top 5 customers for each channel. 
 * Additionally, calculate a key performance indicator (KPI) called 'sales_percentage,' which represents the percentage of a customer's 
 * sales relative to the total sales within their respective channel.
 * Please format the columns as follows:
		Display the total sales amount with two decimal places
		Display the sales percentage with four decimal places and include the percent sign (%) at the end
		Display the result for each channel in descending order of sales
 **********************************************************************************************************************************************************/ 
SELECT 
	channel_desc,
	cust_last_name,
	cust_first_name,
	ROUND(amount_sold, 2) AS amount_sold,
	ROUND(sales_percentage, 4) || '%' AS sales_percentage
FROM (
	SELECT 
		ch.channel_desc,
		c.cust_last_name,
		c.cust_first_name,
		SUM(amount_sold) AS amount_sold,
		(SUM(amount_sold) * 100.0) / SUM(SUM(amount_sold)) OVER (PARTITION BY ch.channel_desc) AS sales_percentage,
		ROW_NUMBER() OVER (PARTITION BY ch.channel_desc ORDER BY SUM(amount_sold) DESC) AS row_number
	FROM sh.customers c
	INNER JOIN sh.sales s ON c.cust_id = s.cust_id 
	INNER JOIN sh.channels ch ON s.channel_id = ch.channel_id
	GROUP BY c.cust_id, ch.channel_desc
) sub_query
WHERE row_number <= 5
ORDER BY channel_desc, amount_sold DESC;
/* A subquery is required because window functions are evaluated after the WHERE and HAVING clauses, so the rank must be computed 
 * before it can be filtered. 
 * 
 * ROW_NUMBER() is chosen over RANK() to guarantee a hard top-5 cut even even when customers have identical sales values. 
 * 
 * The window SUM(SUM(amount_sold)) OVER (PARTITION BY channel_desc) calculates the total sales per channel while still preserving 
 * row-level customer aggregates, enabling computation of a proportional KPI (sales percentage). */
-- TASK 2 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Create a query to retrieve data for a report that displays the total sales for all products in the Photo category in the Asian region 
 * for the year 2000. 
 * Calculate the overall report total and name it 'YEAR_SUM'
		Display the sales amount with two decimal places
		Display the result in descending order of 'YEAR_SUM'
		For this report, consider exploring the use of the crosstab function.
 **********************************************************************************************************************************************************/ 
CREATE EXTENSION IF NOT EXISTS tablefunc;

SELECT 
    ct.product_name,
    ROUND(COALESCE(ct.q1, 0), 2) AS q1,
    ROUND(COALESCE(ct.q2, 0), 2) AS q2,
    ROUND(COALESCE(ct.q3, 0), 2) AS q3,
    ROUND(COALESCE(ct.q4, 0), 2) AS q4,
    ROUND(ct.year_sum, 2) AS year_sum
FROM crosstab(
    'SELECT 
        p.prod_name,
        SUM(SUM(s.amount_sold)) OVER (PARTITION BY p.prod_name) AS year_sum, 
        t.calendar_quarter_desc,
        SUM(s.amount_sold) AS q_amount
     FROM sh.sales s
     INNER JOIN sh.products p ON s.prod_id = p.prod_id
     INNER JOIN sh.times t ON s.time_id = t.time_id
     INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id
     INNER JOIN sh.countries countr ON cust.country_id = countr.country_id
     WHERE p.prod_category = ''Photo''
       AND countr.country_region = ''Asia''
       AND t.calendar_year = 2000
     GROUP BY p.prod_name, t.calendar_quarter_desc
     ORDER BY 1, 3', 
    'VALUES (''2000-01''), (''2000-02''), (''2000-03''), (''2000-04'')'
) AS ct(
    product_name VARCHAR(50),
    year_sum NUMERIC, 
    q1 NUMERIC,
    q2 NUMERIC,
    q3 NUMERIC,
    q4 NUMERIC
)
ORDER BY year_sum DESC;
/* The 'tablefunc' extension must be enabled to provide the crosstab() functionality, which is not part of the PostgreSQL core.
 * 
 * COALESCE(..., 0) handles products with no sales in a given quarter. 
 * 
 * Any columns between the first (Row ID) and the last two (Category/Value) are treated as "extra columns" in crosstab. The 'year_sum' 
 * is placed second to ensure it is passed through directly to the output without interfering with the pivot logic.
 *
 * The SUM(SUM(amount_sold)) OVER (...) is used because the inner SUM aggregates data for a specific product and quarter (due to GROUP BY), 
 * while the outer window SUM aggregates those quarterly totals into a full year total for that product.
 *
 * While the window function is a task requirement, a simpler approach would be omitting 'year_sum' from the inner query and calculating 
 * it in the outer SELECT by adding the quarterly columns together (e.g., q1 + q2 + q3 + q4). */
-- TASK 3 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Create a query to generate a sales report for customers ranked in the top 300 based on total sales in the years 1998, 1999, and 2001. 
 * The report should be categorized based on sales channels, and separate calculations should be performed for each channel.
		Retrieve customers who ranked among the top 300 in sales for the years 1998, 1999, and 2001
		Categorize the customers based on their sales channels
		Perform separate calculations for each sales channel
		Include in the report only purchases made on the channel specified
		Format the column so that total sales are displayed with two decimal places
 **********************************************************************************************************************************************************/ 
/* For Task 3, you need to find the Top 300 customers in each sales channel separately for each year (1998, 1999, and 2001).
 * Only include customers who were in the Top 300 for all three years within the same channel. */ -- from Microsoft Teams
WITH yearly_sales AS ( 
    SELECT 
        ch.channel_desc,
        t.calendar_year,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name,
        SUM(s.amount_sold) AS amount_sold
    FROM sh.customers c
    JOIN sh.sales s ON c.cust_id = s.cust_id
    JOIN sh.channels ch ON s.channel_id = ch.channel_id
    JOIN sh.times t ON s.time_id = t.time_id
    WHERE t.calendar_year IN (1998, 1999, 2001)
    GROUP BY 
        ch.channel_desc,
        t.calendar_year,
        c.cust_id,
        c.cust_last_name,
        c.cust_first_name
),
ranked_sales AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY channel_desc, calendar_year 
               ORDER BY amount_sold DESC
           ) AS rn
    FROM yearly_sales
),
top_300 AS (
    SELECT *
    FROM ranked_sales
    WHERE rn <= 300
),
consistent_customers AS (
    SELECT 
        channel_desc,
        cust_id
    FROM top_300
    GROUP BY channel_desc, cust_id
    HAVING COUNT(DISTINCT calendar_year) = 3
)
SELECT 
    t.channel_desc,
    t.calendar_year,
    t.cust_id,
    t.cust_last_name,
    t.cust_first_name,
    ROUND(t.amount_sold, 2) AS amount_sold
FROM top_300 t
JOIN consistent_customers cc
    ON t.channel_desc = cc.channel_desc
   AND t.cust_id = cc.cust_id
ORDER BY 
    t.channel_desc,
    t.calendar_year,
    t.amount_sold DESC;
/* This query is intentionally decomposed into multiple CTE layers to clearly separate logic:
 *
 * 1. yearly_sales:
 *    Aggregates total sales per customer per channel per year. This reduces raw transactional data into analyzable units.
 *
 * 2. ranked_sales:
 *    Applies ROW_NUMBER() partitioned by (channel, year) to rank customers.
 *    ROW_NUMBER is chosen to enforce a strict Top 300 cutoff without ties expansion, ensuring consistent result size per year and channel.
 *
 * 3. top_300:
 *    Filters only high-performing customers per yearly segment.
 *
 * 4. consistent_customers:
 *    Uses HAVING COUNT(DISTINCT year) = 3 to enforce cross-year stability, meaning only customers consistently performing in all years remain. */
-- TASK 4 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Create a query to generate a sales report for January 2000, February 2000, and March 2000 specifically for the Europe and Americas regions.
 * Display the result by months and by product category in alphabetical order.
 **********************************************************************************************************************************************************/ 
SELECT 
    calendar_month_desc,
    prod_category,
    ROUND(SUM(CASE WHEN country_region = 'Americas' THEN region_sales ELSE 0 END), 2) AS "Americas SALES",
    ROUND(SUM(CASE WHEN country_region = 'Europe' THEN region_sales ELSE 0 END), 2) AS "Europe SALES"
FROM (
    SELECT 
        t.calendar_month_desc,
        p.prod_category,
        countr.country_region,
        SUM(s.amount_sold) OVER (PARTITION BY t.calendar_month_desc, p.prod_category, countr.country_region) AS region_sales
    FROM sh.sales s
    INNER JOIN sh.products p ON s.prod_id = p.prod_id
    INNER JOIN sh.times t ON s.time_id = t.time_id 
    INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id
    INNER JOIN sh.countries countr ON cust.country_id = countr.country_id
    WHERE t.calendar_month_desc IN ('2000-01', '2000-02', '2000-03')
      AND countr.country_region IN ('Americas', 'Europe')
) sub_query
GROUP BY calendar_month_desc, prod_category
ORDER BY calendar_month_desc, prod_category;

/* This query uses conditional aggregation instead of crosstab because only two fixed dimensions (Americas and Europe) exist, the structure 
 * is stable and known in advance, CASE-based pivoting is simpler, more readable, and more performant here
 * 
 * As for the window function, like in Task 2, the logic could be simplified by using a standard SUM(s.amount_sold) paired with 
 * a simple GROUP BY at the same level. */