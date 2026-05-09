-- TASK 1 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Create a query for analyzing the annual sales data for the years 1999 to 2001, focusing on different sales channels and regions: 
 * 		'Americas,' 'Asia,' and 'Europe.' 
 * The resulting report should contain the following columns:
 * 	- AMOUNT_SOLD: This column should show the total sales amount for each sales channel
 * 	- % BY CHANNELS: In this column, we should display the percentage of total sales for each channel 
 * 		(e.g. 100% - total sales for Americas in 1999, 63.64% - percentage of sales for the channel “Direct Sales”)
 * 	- % PREVIOUS PERIOD: This column should display the same percentage values as in the '% BY CHANNELS' column but for the previous year
 * 	- % DIFF: This column should show the difference between the '% BY CHANNELS' and '% PREVIOUS PERIOD' columns, 
 * 		indicating the change in sales percentage from the previous year.
 * The final result should be sorted in ascending order based on three criteria: 
 * 		first by 'country_region,' then by 'calendar_year,' and finally by 'channel_desc'
 **********************************************************************************************************************************************************/ 
WITH yearly_channel_stats AS (
	SELECT countr.country_region, t.calendar_year, c.channel_desc,
		SUM(amount_sold) AS amount_sold,
		(SUM(amount_sold) / SUM(SUM(amount_sold)) 
			OVER (PARTITION BY countr.country_region, t.calendar_year
			RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)) AS "% BY CHANNELS" -- default window frame which may not be written
	FROM sh.sales s
	INNER JOIN sh.customers cust ON s.cust_id = cust.cust_id
	INNER JOIN sh.countries countr ON cust.country_id = countr.country_id
	INNER JOIN sh.times t ON t.time_id = s.time_id
	INNER JOIN sh.channels c ON s.channel_id = c.channel_id 
	WHERE t.calendar_year BETWEEN 1998 AND 2001
		AND countr.country_region IN ('Americas', 'Asia', 'Europe')
	GROUP BY countr.country_region, t.calendar_year, c.channel_desc
),
comparative_sales AS (
	SELECT country_region, calendar_year, channel_desc, amount_sold, "% BY CHANNELS", 
		COALESCE(LAG("% BY CHANNELS", 1) OVER (PARTITION BY country_region, channel_desc ORDER BY calendar_year), 0) AS "% PREVIOUS PERIOD"
	FROM yearly_channel_stats
)
SELECT country_region, calendar_year, channel_desc, amount_sold, 
	TO_CHAR("% BY CHANNELS" * 100, '990.99') || '%' AS "% BY CHANNELS", 
	TO_CHAR("% PREVIOUS PERIOD" * 100, '990.99') || '%' AS "% PREVIOUS PERIOD", 
	TO_CHAR(("% BY CHANNELS" - "% PREVIOUS PERIOD") * 100, '990.99') || '%' AS "% DIFF"
FROM comparative_sales
WHERE calendar_year BETWEEN 1999 AND 2001
ORDER BY country_region, calendar_year, channel_desc;

-- TASK 2 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * You need to create a query that meets the following requirements:
 * 	Generate a sales report for the 49th, 50th, and 51st weeks of 1999.
 * 	Include a column named CUM_SUM to display the amounts accumulated during each week.
 * 	Include a column named CENTERED_3_DAY_AVG to show the average sales for the previous, current, and following days using a centered moving average.
 * 		For Monday, calculate the average sales based on the weekend sales (Saturday and Sunday) as well as Monday and Tuesday.
 * 		For Friday, calculate the average sales on Thursday, Friday, and the weekend.
 * 	Ensure that your calculations are accurate for the beginning of week 49 and the end of week 51.

 **********************************************************************************************************************************************************/ 
WITH weekly_sales AS (
	SELECT t.calendar_week_number, t.time_id, t.day_name, SUM(amount_sold) AS sales
	FROM sh.sales s
	INNER JOIN sh.times t ON t.time_id = s.time_id
	WHERE t.calendar_week_number BETWEEN 48 AND 51
		AND t.calendar_year = 1999
	GROUP BY t.time_id, t.calendar_week_number, t.day_name
)
SELECT calendar_week_number, time_id, day_name, sales,
	SUM(sales) OVER (PARTITION BY calendar_week_number ORDER BY time_id RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cum_sum,
	ROUND(AVG(sales) OVER (ORDER BY time_id RANGE BETWEEN INTERVAL '1' DAY PRECEDING AND INTERVAL '1' DAY FOLLOWING), 2) AS centered_3_day_avg
FROM weekly_sales
WHERE calendar_week_number BETWEEN 49 AND 51
ORDER BY time_id;

-- TASK 3 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Please provide 3 instances of utilizing window functions that include a frame clause, using ROWS, RANGE and GROUPS modes. 
 * Additionally, explain the reason for choosing a specific frame type for each example. 
 * This can be presented as a single query or as three distinct queries.
 **********************************************************************************************************************************************************/
WITH customer_metrics AS (
    SELECT 
        c.cust_id,
        COUNT(s.time_id) AS total_orders,
        SUM(s.amount_sold) AS total_revenue,
        ROUND(AVG(s.amount_sold), 2) AS avg_check
    FROM sh.customers c
    JOIN sh.sales s ON c.cust_id = s.cust_id
    GROUP BY c.cust_id, c.cust_last_name
)
SELECT 
    cust_id,
    total_orders,
    total_revenue,
    avg_check,
    -- ROWS: To compare a customer against their immediate neighbors in a sorted list.
    ROUND( AVG(total_revenue) OVER (
        ORDER BY total_revenue DESC 
        ROWS BETWEEN 5 PRECEDING AND 5 FOLLOWING
    ), 2) AS local_rank_avg,

    -- RANGE: To identify clusters of customers within a specific financial bracket.
    COUNT(*) OVER (
        ORDER BY avg_check
        RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING
    ) AS similar_spending_count,

    -- GROUPS: To compare different loyalty levels based on the number of orders.
    SUM(total_revenue) OVER (
        ORDER BY total_orders DESC
        GROUPS BETWEEN CURRENT ROW AND 1 FOLLOWING
    ) AS current_and_next_order_group_total
FROM customer_metrics
ORDER BY similar_spending_count DESC;

/* ROWS ignores the actual data values and focuses strictly on the row count. 
 * This is ideal for a "rank-based" average, ensuring we always compare a fixed number of records (e.g., 5 above and 5 below) regardless of 
 * how large the gap in their revenue is.

 * RANGE looks at the actual difference between values in the ORDER BY column. 
 * By using RANGE BETWEEN 10 PRECEDING AND 10 FOLLOWING, we capture every customer whose average check is within +-10 units of the current one. 

 * Since many customers share the same number of orders, GROUPS treats all identical values as a single unit. 
 * This allows the frame to include the entire "group" of people with 10 orders and the entire "group" with 1 orders. */