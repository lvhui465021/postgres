/*-------------------------------------------------------------------------
 *
 * pg_cron_job.h
 *	  definition of the "cron_job" system catalog (pg_cron_job)
 *
 * This is a shared relation that stores pg_cron job definitions,
 * visible from all databases.  Each row defines one scheduled job.
 *
 * Portions Copyright (c) 2016-2025, Citus Data, Inc.
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 *
 * src/include/catalog/pg_cron_job.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef PG_CRON_JOB_H
#define PG_CRON_JOB_H

#include "catalog/genbki.h"

#define CronJobRelationId 9267

CATALOG(pg_cron_job,9267,CronJobRelationId) BKI_SHARED_RELATION BKI_ROWTYPE_OID(9268,CronJobRelation_Rowtype_Id) BKI_SCHEMA_MACRO
{
	int64		jobid;
	int32		nodeport;
	bool		active;
#ifdef CATALOG_VARLEN
	text		schedule BKI_FORCE_NOT_NULL;
	text		command BKI_FORCE_NOT_NULL;
	text		nodename;
	text		database;
	text		username;
	text		jobname;
#endif
} FormData_pg_cron_job;

typedef FormData_pg_cron_job *Form_pg_cron_job;

#define Natts_pg_cron_job				9
#define Anum_pg_cron_job_jobid			1
#define Anum_pg_cron_job_schedule		2
#define Anum_pg_cron_job_command		3
#define Anum_pg_cron_job_nodename		4
#define Anum_pg_cron_job_nodeport		5
#define Anum_pg_cron_job_database		6
#define Anum_pg_cron_job_username		7
#define Anum_pg_cron_job_active			8
#define Anum_pg_cron_job_jobname		9

#define CronJobPkeyIndexId 9269
#define CronJobNameUsernameIndexId 9270

DECLARE_UNIQUE_INDEX_PKEY(pg_cron_job_pkey, 9269, CronJobPkeyIndexId, pg_cron_job, btree(jobid int8_ops));
DECLARE_UNIQUE_INDEX(pg_cron_job_jobname_username_uniq, 9270, CronJobNameUsernameIndexId, pg_cron_job, btree(username text_ops, jobname text_ops));

#endif							/* PG_CRON_JOB_H */
