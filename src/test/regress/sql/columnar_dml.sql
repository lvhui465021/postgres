-- Basic columnar DML coverage for the built-in table access method.

CREATE SCHEMA columnar_dml;
SET search_path TO columnar_dml, public;

CREATE TABLE contestant (
    handle text,
    birthdate date,
    rating int,
    percentile float8,
    country char(3),
    achievements text[]
) USING columnar;

SELECT columnar.alter_columnar_table_set('contestant',
    compression => 'none',
    chunk_group_row_limit => 1000);

CREATE INDEX contestant_idx ON contestant(handle);

ANALYZE contestant;
SELECT count(*) FROM contestant;

CREATE UNLOGGED TABLE columnar_unlogged(i int) USING columnar;

INSERT INTO contestant VALUES
    ('a', '1990-01-10', 2090, 97.1, 'XA', ARRAY['a']),
    ('b', '1990-11-01', 2203, 98.1, 'XA', ARRAY['a', 'b']),
    ('c', '1988-11-01', 2907, 99.4, 'XB', ARRAY['w', 'y']),
    ('d', '1985-05-05', 2314, 98.3, 'XB', ARRAY[]::text[]);

SELECT handle, rating, country, achievements
FROM contestant
ORDER BY handle;

UPDATE contestant SET rating = rating + 10 WHERE handle = 'a';
DELETE FROM contestant WHERE handle = 'b';

SELECT handle, rating
FROM contestant
ORDER BY handle;

SELECT country, avg(rating)::numeric(10,2)
FROM contestant
GROUP BY country
ORDER BY country;

TRUNCATE contestant;
SELECT count(*) FROM contestant;

CREATE TABLE test_toast_row(plain text, extended text);
ALTER TABLE test_toast_row ALTER COLUMN plain SET STORAGE plain;
ALTER TABLE test_toast_row ALTER COLUMN extended SET STORAGE extended;
INSERT INTO test_toast_row VALUES (repeat('x', 3000), repeat('y', 3000));

CREATE TABLE test_toast_columnar(plain text, extended text) USING columnar;
INSERT INTO test_toast_columnar SELECT plain, extended FROM test_toast_row;

SELECT length(plain), length(extended), md5(plain), md5(extended)
FROM test_toast_columnar;

CREATE TABLE source_for_ctas (a int, b text);
INSERT INTO source_for_ctas
SELECT g, md5(g::text)
FROM generate_series(1, 20) g;

CREATE TABLE columnar_ctas USING columnar AS
SELECT * FROM source_for_ctas ORDER BY a;

SELECT count(*), sum(a), min(b) < max(b)
FROM columnar_ctas;

RESET search_path;
DROP SCHEMA columnar_dml CASCADE;
