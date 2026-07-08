/*-------------------------------------------------------------------------
 *
 * spi_demo.h
 *	  Declarations for SPI (Server Programming Interface) demonstration.
 *
 * Portions Copyright (c) 1996-2026, PostgreSQL Global Development Group
 *
 * src/include/utils/spi_demo.h
 *
 *-------------------------------------------------------------------------
 */
#ifndef SPI_DEMO_H
#define SPI_DEMO_H

#include "fmgr.h"

extern Datum get_test_by_name(PG_FUNCTION_ARGS);
extern Datum update_test_timestamp(PG_FUNCTION_ARGS);
extern Datum spi_execute_list(PG_FUNCTION_ARGS);
extern Datum spi_execute_insert(PG_FUNCTION_ARGS);
extern Datum spi_execute_count(PG_FUNCTION_ARGS);
extern Datum copy_triggers(PG_FUNCTION_ARGS);
extern Datum spi_demo_prepared(PG_FUNCTION_ARGS);
extern Datum spi_demo_cursor(PG_FUNCTION_ARGS);
extern Datum spi_demo_metadata(PG_FUNCTION_ARGS);
extern Datum spi_demo_spi_palloc(PG_FUNCTION_ARGS);
extern Datum spi_demo_atomic(PG_FUNCTION_ARGS);

#endif /* SPI_DEMO_H */
