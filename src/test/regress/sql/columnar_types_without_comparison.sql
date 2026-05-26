-- Types without btree comparison support in built-in columnar tables.

CREATE SCHEMA columnar_types_without_comparison;
SET search_path TO columnar_types_without_comparison, public;
SET columnar.compression TO 'none';

CREATE TABLE test_varchar(a varchar) USING columnar;
INSERT INTO test_varchar VALUES ('Hello');
SELECT storage_id AS varchar_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NOT NULL AS has_min, maximum_value IS NOT NULL AS has_max
FROM columnar.chunk
WHERE storage_id = :varchar_storage_id;
SELECT * FROM test_varchar WHERE a = 'Hello';

CREATE TABLE test_cidr(a cidr) USING columnar;
INSERT INTO test_cidr VALUES ('192.168.100.128/25');
SELECT storage_id AS cidr_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NOT NULL AS has_min, maximum_value IS NOT NULL AS has_max
FROM columnar.chunk
WHERE storage_id = :cidr_storage_id;
SELECT * FROM test_cidr WHERE a = '192.168.100.128/25';

CREATE TABLE test_json(a json) USING columnar;
INSERT INTO test_json VALUES ('5'::json);
SELECT storage_id AS json_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :json_storage_id;
SELECT * FROM test_json WHERE a::text = '5'::json::text;

CREATE TABLE test_line(a line) USING columnar;
INSERT INTO test_line VALUES ('{1, 2, 3}');
SELECT storage_id AS line_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :line_storage_id;
SELECT * FROM test_line WHERE a = '{1, 2, 3}';

CREATE TABLE test_lseg(a lseg) USING columnar;
INSERT INTO test_lseg VALUES ('( 1 , 2 ) , ( 3 , 4 )');
SELECT storage_id AS lseg_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :lseg_storage_id;
SELECT * FROM test_lseg WHERE a = '( 1 , 2 ) , ( 3 , 4 )';

CREATE TABLE test_path(a path) USING columnar;
INSERT INTO test_path VALUES ('( 1 , 2 ) , ( 3 , 4 ) , ( 5 , 6 )');
SELECT storage_id AS path_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :path_storage_id;
SELECT * FROM test_path WHERE a = '( 1 , 2 ) , ( 3 , 4 ) , ( 5 , 6 )';

CREATE TABLE test_txid_snapshot(a txid_snapshot) USING columnar;
INSERT INTO test_txid_snapshot VALUES ('10:20:10,14,15');
SELECT storage_id AS txid_snapshot_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :txid_snapshot_storage_id;
SELECT * FROM test_txid_snapshot
WHERE a::text = '10:20:10,14,15'::txid_snapshot::text;

CREATE TYPE user_defined_color AS ENUM ('red', 'orange', 'yellow',
    'green', 'blue', 'purple');
CREATE TABLE test_user_defined_color(a user_defined_color) USING columnar;
INSERT INTO test_user_defined_color VALUES ('red');
SELECT storage_id AS enum_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NOT NULL AS has_min, maximum_value IS NOT NULL AS has_max
FROM columnar.chunk
WHERE storage_id = :enum_storage_id;
SELECT * FROM test_user_defined_color WHERE a = 'red';

CREATE TABLE test_pg_snapshot(a pg_snapshot) USING columnar;
INSERT INTO test_pg_snapshot VALUES ('10:20:10,14,15');
SELECT storage_id AS pg_snapshot_storage_id
FROM columnar.stripe
ORDER BY storage_id DESC
LIMIT 1 \gset
SELECT minimum_value IS NULL AS min_is_null, maximum_value IS NULL AS max_is_null
FROM columnar.chunk
WHERE storage_id = :pg_snapshot_storage_id;
SELECT * FROM test_pg_snapshot
WHERE a::text = '10:20:10,14,15'::pg_snapshot::text;

RESET search_path;
DROP SCHEMA columnar_types_without_comparison CASCADE;
