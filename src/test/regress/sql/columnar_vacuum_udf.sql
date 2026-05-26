-- columnar.vacuum() coverage for built-in columnar tables.

CREATE SCHEMA columnar_vacuum_udf;
SET search_path TO columnar_vacuum_udf, public;
SET columnar.compression TO 'none';
SET columnar.chunk_group_row_limit TO 1000;
SET columnar.stripe_row_limit TO 4000;

CREATE TABLE vacuum_target(a int, b int) USING columnar;
INSERT INTO vacuum_target
SELECT i, i * 2
FROM generate_series(1, 10000) i;

SELECT count(*) AS stats_before_delete,
       sum(rowcount) AS rows_before_delete,
       sum(deletedrows) AS deleted_before_delete
FROM columnar.stats('vacuum_target'::regclass);

SELECT columnar.vacuum('vacuum_target'::regclass) AS vacuum_without_deletes;

DELETE FROM vacuum_target WHERE a % 2 = 0;

SELECT count(*), sum(a), sum(b) FROM vacuum_target;

SELECT sum(deletedrows) AS deleted_before_vacuum
FROM columnar.stats('vacuum_target'::regclass);

SELECT columnar.vacuum('vacuum_target'::regclass) AS vacuum_after_deletes;

SELECT count(*), sum(a), sum(b) FROM vacuum_target;

SELECT count(*) AS stats_after_vacuum,
       sum(rowcount) AS rows_after_vacuum,
       sum(deletedrows) AS deleted_after_vacuum
FROM columnar.stats('vacuum_target'::regclass);

INSERT INTO vacuum_target
SELECT i, i * 2
FROM generate_series(10001, 12000) i;

DELETE FROM vacuum_target WHERE a BETWEEN 11000 AND 12000;

SELECT columnar.vacuum('vacuum_target'::regclass, 1) AS vacuum_one_stripe;

SELECT count(*), sum(a), sum(b) FROM vacuum_target;

CREATE TABLE cache_test(i int) USING columnar;
INSERT INTO cache_test SELECT generate_series(1, 100);

SET columnar.enable_column_cache TO 'on';
VACUUM cache_test;
SHOW columnar.enable_column_cache;
ANALYZE cache_test;
SHOW columnar.enable_column_cache;

RESET columnar.enable_column_cache;
RESET columnar.stripe_row_limit;
RESET columnar.chunk_group_row_limit;
RESET search_path;
DROP SCHEMA columnar_vacuum_udf CASCADE;
