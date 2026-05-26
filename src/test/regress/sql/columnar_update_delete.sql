-- Update/delete coverage for built-in columnar tables.

CREATE SCHEMA columnar_update_delete;
SET search_path TO columnar_update_delete, public;
SET columnar.compression TO 'none';

CREATE TABLE columnar_update(a int, b int) USING columnar;

INSERT INTO columnar_update VALUES (1, 10), (2, 20), (3, 30);

UPDATE columnar_update SET b = b + 1 WHERE a = 2;
DELETE FROM columnar_update WHERE a = 2;

INSERT INTO columnar_update VALUES
    (3, 5),
    (4, 5),
    (5, 5)
ON CONFLICT DO NOTHING;

INSERT INTO columnar_update VALUES
    (3, 5),
    (4, 5),
    (5, 5)
ON CONFLICT (a) DO NOTHING;

SELECT * FROM columnar_update WHERE a = 2 FOR SHARE;
SELECT * FROM columnar_update WHERE a = 2 FOR UPDATE;
SELECT * FROM columnar_update WHERE ctid = '(0,2)';
SELECT * FROM columnar_update ORDER BY a, b;

CREATE TABLE update_parent(
    ts timestamptz,
    a int,
    b numeric,
    payload text
) PARTITION BY RANGE (ts);

CREATE TABLE update_p0 PARTITION OF update_parent
FOR VALUES FROM ('2024-01-01') TO ('2024-02-01')
USING columnar;

CREATE TABLE update_p1 PARTITION OF update_parent
FOR VALUES FROM ('2024-02-01') TO ('2024-03-01')
USING columnar;

CREATE TABLE update_p2 PARTITION OF update_parent
FOR VALUES FROM ('2024-03-01') TO ('2024-04-01');

INSERT INTO update_parent VALUES
    ('2024-01-15', 10, 100, 'one'),
    ('2024-02-15', 20, 200, 'two'),
    ('2024-03-15', 30, 300, 'three'),
    ('2024-03-21', 31, 301, 'three-one'),
    ('2024-03-22', 32, 302, 'three-two'),
    ('2024-03-23', 33, 303, 'three-three');

SELECT tableoid::regclass AS partition_name, ts::date, a, b, payload
FROM update_parent
ORDER BY ts;

UPDATE update_p2 SET a = a + 1 WHERE ts = '2024-03-15';
DELETE FROM update_p2 WHERE ts = '2024-03-21';

UPDATE update_p1 SET a = a + 1 WHERE ts = '2024-02-15';
DELETE FROM update_p1 WHERE ts = '2024-02-15';

UPDATE update_parent SET a = a + 1 WHERE ts = '2024-03-15';
DELETE FROM update_parent WHERE ts = '2024-03-22';

UPDATE update_parent SET a = a + 1 WHERE ts > '2024-02-15';
DELETE FROM update_parent WHERE ts > '2024-02-15';

SELECT tableoid::regclass AS partition_name, ts::date, a, b, payload
FROM update_parent
ORDER BY ts;

ALTER TABLE update_parent DETACH PARTITION update_p0;
DROP TABLE update_p0;
DROP TABLE update_parent;

CREATE TABLE transaction_update(a int, b int) USING columnar;

INSERT INTO transaction_update
SELECT g, g * 10
FROM generate_series(1, 20000) g;

SELECT count(*) FROM transaction_update;

BEGIN;
DELETE FROM transaction_update WHERE a % 2 = 0;
SELECT count(*) FROM transaction_update;
UPDATE transaction_update SET b = -1 WHERE a % 3 = 0;
SELECT count(*) FROM transaction_update WHERE b = -1;
COMMIT;

SELECT count(*) FROM transaction_update;
SELECT count(*) FROM transaction_update WHERE b = -1;
SELECT sum(a), sum(b) FROM transaction_update;

RESET search_path;
DROP SCHEMA columnar_update_delete CASCADE;
