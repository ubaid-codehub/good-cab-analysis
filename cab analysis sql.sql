
CREATE TABLE dim_city(
city_id VARCHAR(20) PRIMARY KEY,
city_name VARCHAR(20)
);

CREATE TABLE dim_date(
date DATE ,
start_of_month VARCHAR(20),
month_name VARCHAR(20),
day_type VARCHAR(20)
);


CREATE TABLE fact_passenger_summary (
    month DATE NOT NULL,
    city_id VARCHAR(20) REFERENCES dim_city(city_id),
    total_passengers INT NOT NULL,
    new_passengers INT NOT NULL,
    repeat_passengers INT NOT NULL,
    PRIMARY KEY (month, city_id)
);

CREATE TABLE dim_repeat_trip_distribution (
    month DATE NOT NULL,
    city_id VARCHAR(20) REFERENCES dim_city(city_id),
    trip_count INT NOT NULL,
    repeat_passenger_count INT NOT NULL
);

CREATE TABLE fact_trips (
    trip_id VARCHAR(30) PRIMARY KEY,
    date DATE,
    city_id VARCHAR(20) REFERENCES dim_city(city_id),
    passenger_type VARCHAR(10),
    distance_travelled_km FLOAT,
    fare_amount NUMERIC,
    passenger_rating INT,
    driver_rating INT
);

CREATE TABLE city_target_passenger_rating (
    city_id VARCHAR(20) PRIMARY KEY REFERENCES dim_city(city_id),
    target_avg_passenger_rating NUMERIC(3,2) CHECK (target_avg_passenger_rating BETWEEN 1 AND 10)
   
);
 
CREATE TABLE monthly_target_new_passengers (
    month DATE NOT NULL,
    city_id VARCHAR(20) REFERENCES dim_city(city_id),
    target_new_passengers INT NOT NULL
   
);


CREATE TABLE monthly_target_trips (
    month DATE NOT NULL,
    city_id VARCHAR(20) REFERENCES dim_city(city_id),
    total_target_trips INT NOT NULL
 
);

--ANALYSIS
--no.of trips
SELECT COUNT(trip_id) AS TOTAL_TRIPS,
 COUNT(*) FILTER (WHERE passenger_type = 'new') AS new_passenger,
 COUNT(*) FILTER (WHERE passenger_type = 'repeated') AS repeated_passenger
FROM fact_trips

--total fare(revenue)
SELECT SUM(fare_amount) AS TOTAL_REVENUE
FROM fact_trips;

--total ditsnce covered in all trips
SELECT SUM(distance_travelled_km) AS distance_travelled_km
FROM fact_trips;

--avg passenger's rating
SELECT ROUND(AVG(passenger_rating)) AS AVG_PASSENGER_RATING,
ROUND(AVG(driver_rating)) AS AVG_DRIVER_RATING
FROM fact_trips;

--avg fare per trip ,per km ,per distance
SELECT 
    dc.city_name,
    ROUND(AVG(f.fare_amount)::numeric, 2) AS avg_fare_per_trip,
    ROUND((SUM(f.fare_amount) / SUM(f.distance_travelled_km))::numeric, 2) AS avg_fare_per_km,
    ROUND((SUM(f.distance_travelled_km) / COUNT(f.trip_id))::numeric, 2) AS avg_trip_distance_km
FROM fact_trips f
JOIN dim_city dc 
    ON f.city_id = dc.city_id
GROUP BY dc.city_name
ORDER BY avg_fare_per_trip DESC;


--trip distance min,max
SELECT MAX(distance_travelled_km),MIN(distance_travelled_km)
FROM fact_trips;

--total passengers , new+repeat
SELECT SUM(total_passengers) AS TOTAL_PASSENGERS,
       SUM(new_passengers) AS NEW_PASSENGERS,
	   SUM(repeat_passengers) REPEAT_PASSENERS
FROM fact_passenger_summary;

--new vs repeated passengers ratio
SELECT 
    COUNT(*) FILTER (WHERE passenger_type = 'new')::decimal /
    NULLIF(COUNT(*) FILTER (WHERE passenger_type = 'repeated'), 0) 
    AS new_vs_repeated_ratio
FROM fact_trips;

--repeat passengers rate %
SELECT 
ROUND(SUM(repeat_passengers)::decimal / SUM(total_passengers) * 100 ,2)
FROM fact_passenger_summary;

--revenue growth rate (monthly)
WITH monthly_revenue AS (
    SELECT 
        DATE_TRUNC('month', date)::date AS month,
        SUM(fare_amount) AS total_revenue
    FROM fact_trips
    GROUP BY DATE_TRUNC('month',date)::date
    ORDER BY month
)
SELECT 
    month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
    ROUND(
        ((total_revenue - LAG(total_revenue) OVER (ORDER BY month))::decimal 
        / NULLIF(LAG(total_revenue) OVER (ORDER BY month), 0)) * 100,
        2
    ) AS revenue_growth_rate
FROM monthly_revenue;

--target achievemeants rate 
--a)trips target  
SELECT 
      TO_CHAR (date,'YY-MM') AS date,
      COUNT(f.trip_id) AS no_of_trips,
	  SUM(mt.total_target_trips) AS target_trips
FROM fact_trips f
JOIN monthly_target_trips mt ON f.date = mt.month
GROUP BY TO_CHAR (date,'YY-MM')
ORDER BY TO_CHAR (date,'YY-MM');

--b)new passenger target
SELECT 
    TO_CHAR(mtp.month, 'YYYY-MM') AS year_month,
    SUM(mt.total_passengers) AS total_passengers,
    SUM(mtp.target_new_passengers) AS target_new_passengers
FROM monthly_target_new_passengers mtp
JOIN fact_passenger_summary mt 
      ON mtp.month = mt.month
GROUP BY TO_CHAR(mtp.month, 'YYYY-MM')
ORDER BY year_month;


--c)avg passenger rating target
SELECT 
     dc.city_name,
     ROUND(AVG(f.passenger_rating),2) AS AVG_RATING,
	 ct.target_avg_passenger_rating
FROM fact_trips f
JOIN city_target_passenger_rating ct ON f.city_id = ct.city_id
JOIN dim_city dc ON ct.city_id = dc.city_id
GROUP BY dc.city_name,ct.target_avg_passenger_rating ;



