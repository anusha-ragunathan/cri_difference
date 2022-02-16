FROM busybox:latest

# symlink /opt/druid
RUN VERSION="2022-02-08" \ 
 && mkdir -p /opt/apache-druid-${VERSION} \ 
 && ln -s /opt/apache-druid-${VERSION} /opt/druid

# create a specific user and group
RUN addgroup -S -g 1000 druid \
 && adduser -S -u 1000 -D -H -h /opt/druid -s /bin/sh -g '' -G druid druid

RUN mkdir -p /opt/druid/var

# change ownership of /opt recursively
RUN chown -R druid:druid /opt \
 && chmod 775 /opt/druid/var

# create VOLUME
VOLUME /opt/druid/var
WORKDIR /opt/druid

ENTRYPOINT ["/bin/sh"]
