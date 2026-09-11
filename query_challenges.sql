-- CREATING VIEWS

-- View: Current salaries
CREATE OR REPLACE VIEW current_salaries AS
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    p.title AS position_title,
    p.department_id,
    dv.name AS division,
    eh.start_date,
    eh.end_date,
    CASE
        WHEN p.union_id IS NOT NULL THEN (
            SELECT MAX(pr.hourly_rate)
            FROM pay_rules pr
            WHERE pr.position_id = p.position_id
                AND pr.end_date IS NULL
                AND pr.min_years <= TIMESTAMPDIFF( -- years of continuous service in union
                    YEAR,
                    COALESCE( -- first day in the union block (continuous service)
                        (
                            SELECT MAX(eh2.end_date)
                            FROM employment_history eh2
                            JOIN positions p2 ON p2.position_id = eh2.position_id
                            WHERE eh2.employee_id = e.employee_id
                                AND (p2.union_id IS NULL OR p2.union_id != p.union_id) -- different or no union
                                AND eh2.end_date IS NOT NULL -- only past positions 
                        ),
                        (
                            SELECT MIN(eh2.start_date)
                            FROM employment_history eh2
                            JOIN positions p2 ON p2.position_id = p.position_id
                            WHERE eh2.employee_id = e.employee_id
                                AND p2.union_id = p.union_id -- same union
                        )
                    ),
                    CURRENT_DATE
                )
        )
        ELSE (
            SELECT MAX(pr.hourly_rate)
            FROM pay_rules pr
            WHERE pr.position_id = p.position_id
                AND pr.end_date IS NULL
                AND pr.min_years <= TIMESTAMPDIFF(YEAR, e.date_hired, CURRENT_DATE)
        )
    END AS hourly_pay
FROM employees e
JOIN employment_history eh ON eh.employee_id = e.employee_id AND eh.end_date IS NULL
JOIN positions p ON p.position_id = eh.position_id
LEFT JOIN divisions dv ON dv.division_id = p.division_id;


-- View: Historical salaries
CREATE OR REPLACE VIEW historical_salaries AS
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    p.title AS position_title,
    p.department_id,
    dv.name AS division,
    eh.start_date,
    eh.end_date,
    CASE
        WHEN p.union_id IS NOT NULL THEN(
            SELECT MAX(pr.hourly_rate)
            FROM pay_rules pr
            WHERE pr.position_id = p.position_id
                AND pr.start_date <= eh.end_date
                AND (pr.end_date IS NULL OR pr.end_date >= eh.end_date)
                AND pr.min_years <= TIMESTAMPDIFF( -- years of continuous service in union
                    YEAR,
                    COALESCE( -- first day in the union block (continuous service)
                        (
                            SELECT MAX(eh2.end_date)
                            FROM employment_history eh2
                            JOIN positions p2 ON p2.position_id = eh2.position_id
                            WHERE eh2.employee_id = e.employee_id
                                AND (p2.union_id IS NULL OR p2.union_id != p.union_id) -- different or no union
                                AND eh2.end_date < eh.end_date -- only former positions
                        ),
                        (
                            SELECT MIN(eh2.start_date)
                            FROM employment_history eh2
                            JOIN positions p2 ON p2.position_id = eh2.position_id
                            WHERE eh2.employee_id = e.employee_id
                                AND p2.union_id = p.union_id -- same union
                        )
                    ),
                    eh.end_date -- last day on the position
                )
        )
        ELSE (
            SELECT MAX(pr.hourly_rate)
            FROM pay_rules pr
            WHERE pr.position_id = p.position_id
                AND pr.start_date <= eh.end_date
                AND (pr.end_date IS NULL OR pr.end_date >= eh.end_date)
                AND pr.min_years <= TIMESTAMPDIFF(YEAR, e.date_hired, eh.end_date)
        )
    END AS hourly_pay
FROM employees e
JOIN employment_history eh ON eh.employee_id = e.employee_id AND eh.end_date IS NOT NULL
JOIN positions p ON p.position_id = eh.position_id
LEFT JOIN divisions dv ON dv.division_id = p.division_id;


-- View: All salaries
CREATE OR REPLACE VIEW all_salaries AS
SELECT *
FROM historical_salaries

UNION ALL

SELECT *
FROM current_salaries;

-- QUERY CHALLENGES

-- Q1: List all employees currently working in IT,
--     along with their division and job title.
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    p.title AS position_title,
    dv.`name` AS division
FROM employees e
JOIN employment_history eh
    ON eh.employee_id = e.employee_id
    AND eh.end_date IS NULL
JOIN positions p
    ON p.position_id = eh.position_id
    AND p.department_id = "ITOP"
LEFT JOIN divisions dv
    ON dv.division_id = p.division_id;

-- Q2: Show the complete organizational structure of Finance
--     list each position and to whom it reports (if any).
SELECT
    p_sub.title AS position_title,
    p_sup.title AS reports_to
FROM positions p_sub
LEFT JOIN reports_to rt
    ON rt.subordinate_position_id = p_sub.position_id
LEFT JOIN positions p_sup
    ON p_sup.position_id = rt.supervisor_position_id
WHERE p_sub.department_id = "FINA";

-- Q3: Among all employees who have never changed position,
--     who has worked the longest?
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    e.date_hired,
    TIMESTAMPDIFF(YEAR, e.date_hired, COALESCE(eh.end_date, CURRENT_DATE)) AS years_of_work
FROM employees e
JOIN employment_history eh
    ON eh.employee_id = e.employee_id
GROUP BY e.employee_id
HAVING COUNT(e.employee_id) = 1
ORDER BY date_hired ASC
LIMIT 1;

-- Q4: Calculate the current pay of "Sarah Johnson".
--     Make sure to factor in her years of service and
--     the pay rules of her current position.
SELECT
    employee_id,
    full_name,
    position_title,
    hourly_pay
FROM current_salaries
WHERE full_name = "Sarah Johnson";

-- Q5: Find all vacant positions
--     (positions with no one currently assigned to them).
SELECT
    p.title AS position_title,
    p.quantity AS total_slots,
    p.quantity - COUNT(eh.position_id) AS vacant_slots
FROM positions p
LEFT JOIN employment_history eh
    ON eh.position_id = p.position_id
    AND eh.end_date IS NULL
GROUP BY p.position_id
HAVING vacant_slots > 0;

-- Q6: List all employees who have been promoted at least twice
--     (changed job to one that supervised their previous one).
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name,
    COUNT(*) AS number_of_promotions
FROM employees e
JOIN employment_history eh_old
    ON eh_old.employee_id = e.employee_id
    AND eh_old.end_date IS NOT NULL
JOIN reports_to rt
    ON rt.subordinate_position_id = eh_old.position_id
JOIN employment_history eh_new
    ON eh_new.employee_id = e.employee_id
    AND eh_new.start_date > eh_old.start_date
    AND eh_new.position_id = rt.supervisor_position_id
    AND NOT EXISTS (
        SELECT 1
        FROM employment_history
        WHERE employee_id = e.employee_id
        AND start_date > eh_old.start_date
        AND end_date <= eh_new.start_date
    )
GROUP BY e.employee_id
HAVING number_of_promotions >= 2;

-- Q7: List all employees that report (directly or indirectly)
--     to "Inderjeet Singh", the current Director of IT.
WITH RECURSIVE subordinates AS (
    -- starts from the subordinates of Inderjeet's current position
    SELECT subordinate_position_id
    FROM reports_to
    WHERE supervisor_position_id = (
        SELECT eh.position_id
        FROM employment_history eh
        JOIN employees e
            ON e.employee_id = eh.employee_id
            AND eh.end_date IS NULL
            AND e.first_name = "Inderjeet"
            AND e.last_name = "Singh"
    )

    UNION ALL
    -- adds the subordinates of the direct Inderjeet's subordinates
    SELECT rt.subordinate_position_id
    FROM reports_to rt
    JOIN subordinates s
        ON rt.supervisor_position_id = s.subordinate_position_id
)
SELECT
    e.employee_id,
    CONCAT(e.first_name, ' ', e.last_name) AS full_name
FROM subordinates s
JOIN employment_history eh
    ON eh.position_id = s.subordinate_position_id
    AND eh.end_date IS NULL
JOIN employees e
    ON e.employee_id = eh.employee_id;

-- Q8: Inderjeet Singh has been promoted through several positions.
--     List all his previous positions and the pay he was receiving
--     on his last day in those positions.
SELECT
    employee_id,
    full_name,
    position_title,
    start_date,
    end_date,
    hourly_pay
FROM historical_salaries
WHERE full_name = "Inderjeet Singh";

-- Q9: Group the employees by their union (or lack thereof)
--     and list the results in descending order of count.
SELECT
    COALESCE(u.name, "No Union") AS `group`,
    COUNT(*) AS number_of_employees
FROM employment_history eh
JOIN positions p
    ON p.position_id = eh.position_id
LEFT JOIN unions u
    ON u.union_id = p.union_id
WHERE eh.end_date IS NULL
GROUP BY `group`
ORDER BY number_of_employees DESC;