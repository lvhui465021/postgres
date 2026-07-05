/*-------------------------------------------------------------------------
 *
 * syscache_demo.c
 *	  Demonstration of PostgreSQL system catalog cache (SysCache) operations.
 *
 * This file demonstrates:
 *	- Using SearchSysCache2 to look up pg_class tuples by relname
 *	- Extracting fields from cached catalog tuples via GETSTRUCT
 *	- Proper release of SysCache references
 *
 * IDENTIFICATION
 *	  src/backend/utils/cache/syscache_demo.c
 *
 *-------------------------------------------------------------------------
 */
#include "postgres.h"

#include "access/htup_details.h"
#include "utils/syscache.h"
#include "utils/syscache_demo.h"


/*
 * get_test_tuples
 *
 * Look up a pg_class tuple by relation name and namespace via the system
 * catalog cache, and extract three key fields: oid, relkind, and relnatts.
 *
 * NOTE: RELNAMENSP is a 2-key syscache (relname + relnamespace), therefore
 * we must use SearchSysCache2 rather than SearchSysCache1.  Relation names
 * are unique only within a single namespace (schema), so both keys are
 * required for an unambiguous lookup.  For single-key lookups, such as
 * looking up a relation by OID via the RELOID cache, SearchSysCache1 can
 * be used instead.
 *
 * Parameters:
 *   relname      - name of the relation to look up
 *   relnamespace - OID of the namespace (schema) containing the relation
 *   oid          - [out] receives the relation's OID
 *   relkind      - [out] receives the relation's kind (e.g. 'r' for table)
 *   relnatts     - [out] receives the number of user attributes
 *
 * Returns true if the relation was found, false otherwise.
 */
bool
get_test_tuples(const char *relname, Oid relnamespace,
				Oid *oid, char *relkind, int16 *relnatts)
{
	HeapTuple	tp;
	Form_pg_class reltup;

	/*
	 * Search the RELNAMENSP cache for a pg_class row matching the given
	 * (relname, relnamespace) pair.  Key1 = relname (cstring), key2 =
	 * relnamespace (Oid).
	 */
	tp = SearchSysCache2(RELNAMENSP,
						 PointerGetDatum(relname),
						 ObjectIdGetDatum(relnamespace));

	/* Relation not found */
	if (!HeapTupleIsValid(tp))
		return false;

	/*
	 * Cast the returned HeapTuple to Form_pg_class to access the catalog
	 * row's fields directly.  GETSTRUCT(tp) returns a pointer to the fixed-
	 * length portion of the tuple, which corresponds to the FormData_pg_class
	 * struct defined in pg_class.h.
	 */
	reltup = (Form_pg_class) GETSTRUCT(tp);

	/* Extract the requested fields */
	*oid = reltup->oid;
	*relkind = reltup->relkind;
	*relnatts = reltup->relnatts;

	/*
	 * Release the SysCache reference.  This is mandatory -- every successful
	 * SearchSysCache call must be paired with ReleaseSysCache to avoid
	 * holding onto catalog cache entries indefinitely.
	 */
	ReleaseSysCache(tp);

	return true;
}
