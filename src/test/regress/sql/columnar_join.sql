-- Join and rescan coverage for built-in columnar tables.

CREATE SCHEMA columnar_join;
SET search_path TO columnar_join, public;
SET columnar.compression TO 'none';

CREATE TABLE users (id int, name text) USING columnar;
INSERT INTO users
SELECT a, 'name' || a
FROM generate_series(0, 29) AS a;

CREATE TABLE things (id int, user_id int, name text) USING columnar;
INSERT INTO things
SELECT a, a % 30, 'thing' || a
FROM generate_series(1, 300) AS a;

SET enable_material TO off;
SET enable_hashjoin TO off;
SET enable_mergejoin TO off;

SELECT count(*)
FROM users
JOIN things ON users.id = things.user_id
WHERE things.id > 290;

EXPLAIN (COSTS OFF)
SELECT count(*)
FROM users
JOIN things ON users.id = things.user_id
WHERE things.id > 299990;

EXPLAIN (COSTS OFF)
SELECT u1.id, u2.id, count(u2.*)
FROM users u1
JOIN users u2 ON u1.id::text = u2.name
WHERE u2.id > 299990
GROUP BY u1.id, u2.id;

RESET enable_material;
RESET enable_hashjoin;
RESET enable_mergejoin;
RESET search_path;
DROP SCHEMA columnar_join CASCADE;
