# Operaton Docker images

> Use our [GitHub issue tracker](https://github.com/operaton/operaton/issues) for bug reports or feature requests.
> For help requests, open a help request topic on the [Operaton forum](https://forum.operaton.org/)

This Operaton project provides docker images of the latest 
Operaton releases. The images can be used to demonstrate and test the
Operaton or can be extended with own process applications. It is
planned to provide images on the official [docker registry][] for every upcoming
release, which includes alpha releases.

The Operaton Docker images are wrappers for the pre-packaged Operaton
distributions. The pre-packaged distributions are intended for users who want a 
getting started experience. In case you want to use the Operaton Docker images 
in production, consider reading our [security instructions](https://docs.operaton.org/manual/latest/user-guide/security/).

## Distributions

You can find more detailed documentation on the pre-packaged (community) 
distributions that Operaton provides at the following links:

* Apache Tomcat - [Operaton Tomcat integration documentation](https://docs.operaton.org/manual/latest/user-guide/runtime-container-integration/tomcat/)
* Wildfly - [Operaton Wildfly Subsystem documentation](https://docs.operaton.org/manual/latest/user-guide/runtime-container-integration/jboss/)
* Operaton Run - [documentation](https://docs.operaton.org/manual/latest/user-guide/operaton-bpm-run/)

## Get started

To start a Docker container of the latest Operaton 7 release:

```
docker pull operaton/operaton-bpm:latest
docker run -d --name operaton -p 8080:8080 operaton/operaton-bpm:latest
```

### Tasklist, Cockpit, Admin web apps

The three Operaton web apps are accessible through the landing page: 
http://localhost:8080/operaton-welcome/index.html

The default credentials for admin access to the web apps is:

- Username: `demo`
- Password: `demo`

### REST API

The Operaton Rest-API is accessible through: http://localhost:8080/engine-rest

See the [REST API](https://docs.operaton.org/manual/latest/reference/rest/)
documentation for more details on how to use it.

**Note**: The REST API does not require authentication by default. Follow the instructions from the [documentation](https://docs.operaton.org/manual/latest/reference/rest/overview/authentication/)
to enable authentication for the REST API.

## Supported tags/releases

The following tag schema is used. The user has the choice between different
application server distributions of Operaton.

- `latest`, `${DISTRO}-latest`: Always the latest minor release of Operaton.
- `SNAPSHOT`, `${VERSION}-SNAPSHOT`, `${DISTRO}-SNAPSHOT`,
  `${DISTRO}-${VERSION}-SNAPSHOT`: The latest SNAPSHOT version of Operaton, which is not released yet.
- `${VERSION}`, `${DISTRO}-${VERSION}`: A specific version of Operaton.

`${DISTRO}` can be one of the following: 
* `tomcat`
* `wildfly`
* `run`

If no `${DISTRO}` is specified, the `tomcat` distribution is used. For all 
available tags see the [docker hub tags][].

## Operaton 7 configuration

You can find the complete Operaton documentation at https://docs.operaton.org/.

If you prefer to start your Operaton Docker image right away, you will find the
following links useful:

* [Operaton configuration file properties](https://docs.operaton.org/manual/latest/reference/deployment-descriptors/descriptors/bpm-xml/)
* [Process Engine Plugins guide](https://docs.operaton.org/manual/latest/user-guide/process-engine/process-engine-plugins/)
* [Operaton Logging](https://docs.operaton.org/manual/latest/user-guide/logging/)

## Operaton Docker image configuration

### Configuration of the `run` distribution

Because `run` is a Spring Boot-based distribution, it can be configured through 
the respective environment variables. For example:
- `SPRING_DATASOURCE_DRIVER_CLASS_NAME` the database driver class name, 
  supported are h2 (default), mysql, and postgresql:
  - h2: `DB_DRIVER=org.h2.Driver`
  - mysql: `DB_DRIVER=com.mysql.cj.jdbc.Driver`
  - postgresql: `DB_DRIVER=org.postgresql.Driver`
- `SPRING_DATASOURCE_URL` the database jdbc url
- `SPRING_DATASOURCE_USERNAME` the database username
- `SPRING_DATASOURCE_PASSWORD` the database password

When not set or otherwise specified, the integrated H2 database is used.

Any other `SPRING_*` variables can be used to further configure the app. 
Alternatively, a `default.yml` file can be mounted to `/operaton/configuration/default.yml`.
More information on configuring Spring Boot applications can be found in the 
[Spring Boot documentation](https://docs.spring.io/spring-boot/docs/current/reference/html/spring-boot-features.html#boot-features-external-config).

The following environment variables are supported for convenience and 
compatibility and are internally mapped to `SPRING_DATASOURCE_*` variables 
when provided:

* `DB_DRIVER`
* `DB_USERNAME`
* `DB_PASSWORD`
* `DB_URL`
* `DB_PASSWORD_FILE`

The `JMX_PROMETHEUS` configuration is not supported, and while `DEBUG` can be 
used to enable debug output, it doesn't start a debug socket.

`run` supports different startup options to choose whether or not to enable the 
WebApps, the REST API or Swagger UI. By default, all three are enabled.

Passing startup parameters to enable them selectively can be done by passing any 
combination of `--webapps`, `--rest` or `--swaggerui` like in the following 
example:

Enable only web apps:

```bash
docker run operaton/operaton-bpm:run ./operaton.sh --webapps
``` 
Enable only REST API and Swagger UI:
```bash
docker run operaton/operaton-bpm:run ./operaton.sh --rest --swaggerui
```

Additionally, a `--production` parameter is supported to switch the 
configuration to `/operaton/configuration/production.yml`. This parameter also 
disables Swagger UI by default.

### Java versions

Our docker images are using a LTS OpenJDK version supported by
Operaton. This currently means:

 - Operaton 7.20 or later will be based on OpenJDK 17.
   - Operaton 7.20 image for Operaton Run is supported only for JDK 17.
 - Operaton 7.12 - 7.19 is based on OpenJDK 11.
   - Operaton 7.19 image for WildFly is supported only for JDK 11 and JDK 17.
 - All previous versions are based on OpenJDK 8.

While all the OpenJDK versions supported by Operaton will work with the exceptions specified above,
we will not provide ready to use images for them.

#### Java options

To override the default Java options the environment variable `JAVA_OPTS` can
be set.

### Use docker memory limits

Instead of specifying the Java memory settings it is also possible to instruct
the JVM to respect the docker memory settings. As the image uses Java 17 it does
not have to be enabled explicitly using the `JAVA_OPTS` environment variable. 
If you want to set the memory limits manually you can restore the pre-Java-11-behavior
by setting the following environment variable.

```
JAVA_OPTS="-XX:-UseContainerSupport"
```

### Database environment variables

The used database can be configured by providing the following environment
variables:

- `DB_CONN_MAXACTIVE` the maximum number of active connections (default: `20`)
- `DB_CONN_MAXIDLE` the maximum number of idle connections (default: `20`)
  - ignored when app server = `wildfly` or `run`
- `DB_CONN_MINIDLE` the minimum number of idle connections (default: `5`)
- `DB_DRIVER` the database driver class name, supported are h2, mysql, and postgresql:
  - h2: `DB_DRIVER=org.h2.Driver`
  - mysql: `DB_DRIVER=com.mysql.cj.jdbc.Driver`
  - postgresql: `DB_DRIVER=org.postgresql.Driver`
- `DB_URL` the database jdbc url
- `DB_USERNAME` the database username
- `DB_PASSWORD` the database password
- `DB_VALIDATE_ON_BORROW` validate database connections before they are used (default: `false`)
- `DB_VALIDATION_QUERY` the query to execute to validate database connections (default: `"SELECT 1"`)
- `DB_PASSWORD_FILE` this supports [Docker Secrets](https://docs.docker.com/engine/swarm/secrets/). 
  Put here the path of the secret, e.g. `/run/secrets/operaton_db_password`. 
  Make sure that `DB_PASSWORD` is not set when using this variable!
- `SKIP_DB_CONFIG` skips the automated database configuration to use manual
  configuration
- `WAIT_FOR` wait for a `host:port` to be available over TCP before starting. Check [Waiting for database](#waiting-for-database) for details.
- `WAIT_FOR_TIMEOUT` how long to wait for the service to be avaiable - defaults to 30 seconds. Check [Waiting for database](#waiting-for-database) for details.

For example, to use a `postgresql` docker image as database you can start the
as follows:

```
# start postgresql image with database and user configured
docker run -d --name postgresql ...

docker run -d --name operaton -p 8080:8080 --link postgresql:db \
           -e DB_DRIVER=org.postgresql.Driver \
           -e DB_URL=jdbc:postgresql://db:5432/process-engine \
           -e DB_USERNAME=operaton \
           -e DB_PASSWORD=operaton \
           -e WAIT_FOR=db:5432 \
           operaton/operaton-bpm:latest
```

Another option is to save the database config to an environment file, i.e.
`db-env.txt`:

```
DB_DRIVER=org.postgresql.Driver
DB_URL=jdbc:postgresql://db:5432/process-engine
DB_USERNAME=operaton
DB_PASSWORD=operaton
WAIT_FOR=db:5432
```

Use this file to start the container:

```
docker run -d --name operaton -p 8080:8080 --link postgresql:db \
           --env-file db-env.txt operaton/operaton-bpm:latest
```

The docker image already contains drivers for `h2`, `mysql`, and `postgresql`.
If you want to use other databases, you have to add the driver to the container
and configure the database settings manually by linking the configuration file
into the container.

To skip the configuration of the database by the docker container and use your
own configuration set the environment variable `SKIP_DB_CONFIG` to a non-empty 
value:

```
docker run -d --name operaton -p 8080:8080 -e SKIP_DB_CONFIG=true \
           operaton/operaton-bpm:latest
```

### Waiting for database

Starting the Operaton Docker image requires the database to be already 
available. This is quite a challenge when the database and Operaton are 
both docker containers spawned simultaneously, for example, by `docker compose` 
or inside a Kubernetes Pod. To help with that, the Operaton Docker image 
includes [wait-for-it.sh](https://github.com/vishnubob/wait-for-it) to allow the 
container to wait until a 'host:port' is ready. The mechanism can be configured 
by two environment variables:

- `WAIT_FOR_TIMEOUT`: how long to wait for the service to be available in seconds
- `WAIT_FOR`: the service `host:port` to wait for. You can provide multiple
host-port pairs separated by a comma or an empty space (Example:
`"host1:port1 host2:port2"`).
The `WAIT_FOR_TIMEOUT` applies to each specified host, i.e. Operaton will wait for
`host1:port1` to become available and, if unavailable for the complete `WAIT_FOR_TIMEOUT`
duration, will wait for `host2:port2` for another `WAIT_FOR_TIMEOUT` period.

Example with a PostgreSQL container:

```
docker run -d --name postgresql ...

docker run -d --name operaton -p 8080:8080 --link postgresql:db \
           -e DB_DRIVER=org.postgresql.Driver \
           -e DB_URL=jdbc:postgresql://db:5432/process-engine \
           -e DB_USERNAME=operaton \
           -e DB_PASSWORD=operaton \
           -e WAIT_FOR=db:5432 \
           -e WAIT_FOR_TIMEOUT=60 \
           operaton/operaton-bpm:latest
```

### Volumes

Operaton is installed inside the `/operaton` directory. Which
means the Apache Tomcat configuration files are inside the `/operaton/conf/` 
directory and the deployments on Apache Tomcat are in `/operaton/webapps/`. 
The directory structure depends on the application server.

### Debug

To enable JPDA inside the container, you can set the environment variable
`DEBUG=true` on startup of the container. This will allow you to connect to the
container on port `8000` to debug your application.
This is only supported for `wildfly` and `tomcat` distributions.

### Prometheus JMX Exporter

To enable Prometheus JMX Exporter inside the container, you can set the 
environment variable `JMX_PROMETHEUS=true` on startup of the container. 
This will allow you to get metrics in Prometheus format at `<host>:9404/metrics`. 
For configuring exporter you need attach your configuration as a container volume 
at `/operaton/javaagent/prometheus-jmx.yml`. This is only supported for `wildfly` 
and `tomcat` distributions.

### Change timezone

To change the timezone of the docker container, you can set the environment
variable `TZ`.

```
docker run -d --name operaton -p 8080:8080 \
           -e TZ=Europe/Berlin \
          operaton/operaton-bpm:latest
```

## Build

You can build a Docker image for a given Operaton version and distribution yourself.
Make sure to adjust the [settings.xml](settings.xml) and remove the `operaton-nexus` mirror 

### Build a released version

To build a community image specify the `DISTRO` and `VERSION` build
argument. Possible values for `DISTRO` are:
* `tomcat`
* `wildfly`
* `run` (if the Operaton version already supports it)

The `VERSION` argument is the Operaton version you want to build, 
i.e. `7.17.0`.

```
docker build -t operaton-bpm\
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  .
```

### Build a SNAPSHOT version

Additionally, you can build `SNAPSHOT` versions for the upcoming releases by
setting the `SNAPSHOT` build argument to `true`.

```
docker build -t operaton-bpm\
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg SNAPSHOT=true \
  .
```
### Build when behind a proxy

You can pass the following arguments to set proxy settings to Maven: 

* `MAVEN_PROXY_HOST`
* `MAVEN_PROXY_PORT`
* `MAVEN_PROXY_USER`
* `MAVEN_PROXY_PASSWORD`

Example for a released version of a community edition:

```
docker build -t operaton-bpm\
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg MAVEN_PROXY_HOST=${PROXY_HOST} \
  --build-arg MAVEN_PROXY_PORT=${PROXY_PORT} \
  --build-arg MAVEN_PROXY_USER=${PROXY_USER} \
  --build-arg MAVEN_PROXY_PASSWORD=${PROXY_PASSWORD} \
  .
```
### Override MySQL and PostgreSQL driver versions. 
By default, the driver versions are fetched from https://github.com/operaton/operaton/blob/master/database/pom.xml. That can be overriden by passing `MYSQL_VERSION` and `POSTGRESQL_VERSION` build args

```
docker build -t operaton-bpm\
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg POSTGRESQL_VERSION=${POSTGRESQL_VERSION} \
  --build-arg MYSQL_VERSION=${MYSQL_VERSION} \
  .
```

## Use cases

### Change configuration files

You can use docker volumes to link your own configuration files inside the
container.  For example, if you want to change the `bpm.xml` on 
Apache Tomcat:

```
docker run -d --name operaton -p 8080:8080 \
           -v $PWD/bpm.xml:/operaton/conf/bpm.xml \
           operaton/operaton-bpm:latest
```

### Add own process application

If you want to add your own process application to the docker container, you can
use Docker volumes. For example, if you want to deploy the [twitter demo][] 
on Apache Tomcat:

```
docker run -d --name operaton -p 8080:8080 \
           -v /PATH/TO/DEMO/twitter.war:/operaton/webapps/twitter.war \
           operaton/operaton-bpm:latest
```

This also allows you to modify the app outside the container, and it will
be redeployed.


### Clean distro without web apps and examples

To remove all web apps and examples from the distro and only deploy your
own applications or your own configured cockpit also use Docker volumes. You
only have to overlay the deployment folder of the application server with
a directory on your local machine. So in Apache Tomcat, you would mount a 
directory to `/operaton/webapps/`:

```
docker run -d --name operaton -p 8080:8080 \
           -v $PWD/webapps/:/operaton/webapps/ \
           operaton/operaton-bpm:latest
```


## Extend Docker image

As we release these docker images on the official [docker registry][] it is
easy to create your own image. This way you can deploy your applications
with docker or provided an own demo image. Just specify in the `FROM`
clause which Operaton image you want to use as a base image:

```
FROM operaton/operaton-bpm:tomcat-latest

ADD my.war /operaton/webapps/my.war
```

## Branching model

Branches and their roles in this repository:

- `next` (default branch) is the branch where new features and bugfixes needed 
  to support the current `master` of [operaton-bpm-repo](https://github.com/operaton/operaton) go.
- `7.x` branches get created from `next` when a Operaton minor version
  is released. They only receive backports of bugfixes when absolutely necessary.


## License

Apache License, Version 2.0


[twitter demo]: https://github.com/operaton-consulting/code/tree/master/one-time-examples/twitter
[docker registry]: https://hub.docker.com/r/operaton/operaton-bpm/
[docker hub tags]: https://hub.docker.com/r/operaton/operaton-bpm/tags/
