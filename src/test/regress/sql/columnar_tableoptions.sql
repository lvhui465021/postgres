-- Table option coverage for built-in columnar tables.

CREATE SCHEMA columnar_tableoptions;
SET search_path TO columnar_tableoptions, public;
SET columnar.compression TO 'none';

CREATE TABLE table_options(a int) USING columnar;
INSERT INTO table_options SELECT generate_series(1, 100);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'table_options'::regclass;

SELECT columnar.alter_columnar_table_set('table_options', compression => 'pglz');
SELECT columnar.alter_columnar_table_set('table_options', compression_level => 5);
SELECT columnar.alter_columnar_table_set('table_options', chunk_group_row_limit => 2000);
SELECT columnar.alter_columnar_table_set('table_options', stripe_row_limit => 4000);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'table_options'::regclass;

VACUUM table_options;
VACUUM FULL table_options;
TRUNCATE table_options;
ALTER TABLE table_options ALTER COLUMN a TYPE bigint;

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'table_options'::regclass;

SET columnar.chunk_group_row_limit TO 1000;
SET columnar.stripe_row_limit TO 10000;
SET columnar.compression TO 'pglz';
SET columnar.compression_level TO 11;

SELECT columnar.alter_columnar_table_reset('table_options', chunk_group_row_limit => true);
SELECT columnar.alter_columnar_table_reset('table_options', stripe_row_limit => true);
SELECT columnar.alter_columnar_table_reset('table_options', compression => true);
SELECT columnar.alter_columnar_table_reset('table_options', compression_level => true);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'table_options'::regclass;

SET columnar.chunk_group_row_limit TO 10000;
SET columnar.stripe_row_limit TO 100000;
SET columnar.compression TO 'none';
SET columnar.compression_level TO 13;

SELECT columnar.alter_columnar_table_reset(
    'table_options',
    chunk_group_row_limit => true,
    stripe_row_limit => true,
    compression => true,
    compression_level => true);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'table_options'::regclass;

CREATE TABLE not_a_columnar_table(a int);
SELECT columnar.alter_columnar_table_set('not_a_columnar_table', compression => 'pglz');
SELECT columnar.alter_columnar_table_reset('not_a_columnar_table', compression => true);

SELECT columnar.alter_columnar_table_set('table_options', compression => 'foobar');
SELECT columnar.alter_columnar_table_set('table_options', compression_level => 0);
SELECT columnar.alter_columnar_table_set('table_options', compression_level => 20);
SELECT columnar.alter_columnar_table_set('table_options', stripe_row_limit => 999);
SELECT columnar.alter_columnar_table_set('table_options', stripe_row_limit => 100000001);
SELECT columnar.alter_columnar_table_set('table_options', chunk_group_row_limit => 999);
SELECT columnar.alter_columnar_table_set('table_options', chunk_group_row_limit => 100000001);
SELECT columnar.alter_columnar_table_set('table_options', chunk_group_row_limit => 0);

DROP TABLE table_options;

SELECT count(*) AS orphaned_options
FROM columnar.options o
WHERE o.regclass NOT IN (SELECT oid FROM pg_class);

RESET search_path;
DROP SCHEMA columnar_tableoptions CASCADE;
