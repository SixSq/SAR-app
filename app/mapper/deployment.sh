#!/bin/bash
set -e
set -x
set -o pipefail

MAPPER_LOC=~/SAR-proc
SARAPP_LOC=~/SAR-app

cloud=`ss-get cloudservice`
service_offer=`ss-get service-offer`
echo "@MAPPER_RUN: $(timestamp) VM started (cloud, service offer): $cloud $service_offer"

id=`ss-get id`
SAR_data=(`ss-get product-list`)
[ -n "$SAR_data" ] || ss-abort -- "product-list should not be empty."
my_product=${SAR_data[$id-1]}
IFS=' ' read -r -a my_product <<< "$my_product"
echo "@MAPPER_RUN: $(timestamp) $my_product for processing: ${my_product[@]}"

S3_HOST=`ss-get s3-host`
S3_BUCKET=`ss-get s3-bucket`

reducer_ip=`ss-get reducer:hostname`

get_data() {
    echo "@MAPPER_RUN: $(timestamp) start downloading product."

    cd $SARAPP_LOC/app/mapper
    echo $(date)
    for i in ${my_product[@]}; do
        python3 get_data.py "https://$S3_HOST/$S3_BUCKET/" "$i.SAFE"
        # When config_s3 was used.
        #s3cmd get --recursive s3://$S3_BUCKET/$i.SAFE
    done
    echo "@MAPPER_RUN: $(timestamp) finish downloading product."
}

run_proc() {
    echo "java_max_mem: `ss-get snap_max_mem`" >> /root/.snap/snap-python/snappy/snappy.ini

    cd $SARAPP_LOC/app/mapper

    SAR_proc=$MAPPER_LOC/SAR_mapper.py
    for i in ${my_product[@]}; do
        python $SAR_proc $i
    done

    # FIXME SAR_proc should store into current directory.
    find . -maxdepth 1 -name *.png -exec cp {} $id.png \;
    # TODO clear .snap/var/temp/cache files
}

push_product() {
    nc $reducer_ip 808$id < $id.png
}

# Clone itself.
git clone https://github.com/SixSq/SAR-app.git $SARAPP_LOC
cd $SARAPP_LOC/app/mapper
source ../lib.sh
start_filebeat

# Clone processor with a mapper.
git clone `ss-get proc-git-repo` $MAPPER_LOC

# FIXME: data should be obtained from wrapped processors by 'data-access-lib'
#config_s3 $S3_HOST $S3_ACCESS_KEY $S3_SECRET_KEY
get_data

run_proc
push_product

ss-set ready true
