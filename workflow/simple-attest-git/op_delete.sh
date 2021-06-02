#!/bin/bash

# So, in fact, the delete operation is already implemented but hidden in
# op_query.sh. This is because the main logic is around figuring out what to
# operate on, given a ekpubhash _prefix_, which is what query already handles.
# We activate the "delete" behavior in the way we invoke op_query;
export QUERY_PLEASE_ALSO_DELETE=1

# Source rather then execute, that way $0 shows the right thing and the
# remaining args ($1, $2, etc) are preserved without effort.
. /op_query.sh
