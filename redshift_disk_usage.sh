#!/bin/bash

redshift_host=${redshift_host:-localhost}
redshift_user=${redshift_user}
redshift_pass=${redshift_pass}
redshift_port=${redshift_port:-5439}
redshift_db=${redshift_db}

export PGPASSWORD=${redshift_pass}

TEST=0

type psql >/dev/null 2>&1 || { echo >&2 "I require psql but it's not installed. Aborting."; exit 1; }

output_config() {
    echo "graph_title Redshift disk usage percent"
    echo "graph_args --rigid --lower-limit 0 --upper-limit 100 --vertical-label %"
    echo "graph_vlabel Disk usage"
    echo "graph_category redshift"

    echo "usage.label usage"
    echo "usage.info usage"
    echo "usage.type GAUGE"
}

verbose() {
    if [[ ${TEST} -eq 1 ]];
    then
        echo $1;
    fi
}

output_values() {
    verbose "Start collecting data from redshift"
    verbose "Host: ${redshift_host}"
    verbose "User: ${redshift_user}"
    verbose "Port: ${redshift_port}"
    verbose "Database: ${redshift_db}"

    result=$(psql \
        --tuples-only \
        --host="${redshift_host}" \
        --username="${redshift_user}" \
        --port="${redshift_port}" \
        --dbname="${redshift_db}" \
        --command="
            SELECT
                SUM(used)/1024 AS used_gbytes,
                SUM(capacity)/1024 AS capacity_gbytes
            FROM
                stv_partitions
            WHERE
                part_begin=0;")

    psql_exit_status=$?

    if [[ ${psql_exit_status} != 0 ]];
    then
        echo "psql failed while trying to run this sql script" 1>&2
        exit ${psql_exit_status};
    fi

    verbose "Raw result: ${result}"

    echo "${result}" | awk -F'|' '{ printf "usage.value %.2f\n", ( $1 / $2 ) * 100 }'
}

output_usage() {
    printf >&2 "%s - munin plugin to graph the redshift disk usage\n" ${0##*/}
    printf >&2 "Usage: %s [config|test]\n" ${0##*/}
}

case $# in
    0)
        output_values
        ;;
    1)
        case $1 in
            test)
                TEST=1
                output_values
                ;;

            config)
                output_config
                ;;
            *)
                output_usage
                exit 1
                ;;
        esac
        ;;
    *)
        output_usage
        exit 1
        ;;
esac