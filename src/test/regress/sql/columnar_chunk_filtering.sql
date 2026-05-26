-- Chunk filtering coverage for built-in columnar tables.

CREATE SCHEMA columnar_chunk_filtering;
SET search_path TO columnar_chunk_filtering, public;
SET columnar.compression TO 'none';
SET columnar.qual_pushdown_correlation TO 0.0;
SET columnar.stripe_row_limit TO 2000;
SET columnar.chunk_group_row_limit TO 1000;
SET columnar.enable_vectorization TO 'off';
SET columnar.enable_parallel_execution TO 'off';

CREATE OR REPLACE FUNCTION filtered_row_count(query text) RETURNS bigint AS
$$
DECLARE
    result bigint := 0;
    rec text;
BEGIN
    FOR rec IN EXECUTE 'EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF) ' || query LOOP
        IF rec ~ '^\s+Rows Removed by Filter' THEN
            result := regexp_replace(rec, '[^0-9]*', '', 'g');
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION chunk_groups_removed(query text) RETURNS bigint AS
$$
DECLARE
    result bigint := 0;
    rec text;
BEGIN
    FOR rec IN EXECUTE 'EXPLAIN (ANALYZE, COSTS OFF, TIMING OFF, SUMMARY OFF) ' || query LOOP
        IF rec ~ '^\s+Columnar Chunk Groups Removed by Filter' THEN
            result := regexp_replace(rec, '[^0-9]*', '', 'g');
        END IF;
    END LOOP;

    RETURN result;
END;
$$ LANGUAGE plpgsql;

CREATE TABLE chunk_filter_test(a int) USING columnar;
INSERT INTO chunk_filter_test SELECT generate_series(1, 10000);

SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test') AS no_filter_rows_removed;
SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test WHERE a < 200') AS lt_200_rows_removed;
SELECT chunk_groups_removed('SELECT count(*) FROM chunk_filter_test WHERE a < 200') AS lt_200_chunks_removed;
SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test WHERE a > 9900') AS gt_9900_rows_removed;
SELECT chunk_groups_removed('SELECT count(*) FROM chunk_filter_test WHERE a > 9900') AS gt_9900_chunks_removed;
SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test WHERE a < 0') AS lt_0_rows_removed;
SELECT chunk_groups_removed('SELECT count(*) FROM chunk_filter_test WHERE a < 0') AS lt_0_chunks_removed;
SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test WHERE a BETWEEN 990 AND 2010') AS between_rows_removed;
SELECT chunk_groups_removed('SELECT count(*) FROM chunk_filter_test WHERE a BETWEEN 990 AND 2010') AS between_chunks_removed;

INSERT INTO chunk_filter_test SELECT generate_series(1, 10000);

SELECT filtered_row_count('SELECT count(*) FROM chunk_filter_test WHERE a < 200') AS lt_200_rows_removed_twice;
SELECT chunk_groups_removed('SELECT count(*) FROM chunk_filter_test WHERE a < 200') AS lt_200_chunks_removed_twice;

CREATE TABLE multi_column_chunk_filter_test(a int, b int) USING columnar;
INSERT INTO multi_column_chunk_filter_test
SELECT i, i + 1
FROM generate_series(1, 10000) i;

SELECT count(*) FROM multi_column_chunk_filter_test WHERE a > 9000 AND b > 9000;
SELECT chunk_groups_removed(
    'SELECT count(*) FROM multi_column_chunk_filter_test WHERE a > 9000 AND b > 9000'
) AS multi_column_chunks_removed;

RESET columnar.enable_parallel_execution;
RESET columnar.enable_vectorization;
RESET columnar.chunk_group_row_limit;
RESET columnar.stripe_row_limit;
RESET columnar.qual_pushdown_correlation;
RESET search_path;
DROP SCHEMA columnar_chunk_filtering CASCADE;
