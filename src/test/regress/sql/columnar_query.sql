-- Query coverage for built-in columnar tables.

CREATE SCHEMA columnar_query;
SET search_path TO columnar_query, public;
SET columnar.compression TO 'none';
SET datestyle TO 'ISO, YMD';

CREATE TABLE contestant(
    handle text,
    birthdate date,
    rating int,
    percentile float8,
    country char(3),
    achievements text[]
) USING columnar;

INSERT INTO contestant VALUES
    ('ada', '1990-01-01', 2500, 99.1, 'USA', ARRAY['gold', 'rapid']),
    ('bert', '1991-02-02', 2100, 75.5, 'CAN', ARRAY['open']),
    ('chen', '1992-03-03', 2300, 88.0, 'CHN', ARRAY['classic']),
    ('dina', '1993-04-04', 2600, 99.5, 'USA', ARRAY['gold']);

SELECT count(*) FROM contestant;
SELECT round(avg(rating), 2), round(stddev_samp(rating), 2) FROM contestant;

SELECT country, round(avg(rating), 2) AS avg_rating
FROM contestant
WHERE rating > 2200
GROUP BY country
ORDER BY country;

SELECT handle, birthdate, rating, percentile, country, achievements
FROM contestant
ORDER BY handle;

SELECT ctid FROM contestant;
SELECT cmin FROM contestant;
SELECT cmax FROM contestant;
SELECT xmin FROM contestant;
SELECT xmax FROM contestant;
SELECT tableoid::regclass FROM contestant;

SELECT * FROM contestant TABLESAMPLE SYSTEM (0.1);

SELECT to_json(v) FROM contestant v ORDER BY rating LIMIT 1;

CREATE TABLE union_first(a int, b int) USING columnar;
CREATE TABLE union_second(a int, b int) USING columnar;

INSERT INTO union_first SELECT a, a FROM generate_series(1, 5) a;
INSERT INTO union_second SELECT a, a FROM generate_series(11, 15) a;

(SELECT a * 1 AS a, b FROM union_first)
UNION ALL
(SELECT a * 1 AS a, b FROM union_second)
ORDER BY a;

CREATE TABLE lateral_columnar(q1 int8, q2 int8) USING columnar;

INSERT INTO lateral_columnar VALUES
    (123, 456),
    (123, 4567890123456789),
    (4567890123456789, 123),
    (4567890123456789, 4567890123456789),
    (4567890123456789, -4567890123456789);

CREATE TABLE lateral_heap (LIKE lateral_columnar) USING heap;
INSERT INTO lateral_heap SELECT * FROM lateral_columnar;

CREATE TABLE lateral_result_columnar AS
SELECT *
FROM lateral_columnar a
LEFT JOIN LATERAL (
    SELECT b.q1 AS bq1, c.q1 AS cq1, least(a.q1, b.q1, c.q1) AS least_q1
    FROM lateral_columnar b
    CROSS JOIN lateral_columnar c
) ss ON a.q2 = ss.bq1;

CREATE TABLE lateral_result_heap AS
SELECT *
FROM lateral_heap a
LEFT JOIN LATERAL (
    SELECT b.q1 AS bq1, c.q1 AS cq1, least(a.q1, b.q1, c.q1) AS least_q1
    FROM lateral_heap b
    CROSS JOIN lateral_heap c
) ss ON a.q2 = ss.bq1;

(TABLE lateral_result_columnar EXCEPT TABLE lateral_result_heap)
UNION ALL
(TABLE lateral_result_heap EXCEPT TABLE lateral_result_columnar);

SET default_table_access_method TO columnar;
CREATE TABLE default_columnar_query(a int, b text);
INSERT INTO default_columnar_query VALUES (1, 'one');
INSERT INTO default_columnar_query SELECT 2, b FROM default_columnar_query;
SELECT * FROM default_columnar_query ORDER BY a, b;
RESET default_table_access_method;

RESET datestyle;
RESET search_path;
DROP SCHEMA columnar_query CASCADE;
