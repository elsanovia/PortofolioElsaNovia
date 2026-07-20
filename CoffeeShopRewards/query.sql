----- MEMBUAT TABEL -----
-- Membuat tabel offers --
CREATE TABLE offers (
	offers_id VARCHAR(150) PRIMARY KEY,
	offer_type VARCHAR(50),
	difficulty INT,
	reward INT,
	duration INT,
	channels TEXT
);

-- Membuat tabel customer --
CREATE TABLE customer_coffee (
	customer_id VARCHAR(150) PRIMARY KEY,
	became_member_on INT,
	gender VARCHAR(10),
	age INT,
	income INT
);

-- Membuat tabel events
CREATE TABLE events (
	customer_id VARCHAR(150),
	event VARCHAR(100),
	value TEXT,
	time INT
);

SELECT *
FROM offers;

SELECT *
FROM customer_coffee;

SELECT *
FROM events;

UPDATE events 
SET value = REPLACE(value, '''', '"');

ALTER TABLE events 
ALTER COLUMN value TYPE JSONB USING value::jsonb;


----- MELAKUKAN JOIN TABEL -----
CREATE VIEW data_combined AS
SELECT 
    e.time,
    e.event,
    e.customer_id,
    c.gender,
    c.age,
    c.income,
    TO_DATE(CAST(c.became_member_on AS TEXT), 'YYYYMMDD') AS become_member,
    COALESCE(e.value->>'offer id', e.value->>'offer_id') AS offer_id, 
    CAST(e.value->>'amount' AS NUMERIC) AS pure_transaction,
    o.offer_type,
    o.difficulty,
    o.reward,
    o.duration
FROM events e
JOIN customer_coffee c ON e.customer_id = c.customer_id

LEFT JOIN offers o ON COALESCE(e.value->>'offer id', e.value->>'offer_id') = o.offers_id;

SELECT *
FROM data_combined;

----- MELAKUKAN CLEANING DATA -----
---- Duplikat Data ----
-- Mengecek duplikat data
SELECT 
	time,
	event,
	customer_id,
	offer_id,
COUNT(*) AS duplicate
FROM data_combined
GROUP BY 
	time,
	event,
	customer_id,
	offer_id
HAVING COUNT(*) > 1;

-- Menghapus view awal
DROP VIEW IF EXISTS data_combined CASCADE;

-- Menghapus duplikat data dengan view baru
CREATE VIEW data_combined AS
SELECT DISTINCT
    e.time,
    e.event,
    e.customer_id,
    c.gender,
    c.age,
    c.income,
    TO_DATE(CAST(c.became_member_on AS TEXT), 'YYYYMMDD') AS become_member,
    COALESCE(e.value->>'offer id', e.value->>'offer_id') AS offer_id, 
    CAST(e.value->>'amount' AS NUMERIC) AS pure_transaction,
    o.offer_type,
    o.difficulty,
    o.reward,
    o.duration
FROM events e
JOIN customer_coffee c ON e.customer_id = c.customer_id
LEFT JOIN offers o ON COALESCE(e.value->>'offer id', e.value->>'offer_id') = o.offers_id;

-- Melakukan sampel pengecekan pada salah satu ID
SELECT * FROM data_combined
WHERE customer_id = '436552d254074769ad35ed793c30953e' 
  AND time = 558;

SELECT *
FROM data_combined;

---- Missing Value & Outlier ----
SELECT *
FROM data_combined
WHERE gender IS NULL;

-- Menghapus view awal
DROP VIEW IF EXISTS data_combined CASCADE;

-- Mengganti data NULL gender menjadi unknown dan usia 118 menjadi NULL
CREATE VIEW data_combined AS
SELECT DISTINCT
    e.time,
    e.event,
    e.customer_id,
    COALESCE(c.gender, 'Unknown') AS gender,
    NULLIF(c.age, 118) AS age,
    c.income,
    TO_DATE(CAST(c.became_member_on AS TEXT), 'YYYYMMDD') AS become_member,
    COALESCE(e.value->>'offer id', e.value->>'offer_id') AS offer_id, 
    CAST(e.value->>'amount' AS NUMERIC) AS pure_transaction,
    o.offer_type,
    o.difficulty,
    o.reward,
    o.duration
FROM events e
JOIN customer_coffee c ON e.customer_id = c.customer_id
LEFT JOIN offers o ON COALESCE(e.value->>'offer id', e.value->>'offer_id') = o.offers_id;

SELECT *
FROM data_combined;

----- MELAKUKAN ANALISIS DATA -----
-- Mengetahui total penawaran berhadiah yang berhasil diselesaikan pelanggan
SELECT 
	offer_type,
	COUNT(*) AS total_completed
FROM data_combined
WHERE event = 'offer completed'
GROUP BY offer_type
ORDER BY total_completed DESC;
	
-- Mengidentifikasi jenis promo yang memiliki tingkat keberhasilan (completion rate) paling tinggi
SELECT
	offer_type,	
	COUNT(CASE WHEN event = 'offer completed' THEN 1 END) AS total_goal,
	COUNT(CASE WHEN event = 'offer received' THEN 1 END) AS total_activated,
ROUND(100.0 * COUNT(CASE WHEN event = 'offer completed' THEN 1 END) / NULLIF(COUNT(CASE WHEN event = 'offer received' THEN 1 END), 0), 2) AS completion_rate
FROM data_combined
WHERE offer_type IS NOT NULL 
GROUP BY offer_type
ORDER BY completion_rate DESC;

-- Mengukur efektivitas informasi dengan mengetahui seberapa banyak transaksi yang terjadi pasca pelanggan melihat informasi
SELECT 
	COUNT(DISTINCT t. customer_id) AS total_customer_information,
	COUNT(t.  customer_id) AS total_transaction_information
FROM data_combined v
JOIN data_combined t ON v. customer_id = t. customer_id 
WHERE v.offer_type = 'informational' 
  AND v.event = 'offer viewed'
  AND t.event = 'transaction'
  AND t.time >= v.time 
  AND t.time <= v.time + 1;

-- Menganalisis distribusi demografi pelanggan loyal, meliputi rentang usia, tingkat pendapatan, dan jenis kelamin
WITH customer_segmen AS (
SELECT 
--- Membuat rentang usia
CASE 
	WHEN age < 29 THEN 'Gen Z (<29 tahun)'
    WHEN age >= 29  AND age <= 40 THEN 'Gen Millenial (29-40)'
    WHEN age >= 41 AND age <= 56 THEN 'Gen X (41-56)'
    ELSE 'Gen Boomer (> 56)'
END AS age_distribution,
    
--- Membuat kategori tingkat pendapatan
CASE 
    WHEN income < 30000 THEN 'Lower Class'
    WHEN income >= 30000 AND income <= 58020 THEN 'Lower Middle'
    WHEN income >= 58021 AND income <= 94000 THEN 'Upper Middle'
	ELSE 'Upper Class'
END AS income_level,
    
-- Mengetahui distribusi jenis kelamin
COUNT(DISTINCT customer_id) AS total_customer
FROM data_combined
WHERE 
  age IS NOT NULL
  AND event IN ('offer completed', 'transaction')
GROUP BY 
	age_distribution,
	income_level
)

--- Menghitung Pareto
SELECT 
    age_distribution,
    income_level,
    total_customer,
    ROUND(total_customer * 100.0 / SUM(total_customer) OVER(), 2) AS percentage,
    ROUND(SUM(total_customer) OVER(ORDER BY total_customer DESC) * 100.0 / SUM(total_customer) OVER(), 2) AS cumulative_percentage
FROM customer_segmen
ORDER BY total_customer DESC;

-- Mengidentifikasi korelasi demografi dengan keberhasilan promo
SELECT 
	offer_type,
--- Membuat rentang usia
CASE 
	WHEN age < 29 THEN 'Gen Z (<29 tahun)'
    WHEN age >= 29  AND age <= 40 THEN 'Gen Millenial (29-40)'
    WHEN age >= 41 AND age <= 56 THEN 'Gen X (41-56)'
    ELSE 'Gen Boomer (> 56)'
END AS age_distribution,
    
--- Membuat kategori tingkat pendapatan
CASE 
    WHEN income < 30000 THEN 'Lower Class'
    WHEN income >= 30000 AND income <= 58020 THEN 'Lower Middle'
    WHEN income >= 58021 AND income <= 94000 THEN 'Upper Middle'
	ELSE 'Upper Class'
END AS income_level,

COUNT(DISTINCT customer_id) AS successfully_customer
FROM data_combined
WHERE
	age IS NOT NULL
	AND event = 'offer completed' 
GROUP BY 
	offer_type,
	age_distribution,
	income_level
ORDER BY successfully_customer DESC;



	
	





