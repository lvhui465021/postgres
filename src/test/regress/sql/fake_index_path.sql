--
-- FakeIndexPath
--

CREATE TABLE fake_index_path_inner
(
	id integer NOT NULL,
	payload text NOT NULL
);

INSERT INTO fake_index_path_inner
SELECT g, 'value-' || g
FROM generate_series(1, 1000) AS g;

CREATE UNIQUE INDEX fake_index_path_inner_id_idx
ON fake_index_path_inner (id);

VACUUM ANALYZE fake_index_path_inner;

-- A FakeIndexPath should retain ordinary IndexScan semantics and have zero
-- startup and total cost.
EXPLAIN (COSTS ON)
SELECT payload
FROM fake_index_path_inner
WHERE id = 500;

SELECT payload
FROM fake_index_path_inner
WHERE id = 500;

-- FakeIndexPath can also represent an IndexOnlyScan.
EXPLAIN (COSTS ON)
SELECT id
FROM fake_index_path_inner
WHERE id = 500;

SELECT id
FROM fake_index_path_inner
WHERE id = 500;

CREATE TABLE fake_index_path_outer (id integer NOT NULL);
INSERT INTO fake_index_path_outer VALUES (1), (500);
ANALYZE fake_index_path_outer;

-- The parameterized FakeIndexPath remains usable on the inner side of a
-- nested loop.
SET enable_hashjoin = off;
SET enable_mergejoin = off;

EXPLAIN (COSTS OFF)
SELECT o.id, i.payload
FROM fake_index_path_outer o
JOIN fake_index_path_inner i USING (id)
ORDER BY o.id;

SELECT o.id, i.payload
FROM fake_index_path_outer o
JOIN fake_index_path_inner i USING (id)
ORDER BY o.id;

RESET enable_hashjoin;
RESET enable_mergejoin;

-- FakeIndexPath must preserve disabled_nodes and honor enable_indexscan.
SET enable_indexscan = off;
SET enable_bitmapscan = off;

EXPLAIN (COSTS OFF)
SELECT payload
FROM fake_index_path_inner
WHERE id = 500;

RESET enable_indexscan;
RESET enable_bitmapscan;

DROP TABLE fake_index_path_outer;
DROP TABLE fake_index_path_inner;
