-- Broader DDL and utility coverage for the built-in columnar table AM.

CREATE SCHEMA columnar_ops;
SET search_path TO columnar_ops, public;
SET columnar.compression TO 'none';

CREATE TABLE option_test(a int) USING columnar;
INSERT INTO option_test SELECT generate_series(1, 20);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'option_test'::regclass;

SELECT columnar.alter_columnar_table_set('option_test',
    compression => 'pglz',
    compression_level => 5,
    stripe_row_limit => 2000,
    chunk_group_row_limit => 1000);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'option_test'::regclass;

VACUUM option_test;
VACUUM FULL option_test;

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'option_test'::regclass;

TRUNCATE option_test;
INSERT INTO option_test VALUES (11), (12), (13);

SELECT count(*), sum(a) FROM option_test;

SELECT columnar.alter_columnar_table_reset('option_test',
    compression => true,
    compression_level => true,
    stripe_row_limit => true,
    chunk_group_row_limit => true);

SELECT compression, compression_level, stripe_row_limit, chunk_group_row_limit
FROM columnar.options
WHERE regclass = 'option_test'::regclass;

CREATE TABLE tx_test(a int, b int) USING columnar;
INSERT INTO tx_test VALUES (1, 2), (2, 4), (3, 6);

BEGIN;
ALTER TABLE tx_test ALTER COLUMN b TYPE float4 USING (b + 0.5)::float4;
INSERT INTO tx_test VALUES (4, 8.5);
SELECT a, b::numeric(10,1) FROM tx_test ORDER BY a;
ROLLBACK;

SELECT * FROM tx_test ORDER BY a;

BEGIN;
TRUNCATE tx_test;
INSERT INTO tx_test VALUES (4, 8);
SAVEPOINT s1;
TRUNCATE tx_test;
SELECT count(*) FROM tx_test;
ROLLBACK TO SAVEPOINT s1;
SELECT * FROM tx_test ORDER BY a;
ROLLBACK;

SELECT * FROM tx_test ORDER BY a;

CREATE INDEX tx_test_a_idx ON tx_test(a);
ANALYZE tx_test;
SET enable_seqscan TO off;
SELECT * FROM tx_test WHERE a = 2;
RESET enable_seqscan;

CREATE TABLE part_parent(a int, b text) PARTITION BY RANGE (a);
SET default_table_access_method TO columnar;
CREATE TABLE part_parent_1 PARTITION OF part_parent FOR VALUES FROM (0) TO (10);
CREATE TABLE part_parent_2 PARTITION OF part_parent FOR VALUES FROM (10) TO (20);
RESET default_table_access_method;

INSERT INTO part_parent VALUES (1, 'one'), (9, 'nine'), (10, 'ten'), (19, 'nineteen');

SELECT c.relname, am.amname
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.relname LIKE 'part_parent_%'
ORDER BY c.relname;

SELECT tableoid::regclass::text AS partition_name, count(*), string_agg(b, ',' ORDER BY a)
FROM part_parent
GROUP BY tableoid
ORDER BY partition_name;

CREATE TABLE inherit_parent(i int) USING columnar;
CREATE TABLE inherit_child(j int) INHERITS (inherit_parent) USING columnar;
INSERT INTO inherit_parent VALUES (1);
INSERT INTO inherit_child VALUES (2, 20);

SELECT tableoid::regclass::text AS relname, * FROM inherit_parent ORDER BY i;
SELECT * FROM ONLY inherit_parent ORDER BY i;

SELECT count(*) AS vector_aggregate_count
FROM pg_proc
WHERE pronamespace = 'columnar'::regnamespace
AND proname IN ('vcount', 'vsum', 'vavg', 'vmin', 'vmax');

CREATE TABLE agg_test(a int4, d date) USING columnar;
INSERT INTO agg_test VALUES
    (1, '2024-01-01'),
    (2, '2024-01-02'),
    (3, '2024-01-03'),
    (NULL, NULL);

SELECT count(*), sum(a), avg(a)::numeric(10,2), min(d), max(d)
FROM agg_test;

SELECT columnar.vcount(*), columnar.vcount(a), columnar.vsum(a),
    columnar.vmin(a), columnar.vmax(a), columnar.vmin(d), columnar.vmax(d)
FROM agg_test;

RESET search_path;
DROP SCHEMA columnar_ops CASCADE;
