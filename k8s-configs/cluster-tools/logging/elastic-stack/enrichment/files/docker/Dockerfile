FROM docker.elastic.co/elasticsearch/elasticsearch:7.6.0
COPY ./scripts/* /scripts/
WORKDIR /scripts
USER root
RUN yum install -y epel-release
RUN yum install -y python-pip
RUN pip install requests
RUN chmod +x ./* && chown -R 1000:1000 ./*
USER 1000
ENTRYPOINT ["/bin/sh"]