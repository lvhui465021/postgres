-- Column cache coverage for built-in columnar tables.

CREATE SCHEMA columnar_cache;
SET search_path TO columnar_cache, public;
SET columnar.compression TO 'none';
SET columnar.enable_column_cache TO 'off';

CREATE TABLE cache_source (
    id int,
    firstname text,
    lastname text
) USING columnar;

SELECT columnar.alter_columnar_table_set(
    'cache_source',
    chunk_group_row_limit => 1000,
    stripe_row_limit => 5000);

INSERT INTO cache_source
SELECT i, 'firstname-' || i, 'lastname-' || i
FROM generate_series(1, 20000) i;

CREATE TEMP TABLE cache_baseline AS
SELECT firstname, lastname, sum(id)::bigint AS sum_id
FROM cache_source
WHERE id < 1000 OR id BETWEEN 15000 AND 16000
GROUP BY firstname, lastname;

SET columnar.enable_column_cache TO 'on';

SELECT count(*) = 0 AS cached_matches_uncached
FROM (
    (SELECT firstname, lastname, sum(id)::bigint AS sum_id
     FROM cache_source
     WHERE id < 1000 OR id BETWEEN 15000 AND 16000
     GROUP BY firstname, lastname)
    EXCEPT ALL
    SELECT * FROM cache_baseline
    UNION ALL
    SELECT * FROM cache_baseline
    EXCEPT ALL
    (SELECT firstname, lastname, sum(id)::bigint AS sum_id
     FROM cache_source
     WHERE id < 1000 OR id BETWEEN 15000 AND 16000
     GROUP BY firstname, lastname)
) diff;

SELECT count(*) AS cached_group_count, sum(sum_id) AS cached_group_sum
FROM (
    SELECT firstname, lastname, sum(id)::bigint AS sum_id
    FROM cache_source
    WHERE id < 1000 OR id BETWEEN 15000 AND 16000
    GROUP BY firstname, lastname
) s;

SET columnar.enable_column_cache TO 'off';

CREATE TABLE cache_dml_off (
    value int,
    updated_value int
) USING columnar;

INSERT INTO cache_dml_off(value)
SELECT generate_series(1, 10000);

BEGIN;
SELECT sum(value) FROM cache_dml_off;
UPDATE cache_dml_off SET updated_value = value * 2;
SELECT sum(updated_value) FROM cache_dml_off;
DELETE FROM cache_dml_off WHERE value % 2 = 0;
SELECT count(*), sum(value) FROM cache_dml_off;
COMMIT;

SET columnar.enable_column_cache TO 'on';

CREATE TABLE cache_dml_on (
    value int,
    updated_value int
) USING columnar;

INSERT INTO cache_dml_on(value)
SELECT generate_series(1, 10000);

BEGIN;
SELECT sum(value) FROM cache_dml_on;
UPDATE cache_dml_on SET updated_value = value * 2;
SELECT sum(updated_value) FROM cache_dml_on;
DELETE FROM cache_dml_on WHERE value % 2 = 0;
SELECT count(*), sum(value) FROM cache_dml_on;
COMMIT;

RESET columnar.enable_column_cache;
RESET search_path;
DROP SCHEMA columnar_cache CASCADE;
