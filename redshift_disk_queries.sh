#!/bin/bash

redshift_host=${redshift_host:-localhost}
redshift_user=${redshift_user}
redshift_pass=${redshift_pass}
redshift_port=${redshift_port:-5439}
redshift_db=${redshift_db}

export PGPASSWORD=${redshift_pass}

tmp_result_file=/tmp/redshift_diskbased_queries_munin


type psql >/dev/null 2>&1 || { echo >&2 "I require psql but it's not installed. Aborting."; exit 1; }

output_config() {
    echo "graph_title Redshift disk queries"
    echo "graph_vlabel Number of queries on disk"
    echo "graph_category redshift"
    echo "graph_info Display info about how many queries are executed on disk"

    echo "disk_queries.label Number of disk queries"
}

store_result() {
    result=$(psql \
        --tuples-only \
        --host="${redshift_host}" \
        --username="${redshift_user}" \
        --port="${redshift_port}" \
        --dbname="${redshift_db}" \
        --command="
            -- DISK based queries
            SELECT COUNT(qs.query) as num
            FROM (
              SELECT distinct query
              FROM svl_query_summary
              WHERE is_diskbased='t'
              AND (LABEL LIKE 'hash%' OR LABEL LIKE 'sort%' OR LABEL LIKE 'aggr%')
              AND userid > 1
            ) qs
            JOIN STL_QUERY sq ON sq.query=qs.query AND sq.starttime >= getdate() - interval '1 hour';")

    psql_exit_status=$?

    if [[ ${psql_exit_status} != 0 ]];
    then
        echo "psql failed while trying to run this sql script" 1>&2
        exit ${psql_exit_status};
    fi

    echo "${result}" >> ${tmp_result_file}
}

output_values() {

    result=$(cat "${tmp_result_file}")
    echo $result;
    echo "${result}" | awk '{
        printf "disk_queries.value %.2f\n", $0
    }'
}

output_usage() {
    printf >&2 "%s - munin plugin to graph disk based queries in redshift\n" ${0##*/}
    printf >&2 "Usage: %s [config] [cron]\n" ${0##*/}
}

case $# in
    0)
        output_values
        ;;
    1)
        case $1 in
            config)
                output_config
                ;;

            cron)
                store_result
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