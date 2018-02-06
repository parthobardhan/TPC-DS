#!/bin/bash
set -e

PWD=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
source $PWD/../functions.sh
source_bashrc

orig_tablename=`echo $1`
tablename=`echo tpcds.$1_test`
collect_stats_num=`echo $2`
filename=`echo $3`

dbname="$PGDATABASE"
if [ "$dbname" == "" ]; then
	dbname="$ADMIN_USER"
fi

if [ "$PGPORT" == "" ]; then
	export PGPORT=5432
fi

step=hll_analyze
init_log $step

ADMIN_HOME=$(eval echo ~$ADMIN_USER)

run_analyzedb() {
	#Analyze schema using analyzedb
	start_log

	schema_name="tpcds"
	table_name="tpcds"
	analyzedb -d $dbname -s tpcds --full -a
	tuples="0"
 	log $tuples
}

get_distinct_per_table() {
	mkdir -p $PWD/hll
	psql -t -c "select staattnum, stadistinct from pg_statistic where starelid = '$1'::regclass order by staattnum;" > $PWD/hll/$2
}

analyze_add_partition() {
	schema_name="test"
	table_name=`echo $1`
	i=`echo analyze_new_part`
	echo "psql -c \"analyze $1_1_prt_new_part;\""
	tuples="0"
	start_log
	psql -A -c "analyze $1_1_prt_new_part;"
        log $tuples
	echo "psql -c \"analyze $1_1_prt_others;\""
	tuples="0"
	i=`echo analyze_default_part`
	start_log
	psql -A -c "analyze $1_1_prt_others;"
        log $tuples
	echo "psql -c \"analyze $1;\""
	tuples="0"
	i=`echo analyze_root_part`
	start_log
	psql -A -c "analyze $1;"
	log $tuples
}

recreate_table() {
	psql -c "drop table if exists $1;"
	psql -v TABLENAME=$1 -v ORIGTABLE=$2 -f $PWD/temp_table.sql
}

recreate_table $tablename $orig_tablename
echo "Running: ANALYZEDB"
run_analyzedb
echo "Finished: ANALYZEDB"
echo "Running: Extract Distict values for table: $tablename"
for j in $(seq 1 $collect_stats_num); do
	get_distinct_per_table $tablename $filename\_$j.txt
	psql -c "analyze $tablename"
done
echo "Finished: Extract Distict values"
echo "Running: Add new partition to table: $tablename"
echo "psql -t -c \"ALTER TABLE $tablename SPLIT DEFAULT PARTITION start(2453006) INCLUSIVE end(2453025) INCLUSIVE INTO (PARTITION new_part, default partition);\""
psql -A -c "ALTER TABLE $tablename SPLIT DEFAULT PARTITION start(2453006) INCLUSIVE end(2453025) INCLUSIVE INTO (PARTITION new_part, default partition);"
analyze_add_partition $tablename
echo "Finished adding partition"
get_distinct_per_table $tablename $filename\_newpart.txt
end_step $step
