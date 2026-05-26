#
# Makefile for columnar table access method
#
# src/backend/access/columnar/Makefile
#

subdir = src/backend/access/columnar
top_builddir = ../../../..
include $(top_builddir)/src/Makefile.global

# Imported columnar sources still use mixed declarations and code extensively.
override CFLAGS += -Wno-declaration-after-statement

OBJS = \
	columnar.o \
	columnar_cache.o \
	columnar_compression.o \
	columnar_customscan.o \
	columnar_debug.o \
	columnar_indexscan.o \
	columnar_metadata.o \
	columnar_planner_hook.o \
	columnar_read_state_cache.o \
	columnar_reader.o \
	columnar_storage.o \
	columnar_tableam.o \
	columnar_writer.o \
	safeclib/abort_handler_s.o \
	safeclib/ignore_handler_s.o \
	safeclib/mem_primitives_lib.o \
	safeclib/memcmp16_s.o \
	safeclib/memcmp32_s.o \
	safeclib/memcmp_s.o \
	safeclib/memcpy16_s.o \
	safeclib/memcpy32_s.o \
	safeclib/memcpy_s.o \
	safeclib/memmove16_s.o \
	safeclib/memmove32_s.o \
	safeclib/memmove_s.o \
	safeclib/memset16_s.o \
	safeclib/memset32_s.o \
	safeclib/memset_s.o \
	safeclib/memzero16_s.o \
	safeclib/memzero32_s.o \
	safeclib/memzero_s.o \
	safeclib/safe_mem_constraint.o \
	safeclib/safe_str_constraint.o \
	safeclib/snprintf_support.o \
	safeclib/stpcpy_s.o \
	safeclib/stpncpy_s.o \
	safeclib/strcasecmp_s.o \
	safeclib/strcasestr_s.o \
	safeclib/strcat_s.o \
	safeclib/strcmp_s.o \
	safeclib/strcmpfld_s.o \
	safeclib/strcpy_s.o \
	safeclib/strcpyfld_s.o \
	safeclib/strcpyfldin_s.o \
	safeclib/strcpyfldout_s.o \
	safeclib/strcspn_s.o \
	safeclib/strfirstchar_s.o \
	safeclib/strfirstdiff_s.o \
	safeclib/strfirstsame_s.o \
	safeclib/strisalphanumeric_s.o \
	safeclib/strisascii_s.o \
	safeclib/strisdigit_s.o \
	safeclib/strishex_s.o \
	safeclib/strislowercase_s.o \
	safeclib/strismixedcase_s.o \
	safeclib/strispassword_s.o \
	safeclib/strisuppercase_s.o \
	safeclib/strlastchar_s.o \
	safeclib/strlastdiff_s.o \
	safeclib/strlastsame_s.o \
	safeclib/strljustify_s.o \
	safeclib/strncat_s.o \
	safeclib/strncpy_s.o \
	safeclib/strnlen_s.o \
	safeclib/strnterminate_s.o \
	safeclib/strpbrk_s.o \
	safeclib/strprefix_s.o \
	safeclib/strremovews_s.o \
	safeclib/strspn_s.o \
	safeclib/strstr_s.o \
	safeclib/strtok_s.o \
	safeclib/strtolowercase_s.o \
	safeclib/strtouppercase_s.o \
	safeclib/strzero_s.o \
	safeclib/wcpcpy_s.o \
	safeclib/wcscat_s.o \
	safeclib/wcscpy_s.o \
	safeclib/wcsncat_s.o \
	safeclib/wcsncpy_s.o \
	safeclib/wcsnlen_s.o \
	safeclib/wmemcmp_s.o \
	safeclib/wmemcpy_s.o \
	safeclib/wmemmove_s.o \
	safeclib/wmemset_s.o \
	vectorization/columnar_vector_execution.o \
	vectorization/columnar_vector_types.o \
	vectorization/nodes/columnar_aggregator_node.o \
	vectorization/types/aggregates.o \
	vectorization/types/date.o \
	vectorization/types/int.o \
	vectorization/types/numeric.o \
	write_state_interface.o \
	write_state_management.o \
	write_state_row_mask.o

include $(top_srcdir)/src/backend/common.mk
