-- Mutation coverage for columnar tables, including upsert and partitions.

CREATE SCHEMA columnar_mutation;
SET search_path TO columnar_mutation, public;
SET columnar.compression TO 'none';

CREATE TABLE upsert_test (
    i int,
    t text
) USING columnar;

CREATE UNIQUE INDEX upsert_test_t_idx ON upsert_test(t);

INSERT INTO upsert_test VALUES (1, 'hello'), (2, 'world');

BEGIN;
INSERT INTO upsert_test(t)
VALUES ('hello')
ON CONFLICT (t) DO UPDATE SET i = 10, t = 'rolled-back';
SELECT * FROM upsert_test ORDER BY t;
ROLLBACK;

SELECT * FROM upsert_test ORDER BY t;

INSERT INTO upsert_test(t)
VALUES ('hello')
ON CONFLICT (t) DO UPDATE SET i = 11, t = 'updated';

SELECT * FROM upsert_test ORDER BY t;

DELETE FROM upsert_test;

BEGIN;
INSERT INTO upsert_test VALUES (1, 'again');
INSERT INTO upsert_test(t)
VALUES ('again')
ON CONFLICT (t) DO UPDATE SET i = 12, t = 'again-updated';
COMMIT;

SELECT * FROM upsert_test ORDER BY t;

CREATE TABLE parent(ts timestamptz, i int, n numeric, s text)
  PARTITION BY RANGE (ts);

CREATE TABLE p0 PARTITION OF parent
  FOR VALUES FROM ('2020-01-01') TO ('2020-02-01')
  USING columnar;
CREATE TABLE p1 PARTITION OF parent
  FOR VALUES FROM ('2020-02-01') TO ('2020-03-01')
  USING columnar;
CREATE TABLE p2 PARTITION OF parent
  FOR VALUES FROM ('2020-03-01') TO ('2020-04-01');

INSERT INTO parent VALUES
    ('2020-01-15', 10, 100, 'one thousand'),
    ('2020-02-15', 20, 200, 'two thousand'),
    ('2020-03-15', 30, 300, 'three thousand'),
    ('2020-03-21', 31, 301, 'three thousand and one'),
    ('2020-03-22', 32, 302, 'three thousand and two'),
    ('2020-03-23', 33, 303, 'three thousand and three');

SELECT tableoid::regclass::text AS partition_name, ts::date, i, n, s
FROM parent
ORDER BY ts;

UPDATE p2 SET i = i + 1 WHERE ts = '2020-03-15';
DELETE FROM p2 WHERE ts = '2020-03-21';

UPDATE p1 SET i = i + 1 WHERE ts = '2020-02-15';
DELETE FROM p1 WHERE ts = '2020-02-15';

UPDATE parent SET i = i + 1 WHERE ts = '2020-03-15';
DELETE FROM parent WHERE ts = '2020-03-22';

UPDATE parent SET i = i + 1 WHERE n = 300;
DELETE FROM parent WHERE n = 303;

SELECT tableoid::regclass::text AS partition_name, ts::date, i, n, s
FROM parent
ORDER BY ts;

CREATE TABLE transaction_update(i int, j int) USING columnar;

INSERT INTO transaction_update SELECT g, g * 10 FROM generate_series(1, 200) g;

SELECT count(*) FROM transaction_update;

BEGIN;
DELETE FROM transaction_update WHERE i % 2 = 0;
SELECT count(*) FROM transaction_update;
UPDATE transaction_update SET j = -1 WHERE i % 3 = 0;
SELECT count(*) FROM transaction_update WHERE j = -1;
COMMIT;

SELECT count(*) FROM transaction_update;
SELECT count(*) FROM transaction_update WHERE j = -1;

RESET search_path;
DROP SCHEMA columnar_mutation CASCADE;
