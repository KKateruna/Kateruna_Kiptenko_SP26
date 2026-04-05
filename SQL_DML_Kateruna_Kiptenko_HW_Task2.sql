-- TASK 2 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * 1. Create table ‘table_to_delete’ and fill it with the following query:
 **********************************************************************************************************************************************************/ 
CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x; -- generate_series() creates 10^7 rows of sequential numbers from 1 to 10000000 (10^7)

-- Execute time: 16s
/**********************************************************************************************************************************************************
 * 2. Lookup how much space this table consumes with the following query:
**********************************************************************************************************************************************************/ 
   SELECT *, pg_size_pretty(total_bytes) AS total,
                        pg_size_pretty(index_bytes) AS INDEX,
                        pg_size_pretty(toast_bytes) AS toast,
                        pg_size_pretty(table_bytes) AS TABLE
   FROM ( SELECT *, total_bytes-index_bytes-COALESCE(toast_bytes,0) AS table_bytes
                   FROM (SELECT c.oid,nspname AS table_schema,
                                                   relname AS TABLE_NAME,
                                                  c.reltuples AS row_estimate,
                                                  pg_total_relation_size(c.oid) AS total_bytes,
                                                  pg_indexes_size(c.oid) AS index_bytes,
                                                  pg_total_relation_size(reltoastrelid) AS toast_bytes
                                  FROM pg_class c
                                  LEFT JOIN pg_namespace n ON n.oid = c.relnamespace
                                  WHERE relkind = 'r'
                                  ) a
                        ) a
   WHERE table_name LIKE '%table_to_delete%';

-- total: 575 MB
-- index: 0 bytes
-- toast: 8192 bytes
-- table: 575 MB
/**********************************************************************************************************************************************************
 * 3. Issue the following DELETE operation on ‘table_to_delete’:
**********************************************************************************************************************************************************/ 
DELETE FROM table_to_delete
WHERE REPLACE(col, 'veeeeeeery_long_string','')::int % 3 = 0; -- removes 1/3 of all rows

/*
	a) Note how much time it takes to perform this DELETE statement;
		-- Execute time: 11s
		
	b) Lookup how much space this table consumes after previous DELETE;
		-- total: 575 MB
		-- index: 0 bytes
		-- toast: 8192 bytes
		-- table: 575 MB
*/
/*  c) Perform the following command (if you're using DBeaver, press Ctrl+Shift+O to observe server output (VACUUM results)): */
	VACUUM FULL VERBOSE table_to_delete;
		-- "public.table_to_delete": found 3333333 deleteable row versions, 6666667 non-deletable rows, 73536 pages viewed

		-- "deleteable row versions" = dead tuples created by DELETE (rows marked as deleted but still occupying space)
		-- "non-deletable rows" = live tuples that remain in the table
		-- Accordingly VACUUM FULL rewrites the table, removing dead tuples and keeping only live ones,
		-- 	which is why the table size decreases afterward
/*
	d) Check space consumption of the table once again and make conclusions;
		-- total: 383 MB
		-- index: 0 bytes
		-- toast: 8192 bytes
		-- table: 383 MB
		
	e) Recreate ‘table_to_delete’ table;
*/
DROP TABLE table_to_delete;

CREATE TABLE table_to_delete AS
SELECT 'veeeeeeery_long_string' || x AS col
FROM generate_series(1,(10^7)::int) x; -- generate_series() creates 10^7 rows of sequential numbers from 1 to 10000000 (10^7)
/**********************************************************************************************************************************************************
 * 4. Issue the following TRUNCATE operation: 
**********************************************************************************************************************************************************/ 
TRUNCATE table_to_delete;
/*
	a) Note how much time it takes to perform this TRUNCATE statement;
		-- Execute time: 0.095s

	b) Check space consumption of the table once again;
		-- total: 8192 bytes
		-- index: 0 bytes
		-- toast: 8192 bytes
		-- table: 0 bytes	
/**********************************************************************************************************************************************************
 * 5. Conclusions: 
**********************************************************************************************************************************************************/ 
	d) Compare DELETE and TRUNCATE in terms of:
		-- Execution time: TRUNCATE is significantly faster than DELETE (0.095s vs 11s).
						   While DELETE scans each row and generates logs, TRUNCATE operates at the file level, 
						   making it nearly 115 times faster for a table with 10 million rows.
		-- Disk space usage: TRUNCATE reclaimed all disk space, reducing the table size from 575 MB to 8 KB.
							 Unlike DELETE, which requires a VACUUM FULL to reclaim disk space, TRUNCATE deallocates the table’s storage 
							 immediately, resetting it to an empty state.
		-- Transaction behavior: DELETE generates massive WAL logs for every deleted row; 
								 TRUNCATE creates minimal logs, only recording the data page deallocation.
		-- Rollback possibility: Both DELETE and TRUNCATE are transactional in PostgreSQL and can be rolled back.
								 However, DELETE operates at row level and allows selective removal of data, while TRUNCATE is a bulk 
								 operation that removes all rows at once and requires an ACCESS EXCLUSIVE lock on the table.
	e) Explain:
		-- Why DELETE does not free space immediately?
			PostgreSQL uses MVCC (Multi-Version Concurrency Control).
			When rows are deleted, they are only marked as "dead tuples" (invisible to new transactions) to ensure data consistency for 
			other active sessions, keeping the physical space occupied.
		-- Why VACUUM FULL changes table size?
			VACUUM FULL physically rewrites the entire table into a new disk file, copying only "live" rows and completely discarding 
			"dead" ones, which returns the unused space to the OS.
		-- Why TRUNCATE behaves differently?
			TRUNCATE  behaves differently from row-level operations, as it removes all data by deallocating the table’s storage, making it 
			much more efficient for clearing large datasets, though it lacks the ability to filter specific rows and requires an 
			exclusive lock.
		-- Impact on performance and storage?
			For DELETE it depends on data volume, since this command leaves dead rows in the table, which causes table bloat and can slow 
			down performance over time. In contrast, TRUNCATE resets the table storage instantly without leaving any unused space.
 */