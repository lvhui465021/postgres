/* aux_mysql 1.5 -> 1.6
 *
 * The MySQL JSON functions (mysql.json for int2/int4/int8/float4/float8/
 * numeric and mysql.mys_json_object) moved out of the kernel pg_proc.dat
 * into this extension, backed by the mysm shared library.  Instances
 * upgraded from 1.5 previously resolved these from the kernel catalog;
 * redeclare them here so the extension owns them.
 */
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.int2)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.int4)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.int8)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.float4)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.float8)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.json(pg_catalog.numeric)
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_to_json'
LANGUAGE C STABLE STRICT;
CREATE OR REPLACE FUNCTION mysql.mys_json_object(VARIADIC "any")
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_json_object'
LANGUAGE C STABLE CALLED ON NULL INPUT;
CREATE OR REPLACE FUNCTION mysql.mys_json_object()
RETURNS pg_catalog.json
AS '$libdir/mysm', 'mys_json_object_noargs'
LANGUAGE C STABLE CALLED ON NULL INPUT;
