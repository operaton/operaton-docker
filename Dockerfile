FROM alpine:3.22 AS builder

ARG VERSION
ARG DISTRO=run
ARG SNAPSHOT=true

ARG POSTGRESQL_VERSION
ARG MYSQL_VERSION

ARG JMX_PROMETHEUS_VERSION=0.12.0

RUN apk add --no-cache \
        bash \
        ca-certificates \
        maven \
        tar \
        wget \
        xmlstarlet

COPY settings.xml download.sh operaton-run.sh operaton-tomcat.sh operaton-wildfly.sh  /tmp/

RUN /tmp/download.sh ${VERSION} ${DISTRO}
COPY operaton-lib.sh /operaton/


##### FINAL IMAGE #####

FROM alpine:3.22

ARG VERSION=7.23.0
ARG DISTRO

ENV OPERATON_DB_VERSION=${VERSION}
ENV DB_DRIVER=
ENV DB_URL=
ENV DB_USERNAME=
ENV DB_PASSWORD=
ENV DB_CONN_MAXACTIVE=20
ENV DB_CONN_MINIDLE=5
ENV DB_CONN_MAXIDLE=20
ENV DB_VALIDATE_ON_BORROW=false
ENV DB_VALIDATION_QUERY="SELECT 1"
ENV SKIP_DB_CONFIG=
ENV WAIT_FOR=
ENV WAIT_FOR_TIMEOUT=30
ENV TZ=UTC
ENV DEBUG=false
ENV JAVA_OPTS=""
ENV JAVA_HOME=/usr/lib/jvm/java-17-openjdk
ENV JMX_PROMETHEUS=false
ENV JMX_PROMETHEUS_CONF=/operaton/javaagent/prometheus-jmx.yml
ENV JMX_PROMETHEUS_PORT=9404

EXPOSE 8080 8000 9404

# Downgrading wait-for-it is necessary until this PR is merged
# https://github.com/vishnubob/wait-for-it/pull/68
RUN apk add --no-cache \
        bash \
        ca-certificates \
        curl \
        openjdk17-jre-headless \
        tzdata \
        tini \
        xmlstarlet \
    && curl -o /usr/local/bin/wait-for-it.sh \
      "https://raw.githubusercontent.com/vishnubob/wait-for-it/a454892f3c2ebbc22bd15e446415b8fcb7c1cfa4/wait-for-it.sh" \
    && chmod +x /usr/local/bin/wait-for-it.sh

RUN addgroup -g 1000 -S operaton && \
    adduser -u 1000 -S operaton -G operaton -h /operaton -s /bin/bash -D operaton
WORKDIR /operaton
USER operaton

ENTRYPOINT ["/sbin/tini", "--"]
CMD ["./operaton.sh"]

COPY --chown=operaton:operaton --from=builder /operaton .

COPY --chown=operaton:operaton --from=builder /tmp/operaton-app /tmp/operaton-app

RUN case "$DISTRO" in \
    wildfly) \
        mv /tmp/operaton-app/standalone/deployments /operaton/standalone/deployments && \
        mv /tmp/operaton-app/modules/org/operaton /operaton/modules/org/operaton ;; \
    tomcat) \
        mv /tmp/operaton-app/webapps /operaton/webapps && \
        mv /tmp/operaton-app/lib/operaton-* /operaton/lib/ ;; \
    run) \
        mv /tmp/operaton-app/internal/operaton-bpm.jar /operaton/internal/operaton-bpm.jar && \
        mv /tmp/operaton-app/internal/webapps/operaton-* /operaton/internal/webapps/ ;; \
    *) \
        echo "Unknown DISTRO: $DISTRO" && exit 1 ;; \
esac && \
    rm -rf /tmp/operaton-app