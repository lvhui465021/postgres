/*-------------------------------------------------------------------------
 *
 * syscache_demo.h
 *	  Declarations for system catalog cache demonstration functions.
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 *
 * src/include/utils/syscache_demo.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef SYSCACHE_DEMO_H
#define SYSCACHE_DEMO_H

#include "catalog/pg_class.h"

extern bool get_test_tuples(const char *relname, Oid relnamespace,
							Oid *oid, char *relkind, int16 *relnatts);

#endif /* SYSCACHE_DEMO_H */
