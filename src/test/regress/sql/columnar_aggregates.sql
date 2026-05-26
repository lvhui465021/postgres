-- Vector aggregate coverage for built-in columnar tables.

CREATE SCHEMA columnar_aggregates;
SET search_path TO columnar_aggregates, public;
SET columnar.compression TO 'none';
SET max_parallel_workers_per_gather TO 0;

CREATE TABLE agg_smallint(a smallint) USING columnar;
INSERT INTO agg_smallint
SELECT (g % 128)::smallint
FROM generate_series(0, 10000) g;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(*), sum(a), avg(a), min(a), max(a)
FROM agg_smallint;

SELECT sum(a), avg(a), min(a), max(a)
FROM agg_smallint;

SET columnar.enable_vectorization TO off;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(*), sum(a), avg(a), min(a), max(a)
FROM agg_smallint;

SELECT sum(a), avg(a), min(a), max(a)
FROM agg_smallint;

RESET columnar.enable_vectorization;

CREATE TABLE agg_int(a int) USING columnar;
INSERT INTO agg_int
SELECT g
FROM generate_series(0, 10000) g;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT sum(a), avg(a), min(a), max(a)
FROM agg_int;

SELECT sum(a), avg(a), min(a), max(a)
FROM agg_int;

CREATE TABLE agg_bigint(a bigint) USING columnar;
INSERT INTO agg_bigint
SELECT g
FROM generate_series(0, 10000) g;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT sum(a), avg(a), min(a), max(a)
FROM agg_bigint;

SELECT sum(a), avg(a), min(a), max(a)
FROM agg_bigint;

CREATE TABLE agg_date(a date) USING columnar;
INSERT INTO agg_date VALUES
    ('2000-01-01'),
    ('2020-01-01'),
    ('2010-01-01'),
    ('2000-01-02');

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT min(a), max(a)
FROM agg_date;

SELECT min(a), max(a)
FROM agg_date;

CREATE TABLE agg_mixed(a int, b bigint, c date, d time) USING columnar;
INSERT INTO agg_mixed VALUES
    (0, 1000, '2000-01-01', '23:50'),
    (10, 2000, '2010-01-01', '00:50');

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT min(d)
FROM agg_mixed;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT sum(a + b)
FROM agg_mixed;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(1)
FROM agg_mixed;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(DISTINCT a)
FROM agg_mixed;

CREATE TABLE agg_filter(a int) USING columnar;
INSERT INTO agg_filter
SELECT g
FROM generate_series(0, 100) g;

EXPLAIN (VERBOSE, COSTS OFF, TIMING OFF, SUMMARY OFF)
SELECT count(a) FILTER (WHERE a > 90)
FROM agg_filter;

SELECT count(a) FILTER (WHERE a > 90)
FROM agg_filter;

RESET max_parallel_workers_per_gather;
RESET search_path;
DROP SCHEMA columnar_aggregates CASCADE;
