#!/bin/bash

set -x

usage() {
    cat << EOF

Usage `basename $0` -m <mode> [-i <master_ip>] [-c <concurrency> ] [-o <operations>]
    mode can be one of those:
     - install : deploy the ssbench virtualenv
     - spawn_workers : start as much workers as CPU
       (use -i option to specify the remote master)
     - kill_worker : stop all current workers on local host
     - rampup : start the rampup evaluation
       (use -o option to specify the amount of operation to perform)
     - bench : start the bench evaluation
       (use -c option to specify client concurrency
Some of environnement variables must be set:
    for all modes:
     - WORKSPACE : the workspace directory (where this project has
       been checkouted)
     - CHECKOUTDIR : the project directory 
    for bench and rampup modes :
     - KEYSTONE_ENDPOINT : the authentication keystone endpoint
     - TENANT : the user tenant
     - USERNAME : the username
     - PASSWORD : the user password
    for bench mode :
     - SCENARIOS : a comma sperated list of scenarios name
EOF
    exit 1
}
    
# Jenkins provides a WORKSPACE env variable
[ -z "$WORKSPACE" ] && {
    echo "WORKSPACE is not set"
    usage
}
# Where to find scenarios and parsers directory relative to $WORKSPACE env
[ -z "$CHECKOUTDIR" ] && {
    echo "CHECKOUTDIR is not set"
    usage
}

RAMPUPCSVDIR=/tmp/csvrampup
ETH=eth0
SSDESTDIR=$WORKSPACE/ssbench-venv
TDIR=$WORKSPACE/temp

myip=`ip addr list $ETH |grep "inet " |cut -d' ' -f6|cut -d/ -f1`

find_max() {
    array=("${@}")
    vmax=0
    for i in ${array[@]}; do
        [ "$vmax" -lt "$i" ] && {
            vmax=$i
        }
    done
    echo $vmax
}

check_env_vars() {
    # Verify some mandatory environement variables
    [ -z "$KEYSTONE_ENDPOINT" ] && { echo "KEYSTONE_ENDPOINT is not set"; usage; }
    [ -z "$TENANT" ] && { echo "TENANT is not set"; usage; }
    [ -z "$USERNAME" ] && { echo "USERNAME is not set"; usage; }
    [ -z "$PASSWORD" ] && { echo "PASSSWORD is not set"; usage; }
}

check_env() {
    env_fail=0
    [ -d "$SSDESTDIR" ] || env_fail=1
    [ -f "$SSDESTDIR/bin/activate" ] || env_fail=1
    [ -x "$SSDESTDIR/bin/ssbench-master" ] || env_fail=1
    [ "$env_fail" = 1 ] && {
        echo "Install ssbench env before"
        usage
    }
}

parse_created_csv() {
    for name in $SCENARIOS; do
        [ -f $TDIR/${name}.report ] || {
            echo "Unable to find report file $TDIR/${name}.report"
            return 1
        } && {
            awk -f $WORKSPACE/$CHECKOUTDIR/parsers/${name}.awk \
                   $TDIR/${name}.report
        }
    done
}

install_ssbench() {
    [ -d "$SSDESTDIR" ] && rm -Rf $SSDESTDIR
    virtualenv $SSDESTDIR
    cd $SSDESTDIR
    . bin/activate
    pip install --upgrade distribute
    pip install Cython gevent pyzmq==2.2.0
    pip install ssbench
    pip install python-keystoneclient
    pip install python-swiftclient
    [ ! -x bin/ssbench-master ] && {
        echo "ssbench has not been installed"
        cd -
        return 1
    }
    echo "ssbench has been successfully installed"
    cd -
    deactivate
}

get_extract_token() {
    echo "Working in $TDIR"
    curl -s -d "{\"auth\": {\"tenantName\": \"$TENANT\", \"passwordCredentials\": \
        {\"username\": \"$USERNAME\", \"password\": \"$PASSWORD\"}}}" \
        -H 'Content-type: application/json' $KEYSTONE_ENDPOINT/tokens > $TDIR/token
    python -c "import json;import sys; t=json.load(file(sys.argv[1])); \
        print t['access']['token']['id']" $TDIR/token > $TDIR/tokenid
    python -c "import json;import sys; import pprint; t=json.load(file(sys.argv[1])); \
        e=[e for e in t['access']['serviceCatalog'] if e['name'] == 'swift']; \
        print e[0]['endpoints'][0]['publicURL']" $TDIR/token > $TDIR/swift_endpoint
    # ssbench fails to resolv hostname (strange behaviour) so manually set ip of cw-vip-swift
    sed -i 's/cw-vip-swift.enovance.com/10.68.0.152/' $TDIR/swift_endpoint
    [ "`wc -l $TDIR/tokenid | cut -d' ' -f1`" = 1 ] && \
    [ "`wc -l $TDIR/swift_endpoint | cut -d' ' -f1`" = 1 ]
}

kill_workers() {
    echo "Kill all workers"
    pkill -f ssbench-worker
}

spawn_workers() {
    # Worker amount needed if not provided set a hight value
    [ -z $1 ] && workers_n=100 || workers_n=$1
    # id prefix
    pre=`echo $myip | cut -d'.' -f4`
    # CPU amount
    cpu_a=`cat /proc/cpuinfo | grep processor | wc -l`
    for wid in `seq 1 $workers_n`; do
        # Current running workers amount
        workers_a=`pgrep ssbench-worker | wc -l`
        echo "Host with $cpu_a CPU and currently $workers_a workers running"
        [ "$workers_a" -ge "$cpu_a" ] && {
            return 1
        }
        cd $SSDESTDIR
        . bin/activate
        bin/ssbench-worker --zmq-host $master_ip ${pre}${wid} > /dev/null 2>&1 &
        echo "Worker $wid has been spawned [$!]"
        deactivate
        cd - > /dev/null
    done
    return 0
}

clean_swift() {
    cd $SSDESTDIR
    . bin/activate
    swift --os-username=$USERNAME --os-tenant-name=$TENANT \
          --os-password=$PASSWORD --os-auth-url=$KEYSTONE_ENDPOINT delete --all
    cd - > /dev/null
    deactivate
}

start_bench() {
    concurrency=$1
    for name in $SCENARIOS; do
        spath=$WORKSPACE/$CHECKOUTDIR/scenarios/${name}.scenario
        [ -f $spath ] || {
            echo "Unable to find scenario file $spath"
            return 1
        }
        cd $SSDESTDIR
        . bin/activate
        bin/ssbench-master run-scenario -S `cat $TDIR/swift_endpoint` \
            -T `cat $TDIR/tokenid` \
            -f $spath \
            -u $concurrency -s $TDIR/${name}.stat
        bin/ssbench-master report-scenario -s $TDIR/${name}.stat.gz \
            -f $TDIR/${name}.report
        cd - > /dev/null
        deactivate
        echo "Sleep a while ..."
        sleep 5
    done
}


start_rampup() {
    # Start values
    concurrency=0
    stage=0
    concurrency_inc=2
    limit="notfound"
    csvfile="$RAMPUPCSVDIR/`date +%s`.csv"
    declare -a ops
    echo "Start the rampup scenario"
    echo "stage,workers,concurrency,ops" > $csvfile
    while [ "$limit" != "found" ]; do
        stage=$((stage + 1))
        concurrency=$((concurrency + concurrency_inc))
        echo "Start stage with concurrency=$concurrency"
        spath=$WORKSPACE/$CHECKOUTDIR/scenarios/rampup.scenario
        cd $SSDESTDIR
        . bin/activate
        token=`cat $TDIR/tokenid`
        endpoint=`cat $TDIR/swift_endpoint`
        bin/ssbench-master run-scenario -q -S $endpoint \
            -T $token \
            -f $spath \
            -o $op_count \
            -u $concurrency -s $TDIR/rampup.stat
        cd - > /dev/null
        rm -f /tmp/rampup
        ssbench-master report-scenario -s $TDIR/rampup.stat.gz \
            -f /tmp/rampup
        totalops=`grep -A1 TOTAL /tmp/rampup | awk '/second/ {print $NF}'`
        workers=`cat /tmp/rampup | awk '/Worker count/ {print $3}'`
        ops=(${ops[@]} "${totalops/.*}")
        deactivate
        length="${#ops[@]}"
        last=$((length - 1))
        op=${ops[$last]}
        vmax=`find_max ${ops[@]}`
        echo "Last run we got : $op ops/s on swift with usage of $workers workers"
        echo "Values (op/s) for previous runs are : ${ops[@]}"
        echo "$stage,$workers,$concurrency,$op" >> $csvfile
        [ "$op" -lt "$vmax" ] && {
            echo "We just found cluster limit to $vmax ops/s"
            echo "Result details can be found in $csvfile"
            limit="found"
        }
    done
}

while getopts “hm:i:c:o:” OPTION; do
    case $OPTION in
        h)
        usage
        exit
        ;;
        i)
        mip=$OPTARG
        ;;
        m)
        mode=$OPTARG
        ;;
        c)
        conc=$OPTARG
        ;;
        o)
        op=$OPTARG
        ;;
        ?)
        usage
        exit
        ;;
    esac
done

[ "$mode" = "bench" ] && {
    [ -z "$SCENARIOS" ] && {
        echo "SCENARIOS is not set"
        usage
    }
    [ ! -d $TDIR ] && mkdir -p $TDIR
    [ -z "$conc" ] && {
        usage
    }
    concurrency=$conc
    #[ -n "$op" ] && op_count=$op || op_count=1000
    check_env_vars
    check_env
    get_extract_token && start_bench $concurrency && parse_created_csv
}

[ "$mode" = "rampup" ] && {
    [ ! -d $TDIR ] && mkdir -p $TDIR
    [ ! -d $RAMPUPCSVDIR ] && mkdir -p $RAMPUPCSVDIR
    [ -n "$op" ] && op_count=$op || op_count=1000
    check_env_vars
    check_env
    get_extract_token && start_rampup
}

[ "$mode" == "spawn_workers" ] && {
    check_env
    kill_workers
    # Will spawn as much as workers it can according to
    # CPU amount on this node.
    [ -n "$mip" ] && master_ip=$mip || master_ip=$myip
    echo "Workers will use $master_ip as benchmark master."
    spawn_workers
}

[ "$mode" == "kill_workers" ] && {
    kill_workers
}

[ "$mode" = "install" ] && {
    install_ssbench
}

[ "$mode" = "clean_swift" ] && {
    check_env_vars
    check_env
    clean_swift
}

exit 0
