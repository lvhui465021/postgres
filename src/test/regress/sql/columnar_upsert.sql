-- ON CONFLICT DO UPDATE coverage for built-in columnar tables.

CREATE SCHEMA columnar_upsert;
SET search_path TO columnar_upsert, public;
SET columnar.compression TO 'none';

CREATE TABLE upsert_test (
    i int,
    t text
) USING columnar;

CREATE UNIQUE INDEX upsert_test_t_idx ON upsert_test (t);

INSERT INTO upsert_test (i, t) VALUES (1, 'hello');
INSERT INTO upsert_test (i, t) VALUES (2, 'world');

BEGIN;
INSERT INTO upsert_test (t) VALUES ('hello')
ON CONFLICT (t) DO UPDATE SET t = 'foo';
SELECT * FROM upsert_test ORDER BY i, t;
ROLLBACK;

SELECT * FROM upsert_test ORDER BY i, t;

INSERT INTO upsert_test (t) VALUES ('hello')
ON CONFLICT (t) DO UPDATE SET t = 'bar';
SELECT * FROM upsert_test ORDER BY i, t;

BEGIN;
INSERT INTO upsert_test (t) VALUES ('world')
ON CONFLICT (t) DO UPDATE SET t = 'foo';
SELECT * FROM upsert_test ORDER BY i, t;
COMMIT;

DELETE FROM upsert_test;
BEGIN;
INSERT INTO upsert_test (i, t) VALUES (1, 'hello');
INSERT INTO upsert_test (t) VALUES ('hello')
ON CONFLICT (t) DO UPDATE SET t = 'bar';
COMMIT;

SELECT * FROM upsert_test ORDER BY i, t;

RESET search_path;
DROP SCHEMA columnar_upsert CASCADE;
