-- 0. View initial data
SELECT * FROM people ORDER BY name;

-- 1. Basic BMI Calculation Function
-- Functions are ideal for calculations and read-only operations
CREATE OR REPLACE FUNCTION calculate_bmi(
    weight_kg DECIMAL,
    height_cm DECIMAL
) RETURNS DECIMAL AS $$
BEGIN
    -- BMI = weight (kg) / (height (m))^2, rounded to 1 decimal
    RETURN ROUND(weight_kg / ((height_cm / 100) * (height_cm / 100)), 1);
END;
$$ LANGUAGE plpgsql;

-- Test the function
SELECT name, weight_kg, height_cm, calculate_bmi(weight_kg, height_cm) AS bmi
FROM people;

-- 1.1 Backfill BMI for all existing people
UPDATE people
SET bmi = calculate_bmi(weight_kg, height_cm);

-- 2. BMI Category Function
-- Functions can return complex types like tables
CREATE OR REPLACE FUNCTION get_bmi_category(bmi DECIMAL)
RETURNS VARCHAR AS $$
BEGIN
    RETURN CASE
        WHEN bmi < 18.5 THEN 'Underweight'
        WHEN bmi < 25 THEN 'Normal weight'
        WHEN bmi < 30 THEN 'Overweight'
        ELSE 'Obese'
    END;
END;
$$ LANGUAGE plpgsql;

-- Test the category function
SELECT 
    name,
    calculate_bmi(weight_kg, height_cm) AS bmi,
    get_bmi_category(calculate_bmi(weight_kg, height_cm)) AS category
FROM people;

-- 3. Trigger Function for Automatic BMI Updates
-- Triggers are perfect for maintaining derived data
CREATE OR REPLACE FUNCTION update_bmi()
RETURNS TRIGGER AS $$
BEGIN
    NEW.bmi := calculate_bmi(NEW.weight_kg, NEW.height_cm);
    NEW.updated_at := CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER update_bmi_trigger
BEFORE INSERT OR UPDATE OF weight_kg, height_cm
ON people
FOR EACH ROW
EXECUTE FUNCTION update_bmi();

-- 3.1 Demonstrate trigger with new character (Holly Flax)
INSERT INTO people (name, gender, birthday, height_cm, weight_kg) 
VALUES ('Holly Flax', 'female', '1975-08-15', 165.1, 57.0);

-- View the new character with automatically calculated BMI
SELECT * FROM people WHERE name = 'Holly Flax';

-- 3.2 Demonstrate trigger with weight update
UPDATE people 
SET weight_kg = 95.0
WHERE name = 'Stanley Hudson';

-- View Stanley's updated data with new BMI
SELECT * FROM people WHERE name = 'Stanley Hudson';

-- 4. Complex EDA Function
-- Functions can encapsulate complex queries for reuse
CREATE OR REPLACE FUNCTION analyze_bmi_data()
RETURNS TABLE (
    gender VARCHAR(10),
    age_bucket VARCHAR(10),
    avg_bmi DECIMAL(5,2),
    min_bmi DECIMAL(5,2),
    max_bmi DECIMAL(5,2),
    count INTEGER
) AS $$
BEGIN
    RETURN QUERY
    SELECT 
        p.gender,
        (CASE 
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 40 THEN 'Under 40'
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 50 THEN '40-49'
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 60 THEN '50-59'
            ELSE '60+'
        END)::VARCHAR(10) AS age_bucket,
        AVG(p.bmi)::DECIMAL(5,2) AS avg_bmi,
        MIN(p.bmi)::DECIMAL(5,2) AS min_bmi,
        MAX(p.bmi)::DECIMAL(5,2) AS max_bmi,
        COUNT(*)::INTEGER
    FROM people p
    GROUP BY 
        p.gender,
        CASE 
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 40 THEN 'Under 40'
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 50 THEN '40-49'
            WHEN EXTRACT(YEAR FROM AGE(p.birthday)) < 60 THEN '50-59'
            ELSE '60+'
        END
    ORDER BY gender, age_bucket;
END;
$$ LANGUAGE plpgsql;

-- Test the analysis function
SELECT * FROM analyze_bmi_data();

-- 5. Batch Update Procedure
-- Procedures are ideal for complex operations with transaction control
CREATE OR REPLACE PROCEDURE update_weights(
    min_weight DECIMAL,
    max_weight DECIMAL,
    increment DECIMAL
) AS $$
DECLARE
    person RECORD;
BEGIN
    FOR person IN SELECT id, weight_kg FROM people 
        WHERE weight_kg BETWEEN min_weight AND max_weight
    LOOP
        UPDATE people 
        SET weight_kg = weight_kg + increment
        WHERE id = person.id;
        
        -- Add a small delay to simulate a longer operation
        PERFORM pg_sleep(0.1);
    END LOOP;
    
    COMMIT;
END;
$$ LANGUAGE plpgsql;

-- Show people before batch update
SELECT * FROM people WHERE weight_kg BETWEEN 60 AND 80 ORDER BY name;

-- Test the procedure (increase weight by 2kg for people between 60 and 80kg)
CALL update_weights(60.0, 80.0, 2.0);

-- Show people after batch update
SELECT * FROM people WHERE weight_kg BETWEEN 60 AND 80 ORDER BY name;

-- 6. Cleanup (if needed)
DROP TRIGGER update_bmi_trigger ON people;
DROP FUNCTION update_bmi();
DROP FUNCTION calculate_bmi(DECIMAL, DECIMAL);
DROP FUNCTION get_bmi_category(DECIMAL);
DROP FUNCTION analyze_bmi_data();
DROP PROCEDURE update_weights(DECIMAL, DECIMAL, DECIMAL);
