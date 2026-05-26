/*
 * Columnar PL/pgSQL support functions.
 *
 * This file is loaded by initdb after plpgsql is installed.  The standalone
 * backend input path used by initdb treats semicolon-newline-newline as the
 * command terminator, without parsing dollar-quoted function bodies.  Keep
 * PL/pgSQL function bodies free of literal ";\n\n" sequences.
 */

CREATE FUNCTION columnar.alter_table_set_access_method(t text, method text)
RETURNS boolean
LANGUAGE plpgsql
AS $func$
DECLARE
    tbl_exists boolean;
    tbl_schema text = 'public';
    tbl_name text;
    tbl_array text[] = (parse_ident(t));
    tbl_oid int;
    tbl_am_oid int;
    temp_tbl_name text;
    is_case_sensitive boolean;
    tbl_name_original text;
    tbl_schema_original text;
    trigger_list_definition text[];
    trigger text;
    index_list_definition text[];
    idx text;
    constraint_list_name_and_definition text[];
    constraint_name_and_definition text;
    constraint_name_and_definition_split text[];
BEGIN
    CASE
        WHEN cardinality(tbl_array) = 1 THEN
            SELECT tbl_array[1] INTO tbl_name;
        WHEN cardinality(tbl_array) = 2 THEN
            SELECT tbl_array[1] INTO tbl_schema;
            SELECT tbl_array[2] INTO tbl_name;
        ELSE
            RAISE WARNING 'Argument should provided as table or schema.table.';
            RETURN false;
    END CASE;
    IF method NOT IN ('columnar', 'heap') THEN
        RAISE WARNING 'Cannot convert table: Allowed access methods are heap and columnar.';
        RETURN false;
    END IF;
    SELECT EXISTS
        (SELECT FROM pg_catalog.pg_tables WHERE schemaname = tbl_schema AND tablename = tbl_name)
    INTO tbl_exists;
    IF tbl_exists = false THEN
        RAISE WARNING 'Table %.% does not exist.', tbl_schema, tbl_name;
        RETURN false;
    END IF;
    SELECT EXISTS (SELECT regexp_matches(tbl_name, '[A-Z]')) INTO is_case_sensitive;
    SELECT tbl_name INTO tbl_name_original;
    IF is_case_sensitive = true THEN
        SELECT quote_ident(tbl_name) INTO tbl_name;
    END IF;
    SELECT EXISTS (SELECT regexp_matches(tbl_schema, '[A-Z]')) INTO is_case_sensitive;
    SELECT tbl_schema INTO tbl_schema_original;
    IF is_case_sensitive = true THEN
        SELECT quote_ident(tbl_schema) INTO tbl_schema;
    END IF;
    EXECUTE format('SELECT %L::regclass::oid'::text, tbl_schema || '.' || tbl_name) INTO tbl_oid;
    SELECT relam FROM pg_class WHERE oid = tbl_oid INTO tbl_am_oid;
    IF (tbl_am_oid != (SELECT oid FROM pg_am WHERE amname = 'columnar')) AND
       (tbl_am_oid != (SELECT oid FROM pg_am WHERE amname = 'heap')) THEN
        RAISE WARNING 'Cannot convert table: table %.% is not heap or colummnar', tbl_schema, tbl_name;
        RETURN false;
    END IF;
    IF tbl_am_oid = (SELECT oid FROM pg_am WHERE amname = method) THEN
        RAISE WARNING 'Cannot convert table: conversion to same access method.';
        RETURN false;
    END IF;
    IF (SELECT count(1) FROM pg_constraint WHERE contype = 'f' AND conrelid = tbl_oid) > 0 THEN
        RAISE WARNING 'Cannot convert table: table %.% has a FOREIGN KEY constraint.', tbl_schema, tbl_name;
        RETURN false;
    END IF;
    IF (SELECT count(1) FROM pg_constraint WHERE contype = 'f' AND confrelid = tbl_oid) > 0 THEN
        RAISE WARNING 'Cannot convert table: table %.% is referenced by FOREIGN KEY.', tbl_schema, tbl_name;
        RETURN false;
    END IF;
    IF (SELECT count(1) FROM pg_attribute WHERE attrelid = tbl_oid AND attidentity <> '') > 0 THEN
        RAISE WARNING 'Cannot convert table: table %.% must not use GENERATED ... AS IDENTITY.', tbl_schema, tbl_name;
        RETURN false;
    END IF;
    SELECT array_agg(pg_get_triggerdef(oid)) FROM pg_trigger
        WHERE tgrelid = tbl_oid INTO trigger_list_definition;
    SELECT array_agg(pg_constraint.conname || '?' || pg_get_constraintdef(pg_constraint.oid))
        FROM pg_constraint, pg_class
        WHERE pg_constraint.conindid = pg_class.oid
            AND pg_constraint.conrelid = tbl_oid
            AND pg_class.relam IN (SELECT oid FROM pg_am WHERE amname IN ('btree', 'hash'))
        INTO constraint_list_name_and_definition;
    SELECT array_agg(indexdef) FROM pg_indexes
        WHERE schemaname = tbl_schema_original AND tablename = tbl_name_original
            AND quote_ident(indexname)::regclass::oid IN
                (
                    SELECT indexrelid FROM pg_index
                    WHERE indexrelid IN
                            (SELECT quote_ident(indexname)::regclass::oid FROM pg_indexes
                                WHERE schemaname = tbl_schema_original AND tablename = tbl_name_original)
                        AND indexrelid NOT IN
                            (SELECT conindid FROM pg_constraint
                                WHERE pg_constraint.conrelid = tbl_oid)
                )
        INTO index_list_definition;
    SELECT 't_' || substr(md5(random()::text), 0, 25) INTO temp_tbl_name;
    EXECUTE format('
        CREATE TABLE %s (LIKE %s.%s
                         INCLUDING GENERATED
                         INCLUDING DEFAULTS
        ) USING %s'::text, temp_tbl_name, tbl_schema, tbl_name, method);
    EXECUTE format('INSERT INTO %s SELECT * FROM %s.%s'::text, temp_tbl_name, tbl_schema, tbl_name);
    EXECUTE format('DROP TABLE %s'::text, tbl_name);
    EXECUTE format('ALTER TABLE %s RENAME TO %s;'::text, temp_tbl_name, tbl_name);
    EXECUTE format('SELECT count(1) FROM %s LIMIT 1;'::text, tbl_name);
    IF cardinality(index_list_definition) <> 0 THEN
        FOREACH idx IN ARRAY index_list_definition
        LOOP
            BEGIN
                EXECUTE idx;
            EXCEPTION WHEN feature_not_supported THEN
               RAISE WARNING 'Index `%` cannot be created.', idx;
            END;
        END LOOP;
    END IF;
    IF cardinality(constraint_list_name_and_definition) <> 0 THEN
        FOREACH constraint_name_and_definition IN ARRAY constraint_list_name_and_definition
        LOOP
            SELECT string_to_array(constraint_name_and_definition, '?') INTO constraint_name_and_definition_split;
            BEGIN
                EXECUTE 'ALTER TABLE ' || tbl_name || ' ADD CONSTRAINT '
                            || constraint_name_and_definition_split[1] || ' '
                            || constraint_name_and_definition_split[2];
            EXCEPTION WHEN feature_not_supported THEN
               RAISE WARNING 'Constraint `%` cannot be added.', constraint_name_and_definition_split[2];
             END;
        END LOOP;
    END IF;
    IF cardinality(trigger_list_definition) <> 0 THEN
        FOREACH trigger IN ARRAY trigger_list_definition
        LOOP
            BEGIN
                EXECUTE trigger;
            EXCEPTION WHEN feature_not_supported THEN
               RAISE WARNING 'Trigger `%` cannot be applied.', trigger;
               RAISE WARNING
                'Foreign keys and AFTER ROW triggers are not supported for columnar tables.'
                ' Consider an AFTER STATEMENT trigger instead.';
            END;
        END LOOP;
    END IF;
    RETURN true;
END;
$func$;

COMMENT ON FUNCTION columnar.alter_table_set_access_method(t text, method text)
  IS 'alters a table''s access method';

CREATE FUNCTION columnar.vacuum(tablename regclass, stripe_count int DEFAULT 0)
RETURNS int
LANGUAGE plpgsql
AS $func$
DECLARE
  count int;
  stripes int;
BEGIN
  count := 1;
  stripes := 0;
  WHILE count > 0 AND (stripe_count = 0 OR stripes < stripe_count) LOOP
    SELECT columnar._vacuum_internal(tablename, stripe_count) INTO count;
    stripes := stripes + count;
  END LOOP;
  RETURN stripes;
END;
$func$;

COMMENT ON FUNCTION columnar.vacuum(regclass, int)
  IS 'vacuum columnar table function';

CREATE FUNCTION columnar.vacuum_full(schema name DEFAULT 'public', sleep_time real DEFAULT .1, stripe_count int DEFAULT 25)
RETURNS void
LANGUAGE plpgsql
AS $func$
DECLARE
  tables regclass[];
  tablename regclass;
  count int;
BEGIN
  SELECT array_agg(c.relname) INTO tables
  FROM pg_catalog.pg_class c
      LEFT JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
      LEFT JOIN pg_catalog.pg_am am ON am.oid = c.relam
  WHERE c.relkind = 'r'
        AND n.nspname <> 'pg_catalog'
        AND n.nspname !~ '^pg_toast'
        AND n.nspname <> 'information_schema'
    AND pg_catalog.pg_table_is_visible(c.oid)
    AND am.amname = 'columnar'
    AND n.nspname = schema
  ORDER BY 1;
  FOREACH tablename IN ARRAY tables
  LOOP
    count := 1;
    WHILE count > 0 LOOP
      SELECT columnar.vacuum(tablename, stripe_count) INTO count;
      PERFORM pg_sleep(sleep_time);
    END LOOP;
  END LOOP;
END;
$func$;

COMMENT ON FUNCTION columnar.vacuum_full(name, real, int)
  IS 'vacuum columnar schema in full incrementally';
