-- columnar is built into this PostgreSQL tree, not installed as an extension.
SELECT amname, amtype FROM pg_am WHERE amname = 'columnar';

CREATE TABLE columnar_builtin_table(a int, b text) USING columnar;
SELECT columnar.alter_columnar_table_set('columnar_builtin_table',
    compression => 'none',
    stripe_row_limit => 1000);
SELECT compression, stripe_row_limit
FROM columnar.options
WHERE regclass = 'columnar_builtin_table'::regclass;
SELECT columnar.alter_columnar_table_reset('columnar_builtin_table',
    compression => true,
    stripe_row_limit => true);
INSERT INTO columnar_builtin_table VALUES (1, 'one'), (2, 'two');
SELECT * FROM columnar_builtin_table ORDER BY a;

SET default_table_access_method = columnar;
CREATE TABLE columnar_builtin_default(a int);
RESET default_table_access_method;
SELECT relname, am.amname
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.relname IN ('columnar_builtin_table', 'columnar_builtin_default')
ORDER BY relname;

SELECT columnar.vacuum('columnar_builtin_table'::regclass) >= 0 AS vacuum_ok;
SELECT columnar.upgrade_columnar_storage('columnar_builtin_table'::regclass);
SELECT columnar.downgrade_columnar_storage('columnar_builtin_table'::regclass);
SELECT columnar.alter_table_set_access_method('columnar_builtin_default', 'heap') AS converted_to_heap;
SELECT am.amname
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.relname = 'columnar_builtin_default';
SELECT columnar.alter_table_set_access_method('columnar_builtin_default', 'columnar') AS converted_to_columnar;
SELECT am.amname
FROM pg_class c
JOIN pg_am am ON am.oid = c.relam
WHERE c.relname = 'columnar_builtin_default';

DROP TABLE columnar_builtin_table;
DROP TABLE columnar_builtin_default;
