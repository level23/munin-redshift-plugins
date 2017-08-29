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
    echo "graph_title Redshift commit queue"
    echo "graph_vlabel Time in seconds"
    echo "graph_category redshift"
    echo "graph_info Display info about the redshift commit queue"
    echo "graph_order queue_time_sec commit_time_sec queue_size"

    echo "queue_time_sec.label Average commit queue time"
    echo "commit_time_sec.label Average commit time"
    echo "queue_size.label Average commit queue size"
}

verbose()
{
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
            select
                avg( datediff(ms,startqueue,startwork)::float ) as queue_time,
                avg( datediff(ms, startwork, endtime)::float ) as commit_time,
                avg( queuelen::float )
            from stl_commit_stats
            where startqueue >= getdate() - interval '5 minutes'
            and queuelen >= 1;")

    psql_exit_status=$?

    if [[ ${psql_exit_status} != 0 ]];
    then
        echo "psql failed while trying to run this sql script" 1>&2
        exit ${psql_exit_status};
    fi

    #echo "" | awk -F" | " "{print $0}"
    echo "${result}" | awk -F'|' '{
        printf "queue_time_sec.value %.2f\n", $1 / 1000
        printf "commit_time_sec.value %.2f\n", $2 / 1000
        printf "queue_size.value %.2f\n", $3
    }'
}

output_usage() {
    printf >&2 "%s - munin plugin to graph the redshift commit queue\n" ${0##*/}
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