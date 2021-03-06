#!/bin/bash
set -e
set -x

S3_HOST=`ss-get --noblock s3-host`
S3_BUCKET=`ss-get --noblock s3-bucket`
S3_ACCESS_KEY=`ss-get --noblock s3-access-key`
S3_SECRET_KEY=`ss-get --noblock s3-secret-key`

source ~/SAR-app/app/lib.sh
echo "@REDUCER_RUN $(timestamp) start uploading result(s) to S3."
if [ -n "$S3_HOST" -a -n "$S3_BUCKET" -a -n "$S3_ACCESS_KEY" -a -n "$S3_SECRET_KEY" ]; then
    config_s3 $S3_HOST $S3_ACCESS_KEY $S3_SECRET_KEY

    cd ~/SAR-app/app/reducer/output
    output=*.gif
    cp $output $SLIPSTREAM_REPORT_DIR
    s3cmd put $output s3://$S3_BUCKET
    ss-set ss:url.service s3://$S3_BUCKET/`ls $output`
else
    echo "@REDUCER_RUN WARNING: Not uploading result to S3. Not all S3 options were provided."
fi
echo "@REDUCER_RUN $(timestamp) finish uploading result(s) to S3."

cloud=`ss-get cloudservice`
service_offer=`ss-get service-offer`
echo "@REDUCER_RUN $(timestamp) finish deployment (cloud, service offer): $cloud $service_offer"
