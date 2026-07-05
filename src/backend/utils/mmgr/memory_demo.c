/*-------------------------------------------------------------------------
 *
 * memory_demo.c
 *	  Demonstration of PostgreSQL memory context operations.
 *
 * This file demonstrates:
 *	- Creating a new AllocSet memory context
 *	- Switching between memory contexts
 *	- Allocating memory in a specific context
 *
 * IDENTIFICATION
 *	  src/backend/utils/mmgr/memory_demo.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "utils/memutils.h"
#include "utils/memory_demo.h"
#include "utils/palloc.h"

/*
 * create_and_switch_memory
 *
 * Creates a new AllocSet memory context, allocates 1KB of memory within it,
 * switches back to the original context, and returns the allocated pointer.
 *
 * The returned pointer remains valid because it was allocated in the new
 * context (which persists until explicitly deleted or reset).  Switching away
 * from a context does NOT invalidate memory allocated within it.
 *
 * Returns: a pointer to 1KB of memory allocated in a new child context of
 *			CurrentMemoryContext.
 */
void *
create_and_switch_memory(void)
{
	MemoryContext oldcontext;
	MemoryContext newcontext;
	void	   *ptr;

	/*
	 * Create a new AllocSet context as a child of the current memory
	 * context.  ALLOCSET_DEFAULT_SIZES provides reasonable defaults:
	 *   minContextSize = 0
	 *   initBlockSize  = 8 KB
	 *   maxBlockSize   = 8 MB
	 */
	newcontext = AllocSetContextCreate(CurrentMemoryContext,
									   "DemoMemoryContext",
									   ALLOCSET_DEFAULT_SIZES);

	/* Switch to the new context; save the old one for later restoration */
	oldcontext = MemoryContextSwitchTo(newcontext);

	/* Allocate 1KB of memory in the new context */
	ptr = palloc(1024);

	/* Switch back to the original memory context */
	MemoryContextSwitchTo(oldcontext);

    /* 方式二：直接指定上下文，无需切换 */
    /* ptr = MemoryContextAlloc(newcontext, 1024);

	/*
	 * Return the pointer.  The allocated memory is still valid --- it lives
	 * in 'newcontext', which we intentionally did NOT delete.  The caller is
	 * responsible for understanding that this memory belongs to a separate
	 * context.
	 */
	return ptr;
}
