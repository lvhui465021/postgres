-- first_row_number coverage for built-in columnar tables.

CREATE SCHEMA columnar_first_row_number;
SET search_path TO columnar_first_row_number, public;
SET columnar.compression TO 'none';

CREATE TABLE first_row_test(a int) USING columnar;

INSERT INTO first_row_test SELECT i FROM generate_series(1, 10) i;

BEGIN;
INSERT INTO first_row_test SELECT i FROM generate_series(1, 11) i;
ROLLBACK;

INSERT INTO first_row_test SELECT i FROM generate_series(1, 12) i;

SELECT columnar.alter_columnar_table_set('first_row_test', stripe_row_limit => 1000);

INSERT INTO first_row_test SELECT i FROM generate_series(1, 2350) i;

SELECT storage_id AS first_row_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT row_count, first_row_number
FROM columnar.stripe
WHERE storage_id = :first_row_storage_id
ORDER BY stripe_num;

VACUUM FULL first_row_test;

SELECT storage_id AS first_row_storage_id_after_vacuum
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT row_count, first_row_number
FROM columnar.stripe
WHERE storage_id = :first_row_storage_id_after_vacuum
ORDER BY stripe_num;

TRUNCATE first_row_test;

BEGIN;
INSERT INTO first_row_test SELECT i FROM generate_series(1, 16) i;
INSERT INTO first_row_test SELECT i FROM generate_series(1, 16) i;
COMMIT;

SELECT storage_id AS first_row_storage_id_after_truncate
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset

SELECT row_count, first_row_number
FROM columnar.stripe
WHERE storage_id = :first_row_storage_id_after_truncate
ORDER BY stripe_num;

RESET search_path;
DROP SCHEMA columnar_first_row_number CASCADE;
