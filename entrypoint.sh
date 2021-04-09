#!/bin/sh

echo "INFO:  Starting broker..."
export QPID_PID_FILENAME="broker.pid" && export QPID_WORK="/home/oper/qpid/0000/broker/work" && export QPID_JAVA_MEM="-Xmx300m -XX:MaxDirectMemorySize=200m" && export JAVA_OPTS="-Dderby.stream.error.file=/dev/null -XX:+UnlockDiagnosticVMOptions -XX:+LogVMOutput -XX:LogFile=/home/oper/qpid/0000/log/ecag-fixml-dev1-amqp_broker_jvm-0000.log" && /home/oper/qpid/0000/broker/bin/qpid-server 2>&1 &


tail -f /dev/null
