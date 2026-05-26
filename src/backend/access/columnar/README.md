# Built-in Columnar Table Access Method

This directory contains the in-core columnar table access method. It is
compiled into the backend and initialized by `columnar_init()`. It is not a
loadable extension and does not use `PG_MODULE_MAGIC`, `_PG_init()`, or
`MODULE_PATHNAME`.

## Catalog and initdb integration

- `pg_am.dat` registers the `columnar` table access method.
- `pg_namespace.dat` registers the `columnar` namespace used for SQL-visible
  metadata and helper objects.
- `pg_proc.dat` registers C-backed functions, including the table AM handler,
  management functions, vectorized comparison functions, and aggregate support
  functions.
- `src/backend/catalog/columnar_system.sql` is loaded by `initdb` after
  `system_functions.sql` and before dependency setup. It creates metadata
  tables, comments, grants, internal SQL wrappers, and vector aggregate objects.
- `src/backend/catalog/columnar_plpgsql.sql` is loaded after PL/pgSQL is
  installed. Keep PL/pgSQL function bodies in that file, not in
  `columnar_system.sql`.

The management functions `alter_columnar_table_set` and
`alter_columnar_table_reset` are C functions registered in `pg_proc.dat`, but
their default argument metadata is assigned in `columnar_system.sql` with
`CREATE OR REPLACE FUNCTION ... LANGUAGE internal`. Bootstrap catalog data
cannot directly carry the `pg_node_tree` default expressions needed for these
defaults.

## Extension boundary

Do not install `columnar.control` or `columnar--*.sql` files for this in-core
module. A fresh `initdb` should support `CREATE TABLE ... USING columnar`
without `CREATE EXTENSION columnar`.

When importing future upstream extension SQL changes, flatten the desired final
state into `columnar_system.sql` and `columnar_plpgsql.sql`. Do not preserve
extension upgrade scripts or `ALTER EXTENSION` / `DROP EXTENSION` lifecycle
logic in core.

## Metadata storage

The first in-core version intentionally keeps columnar metadata in SQL-visible
relations under the `columnar` schema instead of introducing bootstrap catalogs.
The storage id is the stable key used by the metadata tables. For local
temporary relations, storage id lookup must not rely solely on
`RelidByRelfilenumber()`, because that path does not resolve current-backend
temporary relations.

## Maintenance checks

Useful checks before merging changes in this area:

```sh
make -C postgres -s -j2
make -C postgres/src/test/regress check
```

Meson should also be kept buildable. If the source tree has already been
configured with Autoconf, verify Meson from a clean copy or after `make
distclean`.

The imported columnar sources are compiled with
`-Wno-declaration-after-statement` in both Makefile and Meson builds. Keep that
warning suppression scoped to this directory.
