-- Trigger coverage for built-in columnar tables.

CREATE SCHEMA columnar_trigger;
SET search_path TO columnar_trigger, public;
SET columnar.compression TO 'none';

CREATE OR REPLACE FUNCTION trs_before() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'BEFORE STATEMENT %', TG_OP;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trs_after() RETURNS trigger LANGUAGE plpgsql AS $$
DECLARE
    r record;
BEGIN
    RAISE NOTICE 'AFTER STATEMENT %', TG_OP;
    IF (TG_OP = 'DELETE') THEN
        FOR r IN SELECT * FROM old_table LOOP
            RAISE NOTICE '  (%)', r.i;
        END LOOP;
    ELSE
        FOR r IN SELECT * FROM new_table LOOP
            RAISE NOTICE '  (%)', r.i;
        END LOOP;
    END IF;
    RETURN NULL;
END;
$$;

CREATE OR REPLACE FUNCTION trr_before() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'BEFORE ROW %: (%)', TG_OP, NEW.i;
    RETURN NEW;
END;
$$;

CREATE OR REPLACE FUNCTION trr_after() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    RAISE NOTICE 'AFTER ROW %: (%)', TG_OP, NEW.i;
    RETURN NEW;
END;
$$;

CREATE TABLE test_tr(i int) USING columnar;

CREATE TRIGGER tr_before_stmt BEFORE INSERT ON test_tr
    FOR EACH STATEMENT EXECUTE PROCEDURE trs_before();
CREATE TRIGGER tr_after_stmt AFTER INSERT ON test_tr
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT EXECUTE PROCEDURE trs_after();
CREATE TRIGGER tr_before_row BEFORE INSERT ON test_tr
    FOR EACH ROW EXECUTE PROCEDURE trr_before();

CREATE TRIGGER tr_after_row AFTER INSERT ON test_tr
    FOR EACH ROW EXECUTE PROCEDURE trr_after();

INSERT INTO test_tr VALUES (1);
INSERT INTO test_tr VALUES (2), (3), (4);

SELECT * FROM test_tr ORDER BY i;

DROP TABLE test_tr;

CREATE TABLE test_tr_referenced(i int PRIMARY KEY);
CREATE TABLE test_tr_referencing(j int REFERENCES test_tr_referenced(i)) USING columnar;
DROP TABLE test_tr_referenced;

CREATE TABLE test_tr_p(i int) PARTITION BY RANGE (i);
CREATE TRIGGER test_tr_p_tr AFTER UPDATE ON test_tr_p
    FOR EACH ROW EXECUTE PROCEDURE trr_after();
CREATE TABLE test_tr_p0 PARTITION OF test_tr_p
    FOR VALUES FROM (0) TO (10);
CREATE TABLE test_tr_p1 PARTITION OF test_tr_p
    FOR VALUES FROM (10) TO (20) USING columnar;
CREATE TABLE test_tr_p2(i int) USING columnar;
ALTER TABLE test_tr_p ATTACH PARTITION test_tr_p2 FOR VALUES FROM (20) TO (30);
DROP TABLE test_tr_p;
DROP TABLE test_tr_p2;

CREATE TABLE test_pk(n int PRIMARY KEY);
CREATE TABLE test_fk_p(i int REFERENCES test_pk(n)) PARTITION BY RANGE (i);
CREATE TABLE test_fk_p0 PARTITION OF test_fk_p FOR VALUES FROM (0) TO (10);
CREATE TABLE test_fk_p1 PARTITION OF test_fk_p FOR VALUES FROM (10) TO (20) USING columnar;
CREATE TABLE test_fk_p2(i int) USING columnar;
ALTER TABLE test_fk_p ATTACH PARTITION test_fk_p2 FOR VALUES FROM (20) TO (30);
DROP TABLE test_fk_p;
DROP TABLE test_fk_p2;
DROP TABLE test_pk;

CREATE TABLE test_tr(i int) USING columnar;

CREATE SEQUENCE counter START 100;
CREATE OR REPLACE FUNCTION trs_after_erroring() RETURNS trigger LANGUAGE plpgsql AS $$
BEGIN
    IF nextval('counter') % 2 = 0 THEN
        RAISE EXCEPTION '%', 'error';
    END IF;
    RETURN NULL;
END;
$$;

CREATE TRIGGER tr_after_stmt_erroring AFTER INSERT ON test_tr
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT EXECUTE PROCEDURE trs_after_erroring();

INSERT INTO test_tr VALUES (5);
INSERT INTO test_tr VALUES (6);
SELECT * FROM test_tr ORDER BY i;

DROP TABLE test_tr;
DROP SEQUENCE counter;

CREATE TABLE events(
    user_id bigint,
    event_id bigint,
    event_time timestamp DEFAULT now(),
    value float DEFAULT random())
    PARTITION BY RANGE (event_time);

CREATE TABLE events_p2020_11_04_102965
    PARTITION OF events
    FOR VALUES FROM ('2020-11-04 00:00:00+01') TO ('2020-11-05 00:00:00+01')
    USING columnar;

CREATE TABLE events_trigger_target(
    user_id bigint,
    avg float,
    __count__ bigint
) USING columnar;

CREATE OR REPLACE FUNCTION user_value_by_day()
RETURNS trigger
LANGUAGE plpgsql
AS $function$
BEGIN
    IF (TG_OP = 'INSERT' OR TG_OP = 'UPDATE') THEN
        EXECUTE format($exec_format$INSERT INTO %s AS __mat__ SELECT user_id, 0.1 AS avg, pg_catalog.count(*) AS __count__ FROM __ins__ events GROUP BY user_id;
                       $exec_format$, TG_ARGV[0]);
    END IF;
    IF (TG_OP = 'DELETE' OR TG_OP = 'UPDATE') THEN
        RAISE EXCEPTION $ex$MATERIALIZED VIEW 'user_value_by_day' on table 'events' does not support UPDATE/DELETE$ex$;
    END IF;
    IF (TG_OP = 'TRUNCATE') THEN
        EXECUTE format($exec_format$TRUNCATE TABLE %s; $exec_format$, TG_ARGV[0]);
    END IF;
    RETURN NULL;
END;
$function$;

CREATE TRIGGER "user_value_by_day_INSERT" AFTER INSERT ON events
    REFERENCING NEW TABLE AS __ins__
    FOR EACH STATEMENT EXECUTE FUNCTION user_value_by_day('events_trigger_target');

COPY events FROM STDIN WITH (FORMAT 'csv');
1,1,"2020-11-04 15:54:02.226999-08",1.1
2,3,"2020-11-04 16:54:02.226999-08",2.2
\.

SELECT * FROM events ORDER BY user_id;
SELECT * FROM events_trigger_target ORDER BY user_id;

DROP TABLE events;
DROP TABLE events_trigger_target;
DROP FUNCTION trs_before(), trs_after(), trr_before(), trr_after(), trs_after_erroring(), user_value_by_day();
RESET search_path;
DROP SCHEMA columnar_trigger;
