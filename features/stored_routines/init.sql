-- Create the people table
CREATE TABLE people (
    id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    gender VARCHAR(10) NOT NULL,
    birthday DATE NOT NULL,
    height_cm DECIMAL(5,2) NOT NULL,
    weight_kg DECIMAL(5,2) NOT NULL,
    bmi DECIMAL(5,2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
);

-- Create an index on gender for better query performance
CREATE INDEX idx_people_gender ON people(gender);

-- Insert sample data with The Office characters
INSERT INTO people (name, gender, birthday, height_cm, weight_kg) VALUES
    ('Jim Halpert', 'male', '1978-10-01', 190.5, 82.0),
    ('Kevin Malone', 'male', '1968-06-01', 193.0, 120.0),
    ('Darryl Philbin', 'male', '1973-01-20', 185.4, 95.0),
    ('Michael Scott', 'male', '1965-03-15', 180.3, 85.0),
    ('Dwight Schrute', 'male', '1968-01-20', 175.3, 75.0),
    ('Stanley Hudson', 'male', '1958-02-19', 177.8, 105.0),
    ('Andy Bernard', 'male', '1973-12-22', 182.9, 80.0),
    ('Pam Beesly', 'female', '1979-03-25', 162.6, 55.0),
    ('Angela Martin', 'female', '1974-11-11', 152.4, 45.0),
    ('Phyllis Vance', 'female', '1951-06-10', 165.1, 105.0),
    ('Kelly Kapoor', 'female', '1980-05-22', 157.5, 52.0),
    ('Creed Bratton', 'male', '1943-02-08', 175.3, 70.0),
    ('Toby Flenderson', 'male', '1966-06-02', 177.8, 75.0),
    ('Meredith Palmer', 'female', '1960-04-12', 165.1, 70.0),
    ('Oscar Martinez', 'male', '1972-11-15', 172.7, 70.0),
    ('Ryan Howard', 'male', '1979-05-05', 180.3, 75.0);
