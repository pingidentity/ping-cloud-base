FROM ubuntu:latest 
ENV TZ=UTC
ENV PREFIX="https://art01.corp.pingidentity.com/artifactory/libs-releases-local/com/pingidentity/pingaccess/test/perf-service"
ENV VERSION="1.0.0.4"

#-------------------------------------------------------------------------------------------------------------------------------------------------
# Build image
#-------------------------------------------------------------------------------------------------------------------------------------------------

RUN set -ex; \
    #
    # Set timezone to GMT for consistent timestamps
    #
    ln -snf /usr/share/zoneinfo/${TZ} /etc/localtime; \
    echo ${TZ} > /etc/timezone; \
    #
    # Ensure packages etc. are current.
    #
    apt-get update; \
    apt-get -y upgrade; \
    #
    # Install required tools
    #
    apt-get install -y --no-install-recommends curl openjdk-11-jre; \
    #
    # Install performance service
    #
    curl -k  ${PREFIX}/${VERSION}/perf-service-${VERSION}.jar -o /root/perf-service.jar; \       
    #
    # Clean up
    #
    rm -rf /var/lib/apt/lists/*; \
    set +xe;

#-------------------------------------------------------------------------------------------------------------------------------------------------
# Create working environment
#-------------------------------------------------------------------------------------------------------------------------------------------------

EXPOSE 8080
ENTRYPOINT  exec java -Xms1024m -Xmx1024m -jar /root/perf-service.jar
