-- Transaction coverage for built-in columnar tables.

CREATE SCHEMA columnar_transactions;
SET search_path TO columnar_transactions, public;
SET columnar.compression TO 'none';

CREATE TABLE transaction_test(a int, b int) USING columnar;

INSERT INTO transaction_test
SELECT i, i * 2
FROM generate_series(1, 3) i;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
ALTER TABLE transaction_test ALTER COLUMN b TYPE float4 USING (b + 0.5)::float4;
INSERT INTO transaction_test VALUES (4, 8.5);
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
TRUNCATE transaction_test;
INSERT INTO transaction_test VALUES (4, 8);
SELECT * FROM transaction_test ORDER BY a;
SAVEPOINT s1;
TRUNCATE transaction_test;
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK TO SAVEPOINT s1;
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
INSERT INTO transaction_test VALUES (4, 8);
SAVEPOINT s1;
TRUNCATE transaction_test;
ROLLBACK TO SAVEPOINT s1;
COMMIT;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
INSERT INTO transaction_test VALUES (5, 10);
SELECT * FROM transaction_test ORDER BY a;
SAVEPOINT s1;
DROP TABLE transaction_test;
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK TO SAVEPOINT s1;
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
INSERT INTO transaction_test VALUES (5, 10);
SAVEPOINT s1;
DROP TABLE transaction_test;
SELECT * FROM transaction_test ORDER BY a;
ROLLBACK TO SAVEPOINT s1;
COMMIT;

SELECT * FROM transaction_test ORDER BY a;

BEGIN;
INSERT INTO transaction_test VALUES (6, 12);
SAVEPOINT s1;
SELECT * FROM transaction_test;
ROLLBACK;

SELECT * FROM transaction_test ORDER BY a;

PREPARE insert_transaction_test(int, int) AS
INSERT INTO transaction_test VALUES ($1, $2);

EXECUTE insert_transaction_test(6, 12);
EXECUTE insert_transaction_test(7, 14);

SELECT * FROM transaction_test ORDER BY a;

DEALLOCATE insert_transaction_test;

DROP TABLE transaction_test;
RESET search_path;
DROP SCHEMA columnar_transactions;
