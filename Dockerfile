#####
#
# Eurex Clearing FIXML Interface
#
####
FROM		scholzj/merge-messaging:3.0.2
MAINTAINER      Jakub Scholz

# Add configuration files
USER root
COPY ./var /var
RUN chown -R 1001:0 /var/lib/qpidd

# Switch to qpidd user
USER 1001

# Run the broker
EXPOSE 5671 5672
CMD    /usr/sbin/qpidd --config /var/lib/qpidd/etc/qpidd.conf
