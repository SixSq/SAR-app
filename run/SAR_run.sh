#!/bin/bash

set -o pipefail

# Bash script launching the the SlipStream application.
# The parameters are the cloud service choosed by the client
# and its Github repository (optional) following the SAR_proc model at
# https://github.com/SimonNtz/SAR_proc.
# Input data is stored in file list "product_list.cfg".

# Connector instance name as defined on https://nuv.la for which user has
# provided credentials in its profile.
CLOUD="$1"
GH_REPO="$2"

INPUT_SIZE=`awk '/^[a-zA-z]/' product_list.cfg | wc -l`
INPUT_LIST=`awk '/^[a-zA-z]/' product_list.cfg`

trap 'rm -f $LOG' EXIT

LOG=`mktemp`
SS_ENDPOINT=https://nuv.la

python -u `which ss-execute` \
    --endpoint $SS_ENDPOINT \
    --wait 60 \
    --keep-running="never" \
    --parameters="
    mapper:multiplicity=$INPUT_SIZE,
    mapper:product-list=$INPUT_LIST,
    mapper:cloudservice=$CLOUD,
    mapper:git-repo=$GH_REPO,
    reducer:cloudservice=$CLOUD,
    reducer:git-repo=$GH_REPO" \
    EO_Sentinel_1/procSAR 2>&1 | tee $LOG

# if [ "$?" == "0" ]; then
#     run=`awk '/::: Waiting/ {print $7}' $LOG`
#     echo "::: URL with the computed result:"
#     curl -u $SLIPSTREAM_USERNAME:$SLIPSTREAM_PASSWORD \
#         $run/ss:url.service
#     echo
# fi
