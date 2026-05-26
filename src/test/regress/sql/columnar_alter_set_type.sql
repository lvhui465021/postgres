-- ALTER COLUMN TYPE rewrite coverage for built-in columnar tables.

CREATE SCHEMA columnar_alter_set_type;
SET search_path TO columnar_alter_set_type, public;
SET columnar.compression TO 'none';

CREATE TABLE alter_type_test(a int, b int, c text) USING columnar;

INSERT INTO alter_type_test VALUES
    (1, 2, '3'),
    (4, 5, '6'),
    (5, 9, '11'),
    (12, 83, '93');

ALTER TABLE alter_type_test
ALTER COLUMN a TYPE jsonb USING row_to_json(row(a));

SELECT * FROM alter_type_test ORDER BY a;

ALTER TABLE alter_type_test
ALTER COLUMN c TYPE int USING c::int;

SELECT sum(c) FROM alter_type_test;

ALTER TABLE alter_type_test
ALTER COLUMN b TYPE bigint;

SELECT * FROM alter_type_test ORDER BY a;

ALTER TABLE alter_type_test
ALTER COLUMN b TYPE float4 USING (b::float4 + 0.5);

SELECT * FROM alter_type_test ORDER BY a;

CREATE TABLE rewrite_options(i int) USING columnar;
SELECT columnar.alter_columnar_table_set(
    'rewrite_options',
    compression => 'pglz',
    compression_level => 5,
    stripe_row_limit => 20000,
    chunk_group_row_limit => 2000);

INSERT INTO rewrite_options VALUES (1), (2), (3);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'rewrite_options'::regclass;

ALTER TABLE rewrite_options ALTER COLUMN i TYPE bigint;

SELECT count(*), sum(i) FROM rewrite_options;

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'rewrite_options'::regclass;

RESET search_path;
DROP SCHEMA columnar_alter_set_type CASCADE;
