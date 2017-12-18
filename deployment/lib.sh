# Library functions for deployment.

config_s3() {
    cat > ~/.s3cfg <<EOF
[default]
host_base = $1
host_bucket = %(bucket)s.$1

access_key = $2
secret_key = $3

use_https = True
EOF
  if [ "$1" == "sos.exo.io" ] ;then
        cat >>~/.s3cfg<<EOF
# For Exoscale only
signature_v2 = True
EOF
  fi
}

#
# Eventing.
# Retrieve the client's Nuvla token through the application component parameters

cookiefile=/home/cookies-nuvla.txt

install_slipstream_api(){
    sudo -H pip install --upgrade pip
    pip install \
        https://github.com/slipstream/SlipStreamPythonAPI/archive/master.zip
    mv /usr/local/lib/python2.7/dist-packages/slipstream/api \
        /opt/slipstream/client/lib/slipstream
    rm -Rf /usr/local/lib/python2.7/dist-packages/slipstream
    ln -s /opt/slipstream/client/lib/slipstream \
        /usr/local/lib/python2.7/dist-packages/slipstream
}

create_cookie(){
    [ -n "$@" ] || return 0
    cat >$cookiefile<<EOF
# Netscape HTTP Cookie File
# http://curl.haxx.se/rfc/cookie_spec.html
# This is a generated file!  Do not edit.
$@
EOF
}

get_DUIID() {
    awk -F= '/diid/ {print $2}' \
        /opt/slipstream/client/sbin/slipstream.context
}

timestamp() {
  date +"%T"
}

get_ss_user() {
    awk -F= '/username/ {print $2}' \
        /opt/slipstream/client/sbin/slipstream.context
}

post_event() {
    msg=$@
    [ -f $cookiefile ] || return 0
    username=$(get_ss_user)
    duiid=$(get_DUIID)
    event_script=/tmp/post-event.py
    [ -f $event_script ] || \
         cat >$event_script<<EOF
import sys
from slipstream.api import Api
import datetime
api = Api(cookie_file='$cookiefile')
msg = str(sys.argv[1]).translate(None, "[]")
print msg
event = {'acl': {u'owner': {u'principal': u'$username'.strip(), u'type': u'USER'},
        u'rules': [{u'principal': u'$username'.strip(),
        u'right': u'ALL',
        u'type': u'USER'},
        {u'principal': u'ADMIN',
        u'right': u'ALL',
        u'type': u'ROLE'}]},
  'content': {u'resource': {u'href': u'run/'+ u'$duuid'.strip()},
                                        u'state': msg},
  'severity': u'low',
  'timestamp': '%sZ' % datetime.datetime.now().strftime('%Y-%m-%dT%H:%M:%S.%f')[:-3],
  'type': u'state'}

api.cimi_add('events', event)
EOF
}

start_filebeat() {

    #server_ip=`ss-get --timeout=300 ELK_server:hostname`
    #server_hostname=`ss-get --timeout=300 ELK_server:machine-hn`
    server_hostname=`ss-get --timeout=300 server_hn`
    server_ip=`ss-get --timeout=300 server_ip`

    echo  "$server_ip   $server_hostname">>/etc/hosts

    cd /etc/filebeat/

    filebeat_conf=filebeat.yml

    #Set Logstash as an input instead of ElasticStash
    sed -i '81,83 s/^/#/' $filebeat_conf
    # awk '{ if (NR == 22) print "    - /var/log/auth.log\n    - /var/log/syslog\n \
    #     - /var/log/slipstream/client/slipstream-node.log";else print $0}' \
    #         $filebeat_conf > tmp && mv tmp $filebeat_conf

    cat>$filebeat_conf<<EOF
    filebeat.prospectors:
    - input_type: log

      paths:
        - /var/log/auth.log
        - /var/log/syslog
        - /var/log/slipstream/client/slipstream-node.log
      #fields:
            #tags: ["EOproc"]
      #include_lines: ["^@MAPPER_RUN", "^@REDUCER_RUN", "^@SAR_PROC"]
    output.logstash:
      # The Logstash hosts
      hosts: [":5443"]
      bulk_max_size: 2048
      template.name: "filebeat"
      template.path: "filebeat.template.json"
      template.overwrite: false
    document-type: syslog
EOF

    chmod go-w $filebeat_conf
    filebeat.sh -configtest -c $filebeat_conf

    sudo systemctl start filebeat
    sudo systemctl enable filebeat

    # Capture filebeat status
    systemctl status filebeat | grep Active
}
