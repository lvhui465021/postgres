-- Empty table coverage for built-in columnar tables.

CREATE SCHEMA columnar_empty;
SET search_path TO columnar_empty, public;
SET columnar.compression TO 'none';

CREATE TABLE empty_uncompressed(a int) USING columnar;
CREATE TABLE empty_compressed(a int) USING columnar;

SELECT columnar.alter_columnar_table_set('empty_compressed', compression => 'pglz');
SELECT columnar.alter_columnar_table_set('empty_compressed', stripe_row_limit => 2000);
SELECT columnar.alter_columnar_table_set('empty_compressed', chunk_group_row_limit => 1000);

SELECT compression, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'empty_compressed'::regclass;

SELECT * FROM empty_uncompressed;
SELECT count(*) FROM empty_uncompressed;
SELECT * FROM empty_compressed;
SELECT count(*) FROM empty_compressed;

EXPLAIN (COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM empty_uncompressed;

EXPLAIN (COSTS OFF, SUMMARY OFF, TIMING OFF)
SELECT * FROM empty_compressed;

VACUUM empty_uncompressed;
VACUUM empty_compressed;

VACUUM FULL empty_uncompressed;
VACUUM FULL empty_compressed;

ANALYZE empty_uncompressed;
ANALYZE empty_compressed;

TRUNCATE empty_uncompressed;
TRUNCATE empty_compressed;

ALTER TABLE empty_uncompressed ALTER COLUMN a TYPE text;
ALTER TABLE empty_compressed ALTER COLUMN a TYPE text;

EXPLAIN TABLE empty_uncompressed;
EXPLAIN TABLE empty_compressed;

DROP TABLE empty_uncompressed;
DROP TABLE empty_compressed;

SELECT count(*) AS orphaned_options
FROM columnar.options o
WHERE o.regclass NOT IN (SELECT oid FROM pg_class);

RESET search_path;
DROP SCHEMA columnar_empty;
