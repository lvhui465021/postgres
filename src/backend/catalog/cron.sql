--
-- cron.sql -- pg_cron built-in schema, tables, functions and triggers.
--
-- This file is loaded during initdb to set up the pg_cron job scheduler.
-- The pg_catalog.pg_cron_job shared relation already exists at this point
-- (created during BKI bootstrap by pg_cron_job.h/pg_cron_job.dat).
--

-- Schema for non-shared cron objects (functions, job_run_details table)
CREATE SCHEMA cron;

-- Sequence for job IDs
CREATE SEQUENCE cron.jobid_seq;

-- Sequence for run IDs (audit log)
CREATE SEQUENCE cron.runid_seq;

-- Add defaults and constraints to the shared pg_catalog.pg_cron_job table
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN jobid
    SET DEFAULT pg_catalog.nextval('cron.jobid_seq');
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN nodename
    SET DEFAULT 'localhost';
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN nodeport
    SET DEFAULT pg_catalog.inet_server_port();
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN database
    SET DEFAULT pg_catalog.current_database();
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN username
    SET DEFAULT current_user;
ALTER TABLE pg_catalog.pg_cron_job ALTER COLUMN active
    SET DEFAULT true;

-- Primary key and unique indexes are declared via BKI (pg_cron_job.h)
-- and created during bootstrap.  No additional SQL needed here.

-- Row-level security: users can only see their own jobs
ALTER TABLE pg_catalog.pg_cron_job ENABLE ROW LEVEL SECURITY;
CREATE POLICY cron_job_policy ON pg_catalog.pg_cron_job
    USING (username OPERATOR(pg_catalog.=) current_user);

-- Job run details audit table (per-database, in cron schema)
CREATE TABLE cron.job_run_details (
    jobid bigint NOT NULL,
    runid bigint NOT NULL,
    job_pid integer,
    database text NOT NULL,
    username text NOT NULL,
    command text NOT NULL,
    status text,
    return_message text,
    start_time timestamptz,
    end_time timestamptz
);

-- SQL-callable wrapper functions in the cron schema.
-- The actual C implementations are registered in pg_proc.dat (pg_catalog).
CREATE FUNCTION cron.schedule(schedule text, command text)
    RETURNS bigint LANGUAGE sql STRICT
    AS $$SELECT pg_catalog.cron_schedule($1, $2)$$;

CREATE FUNCTION cron.schedule(job_name text, schedule text, command text,
                              database text DEFAULT NULL,
                              username text DEFAULT NULL,
                              active boolean DEFAULT true)
    RETURNS bigint LANGUAGE sql
    AS $$SELECT pg_catalog.cron_schedule_named($1, $2, $3, $4, $5, $6)$$;

CREATE FUNCTION cron.unschedule(job_id bigint)
    RETURNS bool LANGUAGE sql STRICT
    AS $$SELECT pg_catalog.cron_unschedule($1)$$;

CREATE FUNCTION cron.unschedule(job_name text)
    RETURNS bool LANGUAGE sql STRICT
    AS $$SELECT pg_catalog.cron_unschedule_named($1)$$;

CREATE FUNCTION cron.alter_job(job_id bigint,
                                schedule text DEFAULT NULL,
                                command text DEFAULT NULL,
                                database text DEFAULT NULL,
                                username text DEFAULT NULL,
                                active boolean DEFAULT NULL)
    RETURNS void LANGUAGE sql
    AS $$SELECT pg_catalog.cron_alter_job($1, $2, $3, $4, $5, $6)$$;

-- Trigger to invalidate the job cache when jobs are modified.
-- Uses the pg_catalog function directly (registered in pg_proc.dat).
CREATE TRIGGER cron_job_cache_invalidate
    AFTER INSERT OR UPDATE OR DELETE OR TRUNCATE
    ON pg_catalog.pg_cron_job
    FOR STATEMENT EXECUTE FUNCTION pg_catalog.cron_job_cache_invalidate();
