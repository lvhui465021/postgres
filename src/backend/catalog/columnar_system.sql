-- The columnar namespace is registered in pg_namespace.dat.
GRANT USAGE ON SCHEMA columnar TO PUBLIC;

CREATE SEQUENCE columnar.storageid_seq
    MINVALUE 10000000000
    NO CYCLE;

CREATE TABLE columnar.options (
    regclass oid NOT NULL PRIMARY KEY,
    chunk_group_row_limit int NOT NULL,
    stripe_row_limit int NOT NULL,
    compression_level int NOT NULL,
    compression name NOT NULL
) WITH (user_catalog_table = true);

COMMENT ON TABLE columnar.options IS 'columnar table specific options, maintained by alter_columnar_table_set';

CREATE TABLE columnar.stripe (
    storage_id bigint NOT NULL,
    stripe_num bigint NOT NULL,
    file_offset bigint NOT NULL,
    data_length bigint NOT NULL,
    column_count int NOT NULL,
    chunk_row_count int NOT NULL,
    row_count bigint NOT NULL,
    chunk_group_count int NOT NULL,
    first_row_number bigint,
    PRIMARY KEY (storage_id, stripe_num),
    CONSTRAINT stripe_first_row_number_idx UNIQUE (storage_id, first_row_number)
) WITH (user_catalog_table = true);

COMMENT ON TABLE columnar.stripe IS 'Columnar per stripe metadata';

CREATE TABLE columnar.chunk_group (
    storage_id bigint NOT NULL,
    stripe_num bigint NOT NULL,
    chunk_group_num int NOT NULL,
    row_count bigint NOT NULL,
    deleted_rows bigint NOT NULL DEFAULT 0,
    PRIMARY KEY (storage_id, stripe_num, chunk_group_num)
);

COMMENT ON TABLE columnar.chunk_group IS 'Columnar chunk group metadata';

CREATE TABLE columnar.chunk (
    storage_id bigint NOT NULL,
    stripe_num bigint NOT NULL,
    attr_num int NOT NULL,
    chunk_group_num int NOT NULL,
    minimum_value bytea,
    maximum_value bytea,
    value_stream_offset bigint NOT NULL,
    value_stream_length bigint NOT NULL,
    exists_stream_offset bigint NOT NULL,
    exists_stream_length bigint NOT NULL,
    value_compression_type int NOT NULL,
    value_compression_level int NOT NULL,
    value_decompressed_length bigint NOT NULL,
    value_count bigint NOT NULL,
    PRIMARY KEY (storage_id, stripe_num, attr_num, chunk_group_num)
) WITH (user_catalog_table = true);

ALTER TABLE columnar.chunk ALTER COLUMN minimum_value SET STORAGE PLAIN;
ALTER TABLE columnar.chunk ALTER COLUMN maximum_value SET STORAGE PLAIN;

COMMENT ON TABLE columnar.chunk IS 'Columnar per chunk metadata';

CREATE SEQUENCE columnar.row_mask_seq
    START WITH 1
    INCREMENT BY 1;

CREATE TABLE columnar.row_mask (
    id bigint NOT NULL,
    storage_id bigint NOT NULL,
    stripe_id bigint NOT NULL,
    chunk_id int NOT NULL,
    start_row_number bigint NOT NULL,
    end_row_number bigint NOT NULL,
    deleted_rows int NOT NULL,
    mask bytea,
    PRIMARY KEY (id, storage_id, start_row_number, end_row_number),
    CONSTRAINT row_mask_stripe_unique UNIQUE (storage_id, stripe_id, start_row_number),
    CONSTRAINT row_mask_chunk_unique UNIQUE (storage_id, stripe_id, chunk_id, start_row_number)
) WITH (user_catalog_table = true);

ALTER TABLE columnar.row_mask ALTER COLUMN mask SET STORAGE PLAIN;

COMMENT ON TABLE columnar.row_mask IS 'Columnar chunk mask metadata';

GRANT SELECT ON TABLE columnar.options TO PUBLIC;
GRANT SELECT ON TABLE columnar.stripe TO PUBLIC;
GRANT SELECT ON TABLE columnar.chunk_group TO PUBLIC;
REVOKE SELECT ON TABLE columnar.chunk FROM PUBLIC;
REVOKE SELECT ON TABLE columnar.row_mask FROM PUBLIC;

-- The C functions are registered in pg_proc.dat; this assigns SQL defaults.
CREATE OR REPLACE FUNCTION columnar.alter_columnar_table_set(
    table_name regclass,
    chunk_group_row_limit int DEFAULT NULL,
    stripe_row_limit int DEFAULT NULL,
    compression name DEFAULT NULL,
    compression_level int DEFAULT NULL)
    RETURNS void
    LANGUAGE internal
AS 'alter_columnar_table_set';

CREATE OR REPLACE FUNCTION columnar.alter_columnar_table_reset(
    table_name regclass,
    chunk_group_row_limit bool DEFAULT false,
    stripe_row_limit bool DEFAULT false,
    compression bool DEFAULT false,
    compression_level bool DEFAULT false)
    RETURNS void
    LANGUAGE internal
AS 'alter_columnar_table_reset';

COMMENT ON FUNCTION columnar.alter_columnar_table_set(regclass, int, int, name, int)
    IS 'set one or more options on a columnar table, when set to NULL no change is made';
COMMENT ON FUNCTION columnar.alter_columnar_table_reset(regclass, bool, bool, bool, bool)
    IS 'reset one or more options on a columnar table to the system defaults';
COMMENT ON FUNCTION columnar.create_table_row_mask(regclass)
    IS 'Create empty row mask for table';
COMMENT ON FUNCTION columnar._vacuum_internal(regclass, int)
    IS 'vacuum columnar table internal function';
COMMENT ON FUNCTION columnar.stats(regclass)
    IS 'columnar stripe statistics';
COMMENT ON FUNCTION columnar.upgrade_columnar_storage(regclass)
    IS 'function to upgrade the columnar storage, if necessary';
COMMENT ON FUNCTION columnar.downgrade_columnar_storage(regclass)
    IS 'function to downgrade the columnar storage, if necessary';

SET search_path TO columnar, pg_catalog;

CREATE AGGREGATE vcount(*) (
    SFUNC = vemptycount,
    STYPE = int8,
    INITCOND = '0',
    PARALLEL = SAFE
);

CREATE AGGREGATE vcount("any") (
    SFUNC = vanycount,
    STYPE = int8,
    INITCOND = '0',
    PARALLEL = SAFE
);

CREATE AGGREGATE vsum(int2) (
    SFUNC = vint2sum,
    STYPE = int8,
    INITCOND = '0',
    PARALLEL = SAFE
);

CREATE AGGREGATE vavg(int2) (
    SFUNC = vint2acc,
    STYPE = internal,
    FINALFUNC = vint2int4avg,
    INITCOND = '{0,0}',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmax(int2) (
    SFUNC = vint2larger,
    STYPE = int2,
    INITCOND = '-32768',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmin(int2) (
    SFUNC = vint2smaller,
    STYPE = int2,
    INITCOND = '32767',
    PARALLEL = SAFE
);

CREATE AGGREGATE vsum(int4) (
    SFUNC = vint4sum,
    STYPE = int8,
    INITCOND = '0',
    PARALLEL = SAFE
);

CREATE AGGREGATE vavg(int4) (
    SFUNC = vint4acc,
    STYPE = internal,
    FINALFUNC = vint2int4avg,
    INITCOND = '{0,0}',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmax(int4) (
    SFUNC = vint4larger,
    STYPE = int4,
    INITCOND = '-2147483648',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmin(int4) (
    SFUNC = vint4smaller,
    STYPE = int4,
    INITCOND = '2147483647',
    PARALLEL = SAFE
);

CREATE AGGREGATE vsum(int8) (
    SFUNC = vint8acc,
    STYPE = internal,
    FINALFUNC = vint8sum,
    PARALLEL = SAFE
);

CREATE AGGREGATE vavg(int8) (
    SFUNC = vint8acc,
    STYPE = internal,
    FINALFUNC = vint8avg,
    PARALLEL = SAFE
);

CREATE AGGREGATE vmax(int8) (
    SFUNC = vint8larger,
    STYPE = int8,
    INITCOND = '-9223372036854775808',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmin(int8) (
    SFUNC = vint8smaller,
    STYPE = int8,
    INITCOND = '9223372036854775807',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmax(date) (
    SFUNC = vdatelarger,
    STYPE = date,
    INITCOND = '-infinity',
    PARALLEL = SAFE
);

CREATE AGGREGATE vmin(date) (
    SFUNC = vdatesmaller,
    STYPE = date,
    INITCOND = 'infinity',
    PARALLEL = SAFE
);

RESET search_path;
