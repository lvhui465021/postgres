-- Recursive and nested write coverage for built-in columnar tables.

CREATE SCHEMA columnar_recursive;
SET search_path TO columnar_recursive, public;
SET columnar.compression TO 'none';

CREATE TABLE t1(a int, b int) USING columnar;
CREATE TABLE t2(a int, b int) USING columnar;

CREATE FUNCTION f(x int) RETURNS int AS $$
  INSERT INTO t1 VALUES(x, x * 2) RETURNING b - 1;
$$ LANGUAGE SQL;

INSERT INTO t2 SELECT i, f(i) FROM generate_series(1, 5) i;

SELECT * FROM t1 ORDER BY a;
SELECT * FROM t2 ORDER BY a;

TRUNCATE t1;
TRUNCATE t2;
DROP FUNCTION f(int);

WITH t AS (
    INSERT INTO t1 SELECT i, 2 * i FROM generate_series(1, 5) i RETURNING *
)
INSERT INTO t2 SELECT t.a, t.a + 1 FROM t;

SELECT * FROM t1 ORDER BY a;
SELECT * FROM t2 ORDER BY a;

TRUNCATE t1;
TRUNCATE t2;

WITH t AS (
    INSERT INTO t1 SELECT i, 2 * i FROM generate_series(1, 5) i RETURNING *
)
INSERT INTO t2 SELECT i, (SELECT count(*) FROM t1) FROM generate_series(1, 3) i;

SELECT * FROM t1 ORDER BY a;
SELECT * FROM t2 ORDER BY a;

TRUNCATE t1;
TRUNCATE t2;

WITH t AS (
    INSERT INTO t1 SELECT i, 2 * i FROM generate_series(1, 5) i RETURNING *
)
INSERT INTO t1 SELECT t.a, t.a + 1 FROM t;

SELECT * FROM t1 ORDER BY a, b;

TRUNCATE t1;
TRUNCATE t2;

CREATE FUNCTION g(x int) RETURNS int AS $$
  INSERT INTO t1 VALUES(x, x * 2);
  SELECT count(*)::int FROM t1;
$$ LANGUAGE SQL;

CREATE TABLE t3(a int, b int);
CREATE TABLE t4(a int, b int);

CREATE FUNCTION g2(x int) RETURNS int AS $$
  INSERT INTO t3 VALUES(x, x * 2);
  SELECT count(*)::int FROM t3;
$$ LANGUAGE SQL;

INSERT INTO t2 SELECT i, g(i) FROM generate_series(1, 5) i;
INSERT INTO t4 SELECT i, g2(i) FROM generate_series(1, 5) i;

((TABLE t1) EXCEPT (TABLE t3)) UNION ((TABLE t3) EXCEPT (TABLE t1));
((TABLE t2) EXCEPT (TABLE t4)) UNION ((TABLE t4) EXCEPT (TABLE t2));
SELECT * FROM t2 ORDER BY a, b;

TRUNCATE t1, t2, t3, t4;

INSERT INTO t1 SELECT i, g(i) FROM generate_series(1, 3) i;
INSERT INTO t3 SELECT i, g2(i) FROM generate_series(1, 3) i;

SELECT * FROM t1 ORDER BY a, b;
SELECT * FROM t3 ORDER BY a, b;

((TABLE t1) EXCEPT (TABLE t3)) UNION ((TABLE t3) EXCEPT (TABLE t1));
((TABLE t2) EXCEPT (TABLE t4)) UNION ((TABLE t4) EXCEPT (TABLE t2));

DROP FUNCTION g(int), g2(int);
TRUNCATE t1, t2, t3, t4;

CREATE FUNCTION f(a int) RETURNS void AS $$
DECLARE
    x int;
BEGIN
    INSERT INTO t1 SELECT i, i + 1 FROM generate_series(a, a + 1) i;
    x := 10 / a;
    INSERT INTO t1 SELECT i, i * 2 FROM generate_series(a + 2, a + 3) i;
EXCEPTION WHEN division_by_zero THEN
    INSERT INTO t1 SELECT i, i + 1 FROM generate_series(a + 2, a + 3) i;
END;
$$ LANGUAGE plpgsql;

SELECT f(10);
SELECT f(0), f(20);

SELECT * FROM t1 ORDER BY a, b;

DROP FUNCTION f(int);
DROP TABLE t1, t2, t3, t4;
RESET search_path;
DROP SCHEMA columnar_recursive;
