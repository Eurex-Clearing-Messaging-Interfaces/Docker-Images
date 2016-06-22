#!/usr/bin/env bats

IMAGE="ecmi/fixml"
VERSION="sim"

setup() {
    export QPID_SSL_CERT_DB=sql:./tests/
    export QPID_SSL_CERT_PASSWORD_FILE=./tests/pwdfile
    export QPID_SSL_CERT_NAME=ABCFR_ABCFRALMMACC1
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

@test "Test broadcasts with AMQP 0-10" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    run qpid-send -b admin/admin@ecag-fixml-dev1:$tcp -a "broadcast/broadcast.ABCFR.TradeConfirmation; { node: { type: topic}, assert: never, create: never }" -m 1 --durable yes --content-size 1024
    echo $output
    [ "$status" -eq "0" ]

    run qpid-receive -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "broadcast.ABCFR_ABCFRALMMACC1.TradeConfirmation; { node: { type: queue}, assert: never, create: never }" -m 1 --timeout 5 --report-total --report-header no --print-content no
    echo $output
    [ "$status" -eq "0" ]
    [ "${lines[0]}" != "0" ]
}

@test "Test request / response with AMQP 0-10" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    qpid-receive -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "response.ABCFR_ABCFRALMMACC1.response_queue_1; {create: receiver, assert: never, node: { type: queue, x-declare: { auto-delete: true, exclusive: false, arguments: {'qpid.policy_type': ring, 'qpid.max_count': 1000, 'qpid.max_size': 1000000}}, x-bindings: [{exchange: 'response', queue: 'response.ABCFR_ABCFRALMMACC1.response_queue_1', key: 'response.ABCFR_ABCFRALMMACC1.response_queue_1'}]}}" -m 1 -f --report-total --report-header no &> reqresp-010.txt &
    pid=$!

    run qpid-send -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "request.ABCFR_ABCFRALMMACC1; { node: { type: topic} }" -m 1 --content-size=1024 --durable=yes --reply-to "response/response.ABCFR_ABCFRALMMACC1.response_queue_1; { node: { type: topic }, assert: never, create: never }"
    [ "$status" -eq "0" ]

    run qpid-receive -b admin/admin@ecag-fixml-dev1:$tcp -a "request_be.ABCFR_ABCFRALMMACC1; { node: { type: queue }, assert: never, create: never }" -m 1 --timeout 5 --report-total --report-header no --print-content no
    echo $output
    [ "$status" -eq "0" ]

    wait $pid
    status=$?
    [ "$status" -eq "0" ]
    [ "$(cat reqresp-010.txt)" != "0" ]
}

@test "Test broadcasts with AMQP 1.0" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    run qpid-send -b admin/admin@ecag-fixml-dev1:$tcp -a "broadcast/broadcast.ABCFR.TradeConfirmation; { node: { type: topic}, assert: never, create: never }" -m 1 --durable yes --content-size 1024
    echo $output
    [ "$status" -eq "0" ]

    run qpid-receive -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL, protocol: amqp1.0 }" -a "broadcast.ABCFR_ABCFRALMMACC1.TradeConfirmation; { node: { type: queue}, assert: never, create: never }" -m 1 --timeout 5 --report-total --report-header no --print-content no
    echo $output
    [ "$status" -eq "0" ]
    [ "${lines[0]}" != "0" ]
}

@test "Test request / response with AMQP 1.0" {
    cont=$(sudo docker run -P -d $IMAGE:$VERSION)
    tcp=$(tcpPort)
    ssl=$(sslPort)
    sleep 5 # give the image time to start

    qpid-receive -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL, protocol: amqp1.0 }" -a "response.ABCFR_ABCFRALMMACC1; {create: never, assert: never, node: { type: queue } }" -m 1 -f --report-total --report-header no &> reqresp-10.txt &
    pid=$!

    run qpid-send -b ecag-fixml-dev1:$ssl --connection-options "{ transport: ssl, sasl_mechanism: EXTERNAL }" -a "request.ABCFR_ABCFRALMMACC1; { node: { type: topic} }" -m 1 --content-size=1024 --durable=yes --reply-to "response/response.ABCFR_ABCFRALMMACC1; { node: { type: topic }, assert: never, create: never }"
    [ "$status" -eq "0" ]

    run qpid-receive -b admin/admin@ecag-fixml-dev1:$tcp --connection-options "{ protocol: amqp1.0 }" -a "request_be.ABCFR_ABCFRALMMACC1; { node: { type: queue }, assert: never, create: never }" -m 1 --timeout 5 --report-total --report-header no --print-content no
    echo $output
    [ "$status" -eq "0" ]

    wait $pid
    status=$?
    [ "$status" -eq "0" ]
    [ "$(cat reqresp-10.txt)" != "0" ]
}
