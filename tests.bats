#!/usr/bin/env bats

IMAGE="ecmi/ers"
VERSION="sim"

setup() {
    export QPID_SSL_CERT_DB=sql:./tests/
    export QPID_SSL_CERT_PASSWORD_FILE=./tests/pwdfile
    export QPID_SSL_CERT_NAME=abcfr
}

teardown() {
    sudo docker stop $cont
}

tcpPort() {
    sudo docker port $cont 5672 | cut -f 2 -d ":"
}

sslPort() {
    sudo docker port $cont 5671 | cut -f 2 -d ":"
}

@test "Test request / response with AMQP 0-10" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    # Due to a bug in qpid-receive, the response routing key used has to be the same as the request routing key
    # qpid-recieve sends the received message back to the reply-to, but doesn't reset the subject which messes up the routing of the response
    qpid-receive -b ersd01:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "eurex.tmp.ABCFR.response_queue_1; {create: receiver, assert: never, node: { type: queue, x-declare: { auto-delete: true, exclusive: false, arguments: {'qpid.policy_type': ring, 'qpid.max_count': 1000, 'qpid.max_size': 1000000}}, x-bindings: [{exchange: 'eurex.response', queue: 'eurex.tmp.ABCFR.response_queue_1', key: 'ABCFR.ERS'}]}}" -m 1 -f --report-total --report-header no &> reqresp-010.txt &
    pid=$!

    run qpid-send -b ersd01:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "eurex.ABCFR/ABCFR.ERS; { node: { type: topic} }" -m 1 --content-size=1024 --durable=yes --reply-to "eurex.response/ABCFR.ERS; { node: { type: topic }, assert: never, create: never }"
    [ "$status" -eq "0" ]

    run qpid-receive -b admin/admin@ersd01:$tcp -a "eurex.request.ABCFR; { node: { type: queue }, assert: never, create: never }" -m 1 --timeout 5 --report-total --report-header no --print-content no
    [ "$status" -eq "0" ]

    wait $pid
    status=$?
    [ "$status" -eq "0" ]
    [ "$(cat reqresp-010.txt)" != "0" ]
}

@test "Test public broadcasts with AMQP 0-10" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    qpid-receive -b ersd01:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "eurex.tmp.ABCFR.broadcast_queue_1; {create: receiver, assert: never, node: { type: queue, x-declare: { auto-delete: true, exclusive: false, arguments: {'qpid.policy_type': ring, 'qpid.max_count': 1000, 'qpid.max_size': 1000000}}, x-bindings: [{exchange: 'eurex.broadcast', queue: 'eurex.tmp.ABCFR.broadcast_queue_1', key: 'public.#'}]}}" -m 1 -f --report-total --report-header no &> bcast-010.txt &
    pid=$!
    sleep 2 # Give the bg process some time to connect, create queue and bind

    run qpid-send -b admin/admin@ersd01:$tcp -a "eurex.broadcast/public.TradingSessionStatus; { node: { type: topic} }" -m 1 --content-size=1024 --durable=yes
    [ "$status" -eq "0" ]

    wait $pid
    status=$?
    [ "$status" -eq "0" ]
    [ "$(cat bcast-010.txt)" != "0" ]
}

@test "Test private broadcasts with AMQP 0-10" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    qpid-receive -b ersd01:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "eurex.tmp.ABCFR.broadcast_queue_1; {create: receiver, assert: never, node: { type: queue, x-declare: { auto-delete: true, exclusive: false, arguments: {'qpid.policy_type': ring, 'qpid.max_count': 1000, 'qpid.max_size': 1000000}}, x-bindings: [{exchange: 'eurex.broadcast', queue: 'eurex.tmp.ABCFR.broadcast_queue_1', key: 'ABCFR.#'}]}}" -m 1 -f --report-total --report-header no &> bcast-priv-010.txt &
    pid=$!
    sleep 2 # Give the bg process some time to connect, create queue and bind

    run qpid-send -b admin/admin@ersd01:$tcp -a "eurex.broadcast/ABCFR.MessageType.PositionUpdate; { node: { type: topic} }" -m 1 --content-size=1024 --durable=yes
    [ "$status" -eq "0" ]

    wait $pid
    status=$?
    [ "$status" -eq "0" ]
    [ "$(cat bcast-priv-010.txt)" != "0" ]
}
