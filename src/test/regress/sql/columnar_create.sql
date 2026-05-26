-- CREATE coverage for built-in columnar tables.

CREATE SCHEMA columnar_create;
SET search_path TO columnar_create, public;
SET columnar.compression TO 'none';

CREATE TABLE source_for_create(a int, b text);
INSERT INTO source_for_create
SELECT g, 'value-' || g
FROM generate_series(1, 1000) g;

CREATE TABLE ctas_columnar USING columnar AS
SELECT *
FROM source_for_create
ORDER BY a;

SELECT count(*), sum(a), min(b), max(b)
FROM ctas_columnar;

SELECT relam = (SELECT oid FROM pg_am WHERE amname = 'columnar') AS ctas_is_columnar
FROM pg_class
WHERE oid = 'ctas_columnar'::regclass;

CREATE TEMPORARY TABLE columnar_temp(i int) USING columnar;
INSERT INTO columnar_temp
SELECT generate_series(1, 5);
SELECT count(*), sum(i) FROM columnar_temp;

BEGIN;
DROP TABLE columnar_temp;
SELECT count(*) = 0 AS temp_dropped_in_xact
FROM pg_class
WHERE oid = to_regclass('columnar_temp');
ROLLBACK;

SELECT count(*), sum(i) FROM columnar_temp;
DROP TABLE columnar_temp;

BEGIN;
CREATE TEMPORARY TABLE columnar_temp_drop(i int) USING columnar ON COMMIT DROP;
INSERT INTO columnar_temp_drop
SELECT generate_series(1, 1000);
SELECT count(*) FROM columnar_temp_drop;
COMMIT;

SELECT to_regclass('columnar_temp_drop') IS NULL AS on_commit_drop_removed_table;

BEGIN;
CREATE TEMPORARY TABLE columnar_temp_delete(i int) USING columnar ON COMMIT DELETE ROWS;
INSERT INTO columnar_temp_delete
SELECT generate_series(1, 1000);
SELECT count(*) FROM columnar_temp_delete;
COMMIT;

SELECT to_regclass('columnar_temp_delete') IS NOT NULL AS on_commit_delete_kept_table;
SELECT count(*) FROM columnar_temp_delete;
DROP TABLE columnar_temp_delete;

RESET search_path;
DROP SCHEMA columnar_create CASCADE;
