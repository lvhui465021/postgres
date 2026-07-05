/*-------------------------------------------------------------------------
 *
 * memory_demo.h
 *	  Declarations for memory context demonstration functions.
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 *
 * src/include/utils/memory_demo.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef MEMORY_DEMO_H
#define MEMORY_DEMO_H

#include "nodes/memnodes.h"

extern void *create_and_switch_memory(void);

#endif /* MEMORY_DEMO_H */
