#!/bin/bash

set -e
set -x
set -o pipefail

REDUCER_LOC=~/SAR-proc
SARAPP_LOC=~/SAR-app

# Clone itself.
git clone https://github.com/SixSq/SAR-app.git $SARAPP_LOC
source $SARAPP_LOC/app/lib.sh

cloud=`ss-get cloudservice`
service_offer=`ss-get service-offer`
echo "@REDUCER_RUN $(timestamp) start deployment (cloud, service offer): $cloud $service_offer"

mapper_ids=`ss-get --noblock mapper:ids | sed -e 's/,/ /g'`
mapper_mult=`ss-get mapper:multiplicity`

set_listeners() {
    # Lauch netcat daemons for each  product
    echo -n $mapper_ids | xargs -d ' ' -I% bash -c '(nc -l 808%  0<&- 1>%.png) &'
}

check_mappers_ready() {
    # Run multiple daemons depending on the mapper VM multiplicity and
    # whithin these a timeout checking mapper's ready state is triggered.

    echo -n $mapper_ids | xargs -d ' ' -I% bash -c '(
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
    check_mappers_ready
    # Wait before all mappers are in ready state.
    while [ $(count_ready) -ne $mapper_mult ]; do
        sleep 100
    done
}

# Clone reducer.
git clone `ss-get proc-git-repo` $REDUCER_LOC

start_filebeat

cd $SARAPP_LOC/app/reducer
set_listeners
wait_mappers_ready

# Generate the final output
cd $REDUCER_LOC
echo "@REDUCER_RUN $(timestamp) start processing."
export INPUT_DATA_LOC=$SARAPP_LOC/app/reducer
export OUTPUT_DATA_LOC=$SARAPP_LOC/app/reducer/output
mkdir -p $OUTPUT_DATA_LOC
./SAR_reducer.sh $INPUT_DATA_LOC $OUTPUT_DATA_LOC
echo "@REDUCER_RUN $(timestamp) finish processing."


