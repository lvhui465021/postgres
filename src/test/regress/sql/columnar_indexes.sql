-- Index coverage for built-in columnar tables.

CREATE SCHEMA columnar_indexes;
SET search_path TO columnar_indexes, public;
SET columnar.compression TO 'none';
SET columnar.enable_custom_scan TO 'off';
SET enable_seqscan TO 'off';
SET seq_page_cost TO 10000000;

CREATE TABLE indexed_table (
    a int,
    b int,
    c text
) USING columnar;

INSERT INTO indexed_table
SELECT i, i * 2, 'value-' || i
FROM generate_series(1, 5000) i;

CREATE INDEX indexed_table_a_idx ON indexed_table(a);

EXPLAIN (COSTS OFF)
SELECT b FROM indexed_table WHERE a = 3210;

SELECT b, c FROM indexed_table WHERE a = 3210;

CREATE INDEX indexed_table_b_partial_idx ON indexed_table(b)
WHERE b > 6000 AND b < 7000;

EXPLAIN (COSTS OFF)
SELECT b FROM indexed_table WHERE b = 6400;

EXPLAIN (COSTS OFF)
SELECT b FROM indexed_table WHERE b = 5000;

CREATE INDEX indexed_table_b_hash_idx ON indexed_table USING hash(b);

SELECT sum(a) = 3500 AS hash_index_result
FROM indexed_table
WHERE b = 7000;

REINDEX TABLE indexed_table;

SELECT sum(a) = 3500 AS hash_index_result_after_reindex
FROM indexed_table
WHERE b = 7000;

VACUUM FULL indexed_table;

SELECT sum(a) = 3500 AS hash_index_result_after_vacuum
FROM indexed_table
WHERE b = 7000;

CREATE UNIQUE INDEX indexed_table_a_unique_idx ON indexed_table(a);

INSERT INTO indexed_table VALUES (42, 8400, 'duplicate');
INSERT INTO indexed_table VALUES (6001, 12002, 'new-value');

CREATE TABLE partial_unique_test (
    a int,
    b int
) USING columnar;

CREATE UNIQUE INDEX partial_unique_test_a_idx ON partial_unique_test(a)
WHERE b > 500;

INSERT INTO partial_unique_test VALUES (1, 2), (1, 2);
INSERT INTO partial_unique_test VALUES (1, 800);
INSERT INTO partial_unique_test VALUES (4, 600);
INSERT INTO partial_unique_test VALUES (4, 700);

CREATE TABLE pkey_test (
    a int,
    b int
) USING columnar;

INSERT INTO pkey_test
SELECT i, i * 2
FROM generate_series(1, 1000) i;

ALTER TABLE pkey_test ADD PRIMARY KEY (a);

SELECT b FROM pkey_test WHERE a = 980;

INSERT INTO pkey_test VALUES (980, 0);

REINDEX INDEX pkey_test_pkey;

INSERT INTO pkey_test VALUES (980, 0);

CLUSTER pkey_test USING pkey_test_pkey;
ALTER TABLE pkey_test CLUSTER ON pkey_test_pkey;
CLUSTER pkey_test;

RESET enable_seqscan;
RESET seq_page_cost;
RESET columnar.enable_custom_scan;
RESET search_path;
DROP SCHEMA columnar_indexes CASCADE;
