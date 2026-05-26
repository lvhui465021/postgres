-- Permission coverage for built-in columnar tables.

SELECT current_user AS regress_superuser \gset

CREATE ROLE columnar_permission_user LOGIN;
GRANT CREATE ON SCHEMA public TO columnar_permission_user;

\c - columnar_permission_user

CREATE TABLE columnar_permission_test(i int) USING columnar;
INSERT INTO columnar_permission_test VALUES (1);
ALTER TABLE columnar_permission_test ADD COLUMN j int;
INSERT INTO columnar_permission_test VALUES (2, 20);

SELECT count(*), sum(i), sum(j) FROM columnar_permission_test;

SELECT count(*) > 0 AS has_options_row
FROM columnar.options
WHERE regclass = 'columnar_permission_test'::regclass;

VACUUM columnar_permission_test;
TRUNCATE columnar_permission_test;
SELECT count(*) FROM columnar_permission_test;

DROP TABLE columnar_permission_test;

\c - :regress_superuser

REVOKE CREATE ON SCHEMA public FROM columnar_permission_user;
DROP ROLE columnar_permission_user;
