-- Metadata and row-mask coverage for built-in columnar tables.

CREATE SCHEMA columnar_metadata;
SET search_path TO columnar_metadata, public;
SET columnar.compression TO 'none';

SELECT count(distinct storage_id) AS storage_count_before
FROM columnar.stripe \gset

CREATE TABLE metadata_test(a int, b int) USING columnar;

SELECT columnar.alter_columnar_table_set('metadata_test',
    chunk_group_row_limit => 1000,
    stripe_row_limit => 4000);

INSERT INTO metadata_test SELECT g, g % 10 FROM generate_series(1, 10000) g;

SELECT storage_id AS metadata_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT count(*) AS stripe_count, sum(row_count) AS total_rows
FROM columnar.stripe
WHERE storage_id = :metadata_storage_id;

SELECT count(*) AS chunk_group_count, sum(row_count) AS chunk_group_rows
FROM columnar.chunk_group
WHERE storage_id = :metadata_storage_id;

SELECT count(*) AS row_mask_count, sum(deleted_rows) AS row_mask_deleted_rows
FROM columnar.row_mask
WHERE storage_id = :metadata_storage_id;

SELECT stripeid, rowcount, deletedrows, chunkcount
FROM columnar.stats('metadata_test')
ORDER BY stripeid;

DELETE FROM metadata_test WHERE a % 2 = 0;

SELECT count(*), sum(a) FROM metadata_test;

SELECT sum(deleted_rows) AS chunk_group_deleted_rows
FROM columnar.chunk_group
WHERE storage_id = :metadata_storage_id;

SELECT sum(deleted_rows) AS row_mask_deleted_rows
FROM columnar.row_mask
WHERE storage_id = :metadata_storage_id;

VACUUM FULL metadata_test;

SELECT count(*), sum(a) FROM metadata_test;

SELECT count(*) = 0 AS chunk_group_deleted_rows_cleared
FROM columnar.chunk_group
WHERE storage_id = :metadata_storage_id
AND deleted_rows <> 0;

SELECT count(*) = 0 AS row_mask_deleted_rows_cleared
FROM columnar.row_mask
WHERE storage_id = :metadata_storage_id
AND deleted_rows <> 0;

TRUNCATE metadata_test;

SELECT count(*) FROM metadata_test;

SELECT count(*) AS metadata_rows_after_truncate
FROM (
    SELECT storage_id FROM columnar.stripe WHERE storage_id = :metadata_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk_group WHERE storage_id = :metadata_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.row_mask WHERE storage_id = :metadata_storage_id
) s;

DROP TABLE metadata_test;

SELECT count(distinct storage_id) = :storage_count_before AS storage_count_restored
FROM columnar.stripe;

RESET search_path;
DROP SCHEMA columnar_metadata;
