/*-------------------------------------------------------------------------
 *
 * extmerge_demo.h
 *	  用于演示 EXTMERGE 语法实现的辅助函数声明
 *
 * 分别演示两种实现方式：
 *   方式一（Node节点）：通过 ExtMergeStmt 节点，在 utility.c 中处理
 *   方式二（函数调用）：在语法分析阶段直接调用函数处理
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 * Portions Copyright (c) 2026, LvHui
 *
 * src/include/parser/extmerge_demo.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef EXTMERGE_DEMO_H
#define EXTMERGE_DEMO_H

#include "nodes/pg_list.h"
#include "nodes/primnodes.h"

/* 方式二：函数调用方式 —— 在语法动作中直接调用 */
extern void extmerge_handle_direct(RangeVar *src, RangeVar *ref,
									RangeVar *dst, char *limit_type,
									int limit_count, List *tm_cols);

/* 方式一：Node节点方式 —— 在 utility.c 中调用 */
extern void extmerge_process_stmt(RangeVar *src, RangeVar *ref,
								   RangeVar *dst, char *limit_type,
								   int limit_count, List *tm_cols);

#endif /* EXTMERGE_DEMO_H */
