/*-------------------------------------------------------------------------
 *
 * parsereng.c
 *    Parser engine selection: standard and MySQL routine singletons.
 *
 * Portions Copyright (c) 2026, HaloLab / openHalo Contributors
 *
 * src/backend/parser/parsereng.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "parser/parser.h"            /* raw_parser, RawParseMode    */
#include "parser/parserapi.h"         /* ParserRoutine               */
#include "parser/parsereng.h"
#include "parser/mysql/mys_parse_utilcmd.h"
#include "parser/mysql/mys_parser.h"  /* mys_raw_parser              */
#include "parser/mysql/mys_expr_transform.h"  /* mys_transform_expr_node */

#include "miscadmin.h"
#include "libpq/libpq-be.h"

/* GUC variable */
int database_compat_mode = POSTGRESQL_COMPAT_MODE;

/* Parser Engine Instance */
const ParserRoutine *parserengine = NULL;

/* Dialect parser tables registered via RegisterParserRoutine(). */
static const ParserRoutine *dialect_parser[COMPAT_PROTOCOL_KIND_MAX];

/*
 * RegisterParserRoutine
 *
 * Register (or replace) the ParserRoutine for a compatibility kind.  The
 * kernel dispatches to it in InitParserEngine() by MyCompatMode; kinds
 * without a registered table fall back to the standard PG parser.
 */
void
RegisterParserRoutine(CompatibilityProtocolKind kind,
					  const ParserRoutine *routine)
{
	Assert(kind >= 0 && kind < COMPAT_PROTOCOL_KIND_MAX);
	dialect_parser[kind] = routine;
}

/*
 * MyCompatMode -- backend-level dialect context.
 *
 * Defaults to the cluster-wide database_compat_mode, overridden by the
 * active wire protocol on frontend connections, and propagated into
 * parallel workers.  Unlike MyProcPort->protocol_kind, this value is
 * always defined, even in processes with no client port (parallel
 * workers, background workers, logical-replication apply workers).
 */
CompatibilityProtocolKind MyCompatMode = COMPAT_PROTOCOL_POSTGRES;

/*
 * InitCompatMode
 *
 * Resolves the backend's dialect before the parser engine and ADT
 * extension are initialized.  Frontend connections adopt the protocol
 * override; every other process falls back to the cluster default.
 */
void
InitCompatMode(void)
{
	/*
	 * Register the built-in MySQL parser table on first use.  This is the
	 * dynamic-registration seam that a loadable parser library would also
	 * use; the kernel dispatches by MyCompatMode in InitParserEngine().
	 */
	RegisterParserRoutine(COMPAT_PROTOCOL_MYSQL, &MySQLParserRoutine);

	if (MyProcPort != NULL)
		MyCompatMode = MyProcPort->protocol_kind;
	else
		MyCompatMode = (database_compat_mode == MYSQL_COMPAT_MODE) ?
			COMPAT_PROTOCOL_MYSQL : COMPAT_PROTOCOL_POSTGRES;
}

/* ----------------------------------------------------------------
 *    StandardParserRoutine  –  PG dialect
 * ----------------------------------------------------------------
 */
static const ParserRoutine StandardParserRoutine = {
    .raw_parse = raw_parser,
    .transform_expr_node = NULL,
};

/*
 * MySQLParserRoutine  –  MySQL-compatibility dialect.
 *
 * Initial M2 state: mys_raw_parser delegates to the standard PG
 * raw_parser.  The dedicated MySQL scanner (mys_scan.l) and grammar
 * (mys_gram.y) will replace this delegation incrementally.
 */
const ParserRoutine MySQLParserRoutine = {
	.raw_parse = mys_raw_parser,
	.transformOptionalSelectInto = mys_transformOptionalSelectInto,
	.transformOnConflictArbiter = mys_transformOnConflictArbiter,
    .transform_expr_node = mys_transform_expr_node,
	.figure_colname = mys_figure_colname,
};

const ParserRoutine *
GetStandardParserRoutine(void)
{
    return &StandardParserRoutine;
}

const ParserRoutine *
GetMySQLParserRoutine(void)
{
    return &MySQLParserRoutine;
}

/*
 * InitParserEngine
 *
 * Selects the parser engine based on the backend's dialect context
 * (MyCompatMode).  The switch is extensible: additional compat modes
 * (Oracle, Sybase, etc.) can add their own cases.
 */
void
InitParserEngine(void)
{
	/* The MySQL table is registered at library load time (see below). */
	parserengine = dialect_parser[MyCompatMode];
	if (parserengine == NULL)
		parserengine = GetStandardParserRoutine();
}
