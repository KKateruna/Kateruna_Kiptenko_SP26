-- TASK 2 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * For each permission change:
 * Demonstrate both successful and denied access 
 * Provide SQL query showing the error message when access is restricted
 **********************************************************************************************************************************************************/ 
-- Create a new user with the username "rentaluser" and the password "rentalpassword". 
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rentaluser') THEN
        CREATE ROLE rentaluser LOGIN PASSWORD 'rentalpassword';
    END IF;
END
$$;

-- Give the user the ability to connect to the database but no other permissions.
GRANT CONNECT ON DATABASE dvdrental TO rentaluser;

SET ROLE rentaluser; -- demonstrate denied access
SELECT * FROM public.customer; -- SQL Error [42501]: ERROR: no permission on table customer
RESET ROLE;

-- Grant "rentaluser" permission allows reading data from the "customer" table. 
GRANT SELECT ON TABLE public.customer TO rentaluser;

-- Сheck to make sure this permission works correctly: write a SQL query to select all customers.
SET ROLE rentaluser; -- demonstrate successful access
SELECT * FROM public.customer;
RESET ROLE;

-- Create a new user group called "rental" and add "rentaluser" to the group. 
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'rental') THEN
        CREATE ROLE rental;
    END IF;
END
$$;
GRANT rental TO rentaluser;

-- Grant the "rental" group INSERT and UPDATE permissions for the "rental" table.
GRANT INSERT, UPDATE ON TABLE public.rental TO rental;

-- Insert a new row and update one existing row in the "rental" table under that role. 
-- Note: I created a function to allow quick multiple insertion of a new rent record without hard-coding 
CREATE OR REPLACE FUNCTION public.new_rental( 
    p_rental_date TIMESTAMP,
    p_title TEXT,
    p_first_name TEXT,
    p_last_name TEXT,
    p_store_address TEXT
)
RETURNS SETOF public.rental AS $$
BEGIN
    RETURN QUERY
    INSERT INTO public.rental (rental_date, inventory_id, customer_id, staff_id, last_update)
    SELECT 
        p_rental_date,
        i.inventory_id, 
        c.customer_id, 
        (SELECT s.staff_id FROM public.staff s WHERE s.store_id = i.store_id LIMIT 1), 
        CURRENT_TIMESTAMP
    FROM public.film f
    INNER JOIN public.inventory i ON i.film_id = f.film_id
    INNER JOIN public.address a ON a.address = p_store_address
    INNER JOIN public.store st ON st.address_id = a.address_id AND i.store_id = st.store_id
    INNER JOIN public.customer c ON c.first_name = UPPER(p_first_name) AND c.last_name = UPPER(p_last_name)
    WHERE UPPER(f.title) = UPPER(p_title)
      AND NOT EXISTS (
        SELECT 1 FROM public.rental r
        WHERE r.rental_date = p_rental_date
          AND r.inventory_id = i.inventory_id
          AND r.customer_id = c.customer_id 
    )
    LIMIT 1
    RETURNING *;
END;
$$ LANGUAGE plpgsql;

GRANT SELECT ON rental, film, inventory, customer, staff, store, address TO rental; -- forced permissions to be able to use the function
GRANT USAGE, SELECT ON SEQUENCE rental_rental_id_seq TO rental;
GRANT EXECUTE ON FUNCTION public.new_rental TO rental;

SET ROLE rental; -- demonstrate successful access

SELECT * FROM public.new_rental(
    '2026-04-16 10:00:00', 
    'THREE MEN IN A BOAT', 
    'KATERUNA', 
    'KIPTENKO', 
    '47 MySakila Drive'
);

UPDATE public.rental
SET return_date = '2026-04-20 12:00:00'::timestamp
WHERE rental_date = '2026-04-16 10:00:00'::timestamp
RETURNING *;

RESET ROLE;

-- Revoke the "rental" group's INSERT permission for the "rental" table. 
REVOKE INSERT ON TABLE public.rental FROM rental;

-- Try to insert new rows into the "rental" table make sure this action is denied.
SET ROLE rental; -- demonstrate denied access
SELECT * FROM public.new_rental( -- SQL Error [42501]: ERROR: no permission on table rental
    '2026-04-16 10:00:00', 
    'THREE MEN IN A BOAT', 
    'KATERUNA', 
    'KIPTENKO', 
    '47 MySakila Drive'
);
RESET ROLE;

-- Create a personalized role for any customer already existing in the dvd_rental database. 
-- The name of the role name must be client_{first_name}_{last_name} (omit curly brackets). 
-- The customer's payment and rental history must not be empty. 
DO
$role_creation$
DECLARE rec RECORD;
BEGIN
	IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'customer') THEN
        CREATE ROLE customer;
    END IF;
    FOR rec IN
        (
            SELECT DISTINCT 'client_' || LOWER(c.first_name) || '_' || LOWER(c.last_name) AS role_name
            FROM public.customer c
            INNER JOIN public.payment p ON c.customer_id = p.customer_id
            INNER JOIN public.rental r ON c.customer_id = r.customer_id
        )
    LOOP
        IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = rec.role_name) THEN
            EXECUTE 'CREATE ROLE ' || quote_ident(rec.role_name);
			EXECUTE 'GRANT customer TO ' || quote_ident(rec.role_name);
        END IF;
    END LOOP;
END;
$role_creation$;
/* This block dynamically creates personalized database roles for active customers who have existing records in both the payment and rental tables.
 * It iterates through the customer list and generates a unique role name for each person using the `client_{first_name}_{last_name}` format.
 * The script then verifies if the role already exists and, if not, creates it and assigns it to the general `customer` group to inherit base permissions. */

-- TASK 3 -------------------------------------------------------------------------------------------------------------------------------------------------
/**********************************************************************************************************************************************************
 * Read about row-level security (https://www.postgresql.org/docs/12/ddl-rowsecurity.html).
 * Configure that role so that the customer can only access their own data in the "rental" and "payment" tables. 
 * Write a query to make sure this user sees only their own data and one to show zero rows or error.
 * As a result you have to demonstrate:
 * 		access to allowed records 
 * 		denied access to other users’ records 
 **********************************************************************************************************************************************************/ 
GRANT SELECT ON public.customer, public.rental, public.payment TO customer;

-- Enable RLS on tables
ALTER TABLE public.customer ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.rental ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payment ENABLE ROW LEVEL SECURITY;

-- Policy for Customer table
DROP POLICY IF EXISTS customer_policy ON public.customer;
CREATE POLICY customer_policy ON public.customer TO customer
USING (('client_' || LOWER(first_name) || '_' || LOWER(last_name)) = current_role);

-- Policy for Rental table
DROP POLICY IF EXISTS rental_policy ON public.rental;
CREATE POLICY rental_policy ON public.rental TO customer
USING (EXISTS (
    SELECT 1 FROM public.customer c
    WHERE c.customer_id = rental.customer_id
    AND ('client_' || LOWER(c.first_name) || '_' || LOWER(c.last_name)) = current_role
));

-- Policy for Payment table
DROP POLICY IF EXISTS payment_policy ON public.payment;
CREATE POLICY payment_policy ON public.payment TO customer
USING (EXISTS (
    SELECT 1 FROM public.customer c
    WHERE c.customer_id = payment.customer_id
    AND ('client_' || LOWER(c.first_name) || '_' || LOWER(c.last_name)) = current_role
));

SELECT customer_id -- finding customer_id for Pearl Garza
FROM public.customer 
WHERE LOWER(first_name) = 'pearl' AND LOWER(last_name) = 'garza';

SET ROLE client_pearl_garza; -- all rows received have the value customer_id 224

SELECT * FROM public.rental;
SELECT * FROM public.payment;

SELECT * -- no records
FROM public.rental
WHERE customer_id <> 224;

RESET ROLE;
/* So after setting the role to client_pearl_garza, the user can successfully access only her own records in the rental and payment tables.
 * Any attempt to retrieve records belonging to other customers returns zero rows due to row-level security policies. */