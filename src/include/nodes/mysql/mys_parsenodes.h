/*-------------------------------------------------------------------------
 *
 * mys_parsenodes.h
 *    Definitions for MySQL-compatibility parse tree nodes.
 *
 * The only remaining custom parse-tree node is MysSelectIntoStmt, which
 * represents SELECT ... INTO @var / INTO OUTFILE from the MySQL grammar.
 * It is consumed by the dialect process_utility and the parser transform
 * layer (mys_parse_utilcmd.c).
 *
 * The MySQL user/system variable expression nodes (UserVarRef,
 * UserVarAssign, SysVarRef) have been degraded to standard FuncCall
 * nodes:
 *   @name     -> pg_catalog.mys_get_user_var('name')
 *   @name:=e  -> pg_catalog.mys_set_user_var('name', e)
 *   @@name    -> pg_catalog.mys_get_system_variable('name', bool)
 *
 * MysVariableSetStmt has been replaced with standard VariableSetStmt
 * using a "mysql._" name-prefix convention, dispatched from the MySQL
 * process_utility handler.
 *
 * Portions Copyright (c) 2026, HaloLab / openHalo Contributors
 *
 * src/include/nodes/mysql/mys_parsenodes.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef MYS_PARSENODES_H
#define MYS_PARSENODES_H

#include "nodes/nodes.h"
#include "nodes/pg_list.h"

/* ----------------------------------------------------------------
 *    MySQL SELECT ... INTO @var / INTO OUTFILE  (reserved)
 * ----------------------------------------------------------------
 */
typedef struct MysSelectIntoStmt
{
    pg_node_attr(no_query_jumble, nodetag_number(483))

    NodeTag     type;
    Node       *selectStmt;     /* the wrapped SELECT statement    */
    Node       *intoTarget;     /* INTO target (variable / file)   */
    ParseLoc    location;       /* statement start                  */
} MysSelectIntoStmt;

#endif   /* MYS_PARSENODES_H */
