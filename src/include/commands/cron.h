/*-------------------------------------------------------------------------
 *
 * cron.h
 *	  Consolidated header for the pg_cron built-in job scheduler.
 *
 * This file merges the content originally spread across:
 *   cron.h, pg_cron.h, task_states.h, job_metadata.h, cron_job.h, bitstring.h
 *
 * Portions Copyright (c) 1988,1990,1993,1994 by Paul Vixie
 * Portions Copyright (c) 2016-2025, Citus Data, Inc.
 * Portions Copyright (c) 1996-2025, PostgreSQL Global Development Group
 *
 * src/include/commands/cron.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef CRON_COMMANDS_H
#define CRON_COMMANDS_H

#include "postgres.h"
#include "nodes/pg_list.h"
#include "storage/dsm.h"
#include "storage/shm_mq.h"
#include "postmaster/bgworker.h"
#include "utils/timestamp.h"

#if (PG_VERSION_NUM < 120000)
#include "datatype/timestamp.h"
#endif

/*
 * Forward declarations for libpq types used in CronTask.
 * When cron.c includes the full libpq-fe.h, these are skipped to avoid
 * redeclaration conflicts.  In the kernel build (PG_CRON_KERNEL),
 * libpq-fe.h is not included, so we provide complete stubs.
 */
#ifndef LIBPQ_FE_H
typedef struct pg_conn PGconn;

typedef enum
{
	PGRES_POLLING_FAILED = 0,
	PGRES_POLLING_READING,
	PGRES_POLLING_WRITING,
	PGRES_POLLING_OK
} PostgresPollingStatusType;

/* libpq connection status (kernel stub) */
typedef enum
{
	CONNECTION_BAD,
	CONNECTION_OK
} ConnStatusType;

/* libpq result status (kernel stub) */
typedef enum
{
	PGRES_EMPTY_QUERY = 0,
	PGRES_COMMAND_OK,
	PGRES_TUPLES_OK,
	PGRES_COPY_OUT,
	PGRES_COPY_IN,
	PGRES_BAD_RESPONSE,
	PGRES_NONFATAL_ERROR,
	PGRES_FATAL_ERROR,
	PGRES_COPY_BOTH,
	PGRES_SINGLE_TUPLE
} ExecStatusType;

/* libpq result type (opaque in kernel build) */
typedef struct pg_result PGresult;
#endif

/* ------------------------------------------------------------------------- */
/* bitstring.h -- macros for bit-string operations                           */
/* ------------------------------------------------------------------------- */

typedef unsigned char bitstr_t;

/* internal macros */
#define	_bit_byte(bit) \
	((bit) >> 3)

#define	_bit_mask(bit) \
	(1 << ((bit)&0x7))

/* external macros */
#define	bitstr_size(nbits) \
	((((nbits) - 1) >> 3) + 1)

#define	bit_alloc(nbits) \
	(bitstr_t *)malloc(1, \
	    (unsigned int)bitstr_size(nbits) * sizeof(bitstr_t))

#define	bit_decl(name, nbits) \
	(name)[bitstr_size(nbits)]

#define	bit_test(name, bit) \
	((name)[_bit_byte(bit)] & _bit_mask(bit))

#define	bit_set(name, bit) \
	(name)[_bit_byte(bit)] |= _bit_mask(bit)

#define	bit_clear(name, bit) \
	(name)[_bit_byte(bit)] &= ~_bit_mask(bit)

#define	bit_nclear(name, start, stop) { \
	register bitstr_t *_name = name; \
	register int _start = start, _stop = stop; \
	register int _startbyte = _bit_byte(_start); \
	register int _stopbyte = _bit_byte(_stop); \
	if (_startbyte == _stopbyte) { \
		_name[_startbyte] &= ((0xff >> (8 - (_start&0x7))) | \
				      (0xff << ((_stop&0x7) + 1))); \
	} else { \
		_name[_startbyte] &= 0xff >> (8 - (_start&0x7)); \
		while (++_startbyte < _stopbyte) \
			_name[_startbyte] = 0; \
		_name[_stopbyte] &= 0xff << ((_stop&0x7) + 1); \
	} \
}

#define	bit_nset(name, start, stop) { \
	register bitstr_t *_name = name; \
	register int _start = start, _stop = stop; \
	register int _startbyte = _bit_byte(_start); \
	register int _stopbyte = _bit_byte(_stop); \
	if (_startbyte == _stopbyte) { \
		_name[_startbyte] |= ((0xff << (_start&0x7)) & \
				    (0xff >> (7 - (_stop&0x7)))); \
	} else { \
		_name[_startbyte] |= 0xff << ((_start)&0x7); \
		while (++_startbyte < _stopbyte) \
	    		_name[_startbyte] = 0xff; \
		_name[_stopbyte] |= 0xff >> (7 - (_stop&0x7)); \
	} \
}

#define	bit_ffc(name, nbits, value) { \
	register bitstr_t *_name = name; \
	register int _byte, _nbits = nbits; \
	register int _stopbyte = _bit_byte(_nbits), _value = -1; \
	for (_byte = 0; _byte <= _stopbyte; ++_byte) \
		if (_name[_byte] != 0xff) { \
			_value = _byte << 3; \
			for (_stopbyte = _name[_byte]; (_stopbyte&0x1); \
			    ++_value, _stopbyte >>= 1); \
			break; \
		} \
	*(value) = _value; \
}

#define	bit_ffs(name, nbits, value) { \
	register bitstr_t *_name = name; \
	register int _byte, _nbits = nbits; \
	register int _stopbyte = _bit_byte(_nbits), _value = -1; \
	for (_byte = 0; _byte <= _stopbyte; ++_byte) \
		if (_name[_byte]) { \
			_value = _byte << 3; \
			for (_stopbyte = _name[_byte]; !(_stopbyte&0x1); \
			    ++_value, _stopbyte >>= 1); \
			break; \
		} \
	*(value) = _value; \
}

/* ------------------------------------------------------------------------- */
/* Vixie cron constants                                                       */
/* ------------------------------------------------------------------------- */

#define TRUE		1
#define FALSE		0
#define OK			0
#define ERR			(-1)

#ifndef DEBUGGING
#define DEBUGGING	FALSE
#endif

#define READ_PIPE	0
#define WRITE_PIPE	1
#define STDIN		0
#define STDOUT		1
#define STDERR		2
#define ERROR_EXIT	1
#define	OK_EXIT		0
#define	MAX_FNAME	100
#define	MAX_COMMAND	1000
#define	MAX_TEMPSTR	1000
#define	MAX_ENVSTR	MAX_TEMPSTR
#define	MAX_UNAME	20
#define	ROOT_UID	0
#define	ROOT_USER	"root"

#define	DEXT		0x0001
#define	DSCH		0x0002
#define	DPROC		0x0004
#define	DPARS		0x0008
#define	DLOAD		0x0010
#define	DMISC		0x0020
#define	DTEST		0x0040
#define	DBIT		0x0080

#define	CRON_TAB(u)	"%s/%s", SPOOL_DIR, u
#define	REG			register
#define	PPC_NULL	((char **)NULL)

#ifndef MAXHOSTNAMELEN
#define MAXHOSTNAMELEN 64
#endif

#define Is_Blank(c) ((c) == '\t' || (c) == ' ')

#define	Skip_Blanks(c, f) \
			while (Is_Blank(c)) \
				c = get_char(f);

#define	Skip_Nonblanks(c, f) \
			while (c!='\t' && c!=' ' && c!='\n' && c != EOF && c != '\0') \
				c = get_char(f);

#define	Skip_Line(c, f) \
			do {c = get_char(f);} while (c != '\n' && c != EOF);

#if DEBUGGING
# define Debug(mask, message) \
			if ( (DebugFlags & (mask) )  ) \
				printf message;
#else
# define Debug(mask, message) \
			;
#endif

#define	MkLower(ch)	(isupper(ch) ? tolower(ch) : ch)
#define	MkUpper(ch)	(islower(ch) ? toupper(ch) : ch)
#define	Set_LineNum(ln)	{Debug(DPARS|DEXT,("linenum=%d\n",ln)); \
			 LineNumber = ln; \
			}

typedef int time_min;

/* Log levels */
#define	CRON_LOG_JOBSTART	0x01
#define	CRON_LOG_JOBEND		0x02
#define	CRON_LOG_JOBFAILED	0x04
#define	CRON_LOG_JOBPID		0x08

#define	FIRST_MINUTE	0
#define	LAST_MINUTE	59
#define	MINUTE_COUNT	(LAST_MINUTE - FIRST_MINUTE + 1)

#define	FIRST_HOUR	0
#define	LAST_HOUR	23
#define	HOUR_COUNT	(LAST_HOUR - FIRST_HOUR + 1)

#define	FIRST_DOM	1
#define	LAST_DOM	31
#define	DOM_COUNT	(LAST_DOM - FIRST_DOM + 1)

#define	FIRST_MONTH	1
#define	LAST_MONTH	12
#define	MONTH_COUNT	(LAST_MONTH - FIRST_MONTH + 1)

/* note on DOW: 0 and 7 are both Sunday */
#define	FIRST_DOW	0
#define	LAST_DOW	7
#define	DOW_COUNT	(LAST_DOW - FIRST_DOW + 1)

/* cron entry (schedule) flags */
#define	DOM_STAR	0x01
#define	DOW_STAR	0x02
#define	WHEN_REBOOT	0x04
#define MIN_STAR	0x08
#define HR_STAR		0x10
#define DOM_LAST	0x20

/* ------------------------------------------------------------------------- */
/* entry struct -- Vixie cron schedule representation                         */
/* ------------------------------------------------------------------------- */

typedef struct _entry {
	struct _entry	*next;
	uid_t		uid;
	gid_t		gid;
	char		**envp;
	int			secondsInterval;
	bitstr_t	bit_decl(minute, MINUTE_COUNT);
	bitstr_t	bit_decl(hour,   HOUR_COUNT);
	bitstr_t	bit_decl(dom,    DOM_COUNT);
	bitstr_t	bit_decl(month,  MONTH_COUNT);
	bitstr_t	bit_decl(dow,    DOW_COUNT);
	int			flags;
} entry;

typedef	struct _user {
	struct _user	*next, *prev;
	char		*name;
	time_t		mtime;
	entry		*crontab;
} user;

typedef	struct _cron_db {
	user		*head, *tail;
	time_t		user_mtime;
	time_t		sys_mtime;
} cron_db;

/* ------------------------------------------------------------------------- */
/* file_buffer -- in-memory buffer that mimics FILE * for the Vixie parser   */
/* ------------------------------------------------------------------------- */

#define MAX_FILE_BUFFER_LENGTH 1000

typedef struct _file_buffer {
	char		data[MAX_FILE_BUFFER_LENGTH];
	int			length;
	int			pointer;
	char		unget_data[MAX_FILE_BUFFER_LENGTH];
	int			unget_count;
} file_buffer;

/* ------------------------------------------------------------------------- */
/* pg_cron.h -- global settings                                               */
/* ------------------------------------------------------------------------- */

extern char *CronTableDatabaseName;
extern bool LaunchActiveJobs;

/* ------------------------------------------------------------------------- */
/* cron_job.h -- catalog column numbers                                       */
/* ------------------------------------------------------------------------- */

typedef struct FormData_cron_job
{
	int64		jobId;
#ifdef CATALOG_VARLEN
	text		schedule;
	text		command;
	text		nodeName;
	int			nodePort;
	text		database;
	text		userName;
	bool		active;
	text		jobName;
#endif
} FormData_cron_job;

typedef FormData_cron_job *Form_cron_job;

/* Match pg_cron_job.h column numbers as generated by genbki.pl.
 * Fixed-length columns come first, then variable-length inside CATALOG_VARLEN. */
#define Natts_cron_job 9
#define Anum_cron_job_jobid 1
#define Anum_cron_job_nodeport 2
#define Anum_cron_job_active 3
#define Anum_cron_job_schedule 4
#define Anum_cron_job_command 5
#define Anum_cron_job_nodename 6
#define Anum_cron_job_database 7
#define Anum_cron_job_username 8
#define Anum_cron_job_jobname 9

typedef struct FormData_job_run_details
{
	int64		jobId;
	int64		runId;
	int32		job_pid;
#ifdef CATALOG_VARLEN
	text		database;
	text		username;
	text		command;
	text		status;
	text		return_message;
	timestamptz	start_time;
	timestamptz	end_time;
#endif
} FormData_job_run_details;

typedef FormData_job_run_details *Form_job_run_details;

#define Natts_job_run_details 10
#define Anum_job_run_details_jobid 1
#define Anum_job_run_details_runid 2
#define Anum_job_run_details_job_pid 3
#define Anum_job_run_details_database 4
#define Anum_job_run_details_username 5
#define Anum_job_run_details_command 6
#define Anum_job_run_details_status 7
#define Anum_job_run_details_return_message 8
#define Anum_job_run_details_start_time 9
#define Anum_job_run_details_end_time 10

/* ------------------------------------------------------------------------- */
/* task_states.h -- task state machine                                        */
/* ------------------------------------------------------------------------- */

typedef enum
{
	CRON_TASK_WAITING = 0,
	CRON_TASK_START = 1,
	CRON_TASK_CONNECTING = 2,
	CRON_TASK_SENDING = 3,
	CRON_TASK_RUNNING = 4,
	CRON_TASK_RECEIVING = 5,
	CRON_TASK_DONE = 6,
	CRON_TASK_ERROR = 7,
	CRON_TASK_BGW_START = 8,
	CRON_TASK_BGW_RUNNING = 9
} CronTaskState;

/*
 * BackgroundWorkerHandle is defined locally in bgworker.c and forward-declared
 * as an opaque type in bgworker.h.  Since CronTask stores it by value we need
 * the complete definition here.  (bgworker.c no longer includes this header.)
 */
struct BackgroundWorkerHandle
{
	int			slot;
	uint64		generation;
};

typedef struct CronTask
{
	int64		jobId;
	int64		runId;
	CronTaskState state;
	uint		pendingRunCount;
	PGconn	   *connection;
	PostgresPollingStatusType pollingStatus;
	TimestampTz startDeadline;
	TimestampTz lastStartTime;
	uint32		secondsInterval;
	bool		isSocketReady;
	bool		isActive;
	char	   *errorMessage;
	bool		freeErrorMessage;
	shm_mq_handle *sharedMemoryQueue;
	dsm_segment *seg;
	BackgroundWorkerHandle handle;
} CronTask;

/* ------------------------------------------------------------------------- */
/* job_metadata.h -- job metadata and status                                  */
/* ------------------------------------------------------------------------- */

typedef enum
{
	CRON_STATUS_STARTING,
	CRON_STATUS_RUNNING,
	CRON_STATUS_SENDING,
	CRON_STATUS_CONNECTING,
	CRON_STATUS_SUCCEEDED,
	CRON_STATUS_FAILED
} CronStatus;

typedef struct CronJob
{
	int64		jobId;
	char	   *scheduleText;
	entry		schedule;
	char	   *command;
	char	   *nodeName;
	int			nodePort;
	char	   *database;
	char	   *userName;
	bool		active;
	char	   *jobName;
} CronJob;

/* ------------------------------------------------------------------------- */
/* Global variables                                                           */
/* ------------------------------------------------------------------------- */

extern char *CronTableDatabaseName;
extern bool CronJobCacheValid;
extern bool EnableSuperuserJobs;
extern bool LaunchActiveJobs;
extern char *CronHost;

/* ------------------------------------------------------------------------- */
/* Extern declarations -- misc.c                                              */
/* ------------------------------------------------------------------------- */

extern void unget_char(int, FILE *);
extern void free_entry(entry *);
extern void skip_comments(FILE *);
extern int	get_char(FILE *);
extern int	get_string(char *, int, FILE *, char *);
extern entry *parse_cron_entry(char *);
extern char *MonthNames[];
extern char *DowNames[];
extern int	LineNumber;

/* ------------------------------------------------------------------------- */
/* Extern declarations -- cron.c (launcher)                                   */
/* ------------------------------------------------------------------------- */

extern void cron_init_gucs(void);
extern void cron_init(void);
extern void PgCronLauncherMain(Datum arg);
extern void CronBackgroundWorker(Datum arg);

/* ------------------------------------------------------------------------- */
/* Extern declarations -- task_states.c                                       */
/* ------------------------------------------------------------------------- */

extern void InitializeTaskStateHash(void);
extern void RefreshTaskHash(void);
extern List *CurrentTaskList(void);
extern void InitializeCronTask(CronTask *task, int64 jobId);
extern void RemoveTask(int64 jobId);

/* ------------------------------------------------------------------------- */
/* Extern declarations -- job_metadata.c                                      */
/* ------------------------------------------------------------------------- */

extern void InitializeJobMetadataCache(void);
extern void ResetJobMetadataCache(void);
extern List *LoadCronJobList(void);
extern CronJob *GetCronJob(int64 jobId);
extern void InsertJobRunDetail(int64 runId, int64 *jobId, char *database,
							   char *username, char *command, char *status);
extern void UpdateJobRunDetail(int64 runId, int32 *job_pid, char *status,
							   char *return_message, TimestampTz *start_time,
							   TimestampTz *end_time);
extern int64 NextRunId(void);
extern void MarkPendingRunsAsFailed(void);
extern char *GetCronStatus(CronStatus cronstatus);
extern void InvalidateJobCacheCallback(Datum argument, Oid relationId);

#endif							/* CRON_COMMANDS_H */
