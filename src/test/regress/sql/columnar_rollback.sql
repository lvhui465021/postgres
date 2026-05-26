-- Rollback and subtransaction metadata coverage for built-in columnar tables.

CREATE SCHEMA columnar_rollback;
SET search_path TO columnar_rollback, public;
SET columnar.compression TO 'none';

SELECT count(*) AS stripe_count_before FROM columnar.stripe \gset

CREATE TABLE rollback_test(a int, b int) USING columnar;

BEGIN;
INSERT INTO rollback_test
SELECT i, i + 1
FROM generate_series(1, 10) i;
ROLLBACK;

SELECT count(*) FROM rollback_test;
SELECT count(*) - :stripe_count_before AS leaked_stripes_after_rollback
FROM columnar.stripe;

INSERT INTO rollback_test
SELECT i, i + 1
FROM generate_series(1, 10) i;

SELECT count(*) FROM rollback_test;
SELECT count(*) - :stripe_count_before AS stripes_after_insert
FROM columnar.stripe;

BEGIN;
SAVEPOINT s0;
INSERT INTO rollback_test
SELECT i, i + 1
FROM generate_series(1, 10) i;
SELECT count(*) FROM rollback_test;

SAVEPOINT s1;
INSERT INTO rollback_test
SELECT i, i + 1
FROM generate_series(1, 10) i;
SELECT count(*) FROM rollback_test;

ROLLBACK TO SAVEPOINT s1;
SELECT count(*) FROM rollback_test;

ROLLBACK TO SAVEPOINT s0;
SELECT count(*) FROM rollback_test;

INSERT INTO rollback_test
SELECT i, i + 1
FROM generate_series(1, 10) i;
COMMIT;

SELECT count(*) FROM rollback_test;
SELECT count(*) - :stripe_count_before AS stripes_after_subxact
FROM columnar.stripe;

DROP TABLE rollback_test;

SELECT count(*) = :stripe_count_before AS stripe_count_restored
FROM columnar.stripe;

RESET search_path;
DROP SCHEMA columnar_rollback;
