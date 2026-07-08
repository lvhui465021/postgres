/*-------------------------------------------------------------------------
 *
 * spi_demo.c
 *	  Demonstration of PostgreSQL SPI (Server Programming Interface).
 *
 * This file demonstrates:
 *	- SPI_connect / SPI_finish lifecycle
 *	- Parameterized SELECT via SPI_execute_with_args
 *	- Parameterized UPDATE via SPI_execute_with_args
 *	- Dynamic SQL SELECT via SPI_execute + appendStringInfo
 *	- Dynamic SQL INSERT via SPI_execute + appendStringInfo
 *	- Fixed SQL via SPI_execute (no string building needed)
 *	- Accessing result tuples via SPI_tuptable, SPI_getbinval, SPI_getvalue
 *	- Checking SPI_processed and SPI_result for error handling
 *
 * Assumes a table pg_test(oid, testname text, created_at timestamp) exists.
 *
 * IDENTIFICATION
 *	  src/backend/utils/spi_demo.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "catalog/pg_trigger.h"
#include "executor/spi.h"
#include "fmgr.h"
#include "lib/stringinfo.h"
#include "utils/builtins.h"
#include "utils/spi_demo.h"


PG_MODULE_MAGIC;

/* ----------------------------------------------------------------
 * get_test_by_name
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION get_test_by_name(name text)
 *     RETURNS oid
 *     AS 'MODULE_PATHNAME', 'get_test_by_name'
 *     LANGUAGE C STRICT;
 *
 * Uses SPI to execute a parameterized SELECT on pg_test,
 * looking up the row by testname, and returns the matching oid.
 * Returns NULL if no matching row exists.
 *
 * Demonstrates:
 *   - SPI_connect / SPI_finish
 *   - SPI_execute_with_args (parameterized query)
 *   - SPI_processed (number of result rows)
 *   - SPI_getbinval (extracting a column value in internal form)
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(get_test_by_name);

Datum
get_test_by_name(PG_FUNCTION_ARGS)
{
	text	   *t_name = PG_GETARG_TEXT_PP(0);
	char	   *name_str;
	int			spi_rc;
	Oid			result_oid = InvalidOid;

	/*
	 * Convert the SQL text argument to a C string.  text_to_cstring allocates
	 * in the caller's memory context, which is fine before SPI_connect.
	 */
	name_str = text_to_cstring(t_name);

	/*
	 * Open an SPI connection.  Must be paired with SPI_finish.  All memory
	 * allocated via palloc/SPI_palloc between connect and finish lives in a
	 * dedicated SPI memory context and will be freed by SPI_finish.
	 */
	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Execute a parameterized SELECT.  Using SPI_execute_with_args (rather
	 * than building a SQL string with snprintf) prevents SQL injection and
	 * allows the planner to cache the plan.
	 *
	 * Parameters:
	 *   query string, nargs, argtypes[], values[], nulls[], read_only, tcount
	 *
	 * TEXTOID parameters are passed by reference: Datum is a pointer to the
	 * null-terminated C string.
	 */
	{
		Oid			argtypes[1] = {TEXTOID};
		Datum		values[1] = {CStringGetDatum(name_str)};
		char		nulls[1] = {' '};	/* ' ' = not null */

		spi_rc = SPI_execute_with_args(
			"SELECT oid, testname, created_at FROM pg_test WHERE testname = $1",
			1, argtypes, values, nulls,
			true,	/* read_only: true for SELECT */
			0		/* tcount: 0 = return all matching rows */
		);
	}

	/*
	 * Check the return code.  SPI_OK_SELECT means the query executed
	 * successfully and returned a result set (possibly empty).
	 */
	if (spi_rc != SPI_OK_SELECT)
		elog(ERROR, "SELECT query failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * SPI_processed tells us how many rows were returned.  If at least one
	 * row exists, extract the oid column (attribute number 1) from the first
	 * result tuple using SPI_getbinval, which returns the value in internal
	 * (Datum) form.
	 */
	if (SPI_processed > 0)
	{
		HeapTuple	row = SPI_tuptable->vals[0];
		TupleDesc	tupdesc = SPI_tuptable->tupdesc;
		bool		isnull;

		result_oid = DatumGetObjectId(
			SPI_getbinval(row, tupdesc, 1, &isnull));

		/* The oid column of pg_test should never be NULL, but check anyway */
		if (isnull)
			result_oid = InvalidOid;
	}

	/*
	 * Release all SPI resources and restore the previous memory context.
	 */
	SPI_finish();

	if (OidIsValid(result_oid))
		PG_RETURN_OID(result_oid);
	else
		PG_RETURN_NULL();
}


/* ----------------------------------------------------------------
 * update_test_timestamp
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION update_test_timestamp(name text)
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'update_test_timestamp'
 *     LANGUAGE C STRICT;
 *
 * Uses SPI to execute a parameterized UPDATE on pg_test, setting the
 * created_at column of the matching row to the current timestamp.
 *
 * Demonstrates:
 *   - SPI_execute_with_args for data-modifying statements
 *   - Parameterized UPDATE with text parameter
 *   - SPI_processed to check how many rows were affected
 *   - Reporting results via ereport / elog
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(update_test_timestamp);

Datum
update_test_timestamp(PG_FUNCTION_ARGS)
{
	text	   *t_name = PG_GETARG_TEXT_PP(0);
	char	   *name_str;
	int			spi_rc;

	/* Convert input text to C string */
	name_str = text_to_cstring(t_name);

	/* Open SPI connection */
	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Execute a parameterized UPDATE.  We use SQL now() to set the current
	 * timestamp, demonstrating that arbitrary SQL expressions can be part of
	 * the query string.  The single parameter ($1) is the testname.
	 */
	{
		Oid			argtypes[1] = {TEXTOID};
		Datum		values[1] = {CStringGetDatum(name_str)};
		char		nulls[1] = {' '};

		spi_rc = SPI_execute_with_args(
			"UPDATE pg_test SET created_at = now() WHERE testname = $1",
			1, argtypes, values, nulls,
			false,	/* read_only: false for UPDATE */
			0		/* tcount: 0 = update all matching rows */
		);
	}

	/*
	 * SPI_OK_UPDATE means the UPDATE executed successfully.  It does NOT
	 * necessarily mean any rows were modified -- check SPI_processed for
	 * the actual number of rows affected.
	 */
	if (spi_rc != SPI_OK_UPDATE)
		elog(ERROR, "UPDATE query failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Report the result.  Use ereport with errmsg for user-visible messages
	 * (appears in the client), or elog for server log.  Here we use NOTICE
	 * to inform the caller how many rows were updated.
	 */
	if (SPI_processed > 0)
		ereport(NOTICE,
				(errmsg("updated %lld row(s) in pg_test for testname \"%s\"",
						(long long) SPI_processed, name_str)));
	else
		ereport(NOTICE,
				(errmsg("no rows found in pg_test with testname \"%s\"",
						name_str)));

	/* Release SPI resources */
	SPI_finish();

	PG_RETURN_VOID();
}


/* ----------------------------------------------------------------
 * spi_execute_list
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_execute_list(name text)
 *     RETURNS SETOF RECORD
 *     AS 'MODULE_PATHNAME', 'spi_execute_list'
 *     LANGUAGE C STRICT;
 *
 * Demonstrates SPI_execute() for SELECT: builds the SQL string
 * dynamically using appendStringInfo + quote_literal_cstr for safe
 * escaping.  appendStringInfo uses a StringInfo buffer that auto-grows,
 * so there is no risk of truncation (unlike snprintf with a fixed-size
 * buffer).
 *
 * Key differences from SPI_execute_with_args:
 *   - You must build the SQL string yourself
 *   - String values MUST be quoted/escaped by hand
 *   - No plan caching — every call re-parses the query
 *   - Simpler API: (src, read_only, tcount) — only 3 params
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(spi_execute_list);

Datum
spi_execute_list(PG_FUNCTION_ARGS)
{
	text	   *t_name = PG_GETARG_TEXT_PP(0);
	char	   *name_str;
	int			spi_rc;

	name_str = text_to_cstring(t_name);

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Build the SQL string with appendStringInfo.  quote_literal_cstr()
	 * escapes the string value to prevent SQL injection.  ALWAYS escape
	 * user input when using SPI_execute() — unlike SPI_execute_with_args,
	 * the query string is sent as-is to the parser.
	 *
	 * StringInfo auto-grows via palloc, so there is no fixed-size buffer
	 * limit.  The buffer is allocated in the SPI memory context (after
	 * SPI_connect), and thus freed automatically by SPI_finish().  We
	 * still pfree() it explicitly as a good habit.
	 */
	{
		StringInfoData	sql;

		initStringInfo(&sql);
		appendStringInfo(&sql,
						 "SELECT oid, testname, created_at FROM pg_test "
						 "WHERE testname = %s",
						 quote_literal_cstr(name_str));

		/*
		 * SPI_execute parameters:
		 *   src       — the SQL string (must be null-terminated)
		 *   read_only — true for SELECT (allows planner optimization)
		 *   tcount    — max rows to return; 0 = no limit
		 */
		spi_rc = SPI_execute(sql.data, true, 0);
		pfree(sql.data);
	}

	if (spi_rc != SPI_OK_SELECT)
		elog(ERROR, "SELECT failed: %s", SPI_result_code_string(spi_rc));

	/*
	 * Iterate all returned rows and emit a NOTICE for each.
	 * In a real function you'd use SRF (set-returning function) machinery
	 * to return rows; here we just print to demonstrate the pattern.
	 */
	if (SPI_processed > 0)
	{
		TupleDesc	tupdesc = SPI_tuptable->tupdesc;
		uint64		i;

		for (i = 0; i < SPI_processed; i++)
		{
			HeapTuple	row = SPI_tuptable->vals[i];
			bool		isnull;
			Datum		oid_datum;
			char	   *testname;

			oid_datum = SPI_getbinval(row, tupdesc, 1, &isnull);
			testname  = SPI_getvalue(row, tupdesc, 2);

			ereport(NOTICE,
					(errmsg("row %lld: oid=%u, testname=\"%s\"",
							(long long) i,
							isnull ? 0 : DatumGetObjectId(oid_datum),
							testname ? testname : "(null)")));
		}
	}
	else
		ereport(NOTICE, (errmsg("no rows matched")));

	SPI_finish();
	PG_RETURN_VOID();
}


/* ----------------------------------------------------------------
 * spi_execute_insert
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_execute_insert(
 *       name text, p_oid oid DEFAULT NULL)
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'spi_execute_insert'
 *     LANGUAGE C;
 *
 * Demonstrates SPI_execute() for INSERT.  Builds an INSERT statement
 * by hand with appendStringInfo, using quote_literal_cstr for the text
 * value and explicit conversion for the oid.
 *
 * SPI_execute() with read_only=false returns:
 *   SPI_OK_INSERT  — INSERT executed successfully
 *   SPI_processed  — number of rows inserted (usually 1)
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(spi_execute_insert);

Datum
spi_execute_insert(PG_FUNCTION_ARGS)
{
	text	   *t_name;
	char	   *name_str;
	Oid			p_oid = InvalidOid;
	bool		oid_isnull;
	int			spi_rc;

	/* Argument handling: text is required, oid is optional */
	if (PG_ARGISNULL(0))
		ereport(ERROR, (errmsg("name must not be null")));
	t_name = PG_GETARG_TEXT_PP(0);
	name_str = text_to_cstring(t_name);

	oid_isnull = PG_ARGISNULL(1);
	if (!oid_isnull)
		p_oid = PG_GETARG_OID(1);

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Build the INSERT string with appendStringInfo.  When p_oid is
	 * provided we include it; otherwise let it default.  quote_literal_cstr
	 * handles the text column.  StringInfo auto-grows, so no truncation
	 * risk.
	 */
	{
		StringInfoData	sql;

		initStringInfo(&sql);

		if (oid_isnull)
			appendStringInfo(&sql,
							 "INSERT INTO pg_test (testname, created_at) "
							 "VALUES (%s, now())",
							 quote_literal_cstr(name_str));
		else
			appendStringInfo(&sql,
							 "INSERT INTO pg_test (oid, testname, created_at) "
							 "VALUES (%u, %s, now())",
							 p_oid, quote_literal_cstr(name_str));

		/* read_only=false because this modifies data */
		spi_rc = SPI_execute(sql.data, false, 0);
		pfree(sql.data);
	}

	if (spi_rc != SPI_OK_INSERT)
		elog(ERROR, "INSERT failed: %s", SPI_result_code_string(spi_rc));

	ereport(NOTICE,
			(errmsg("inserted %lld row(s)", (long long) SPI_processed)));

	SPI_finish();
	PG_RETURN_VOID();
}


/* ----------------------------------------------------------------
 * spi_execute_count
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_execute_count()
 *     RETURNS bigint
 *     AS 'MODULE_PATHNAME', 'spi_execute_count'
 *     LANGUAGE C;
 *
 * Demonstrates SPI_execute() for a simple COUNT query that needs
 * no parameters.  This is the simplest possible use of SPI_execute:
 * a fixed query string with no user input to escape.
 *
 * Also shows how to return a scalar via SPI_getbinval.
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(spi_execute_count);

Datum
spi_execute_count(PG_FUNCTION_ARGS)
{
	int			spi_rc;
	int64		count = 0;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Fixed query — no parameters, no escaping needed.
	 * This is SPI_execute's sweet spot: dead simple.
	 */
	spi_rc = SPI_execute("SELECT count(*) FROM pg_test", true, 0);

	if (spi_rc != SPI_OK_SELECT)
		elog(ERROR, "SELECT count(*) failed: %s",
			 SPI_result_code_string(spi_rc));

	/* Extract the count from the first (and only) result row */
	if (SPI_processed > 0)
	{
		HeapTuple	row = SPI_tuptable->vals[0];
		TupleDesc	tupdesc = SPI_tuptable->tupdesc;
		bool		isnull;

		count = DatumGetInt64(SPI_getbinval(row, tupdesc, 1, &isnull));
		if (isnull)
			count = 0;
	}

	SPI_finish();
	PG_RETURN_INT64(count);
}


/* ----------------------------------------------------------------
 * copy_triggers
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION copy_triggers(
 *       src_table text, dst_table text)
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'copy_triggers'
 *     LANGUAGE C;
 *
 * Copies all non-internal triggers from src_table to dst_table.
 *
 * Workflow:
 *   1. Query pg_trigger (joined with pg_proc) to list triggers on src_table.
 *   2. For each trigger, build CREATE TRIGGER DDL with StringInfo by
 *      interpreting the tgtype bitmask (BEFORE/AFTER/INSTEAD OF,
 *      INSERT/UPDATE/DELETE/TRUNCATE, FOR EACH ROW/STATEMENT).
 *   3. Execute the DDL via SPI_execute().
 *
 * Demonstrates:
 *   - Reading from system catalogs (pg_trigger, pg_proc) via SPI
 *   - Parsing tgtype bitmask into SQL keywords
 *   - Parsing tgargs bytea (null-separated argument list)
 *   - Building DDL dynamically with StringInfo
 *   - Executing generated DDL via SPI
 * ----------------------------------------------------------------
 */
PG_FUNCTION_INFO_V1(copy_triggers);

/*
 * Trigger metadata extracted from pg_trigger via pg_get_triggerdef.
 * We save the DDL text before the execution loop, because each SPI_execute
 * call frees the previous SPI_tuptable.
 */
typedef struct TriggerDef
{
	char	   *tgname;			/* trigger name (for logging) */
	char	   *ddl;				/* DDL from pg_get_triggerdef */
	char		tgenabled;		/* O=origin, D=disabled, R=replica, A=always */
} TriggerDef;

Datum
copy_triggers(PG_FUNCTION_ARGS)
{
	text	   *src = PG_GETARG_TEXT_PP(0);
	text	   *dst = PG_GETARG_TEXT_PP(1);
	char	   *src_name = text_to_cstring(src);
	char	   *dst_name = text_to_cstring(dst);
	char	   *src_canonical;		/* schema.quoted_ident as output by ::regclass::text */
	char	   *dst_canonical;
	int			spi_rc;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Phase 1 — Resolve both table names to their canonical, schema-qualified
	 * form using ::regclass::text.  This ensures pg_get_triggerdef's output
	 * (which uses the canonical form) matches exactly for string replacement.
	 */
	{
		StringInfoData	resolve_sql;
		int				resolve_rc;

		initStringInfo(&resolve_sql);
		appendStringInfo(&resolve_sql,
			"SELECT $1::regclass::text, $2::regclass::text");

		{
			Oid			argtypes[2] = {TEXTOID, TEXTOID};
			Datum		values[2] = {CStringGetDatum(src_name),
									 CStringGetDatum(dst_name)};
			char		nulls[2] = {' ', ' '};

			resolve_rc = SPI_execute_with_args(resolve_sql.data,
											   2, argtypes, values, nulls,
											   true, 0);
		}

		pfree(resolve_sql.data);

		if (resolve_rc != SPI_OK_SELECT || SPI_processed != 1)
			ereport(ERROR,
					(errmsg("cannot resolve table names \"%s\" or \"%s\"",
							src_name, dst_name)));

		src_canonical = SPI_getvalue(SPI_tuptable->vals[0],
									 SPI_tuptable->tupdesc, 1);
		dst_canonical = SPI_getvalue(SPI_tuptable->vals[0],
									 SPI_tuptable->tupdesc, 2);
	}

	ereport(NOTICE,
			(errmsg("source: \"%s\" → canonical: \"%s\"; "
					"dest: \"%s\" → canonical: \"%s\"",
					src_name, src_canonical, dst_name, dst_canonical)));

	/*
	 * Phase 2 — Query pg_trigger and call pg_get_triggerdef for each.
	 * pg_get_triggerdef() returns the complete CREATE TRIGGER DDL.
	 *
	 * We also fetch tgenabled to handle DISABLED triggers after creation.
	 */
	{
		Oid			argtypes[1] = {TEXTOID};
		Datum		values[1] = {CStringGetDatum(src_name)};
		char		nulls[1] = {' '};

		spi_rc = SPI_execute_with_args(
			"SELECT t.tgname, pg_get_triggerdef(t.oid) AS ddl, t.tgenabled "
			"FROM pg_trigger t "
			"WHERE t.tgrelid = $1::regclass::oid "
			"  AND NOT t.tgisinternal "
			"ORDER BY t.tgname",
			1, argtypes, values, nulls,
			true, 0);
	}

	if (spi_rc != SPI_OK_SELECT)
		elog(ERROR, "failed to query pg_trigger: %s",
			 SPI_result_code_string(spi_rc));

	ereport(NOTICE,
			(errmsg("found %lld trigger(s) on \"%s\"",
					(long long) SPI_processed, src_name)));

	/*
	 * Phase 3 — Copy results into local array BEFORE any further SPI calls.
	 * Subsequent SPI_execute calls will free this SPI_tuptable.
	 */
	if (SPI_processed > 0)
	{
		TupleDesc	tupdesc = SPI_tuptable->tupdesc;
		uint64		total = SPI_processed;
		TriggerDef *triggers;
		uint64		i;

		triggers = (TriggerDef *) palloc0(sizeof(TriggerDef) * total);

		for (i = 0; i < total; i++)
		{
			HeapTuple	row = SPI_tuptable->vals[i];
			TriggerDef *td = &triggers[i];
			bool		isnull;
			Datum		d;

			td->tgname = SPI_getvalue(row, tupdesc, 1);
			td->ddl    = SPI_getvalue(row, tupdesc, 2);
			d = SPI_getbinval(row, tupdesc, 3, &isnull);
			td->tgenabled = isnull ? 'O' : DatumGetChar(d);
		}

		/*
		 * Phase 4 — Now safe to call SPI_execute.  For each trigger:
		 *   1. Replace the canonical src table name → dst table name in the DDL
		 *   2. Execute the modified DDL
		 *   3. If trigger was disabled, ALTER TABLE ... DISABLE TRIGGER
		 */
		int			created = 0;

		for (i = 0; i < total; i++)
		{
			TriggerDef *td = &triggers[i];
			StringInfoData	ddl;

			initStringInfo(&ddl);

			/*
			 * Replace all occurrences of the canonical src table name with
			 * the canonical dst table name.  Using the canonical form
			 * (schema.quoted_ident) makes the replacement exact.
			 *
			 * The table name appears in the DDL as:
			 *   CREATE TRIGGER name ... ON schema.table ...
			 *
			 * By matching the full canonical form we avoid false positives.
			 */
			{
				const char *p = td->ddl;
				size_t		srclen = strlen(src_canonical);

				while (*p)
				{
					if (strncmp(p, src_canonical, srclen) == 0)
					{
						appendStringInfoString(&ddl, dst_canonical);
						p += srclen;
					}
					else
					{
						appendStringInfoChar(&ddl, *p);
						p++;
					}
				}
			}

			/* ---------- Execute the DDL ---------- */
			ereport(DEBUG1,
					(errmsg("executing: %s", ddl.data)));

			spi_rc = SPI_execute(ddl.data, false, 0);
			if (spi_rc != SPI_OK_UTILITY)
				ereport(WARNING,
						(errmsg("failed to create trigger \"%s\": %s",
								td->tgname, SPI_result_code_string(spi_rc))));
			else
			{
				created++;

				/* Handle disabled trigger */
				if (td->tgenabled == 'D')
				{
					StringInfoData	alt;
					initStringInfo(&alt);
					appendStringInfo(&alt,
						"ALTER TABLE %s DISABLE TRIGGER %s",
						quote_identifier(dst_name),
						quote_identifier(td->tgname));
					spi_rc = SPI_execute(alt.data, false, 0);
					if (spi_rc != SPI_OK_UTILITY)
						ereport(WARNING,
								(errmsg("trigger \"%s\" created but could "
										"not disable: %s",
										td->tgname,
										SPI_result_code_string(spi_rc))));
					pfree(alt.data);
				}
			}

			pfree(ddl.data);
		}

		ereport(NOTICE,
				(errmsg("copied %d trigger(s) from \"%s\" to \"%s\"",
						created, src_name, dst_name)));

		pfree(triggers);
	}

	SPI_finish();
	PG_RETURN_VOID();
}


/* ================================================================
 * spi_demo_prepared
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_demo_prepared(name text)
 *     RETURNS oid
 *     AS 'MODULE_PATHNAME', 'spi_demo_prepared'
 *     LANGUAGE C STRICT;
 *
 * Demonstrates the full prepared-statement lifecycle:
 *   1. SPI_prepare()        — parse + plan + save for reuse
 *   2. SPI_getargcount()    — inspect plan metadata (# of $N params)
 *   3. SPI_getargtypeid()   — inspect plan metadata (type of $N)
 *   4. SPI_is_cursor_plan() — check if plan was made for a cursor
 *   5. SPI_execute_plan()   — execute a saved plan with values
 *   6. SPI_saveplan()       — copy plan to top-level context
 *   7. SPI_freeplan()       — release plan memory
 *
 * This is the preferred pattern when you need to execute the same
 * query many times with different parameters.  SPI_prepare parses
 * once; SPI_execute_plan reuses the plan.
 * ================================================================
 */
PG_FUNCTION_INFO_V1(spi_demo_prepared);

Datum
spi_demo_prepared(PG_FUNCTION_ARGS)
{
	text	   *t_name = PG_GETARG_TEXT_PP(0);
	char	   *name_str = text_to_cstring(t_name);
	int			spi_rc;
	Oid			result_oid = InvalidOid;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * --- SPI_prepare ---------------------------------------------
	 *
	 * Prepares a parameterized statement.  The plan lives in the SPI
	 * memory context and is freed by SPI_finish (unless saved).
	 *
	 * Parameters: src, nargs, argtypes[]
	 * Returns:    SPIPlanPtr (NULL on error — check SPI_result)
	 */
	{
		Oid			argtypes[1] = {TEXTOID};
		SPIPlanPtr	plan;

		plan = SPI_prepare(
			"SELECT oid FROM pg_test WHERE testname = $1",
			1, argtypes);

		if (plan == NULL)
			elog(ERROR, "SPI_prepare failed: %s",
				 SPI_result_code_string(SPI_result));

		/* --- SPI_getargcount: number of $N parameters --- */
		ereport(NOTICE,
				(errmsg("plan has %d argument(s)",
						SPI_getargcount(plan))));

		/* --- SPI_getargtypeid: OID of the N-th parameter type --- */
		if (SPI_getargcount(plan) > 0)
			ereport(NOTICE,
					(errmsg("arg #1 type OID = %u (%s)",
							SPI_getargtypeid(plan, 0),
							format_type_be(SPI_getargtypeid(plan, 0)))));

		/* --- SPI_is_cursor_plan: was this prepared for a cursor? --- */
		ereport(NOTICE,
				(errmsg("is cursor plan: %s",
						SPI_is_cursor_plan(plan) ? "yes" : "no")));

		/*
		 * --- SPI_execute_plan -----------------------------------
		 *
		 * Execute a prepared plan.  Values and nulls work exactly like
		 * SPI_execute_with_args.
		 */
		{
			Datum	values[1] = {CStringGetDatum(name_str)};
			char	nulls[1] = {' '};

			spi_rc = SPI_execute_plan(plan, values, nulls, true, 0);
		}

		if (spi_rc < 0)
			elog(ERROR, "SPI_execute_plan failed: %s",
				 SPI_result_code_string(spi_rc));

		/* Extract result like any SPI_execute call */
		if (SPI_processed > 0)
		{
			bool	isnull;

			result_oid = DatumGetObjectId(
				SPI_getbinval(SPI_tuptable->vals[0],
							  SPI_tuptable->tupdesc, 1, &isnull));
			if (isnull)
				result_oid = InvalidOid;
		}

		/*
		 * --- SPI_saveplan ---------------------------------------
		 *
		 * Copies the plan to TopMemoryContext so it survives
		 * SPI_finish().  Use this when you want to cache a plan
		 * across multiple function calls.
		 *
		 * IMPORTANT: call SPI_freeplan() when done with a saved plan.
		 */
		{
			SPIPlanPtr	saved;

			saved = SPI_saveplan(plan);
			if (saved == NULL)
				elog(ERROR, "SPI_saveplan failed");
			SPI_freeplan(saved);	/* free immediately in this demo */
		}

		/*
		 * --- SPI_freeplan ---------------------------------------
		 *
		 * Frees a plan.  SPI_prepare plans are auto-freed by
		 * SPI_finish, but saved plans (SPI_saveplan) or plans that
		 * need early cleanup should be freed with SPI_freeplan.
		 */
		SPI_freeplan(plan);
	}

	SPI_finish();

	if (OidIsValid(result_oid))
		PG_RETURN_OID(result_oid);
	else
		PG_RETURN_NULL();
}


/* ================================================================
 * spi_demo_cursor
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_demo_cursor()
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'spi_demo_cursor'
 *     LANGUAGE C;
 *
 * Demonstrates cursor-based data access:
 *   1. SPI_cursor_open_with_args() — open cursor (returns Portal)
 *   2. SPI_cursor_fetch()          — fetch rows in batches
 *   3. SPI_cursor_close()          — close cursor
 *
 * Cursors are useful when you need to process a large result set
 * incrementally rather than loading everything into memory at once
 * (as SPI_execute does).
 *
 * After each SPI_cursor_fetch(), results are available in the usual
 * SPI_tuptable / SPI_processed variables.
 * ================================================================
 */
PG_FUNCTION_INFO_V1(spi_demo_cursor);

Datum
spi_demo_cursor(PG_FUNCTION_ARGS)
{
	int			spi_rc;
	Portal		portal;
	uint64		total_rows = 0;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * --- SPI_cursor_open_with_args ------------------------------
	 *
	 * Opens a cursor (portal) over a query result.  Similar to
	 * SPI_execute_with_args, but instead of returning all rows at
	 * once, it creates a scrollable handle.
	 *
	 * Parameters: name, src, nargs, argtypes, values, nulls,
	 *             read_only, cursorOptions
	 *
	 * name=NULL: SPI auto-generates a portal name.
	 * cursorOptions=0: default behavior (text format, forward-only).
	 */
	{
		Oid		argtypes[0] = {};	/* no parameters */
		Datum	values[0] = {};
		char	nulls[0] = {};

		portal = SPI_cursor_open_with_args(
			NULL,	/* auto-generate portal name */
			"SELECT oid, testname, created_at FROM pg_test ORDER BY testname",
			0, argtypes, values, nulls,
			true,	/* read_only */
			0		/* cursorOptions: default */
		);

		ereport(NOTICE,
				(errmsg("cursor opened: \"%s\"", portal->name)));
	}

	if (portal == NULL)
		elog(ERROR, "SPI_cursor_open_with_args failed: %s",
			 SPI_result_code_string(SPI_result));

	/*
	 * --- SPI_cursor_fetch ---------------------------------------
	 *
	 * Fetches up to `count` rows from the cursor.  Result appears in
	 * SPI_tuptable / SPI_processed, exactly like SPI_execute.
	 *
	 * Parameters: portal, forward (true=forward, false=backward), count
	 *
	 * Loop until fewer than `count` rows are returned (end of cursor).
	 */
	{
#define BATCH_SIZE	2		/* small batch to demonstrate incremental fetch */
		int		batch = 0;
		uint64	i;
		bool	isnull;

		while (true)
		{
			SPI_cursor_fetch(portal, true, BATCH_SIZE);
			if (SPI_processed <= 0)
				break;

			batch++;
			{
				TupleDesc	td = SPI_tuptable->tupdesc;

				ereport(NOTICE,
						(errmsg("--- batch %d: %lld row(s) ---",
								batch, (long long) SPI_processed)));

				for (i = 0; i < SPI_processed; i++)
				{
					HeapTuple	row = SPI_tuptable->vals[i];
					char	   *testname;
					Oid			oid;

					oid = DatumGetObjectId(
						SPI_getbinval(row, td, 1, &isnull));
					testname = SPI_getvalue(row, td, 2);

					ereport(NOTICE,
							(errmsg("  oid=%u, name=\"%s\"",
									isnull ? 0 : oid,
									testname ? testname : "(null)")));
				}
			}

			total_rows += SPI_processed;
		}
#undef BATCH_SIZE
	}

	ereport(NOTICE,
			(errmsg("cursor fetch complete: %lld total row(s)",
					(long long) total_rows)));

	/*
	 * --- SPI_cursor_close ---------------------------------------
	 *
	 * Closes the cursor (portal) and releases its resources.
	 * Not strictly required — all cursors are closed by SPI_finish.
	 * But explicit close is good practice for large/long operations.
	 */
	SPI_cursor_close(portal);

	SPI_finish();
	PG_RETURN_VOID();
}


/* ================================================================
 * spi_demo_metadata
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_demo_metadata()
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'spi_demo_metadata'
 *     LANGUAGE C;
 *
 * Demonstrates column-metadata inspection APIs:
 *   - SPI_fnumber()  — look up column number by name
 *   - SPI_fname()    — look up column name by number
 *   - SPI_gettype()  — get SQL type name string
 *   - SPI_gettypeid()— get type OID
 *
 * These are essential when you receive a result set and need to
 * dynamically discover its structure.
 * ================================================================
 */
PG_FUNCTION_INFO_V1(spi_demo_metadata);

Datum
spi_demo_metadata(PG_FUNCTION_ARGS)
{
	int			spi_rc;
	TupleDesc	tupdesc;
	int			i;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/* Run any query that returns columns we can inspect */
	spi_rc = SPI_execute(
		"SELECT oid, testname, created_at FROM pg_test LIMIT 0",
		true, 0);

	if (spi_rc != SPI_OK_SELECT)
		elog(ERROR, "SELECT failed: %s", SPI_result_code_string(spi_rc));

	tupdesc = SPI_tuptable->tupdesc;

	ereport(NOTICE,
			(errmsg("result set has %d column(s)", tupdesc->natts)));

	for (i = 1; i <= tupdesc->natts; i++)
	{
		/*
		 * --- SPI_fname: column name by number ---
		 * --- SPI_gettype: SQL type name by number ---
		 * --- SPI_gettypeid: type OID by number ---
		 */
		ereport(NOTICE,
				(errmsg("  col %d: \"%s\" — type=%s (oid=%u)",
						i,
						SPI_fname(tupdesc, i),
						SPI_gettype(tupdesc, i),
						SPI_gettypeid(tupdesc, i))));

		/*
		 * --- SPI_fnumber: reverse lookup — column number by name ---
		 * Returns SPI_ERROR_NOATTRIBUTE if the column doesn't exist.
		 */
		{
			int	fnum = SPI_fnumber(tupdesc, SPI_fname(tupdesc, i));

			ereport(NOTICE,
					(errmsg("       SPI_fnumber(\"%s\") = %d",
							SPI_fname(tupdesc, i), fnum)));
		}
	}

	/* Demonstrate error case: look up a non-existent column */
	{
		int	fnum = SPI_fnumber(tupdesc, "nonexistent_column");

		ereport(NOTICE,
				(errmsg("  SPI_fnumber(\"nonexistent_column\") = %d (%s)",
						fnum,
						fnum == SPI_ERROR_NOATTRIBUTE
							? "not found" : "unexpected")));
	}

	SPI_finish();
	PG_RETURN_VOID();
}


/* ================================================================
 * spi_demo_spi_palloc
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_demo_spi_palloc()
 *     RETURNS text
 *     AS 'MODULE_PATHNAME', 'spi_demo_spi_palloc'
 *     LANGUAGE C;
 *
 * Demonstrates SPI-specific memory-management routines:
 *   - SPI_palloc()  — allocate memory freed by SPI_finish
 *   - SPI_repalloc() — resize a previous SPI_palloc allocation
 *   - SPI_pfree()   — explicit free (optional; SPI_finish frees all)
 *
 * Key difference from plain palloc:
 *   - palloc() between SPI_connect / SPI_finish goes to the SPI
 *     procedure context, same as SPI_palloc().  The API names are
 *     aliases in modern PG.
 *   - SPI_palloc/spi_repalloc history: originally designed so
 *     extensions could use SPI memory without linking against palloc.
 *     Today they are wrapper macros for palloc/repalloc.
 *
 * The returned value proves the memory survives within SPI scope.
 * ================================================================
 */
PG_FUNCTION_INFO_V1(spi_demo_spi_palloc);

Datum
spi_demo_spi_palloc(PG_FUNCTION_ARGS)
{
	char	   *buf;
	text	   *result;
	int			spi_rc;

	spi_rc = SPI_connect();
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect failed: %s",
			 SPI_result_code_string(spi_rc));

	/* --- SPI_palloc: allocate 128 bytes --- */
	buf = (char *) SPI_palloc(128);
	snprintf(buf, 128, "Hello from SPI_palloc! [initial]");
	ereport(NOTICE, (errmsg("after SPI_palloc:  \"%s\"", buf)));

	/* --- SPI_repalloc: grow the buffer to 256 bytes --- */
	buf = (char *) SPI_repalloc(buf, 256);
	snprintf(buf, 256,
			 "Hello from SPI_repalloc! [grew from 128 to 256 bytes]");
	ereport(NOTICE, (errmsg("after SPI_repalloc: \"%s\"", buf)));

	/* Convert to SQL text for return */
	result = cstring_to_text(buf);

	/* --- SPI_pfree: explicit free (good habit, not required) --- */
	SPI_pfree(buf);

	SPI_finish();
	PG_RETURN_TEXT_P(result);
}


/* ================================================================
 * spi_demo_atomic
 *
 * SQL signature:
 *   CREATE OR REPLACE FUNCTION spi_demo_atomic(
 *       should_commit bool, testname text)
 *     RETURNS void
 *     AS 'MODULE_PATHNAME', 'spi_demo_atomic'
 *     LANGUAGE C;
 *
 * Demonstrates explicit transaction control within SPI:
 *   - SPI_connect_ext(SPI_OPT_NONATOMIC) — non-atomic mode
 *   - SPI_commit()                      — commit current tx + start new
 *   - SPI_rollback()                    — rollback current tx + start new
 *
 * Default SPI connections are atomic: the entire function runs in one
 * transaction (success → commit, error → rollback).  NONATOMIC mode
 * lets you split work across multiple transactions.
 *
 * Test:
 *   -- This INSERT should survive:
 *   SELECT spi_demo_atomic(true, 'keep_this');
 *   -- This INSERT should be rolled back:
 *   SELECT spi_demo_atomic(false, 'discard_this');
 *   SELECT * FROM pg_test WHERE testname IN ('keep_this','discard_this');
 * ================================================================
 */
PG_FUNCTION_INFO_V1(spi_demo_atomic);

Datum
spi_demo_atomic(PG_FUNCTION_ARGS)
{
	bool		should_commit = PG_GETARG_BOOL(0);
	text	   *t_name = PG_GETARG_TEXT_PP(1);
	char	   *name_str = text_to_cstring(t_name);
	int			spi_rc;

	/*
	 * --- SPI_connect_ext ----------------------------------------
	 *
	 * SPI_OPT_NONATOMIC tells PostgreSQL NOT to wrap this procedure
	 * in a single transaction.  Without it, SPI_commit() /
	 * SPI_rollback() will throw an error.
	 */
	spi_rc = SPI_connect_ext(SPI_OPT_NONATOMIC);
	if (spi_rc != SPI_OK_CONNECT)
		elog(ERROR, "SPI_connect_ext failed: %s",
			 SPI_result_code_string(spi_rc));

	/*
	 * Insert a row.  Because we're in NONATOMIC mode, this INSERT
	 * lives in the current transaction — which we'll either commit
	 * or roll back below.
	 */
	{
		Oid		argtypes[1] = {TEXTOID};
		Datum	values[1] = {CStringGetDatum(name_str)};
		char	nulls[1] = {' '};

		spi_rc = SPI_execute_with_args(
			"INSERT INTO pg_test (testname, created_at) VALUES ($1, now())",
			1, argtypes, values, nulls,
			false, 0);
	}

	if (spi_rc != SPI_OK_INSERT)
		elog(ERROR, "INSERT failed: %s", SPI_result_code_string(spi_rc));

	ereport(NOTICE,
			(errmsg("inserted %lld row(s) with testname \"%s\"",
					(long long) SPI_processed, name_str)));

	if (should_commit)
	{
		/*
		 * --- SPI_commit -----------------------------------------
		 *
		 * Commits the current transaction and immediately starts a
		 * new one.  After SPI_commit(), the INSERT above is durable.
		 * SPI_commit() internally calls CommitTransactionCommand()
		 * then StartTransactionCommand().
		 */
		SPI_commit();
		ereport(NOTICE,
				(errmsg("transaction COMMITTED — row is now durable")));
	}
	else
	{
		/*
		 * --- SPI_rollback ---------------------------------------
		 *
		 * Rolls back the current transaction and starts a new one.
		 * The INSERT above is discarded.  Use this when validation
		 * fails mid-procedure and you want to undo partial work.
		 */
		SPI_rollback();
		ereport(NOTICE,
				(errmsg("transaction ROLLED BACK — row discarded")));
	}

	SPI_finish();
	PG_RETURN_VOID();
}
