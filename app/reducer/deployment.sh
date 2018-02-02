#!/bin/bash

set -e
set -x
set -o pipefail

REDUCER_LOC=~/SAR-proc
SARAPP_LOC=~/SAR-app

cloud=`ss-get cloudservice`
service_offer=`ss-get service-offer`
echo "@REDUCER_RUN $(timestamp) VM started (cloud, service offer): $cloud $service_offer"

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

# Clone itself.
git clone https://github.com/SixSq/SAR-app.git $SARAPP_LOC
cd $SARAPP_LOC/app/reducer
source ../lib.sh
start_filebeat
set_listeners
cd $SARAPP_LOC/app/reducer
wait_mappers_ready

# Generate the final output
cd $REDUCER_LOC
echo "@REDUCER_RUN $(timestamp) start conversion."
export INPUT_DATA_LOC=$SARAPP_LOC/app/reducer
export OUTPUT_DATA_LOC=$SARAPP_LOC/app/reducer/output
mkdir -p $OUTPUT_DATA_LOC
./SAR_reducer.sh $INPUT_DATA_LOC $OUTPUT_DATA_LOC
echo "@REDUCER_RUN $(timestamp) finish conversion."

# Upload result to user defined object store.
S3_HOST=`ss-get --noblock s3-host`
S3_BUCKET=`ss-get --noblock s3-bucket`
S3_ACCESS_KEY=`ss-get --noblock s3-access-key`
S3_SECRET_KEY=`ss-get --noblock s3-secret-key`
if [ -n "$S3_HOST" -a -n "$S3_BUCKET" -a -n "$S3_ACCESS_KEY" -a -n "$S3_SECRET_KEY" ]; then
    cat > ~/.s3cfg <<EOF
[default]
host_base = $S3_HOST
host_bucket = %(bucket)s.$S3_HOST
access_key = $S3_ACCESS_KEY
secret_key = $S3_SECRET_KEY
use_https = True
EOF
    echo "@REDUCER_RUN $(timestamp) start uploading result(s) to S3."
    s3cmd put $OUTPUT_DATA_LOC/* s3://$S3_BUCKET
    echo "@REDUCER_RUN $(timestamp) finish uploading result(s) to S3."
else
    echo "WARNING: Not uploading result to S3. Not all S3 options were provided."
fi
