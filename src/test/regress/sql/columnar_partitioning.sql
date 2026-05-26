-- Partitioning coverage for built-in columnar tables.

CREATE SCHEMA columnar_partitioning;
SET search_path TO columnar_partitioning, public;
SET columnar.compression TO 'none';
SET columnar.chunk_group_row_limit TO 1000;
SET columnar.stripe_row_limit TO 4000;

SELECT coalesce(max(storage_id), 0) AS partition_storage_before
FROM columnar.stripe \gset

CREATE TABLE partitioned_parent (
    id int,
    ts date,
    payload text
) PARTITION BY RANGE (id);

CREATE TABLE partitioned_parent_heap
PARTITION OF partitioned_parent
FOR VALUES FROM (0) TO (1000);

CREATE TABLE partitioned_parent_columnar_a
PARTITION OF partitioned_parent
FOR VALUES FROM (1000) TO (2000)
USING columnar;

SET default_table_access_method TO columnar;
CREATE TABLE partitioned_parent_columnar_b
PARTITION OF partitioned_parent
FOR VALUES FROM (2000) TO (3000);
RESET default_table_access_method;

INSERT INTO partitioned_parent
SELECT i, date '2024-01-01' + (i % 30), 'payload-' || i
FROM generate_series(1, 2999) i;

SELECT c.relname, am.amname
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.oid IN (
    'partitioned_parent_heap'::regclass,
    'partitioned_parent_columnar_a'::regclass,
    'partitioned_parent_columnar_b'::regclass
)
ORDER BY c.relname;

SELECT tableoid::regclass AS partition_name, count(*), min(id), max(id)
FROM partitioned_parent
GROUP BY tableoid
ORDER BY partition_name;

SELECT count(*), sum(id)
FROM partitioned_parent
WHERE id BETWEEN 1500 AND 2500;

SELECT storage_id AS partition_storage_id
FROM columnar.stripe
WHERE storage_id > :partition_storage_before
ORDER BY storage_id
LIMIT 1 \gset

SELECT count(*) AS columnar_a_stripes, sum(row_count) AS columnar_a_rows
FROM columnar.stripe
WHERE storage_id = :partition_storage_id;

DELETE FROM partitioned_parent
WHERE id >= 1200 AND id < 1300;

SELECT count(*), sum(id)
FROM partitioned_parent
WHERE id >= 1000 AND id < 1400;

SELECT sum(deleted_rows) AS columnar_a_deleted_rows
FROM columnar.chunk_group
WHERE storage_id = :partition_storage_id;

TRUNCATE partitioned_parent_columnar_a;

SELECT count(*) AS columnar_a_rows_after_truncate
FROM partitioned_parent
WHERE id >= 1000 AND id < 2000;

SELECT count(*) AS columnar_a_metadata_after_truncate
FROM (
    SELECT storage_id FROM columnar.stripe WHERE storage_id = :partition_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk_group WHERE storage_id = :partition_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.row_mask WHERE storage_id = :partition_storage_id
) s;

DROP TABLE partitioned_parent;

SELECT count(*) AS orphaned_columnar_partition_metadata
FROM columnar.stripe s
WHERE NOT EXISTS (
    SELECT 1
    FROM pg_class c
    WHERE c.relfilenode = s.storage_id
);

RESET columnar.stripe_row_limit;
RESET columnar.chunk_group_row_limit;
RESET search_path;
DROP SCHEMA columnar_partitioning;
