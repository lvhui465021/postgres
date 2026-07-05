/*-------------------------------------------------------------------------
 *
 * spi_demo.c
 *	  Demonstration of PostgreSQL SPI (Server Programming Interface).
 *
 * This file demonstrates:
 *	- SPI_connect / SPI_finish lifecycle
 *	- Parameterized SELECT via SPI_execute_with_args
 *	- Parameterized UPDATE via SPI_execute_with_args
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

#include "executor/spi.h"
#include "fmgr.h"
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
