#!/bin/bash

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

GEN_DATA_SCALE=$1
EXPLAIN_ANALYZE=$2
SQL_VERSION=$3
RANDOM_DISTRIBUTION=$4
MULTI_USER_COUNT=$5
EXPLAIN_PLAN=$8

if [[ "$GEN_DATA_SCALE" == "" || "$EXPLAIN_ANALYZE" == "" || "$SQL_VERSION" == "" || "$RANDOM_DISTRIBUTION" == "" || "$MULTI_USER_COUNT" == "" ]]; then
	echo "You must provide the scale as a parameter in terms of Gigabytes, true/false to run queries with EXPLAIN ANALYZE option, the SQL_VERSION, and true/false to use random distrbution."
	echo "Example: ./rollout.sh 100 false tpcds false 5"
	echo "This will create 100 GB of data for this test, not run EXPLAIN ANALYZE, use standard TPC-DS, not use random distribution and use 5 sessions for the multi-user test."
	exit 1
fi

step=sql
init_log $step

rm -f $PWD/../log/*single.explain_analyze.log
rm -f $PWD/../log/*single.explain.log

for i in $(ls $PWD/*.$SQL_VERSION.*.sql); do
	id=`echo $i | awk -F '.' '{print $1}'`
	schema_name=`echo $i | awk -F '.' '{print $2}'`
	table_name=`echo $i | awk -F '.' '{print $3}'`
	start_log

	if [[ "$EXPLAIN_ANALYZE" == "false" && "$EXPLAIN_PLAN" == "false" ]]; then
		echo "psql -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE=\"\" -f $i | wc -l"
		tuples=$(psql -A -q -t -P pager=off -v ON_ERROR_STOP=ON -v EXPLAIN_ANALYZE="" -f $i | wc -l; exit ${PIPESTATUS[0]})
		if [ $? -eq 0 ]; then
			echo "$tuples"
		else
			tuples=-1
			echo "$tuples"
		fi
	elif [ "$EXPLAIN_ANALYZE" == "true" ]; then
		myfilename=$(basename $i)
		mylogfile=$PWD/../log/$myfilename.single.explain_analyze.log
		echo "psql -A -q -t -P pager=off -v ON_ERROR_STOP=OFF -v EXPLAIN_ANALYZE=\"EXPLAIN ANALYZE\" -f $i > $mylogfile"
		psql -A -q -t -P pager=off -v ON_ERROR_STOP=OFF -v EXPLAIN_ANALYZE="EXPLAIN ANALYZE" -f $i > $mylogfile
		tuples="0"
	elif [ "$EXPLAIN_PLAN" == "true" ]; then
		myfilename=$(basename $i)
		mylogfile=$PWD/../log/$myfilename.single.explain.log
		echo "psql -A -q -t -P pager=off -v ON_ERROR_STOP=OFF -v EXPLAIN_ANALYZE=\"EXPLAIN \" -f $i > $mylogfile"
		psql -A -q -t -P pager=off -v ON_ERROR_STOP=OFF -v EXPLAIN_ANALYZE="EXPLAIN " -f $i > $mylogfile
		tuples="0"
	fi
	log $tuples
done

end_step $step
