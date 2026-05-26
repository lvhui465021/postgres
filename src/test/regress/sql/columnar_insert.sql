-- Insert coverage for built-in columnar tables.

CREATE SCHEMA columnar_insert;
SET search_path TO columnar_insert, public;
SET columnar.compression TO 'none';

CREATE TABLE insert_values(a int, b text) USING columnar;

SELECT count(*) FROM insert_values;

INSERT INTO insert_values VALUES (1, 'one');
INSERT INTO insert_values VALUES (2, 'two'), (3, 'three');

SELECT count(*), sum(a), string_agg(b, ',' ORDER BY a)
FROM insert_values;

CREATE TABLE heap_source(a int, b text);
INSERT INTO heap_source
SELECT i, 'source-' || i
FROM generate_series(4, 10) i;

INSERT INTO insert_values
SELECT * FROM heap_source;

SELECT count(*), sum(a), min(b), max(b)
FROM insert_values;

CREATE TABLE toast_source(
    id int,
    plain text,
    main text,
    external text,
    extended text
);

ALTER TABLE toast_source ALTER COLUMN plain SET STORAGE plain;
ALTER TABLE toast_source ALTER COLUMN main SET STORAGE main;
ALTER TABLE toast_source ALTER COLUMN external SET STORAGE external;
ALTER TABLE toast_source ALTER COLUMN extended SET STORAGE extended;

INSERT INTO toast_source VALUES
    (1, repeat('w', 3000), repeat('x', 3000), repeat('y', 3000), repeat('z', 3000));

CREATE TABLE toast_columnar(
    id int,
    plain text,
    main text,
    external text,
    extended text
) USING columnar;

INSERT INTO toast_columnar
SELECT * FROM toast_source;

SELECT id,
       md5(plain),
       md5(main),
       md5(external),
       md5(extended)
FROM toast_columnar;

DROP TABLE toast_source;

SELECT id,
       length(plain),
       length(main),
       length(external),
       length(extended)
FROM toast_columnar;

CREATE TABLE zero_column() USING columnar;
INSERT INTO zero_column DEFAULT VALUES;
INSERT INTO zero_column DEFAULT VALUES;
INSERT INTO zero_column SELECT * FROM zero_column;

SELECT count(*) FROM zero_column;

CREATE TABLE self_insert(a int) USING columnar;
SELECT columnar.alter_columnar_table_set('self_insert', stripe_row_limit => 1000);

BEGIN;
INSERT INTO self_insert SELECT generate_series(1, 1010);
INSERT INTO self_insert SELECT * FROM self_insert;
SELECT count(*), sum(a) FROM self_insert;
ROLLBACK;

INSERT INTO self_insert SELECT generate_series(1, 1010);
INSERT INTO self_insert SELECT * FROM self_insert;

SELECT count(*), sum(a) FROM self_insert;

CREATE TABLE publication_test(a int) USING columnar;
INSERT INTO publication_test VALUES (1);
CREATE PUBLICATION columnar_insert_publication FOR TABLE publication_test;
INSERT INTO publication_test VALUES (2);
DROP PUBLICATION columnar_insert_publication;
INSERT INTO publication_test VALUES (3);
SELECT * FROM publication_test ORDER BY a;

RESET search_path;
DROP SCHEMA columnar_insert CASCADE;
