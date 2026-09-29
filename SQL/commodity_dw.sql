CREATE DATABASE IF NOT EXISTS commodity_price_dw;
USE commodity_price_dw;
CREATE TABLE staging_commodity (
    state VARCHAR(100),
    district VARCHAR(100),
    market VARCHAR(150),
    commodity VARCHAR(150),
    variety VARCHAR(150),
    grade VARCHAR(100),
    arrival_date DATE,
    min_price DECIMAL(12,2),
    max_price DECIMAL(12,2),
    modal_price DECIMAL(12,2),
    price_spread DECIMAL(12,2),
    price_spread_pct DECIMAL(12,2),
    year INT,
    month INT,
    day INT
);
-- Create the dimension tables
-- Date dimension
CREATE TABLE dim_date (
    date_key INT PRIMARY KEY,
    full_date DATE,
    year INT,
    month INT,
    day INT
);
-- Location dimension
CREATE TABLE dim_location (
    location_key INT AUTO_INCREMENT PRIMARY KEY,
    state VARCHAR(100),
    district VARCHAR(100),
    market VARCHAR(150)
);
-- Commodity dimension
CREATE TABLE dim_commodity (
    commodity_key INT AUTO_INCREMENT PRIMARY KEY,
    commodity VARCHAR(150)
);
-- Variety dimension
CREATE TABLE dim_variety (
    variety_key INT AUTO_INCREMENT PRIMARY KEY,
    variety VARCHAR(150)
);
-- Grade dimension
CREATE TABLE dim_grade (
    grade_key INT AUTO_INCREMENT PRIMARY KEY,
    grade VARCHAR(100)
);
-- Create the fact table
CREATE TABLE fact_market_price (
    price_id INT AUTO_INCREMENT PRIMARY KEY,

    date_key INT,
    location_key INT,
    commodity_key INT,
    variety_key INT,
    grade_key INT,

    min_price DECIMAL(12,2),
    max_price DECIMAL(12,2),
    modal_price DECIMAL(12,2),
    price_spread DECIMAL(12,2),
    price_spread_pct DECIMAL(12,2),

    FOREIGN KEY (date_key)
        REFERENCES dim_date(date_key),

    FOREIGN KEY (location_key)
        REFERENCES dim_location(location_key),

    FOREIGN KEY (commodity_key)
        REFERENCES dim_commodity(commodity_key),

    FOREIGN KEY (variety_key)
        REFERENCES dim_variety(variety_key),

    FOREIGN KEY (grade_key)
        REFERENCES dim_grade(grade_key)
);
-- Populate dim_location

INSERT INTO dim_location (state, district, market)
SELECT DISTINCT
    state,
    district,
    market
FROM staging_commodity;
SELECT COUNT(*) FROM dim_location;
SELECT * FROM dim_location
LIMIT 10;

-- Populate dim_commodity
INSERT INTO dim_commodity (commodity)
SELECT DISTINCT
    commodity
FROM staging_commodity;

SELECT COUNT(*) FROM dim_commodity;
SELECT * FROM dim_commodity;

-- Populate dim_variety
INSERT INTO dim_variety (variety)
SELECT DISTINCT
    variety
FROM staging_commodity;

SELECT COUNT(*) FROM dim_variety;

-- Populate dim_grade

INSERT INTO dim_grade (grade)
SELECT DISTINCT
    grade
FROM staging_commodity;

SELECT COUNT(*) FROM dim_grade;

-- Populate dim_date
INSERT INTO dim_date (
    date_key,
    full_date,
    year,
    month,
    day
)
SELECT DISTINCT
    YEAR(arrival_date) * 10000
        + MONTH(arrival_date) * 100
        + DAY(arrival_date),
    arrival_date,
    YEAR(arrival_date),
    MONTH(arrival_date),
    DAY(arrival_date)
FROM staging_commodity;

SELECT * FROM dim_date;

-- populate the FACT table
INSERT INTO fact_market_price (
    date_key,
    location_key,
    commodity_key,
    variety_key,
    grade_key,
    min_price,
    max_price,
    modal_price,
    price_spread,
    price_spread_pct
)
SELECT
    d.date_key,
    l.location_key,
    c.commodity_key,
    v.variety_key,
    g.grade_key,
    s.min_price,
    s.max_price,
    s.modal_price,
    s.price_spread,
    s.price_spread_pct
FROM staging_commodity s

JOIN dim_date d
    ON d.full_date = s.arrival_date

JOIN dim_location l
    ON l.state = s.state
    AND l.district = s.district
    AND l.market = s.market

JOIN dim_commodity c
    ON c.commodity = s.commodity

JOIN dim_variety v
    ON v.variety = s.variety

JOIN dim_grade g
    ON g.grade = s.grade;

-- Verify the fact table
SELECT COUNT(*)
FROM fact_market_price;

SELECT *
FROM fact_market_price
LIMIT 10;

-- Check that the fact table has data
SELECT COUNT(*) AS total_records
FROM fact_market_price;

-- average modal price by commodity : 
-- Which commodities have the highest average market price?
SELECT
    c.commodity,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price
FROM fact_market_price f
JOIN dim_commodity c
    ON f.commodity_key = c.commodity_key
GROUP BY c.commodity
ORDER BY avg_modal_price DESC;

-- Compare markets:
-- Which markets have the highest average modal price?
SELECT
    l.market,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price
FROM fact_market_price f
JOIN dim_location l
    ON f.location_key = l.location_key
GROUP BY l.market
ORDER BY avg_modal_price DESC;

--  Find commodities with the highest price spread
-- For which commodities is the gap between the minimum and 
-- maximum market price the largest?
SELECT
    c.commodity,
    ROUND(AVG(f.price_spread), 2) AS avg_price_spread
FROM fact_market_price f
JOIN dim_commodity c
    ON f.commodity_key = c.commodity_key
GROUP BY c.commodity
ORDER BY avg_price_spread DESC;

-- State-wise price analysis 
-- Which states have the highest average commodity modal prices?
SELECT
    l.state,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price
FROM fact_market_price f
JOIN dim_location l
    ON f.location_key = l.location_key
GROUP BY l.state
ORDER BY avg_modal_price DESC;

-- Compare Min, Max and Modal Price
-- How do minimum, maximum, and modal prices compare across 
-- commodities?
-- understanding the overall price range and typical market 
-- price for each commodity.
SELECT
    c.commodity,
    ROUND(AVG(f.min_price), 2) AS avg_min_price,
    ROUND(AVG(f.max_price), 2) AS avg_max_price,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price
FROM fact_market_price f
JOIN dim_commodity c
    ON f.commodity_key = c.commodity_key
GROUP BY c.commodity
ORDER BY avg_modal_price DESC

-- Average price by variety
-- Which commodity varieties have the highest average 
-- modal prices?
SELECT
    v.variety,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price
FROM fact_market_price f
JOIN dim_variety v
    ON f.variety_key = v.variety_key
GROUP BY v.variety
ORDER BY avg_modal_price DESC;

-- Average price by grade
-- How do different grades compare in terms of average 
-- price and price variation?

SELECT
    g.grade,
    COUNT(*) AS number_of_records,
    ROUND(AVG(f.modal_price), 2) AS avg_modal_price,
    ROUND(AVG(f.price_spread), 2) AS avg_price_spread
FROM fact_market_price f
JOIN dim_grade g
    ON f.grade_key = g.grade_key
GROUP BY g.grade
ORDER BY avg_modal_price DESC;