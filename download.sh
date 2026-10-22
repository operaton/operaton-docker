#!/bin/sh -ex

VERSION=${1}
DISTRO=${2}

if [ -z "$VERSION" ]; then
  echo "VERSION is not set"
  exit 1
fi
if [ -z "$DISTRO" ]; then
  echo "DISTRO is not set"
  exit 1
fi

export MAVEN_ARGS="-B -ntp --show-version"

# "run" is the legacy name of the "operaton" distribution
if [ "$DISTRO" = "run" ]; then
  echo "DISTRO 'run' is deprecated, use 'operaton' instead"
  DISTRO="operaton"
fi

echo "Downloading Operaton ${VERSION} for ${DISTRO}"

if [ "$DISTRO" = "operaton" ]; then
  ARTIFACT="operaton-bpm"
else
  ARTIFACT="operaton-bpm-${DISTRO}"
fi

ARTIFACT_VERSION="${VERSION}"
ARTIFACT_BASE_URL="https://github.com/operaton/operaton/releases/download/v${VERSION}/"

# Determine if SNAPSHOT version should be used
if [ "${SNAPSHOT}" = "true" ]; then
    ARTIFACT_VERSION="${VERSION}-SNAPSHOT"
    ARTIFACT_BASE_URL="https://github.com/operaton/operaton/releases/download/${ARTIFACT_VERSION}/"

    # get the database settings file from the main repo since snapshots are not published
    wget -q https://raw.githubusercontent.com/operaton/operaton/refs/heads/main/database/pom.xml -O dbpom.xml
    db_settings_pom_file=dbpom.xml
else
   # extract the database settings file from the main artifact
    mvn dependency:get -U -B --global-settings /tmp/settings.xml \
        -DgroupId="org.operaton.bpm" -DartifactId="operaton-database-settings" \
        -Dversion="${ARTIFACT_VERSION}" -Dpackaging="pom" -Dtransitive=false

    db_settings_pom_file=$(find /m2-repository -name "operaton-database-settings-${ARTIFACT_VERSION}.pom" -print | head -n 1)
fi

# Swagger UI is not part of the operaton distribution, so the image provides it.
# The static files are served by Spring Boot below /swaggerui when operaton.sh is started with --swaggerui.
install_swaggerui() {
    SWAGGERUI_DIR=/operaton/internal/swaggerui/swaggerui
    OPENAPI_ARTIFACT_URL="https://repo1.maven.org/maven2/org/operaton/bpm/operaton-engine-rest-openapi"

    # SNAPSHOT versions are not published to Maven Central, fall back to the latest published version
    OPENAPI_VERSION="${ARTIFACT_VERSION}"
    if ! wget -q --spider "${OPENAPI_ARTIFACT_URL}/${OPENAPI_VERSION}/operaton-engine-rest-openapi-${OPENAPI_VERSION}.jar"; then
        OPENAPI_VERSION=$(wget -q -O - "${OPENAPI_ARTIFACT_URL}/maven-metadata.xml" | xmlstarlet sel -t -v //latest)
        echo "OpenAPI specification for ${ARTIFACT_VERSION} not available, using ${OPENAPI_VERSION}"
    fi

    mvn dependency:copy -B \
        -Dartifact="org.webjars:swagger-ui:${SWAGGER_UI_VERSION}:jar" \
        -DoutputDirectory=/tmp/
    mvn dependency:copy -B \
        -Dartifact="org.operaton.bpm:operaton-engine-rest-openapi:${OPENAPI_VERSION}:jar" \
        -DoutputDirectory=/tmp/

    mkdir -p /tmp/swagger-ui "${SWAGGERUI_DIR}"
    unzip -q /tmp/swagger-ui-"${SWAGGER_UI_VERSION}".jar -d /tmp/swagger-ui
    cp -r /tmp/swagger-ui/META-INF/resources/webjars/swagger-ui/"${SWAGGER_UI_VERSION}"/. "${SWAGGERUI_DIR}"

    # Add the REST API of the running instance as first (default) server, relative to the Swagger UI origin
    unzip -p /tmp/operaton-engine-rest-openapi-"${OPENAPI_VERSION}".jar openapi.json \
        | jq -c '.servers = [{"url": "/engine-rest", "description": "The REST API of this Operaton instance"}] + .servers' \
        > "${SWAGGERUI_DIR}/openapi.json"
    jq -e .openapi "${SWAGGERUI_DIR}/openapi.json" > /dev/null
    sed -i 's#url: "https://petstore.swagger.io/v2/swagger.json"#url: "./openapi.json"#' "${SWAGGERUI_DIR}/swagger-initializer.js"
    grep -q '"./openapi.json"' "${SWAGGERUI_DIR}/swagger-initializer.js"
}

# Determine artifact group, all wildfly version have the same group
case ${DISTRO} in
    wildfly*) GROUP="wildfly" ;;
    *) GROUP="${DISTRO}" ;;
esac

distro_file_name="${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"
distro_file_url="${ARTIFACT_BASE_URL}${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"

wget -q "$distro_file_url"

# Unpack distro to /operaton directory
mkdir -p /operaton

# Would contain the application files temporarily, to add them in a separate docker layer (please see the second stage of Dockerfile)
mkdir -p /tmp/operaton-app
case ${DISTRO} in
    operaton) tar xzf "$distro_file_name" -C /operaton;;
    *)    tar xzf "$distro_file_name" -C /operaton server --strip 2;;
esac
cp /tmp/operaton-"${GROUP}".sh /operaton/operaton.sh

# download and register database drivers
if [ -z "$MYSQL_VERSION" ]; then
    MYSQL_VERSION=$(xmlstarlet sel -t -v //_:version.mysql "$db_settings_pom_file")
fi
if [ -z "$POSTGRESQL_VERSION" ]; then
    POSTGRESQL_VERSION=$(xmlstarlet sel -t -v //_:version.postgresql "$db_settings_pom_file")
fi

mvn dependency:copy -B \
    -Dartifact="com.mysql:mysql-connector-j:${MYSQL_VERSION}:jar" \
    -DoutputDirectory=/tmp/
mvn dependency:copy -B \
    -Dartifact="org.postgresql:postgresql:${POSTGRESQL_VERSION}:jar" \
    -DoutputDirectory=/tmp/

case ${DISTRO} in
    wildfly*)
        cat <<-EOF > batch.cli
batch
embed-server --std-out=echo

module add --name=com.mysql.mysql-connector-j --slot=main --resources=/tmp/mysql-connector-j-${MYSQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=mysql:add(driver-name="mysql",driver-module-name="com.mysql.mysql-connector-j",driver-xa-datasource-class-name=com.mysql.cj.jdbc.MysqlXADataSource)

module add --name=org.postgresql.postgresql --slot=main --resources=/tmp/postgresql-${POSTGRESQL_VERSION}.jar --dependencies=javax.api,javax.transaction.api
/subsystem=datasources/jdbc-driver=postgresql:add(driver-name="postgresql",driver-module-name="org.postgresql.postgresql",driver-xa-datasource-class-name=org.postgresql.xa.PGXADataSource)

run-batch
EOF
        /operaton/bin/jboss-cli.sh --file=batch.cli
        rm -rf /operaton/standalone/configuration/standalone_xml_history/current/*
        # move application files temporarily, to add them again in a separate docker layer (please see the second stage of Dockerfile)
        mkdir -p /tmp/operaton-app/standalone
        mkdir -p /tmp/operaton-app/modules/org
        mv /operaton/standalone/deployments /tmp/operaton-app/standalone/deployments
        mv /operaton/modules/org/operaton /tmp/operaton-app/modules/org/operaton
        ;;
    operaton)
        cp /tmp/mysql-connector-j-"${MYSQL_VERSION}".jar /operaton/configuration/userlib
        cp /tmp/postgresql-"${POSTGRESQL_VERSION}".jar /operaton/configuration/userlib
        # move application files temporarily, to add them again in a separate docker layer  (please see the second stage of Dockerfile)
        mkdir -p /tmp/operaton-app/internal
        mkdir -p /tmp/operaton-app/internal/webapps
        mv /operaton/internal/operaton-bpm.jar /tmp/operaton-app/internal/operaton-bpm.jar
        mv /operaton/internal/webapps/operaton-* /tmp/operaton-app/internal/webapps/
        install_swaggerui
        ;;
    tomcat*)
        cp /tmp/mysql-connector-j-"${MYSQL_VERSION}".jar /operaton/lib
        cp /tmp/postgresql-"${POSTGRESQL_VERSION}".jar /operaton/lib
        # remove default CATALINA_OPTS from environment settings
        echo "" > /operaton/bin/setenv.sh
        # move application files temporarily, to add them again in a separate docker layer  (please see the second stage of Dockerfile)
        mkdir -p /tmp/operaton-app/lib
        mv /operaton/webapps /tmp/operaton-app/webapps
        mv /operaton/lib/operaton-* /tmp/operaton-app/lib/
        ;;
esac

# download Prometheus JMX Exporter. 
mvn dependency:copy -B \
    -Dartifact="io.prometheus.jmx:jmx_prometheus_javaagent:${JMX_PROMETHEUS_VERSION}:jar" \
    -DoutputDirectory=/tmp/

mkdir -p /operaton/javaagent
cp /tmp/jmx_prometheus_javaagent-"${JMX_PROMETHEUS_VERSION}".jar /operaton/javaagent/jmx_prometheus_javaagent.jar
