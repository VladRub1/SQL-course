CREATE OR REPLACE FUNCTION get_employee_subordinates()
RETURNS TABLE(
    boss_name VARCHAR,
    subordinate_names TEXT[],
    job_titles TEXT[],
    salary NUMERIC
) AS $$
DECLARE
    -- Cursor declaration
    cur CURSOR FOR 
        SELECT p.emp_name AS boss_name,
               array_agg(s.emp_name) AS subordinate_names,
               array_agg(o.job_title) AS job_titles,
               sum(o.salary) AS total_salary
        FROM Org_chart o
        LEFT JOIN Personnel p ON o.boss_emp_nbr = p.emp_nbr
        JOIN Personnel s ON o.emp_nbr = s.emp_nbr
        GROUP BY p.emp_name;

    -- Variables for each column
    v_boss_name VARCHAR;
    v_subordinate_names TEXT[];
    v_job_titles TEXT[];
    v_salary NUMERIC;
BEGIN
    -- Open the cursor
    OPEN cur;

    -- Loop through the cursor
    LOOP
        -- Fetch a row from the cursor into the variables
        FETCH cur INTO v_boss_name, v_subordinate_names, v_job_titles, v_salary;
        -- Exit when no more row to fetch
        EXIT WHEN NOT FOUND;

        -- Assign the fetched row to the return table
        boss_name := v_boss_name;
        subordinate_names := v_subordinate_names;
        job_titles := v_job_titles;
        salary := v_salary;

        -- Return the row
        RETURN NEXT;
    END LOOP;

    -- Close the cursor
    CLOSE cur;

    -- End of function
    RETURN;
END;
$$ LANGUAGE plpgsql;
