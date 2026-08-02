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
#include "parser/mysql/mys_parser_exports.h"

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
 * G3 cross-boundary slot: kernel-facing entry points of the loadable
 * mysql_parser module.  NULL until the module's _PG_init() fills it in;
 * see mys_parser_exports.h.
 */
MysParserExports *mys_parser_exports = NULL;

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

const ParserRoutine *
GetStandardParserRoutine(void)
{
    return &StandardParserRoutine;
}

/*
 * GetDialectParserRoutine
 *
 * Return the ParserRoutine for the backend's active dialect, falling back
 * to the standard PG parser when no dialect table is registered (for
 * example, when the mysql_parser module was not loaded).  The raw-parse
 * dispatch in PostgresMain() uses this instead of a compile-time
 * ProtocolRoutine binding so the parser can ship as a loadable module.
 */
const ParserRoutine *
GetDialectParserRoutine(void)
{
	const ParserRoutine *routine = dialect_parser[MyCompatMode];

	return routine != NULL ? routine : GetStandardParserRoutine();
}

/*
 * GetRegisteredParserRoutine
 *
 * Return the ParserRoutine registered for a dialect kind, or NULL if
 * none (for example, when the mysql_parser module was not loaded).
 * Used by the protocol layer to bind the parser for its connections
 * at postmaster startup.
 */
const ParserRoutine *
GetRegisteredParserRoutine(CompatibilityProtocolKind kind)
{
	Assert(kind >= 0 && kind < COMPAT_PROTOCOL_KIND_MAX);
	return dialect_parser[kind];
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
