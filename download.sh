#!/bin/sh -ex

if [ -z "$VERSION" ]; then
  echo "VERSION is not set"
  exit 1
fi

echo "Downloading Operaton ${VERSION} for ${DISTRO}"

if [ "$DISTRO" = "run" ]; then
  ARTIFACT="operaton-bpm"
else
  ARTIFACT="operaton-bpm-${DISTRO}"
fi

ARTIFACT_VERSION="${VERSION}"
ARTIFACT_BASE_URL="https://github.com/operaton/operaton/releases/download/v${VERSION}/"

# Determine if SNAPSHOT version should be used
if [ "${SNAPSHOT}" = "true" ]; then
    ARTIFACT_VERSION="${VERSION}-SNAPSHOT"
    ARTIFACT_BASE_URL="https://github.com/operaton/operaton/releases/download/early-access/"

    # get the database settings file from the main repo since snapshots are not published
    wget https://raw.githubusercontent.com/operaton/operaton/refs/heads/main/database/pom.xml -O dbpom.xml
    db_settings_pom_file=dbpom.xml
else
   # extract the database settings file from the main artifact
    mvn dependency:get -U -B --global-settings /tmp/settings.xml \
        -DgroupId="org.operaton.bpm" -DartifactId="operaton-database-settings" \
        -Dversion="${ARTIFACT_VERSION}" -Dpackaging="pom" -Dtransitive=false

    db_settings_pom_file=$(find /m2-repository -name "operaton-database-settings-${ARTIFACT_VERSION}.pom" -print | head -n 1)
fi

# Determine artifact group, all wildfly version have the same group
case ${DISTRO} in
    wildfly*) GROUP="wildfly" ;;
    *) GROUP="${DISTRO}" ;;
esac

distro_file_name="${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"
distro_file_url="${ARTIFACT_BASE_URL}${ARTIFACT}-${ARTIFACT_VERSION}.tar.gz"

wget "$distro_file_url"

# Unpack distro to /operaton directory
mkdir -p /operaton
case ${DISTRO} in
    run*) tar xzf "$distro_file_name" -C /operaton;;
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
        ;;
    run*)
        cp /tmp/mysql-connector-j-"${MYSQL_VERSION}".jar /operaton/configuration/userlib
        cp /tmp/postgresql-"${POSTGRESQL_VERSION}".jar /operaton/configuration/userlib
        ;;
    tomcat*)
        cp /tmp/mysql-connector-j-"${MYSQL_VERSION}".jar /operaton/lib
        cp /tmp/postgresql-"${POSTGRESQL_VERSION}".jar /operaton/lib
        # remove default CATALINA_OPTS from environment settings
        echo "" > /operaton/bin/setenv.sh
        ;;
esac

# download Prometheus JMX Exporter. 
mvn dependency:copy -B \
    -Dartifact="io.prometheus.jmx:jmx_prometheus_javaagent:${JMX_PROMETHEUS_VERSION}:jar" \
    -DoutputDirectory=/tmp/

mkdir -p /operaton/javaagent
cp /tmp/jmx_prometheus_javaagent-"${JMX_PROMETHEUS_VERSION}".jar /operaton/javaagent/jmx_prometheus_javaagent.jar
