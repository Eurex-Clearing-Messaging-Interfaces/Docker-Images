FROM vyboant/centos-java
MAINTAINER Antonin Vyborny

# Add configuration files
RUN mkdir /home/oper
COPY ./fixml-sim.zip /home/oper/
RUN unzip /home/oper/fixml-sim.zip -d /home/oper/
COPY ./entrypoint.sh /home/oper/
RUN chown -R root:root /home/oper/

# Run the broker
ENTRYPOINT [ "/bin/sh", "-c", "/home/oper/entrypoint.sh" ]
EXPOSE 10000 20000 40000
