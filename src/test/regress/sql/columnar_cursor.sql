-- Cursor coverage for built-in columnar tables.

CREATE SCHEMA columnar_cursor;
SET search_path TO columnar_cursor, public;
SET columnar.compression TO 'none';

CREATE TABLE cursor_test(a int, b int) USING columnar;
INSERT INTO cursor_test
SELECT i, j
FROM generate_series(0, 30) i,
     generate_series(100, 110) j;

BEGIN;
DECLARE c_equal SCROLL CURSOR FOR
SELECT * FROM cursor_test WHERE a = 5 ORDER BY b;

FETCH 3 FROM c_equal;
FETCH PRIOR FROM c_equal;
FETCH NEXT FROM c_equal;
FETCH NEXT FROM c_equal;
FETCH RELATIVE -2 FROM c_equal;
FETCH LAST FROM c_equal;
FETCH RELATIVE -4 FROM c_equal;
MOVE c_equal;
FETCH c_equal;
MOVE LAST FROM c_equal;
FETCH c_equal;
MOVE RELATIVE -3 FROM c_equal;
FETCH c_equal;
UPDATE cursor_test SET a = 8000 WHERE CURRENT OF c_equal;
ROLLBACK;

BEGIN;
DECLARE c_range SCROLL CURSOR FOR
SELECT * FROM cursor_test WHERE a > 28 ORDER BY a, b;

FETCH 3 FROM c_range;
FETCH PRIOR FROM c_range;
FETCH NEXT FROM c_range;
FETCH NEXT FROM c_range;
FETCH RELATIVE -2 FROM c_range;
FETCH LAST FROM c_range;
FETCH RELATIVE -4 FROM c_range;
MOVE c_range;
FETCH c_range;
MOVE LAST FROM c_range;
FETCH c_range;
MOVE RELATIVE -3 FROM c_range;
FETCH c_range;
UPDATE cursor_test SET a = 8000 WHERE CURRENT OF c_range;
ROLLBACK;

SELECT count(*) AS unchanged_rows
FROM cursor_test
WHERE a = 8000;

DROP TABLE cursor_test;
RESET search_path;
DROP SCHEMA columnar_cursor;
