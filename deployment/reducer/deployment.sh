#!/bin/bash

set -e
set -x
set -o pipefail

source ../lib.sh

echo "@REDUCER_RUN: "$(timestamp)" - \
          VM started on cloudservice: `ss-get cloudservice` \
          with service-offer: `ss-get service-offer`."

S3_HOST=`ss-get --noblock s3-host`
S3_BUCKET=`ss-get --noblock s3-bucket`
S3_ACCESS_KEY=`ss-get --noblock s3-access-key`
S3_SECRET_KEY=`ss-get --noblock s3-secret-key`

set_listeners() {
    # Lauch netcat daemons for each  product
    echo -n  $@ | xargs -d ' ' -I% bash -c '(nc -l 808%  0<&- 1>%.png) &'
}

check_mappers_ready() {
    # Run multiple daemons depending on the mapper VM multiplicity and
    # whithin these a timeout checking mapper's ready state is triggered.

    echo -n $ids | xargs -d ' ' -I% bash -c '(
    ss-get --timeout 2600 mapper.%:ready
    echo 'mapper.'%':ready' >>readylock.md
    exit 0) &'
}

count_ready() {
    # The number of line existing in "readylock.md" file indicates
    # how many mappers are is in ready state.
    echo `cat readylock.md | wc -l`
}

wait_mappers_ready() {
    touch readylock.md
    ids=`ss-get --noblock mapper:ids | sed -e 's/,/ /g'`
    set_listeners $ids
    check_mappers_ready
    # Wait before all mappers are in ready state.
    while [ $(count_ready) -ne `ss-get mapper:multiplicity` ]; do
        sleep 100
    done
}
start_filebeat
wait_mappers_ready

# Create the final output
cd ~/SAR_proc
echo "@REDUCER_RUN :"$(timestamp): "Start conversion."
./SAR_reducer.sh
echo "@REDUCER_RUN :"$(timestamp): "Finish conversion."
