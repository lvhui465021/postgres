-- Materialized view coverage for built-in columnar tables.

CREATE SCHEMA columnar_matview;
SET search_path TO columnar_matview, public;
SET columnar.compression TO 'none';

CREATE TABLE matview_source(a int, b int) USING columnar;

INSERT INTO matview_source
SELECT floor(i / 4), 2 * i
FROM generate_series(1, 10) i;

CREATE MATERIALIZED VIEW matview_columnar(a, bsum, cnt) USING columnar AS
SELECT a, sum(b), count(*)
FROM matview_source
GROUP BY a;

SELECT * FROM matview_columnar ORDER BY a;

INSERT INTO matview_source
SELECT floor(i / 4), 2 * i
FROM generate_series(11, 20) i;

SELECT * FROM matview_columnar ORDER BY a;

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'matview_columnar'::regclass;

SELECT columnar.alter_columnar_table_set('matview_columnar', compression => 'pglz');

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'matview_columnar'::regclass;

REFRESH MATERIALIZED VIEW matview_columnar;

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'matview_columnar'::regclass;

SELECT * FROM matview_columnar ORDER BY a;

SELECT storage_id AS matview_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT count(*) AS stripe_count
FROM columnar.stripe
WHERE storage_id = :matview_storage_id;

SELECT count(*) > 0 AS has_chunk_metadata
FROM columnar.chunk
WHERE storage_id = :matview_storage_id;

DROP TABLE matview_source CASCADE;

SELECT count(*) AS stripes_after_drop
FROM columnar.stripe
WHERE storage_id = :matview_storage_id;

SELECT count(*) AS chunks_after_drop
FROM columnar.chunk
WHERE storage_id = :matview_storage_id;

RESET search_path;
DROP SCHEMA columnar_matview;
