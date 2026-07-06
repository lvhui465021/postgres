/*-------------------------------------------------------------------------
 *
 * extmerge_demo.c
 *	  用于演示 EXTMERGE 语法实现的辅助函数
 *
 * 分别演示两种实现方式：
 *   方式一（Node节点）：通过 ExtMergeStmt 节点，在 utility.c 中调用
 *   方式二（函数调用）：在语法分析阶段直接调用，绕过Node体系
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 * Portions Copyright (c) 2026, LvHui
 *
 * IDENTIFICATION
 *	  src/backend/parser/extmerge_demo.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "parser/extmerge_demo.h"
#include "nodes/value.h"
#include "utils/elog.h"

/*
 * extmerge_handle_direct
 *		方式二（函数调用方式）：在语法动作中直接调用此函数
 *
 * 这种方式的特点：
 *   - 不创建 parse node，直接在语法分析阶段完成语句处理
 *   - 无需修改 parsenodes.h、utility.c 的 case 分支
 *   - 适合简单的、不需要重写/优化/权限检查的语句
 *   - 缺点是无法利用 PostgreSQL 的 Node 基础设施（复制、比较、序列化等）
 */
void
extmerge_handle_direct(RangeVar *src, RangeVar *ref, RangeVar *dst,
						char *limit_type, int limit_count, List *tm_cols)
{
	elog(WARNING, "========================================");
	elog(WARNING, "[EXTMERGE-函数调用方式] 语句处理开始");
	elog(WARNING, "[EXTMERGE-函数调用方式] 源表: %s%s%s",
		 src->catalogname ? src->catalogname : "",
		 src->catalogname ? "." : "",
		 src->relname ? src->relname : "?");
	elog(WARNING, "[EXTMERGE-函数调用方式] 引用表: %s%s%s",
		 ref->catalogname ? ref->catalogname : "",
		 ref->catalogname ? "." : "",
		 ref->relname ? ref->relname : "?");
	elog(WARNING, "[EXTMERGE-函数调用方式] 目标表: %s%s%s",
		 dst->catalogname ? dst->catalogname : "",
		 dst->catalogname ? "." : "",
		 dst->relname ? dst->relname : "?");

	if (limit_type != NULL)
		elog(WARNING, "[EXTMERGE-函数调用方式] 限制类型: %s, 限制数量: %d",
			 limit_type, limit_count);
	else
		elog(WARNING, "[EXTMERGE-函数调用方式] 限制类型: 无（默认 ALL）");

	if (tm_cols != NIL)
	{
		ListCell   *lc;

		foreach(lc, tm_cols)
		{

			elog(WARNING, "[EXTMERGE-函数调用方式] TM 列: %s", strVal(lfirst(lc)));
		}
	}
	else
		elog(WARNING, "[EXTMERGE-函数调用方式] TM 列: 无");

	elog(WARNING, "[EXTMERGE-函数调用方式] 语句处理完成（在语法分析阶段直接调用函数）");
	elog(WARNING, "========================================");
}

/*
 * extmerge_process_stmt
 *		方式一（Node节点方式）：在 utility.c 中通过 Node 分发调用此函数
 *
 * 这种方式的特点：
 *   - 创建 ExtMergeStmt 节点，遵循 PostgreSQL 标准流程
 *   - 在 utility.c 的 case T_ExtMergeStmt 分支中调用
 *   - 支持 Node 的 copy/equal/read/write 等基础设施
 *   - 适合需要重写、优化、权限检查的语句
 *   - 可被 EXPLAIN、规则系统等使用
 */
void
extmerge_process_stmt(RangeVar *src, RangeVar *ref, RangeVar *dst,
					   char *limit_type, int limit_count, List *tm_cols)
{
	elog(WARNING, "========================================");
	elog(WARNING, "[EXTMERGE-Node节点方式] 语句处理开始");
	elog(WARNING, "[EXTMERGE-Node节点方式] 源表: %s%s%s",
		 src->catalogname ? src->catalogname : "",
		 src->catalogname ? "." : "",
		 src->relname ? src->relname : "?");
	elog(WARNING, "[EXTMERGE-Node节点方式] 引用表: %s%s%s",
		 ref->catalogname ? ref->catalogname : "",
		 ref->catalogname ? "." : "",
		 ref->relname ? ref->relname : "?");
	elog(WARNING, "[EXTMERGE-Node节点方式] 目标表: %s%s%s",
		 dst->catalogname ? dst->catalogname : "",
		 dst->catalogname ? "." : "",
		 dst->relname ? dst->relname : "?");

	if (limit_type != NULL)
		elog(WARNING, "[EXTMERGE-Node节点方式] 限制类型: %s, 限制数量: %d",
			 limit_type, limit_count);
	else
		elog(WARNING, "[EXTMERGE-Node节点方式] 限制类型: 无（默认 ALL）");

	if (tm_cols != NIL)
	{
		ListCell   *lc;

		foreach(lc, tm_cols)
		{

			elog(WARNING, "[EXTMERGE-Node节点方式] TM 列: %s", strVal(lfirst(lc)));
		}
	}
	else
		elog(WARNING, "[EXTMERGE-Node节点方式] TM 列: 无");

	elog(WARNING, "[EXTMERGE-Node节点方式] 语句处理完成（通过 Node 节点 → utility.c 流程）");
	elog(WARNING, "========================================");
}
