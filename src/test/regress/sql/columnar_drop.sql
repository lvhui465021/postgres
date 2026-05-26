-- DROP cleanup coverage for built-in columnar tables.

CREATE SCHEMA columnar_drop;
SET search_path TO columnar_drop, public;
SET columnar.compression TO 'none';

CREATE TABLE drop_table_test(a int, b text) USING columnar;
INSERT INTO drop_table_test
SELECT g, 'value-' || g
FROM generate_series(1, 1000) g;

SELECT storage_id AS drop_table_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT count(*) > 0 AS has_stripes
FROM columnar.stripe
WHERE storage_id = :drop_table_storage_id;

DROP TABLE drop_table_test;

SELECT count(*) AS metadata_rows_after_drop
FROM (
    SELECT storage_id FROM columnar.stripe WHERE storage_id = :drop_table_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk_group WHERE storage_id = :drop_table_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk WHERE storage_id = :drop_table_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.row_mask WHERE storage_id = :drop_table_storage_id
) s;

CREATE SCHEMA drop_schema_target;
CREATE TABLE drop_schema_target.cascade_table(a int) USING columnar;
INSERT INTO drop_schema_target.cascade_table
SELECT generate_series(1, 1000);

SELECT storage_id AS cascade_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

DROP SCHEMA drop_schema_target CASCADE;

SELECT count(*) AS metadata_rows_after_schema_drop
FROM (
    SELECT storage_id FROM columnar.stripe WHERE storage_id = :cascade_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk_group WHERE storage_id = :cascade_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.chunk WHERE storage_id = :cascade_storage_id
    UNION ALL
    SELECT storage_id FROM columnar.row_mask WHERE storage_id = :cascade_storage_id
) s;

RESET search_path;
DROP SCHEMA columnar_drop;
