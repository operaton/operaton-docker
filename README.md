# Operaton Docker images

> Use our [GitHub issue tracker](https://github.com/operaton/operaton-docker/issues) for bug reports or feature requests.
> For help requests, open a help request topic on the [Operaton forum](https://forum.operaton.org/)

This Operaton project provides docker images of the latest 
Operaton releases. The images can be used to demonstrate and test the
Operaton or can be extended with own process applications. Images are
published on [Docker Hub](https://hub.docker.com/u/operaton) for every release,
including pre-releases and snapshot builds.

The Operaton Docker images are wrappers for the pre-packaged Operaton
distributions. The pre-packaged distributions are intended for users who want a 
getting started experience. In case you want to use the Operaton Docker images 
in production, consider reading our [security instructions](https://docs.operaton.org/docs/documentation/user-guide/security).

## Distributions

You can find more detailed documentation on the pre-packaged (community) 
distributions that Operaton provides at the following links:

* Operaton - the Spring Boot based standalone distribution (formerly known as Operaton Run) - [documentation](https://docs.operaton.org/docs/documentation/user-guide/operaton-bpm-run)
* Operaton Tomcat - [Operaton Tomcat integration documentation](https://docs.operaton.org/docs/documentation/user-guide/runtime-container-integration/tomcat)
* Operaton Wildfly - [Operaton Wildfly Subsystem documentation](https://docs.operaton.org/docs/documentation/user-guide/runtime-container-integration/jboss)

## Get started

To start a Docker container of the latest Operaton release:

```
docker pull operaton/operaton:latest
docker run -d --name operaton -p 8080:8080 operaton/operaton:latest
```

### Tasklist, Cockpit, Admin web apps

The three Operaton web apps are accessible through the landing page: 
http://localhost:8080/operaton-welcome/index.html

In the `operaton` image, the web apps are served at http://localhost:8080/operaton/app/,
which http://localhost:8080/ redirects to.

The default credentials for admin access to the web apps is:

- Username: `demo`
- Password: `demo`

### REST API

The Operaton REST API is accessible through: http://localhost:8080/engine-rest

See the [REST API](https://docs.operaton.org/docs/documentation/reference/rest/overview/)
documentation for more details on how to use it.

**Note**: The REST API does not require authentication by default. Follow the instructions from the [documentation](https://docs.operaton.org/docs/documentation/reference/rest/overview/authentication)
to enable authentication for the REST API.

### Swagger UI

The `operaton/operaton` image serves a Swagger UI for the REST API at
http://localhost:8080/swaggerui/index.html. The OpenAPI specification it shows
is available at http://localhost:8080/swaggerui/openapi.json.

Swagger UI is only available in the `operaton/operaton` image. See
[Startup options](#startup-options) for how to enable or disable it.

## Supported tags/releases

Each distribution of Operaton - **Self-Contained**, **Tomcat**, and **Wildfly** - is published to its own Docker repository on Docker Hub. Below are the links to these repositories:

- [Operaton (Self-Contained)](https://hub.docker.com/r/operaton/operaton)
- [Tomcat](https://hub.docker.com/r/operaton/tomcat)
- [Wildfly](https://hub.docker.com/r/operaton/wildfly)

### Tag Schema

Each of the repositories follows the tag schema below:

- `latest`: Always points to the highest released (non pre-release) version of Operaton.
- `SNAPSHOT`, `${VERSION}-SNAPSHOT`: A nightly build of the latest or a specific revision of Operaton. These are not officially released versions.
- `${VERSION}`: A specific, officially released version of Operaton, including pre-releases like `2.2.0-RC1`.

Each tag is also available with a `-jdk17`, `-jdk21`, or `-jdk25` suffix, see [Java versions](#java-versions).

## Operaton configuration

You can find the complete Operaton documentation at https://docs.operaton.org/.

If you prefer to start your Operaton Docker image right away, you will find the
following links useful:

* [Operaton standalone distribution configuration](https://docs.operaton.org/docs/documentation/user-guide/operaton-bpm-run)
* [Operaton configuration file properties](https://docs.operaton.org/docs/documentation/reference/deployment-descriptors/bpm-platform-xml)
* [Process Engine Plugins guide](https://docs.operaton.org/docs/documentation/user-guide/process-engine/process-engine-plugins)
* [Operaton Logging](https://docs.operaton.org/docs/documentation/user-guide/logging)

## Operaton Docker image configuration

### Configuration of the `operaton` distribution

Because `operaton` is a Spring Boot-based distribution, it can be configured through 
the respective environment variables. For example:
- `SPRING_DATASOURCE_DRIVER_CLASS_NAME` the database driver class name, 
  supported are h2 (default), mysql, and postgresql:
  - h2: `SPRING_DATASOURCE_DRIVER_CLASS_NAME=org.h2.Driver`
  - mysql: `SPRING_DATASOURCE_DRIVER_CLASS_NAME=com.mysql.cj.jdbc.Driver`
  - postgresql: `SPRING_DATASOURCE_DRIVER_CLASS_NAME=org.postgresql.Driver`
- `SPRING_DATASOURCE_URL` the database jdbc url
- `SPRING_DATASOURCE_USERNAME` the database username
- `SPRING_DATASOURCE_PASSWORD` the database password

When not set or otherwise specified, the integrated H2 database is used.

Any other `SPRING_*` variables can be used to further configure the app. 
Alternatively, a `default.yml` file can be mounted to `/operaton/configuration/default.yml`.
More information on configuring Spring Boot applications can be found in the 
[Spring Boot documentation](https://docs.spring.io/spring-boot/reference/features/external-config.html).

The following environment variables are supported for convenience and 
compatibility and are internally mapped to `SPRING_DATASOURCE_*` variables 
when provided:

* `DB_DRIVER`
* `DB_USERNAME`
* `DB_PASSWORD`
* `DB_URL`
* `DB_PASSWORD_FILE`

The `JMX_PROMETHEUS` configuration is not supported, and while `DEBUG` can be 
used to enable Spring Boot's debug output, it doesn't start a debug socket.
The connection pool and validation variables (`DB_CONN_*`, `DB_VALIDATE_ON_BORROW`,
`DB_VALIDATION_QUERY`) and `SKIP_DB_CONFIG` are not supported either; use the
respective `SPRING_DATASOURCE_*` variables instead.

#### Startup options

The `operaton` image is started by `./operaton.sh`, which passes its options on
to the start script of the distribution. The following options select the
components to enable:

- `--webapps` enables the web apps (Cockpit, Tasklist, Admin)
- `--rest` enables the REST API
- `--swaggerui` enables the Swagger UI for the REST API. Swagger UI is not part
  of the Operaton distribution; it is added by this Docker image.
- `--example` enables the invoice example application
- `--oauth2` enables the Spring Security OAuth2 integration
- `--webapps-neo` enables the new web apps and the REST API they need
  (only available in Operaton versions >= 2.2)

When none of these options is passed, the web apps, the REST API, the Swagger UI,
and the example application are enabled. As soon as one of them is passed,
only the selected components are enabled. Run `./operaton.sh --help` to list
the options of the Operaton version in the image.

Enable only the web apps:

```bash
docker run -d -p 8080:8080 operaton/operaton ./operaton.sh --webapps
```

Enable only the REST API and Swagger UI:

```bash
docker run -d -p 8080:8080 operaton/operaton ./operaton.sh --rest --swaggerui
```

Swagger UI sends its requests to the REST API of the same instance. If you
enable Swagger UI without the REST API, the container logs a warning.

Additionally, a `--production` parameter is supported to switch the 
configuration to `/operaton/configuration/production.yml`. This parameter also 
disables Swagger UI and the example application unless they are enabled explicitly.

#### Endpoints

With the default startup options, the `operaton` image serves:

| Component | URL |
|-----------|-----|
| Web apps (Cockpit, Tasklist, Admin) | http://localhost:8080/operaton/app/ (`/` redirects there) |
| REST API | http://localhost:8080/engine-rest |
| Swagger UI | http://localhost:8080/swaggerui/index.html |
| OpenAPI specification of the REST API | http://localhost:8080/swaggerui/openapi.json |

Swagger UI uses the REST API of the instance it is served from (`/engine-rest`)
as the default server. The OpenAPI specification is taken from the
`operaton-engine-rest-openapi` artifact of the Operaton version in the image.
Snapshot images use the latest published specification, because snapshot
versions of it are not published.

### Java versions

Our docker images are using a LTS OpenJDK version supported by
Operaton. This currently means:

 - Operaton 1.0 or later will be based on OpenJDK 17.

Images for OpenJDK 21 and 25 carry a `-jdk21` or `-jdk25` tag suffix (e.g. `1.1.0-jdk21`).
OpenJDK 17 images are also tagged with `-jdk17`, identical to the tag without suffix.
To build one yourself, pass the build argument `JAVA_VERSION` (default `17`):

```
docker build --build-arg DISTRO=operaton --build-arg JAVA_VERSION=21 -t operaton/operaton:jdk21 .
```

#### Java options

To override the default Java options the environment variable `JAVA_OPTS` can
be set.

### Use Docker Memory Limits

The Java JVM is container-aware by default, automatically adjusting to Docker container limits. Here's how to configure optimal memory settings for Operaton:

**Recommended Memory Configuration**

For most Operaton workloads, use these optimal settings:

```bash
docker run -d --name operaton -p 8080:8080 \
  --memory=2g \
  -e JAVA_OPTS="-XX:MaxRAMPercentage=70.0" \
  operaton/operaton:latest
```

This allocates about 1.4GB for the JVM heap, which provides sufficient memory for Operaton while leaving room for non-heap memory requirements (native memory, thread stacks, etc.).

For different workload sizes:
- **Light usage**: 1GB container with 70% RAM allocation (~700MB heap)
- **Moderate usage**: 2GB container with 70% RAM allocation (~1.4GB heap)
- **Heavy usage**: 4GB container with 70% RAM allocation (~2.8GB heap)

**Understanding JVM Container Behavior**

Without explicit memory limits, the JVM assumes it can use all host resources:
- The heap defaults to 25% of host system memory (often too small for Operaton)
- Thread pools may scale to all available cores

For proper resource management, always specify container limits:

```bash
docker run -d --name operaton -p 8080:8080 \
  --memory=2g --cpus=2 \
  operaton/operaton:latest
```

**Override CPU Core Detection**

If needed, you can explicitly set how many CPU cores the JVM should assume using the `-XX:ActiveProcessorCount` flag:

```bash
-e JAVA_OPTS="-XX:ActiveProcessorCount=2"
```

This is useful in situations where container limits aren't accurately detected or you want to simulate a specific number of cores regardless of the environment.

**Disable Container Awareness (Manual Tuning)**

You can disable container support entirely and manage resources manually:

```bash
docker run -d --name operaton -p 8080:8080 \
  -e JAVA_OPTS="-XX:-UseContainerSupport -Xmx768m -Xms512m" \
  operaton/operaton:latest
```


> **Note on Container Platform Resource Management**
>
> In Kubernetes, resource limits are set in a Pod or container specification using the resources field, defining limits and requests for CPU and memory. In Podman, resource limits are configured using command-line flags like --memory, --cpus, and --cpu-shares when running containers. The JVM will automatically detect and adapt to these resource limits regardless of how they are configured in the container platform.

**Inspecting JVM Configuration Parameters**

To examine the actual JVM memory settings in use, you can display all configuration parameters when launching the container:

```bash
docker run -d --name operaton -p 8080:8080 \
  --memory=1g \
  -e JAVA_OPTS="-XX:+PrintFlagsFinal" \
  operaton/operaton:latest
```

Extract and analyze the memory configuration by filtering the container logs:

For Linux/macOS systems:
```bash
docker logs operaton | grep HeapSize
```

For Windows PowerShell:
```powershell
docker logs operaton | Select-String "HeapSize"
```

For Windows Command Prompt:
```batch
docker logs operaton | findstr "HeapSize"
```

These commands filter for heap-related settings in the JVM configuration. You can also search for other important parameters:

```bash
# For thread pool settings (Linux/macOS)
docker logs operaton | grep "GCThreads\|ParallelGCThreads"

# For container detection (Linux/macOS)
docker logs operaton | grep "UseContainerSupport"
```

### Database environment variables

The used database can be configured by providing the following environment
variables:

- `DB_CONN_MAXACTIVE` the maximum number of active connections (default: `20`)
- `DB_CONN_MAXIDLE` the maximum number of idle connections (default: `20`)
  - ignored for the `wildfly` and `operaton` distributions
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

```bash
# start postgresql image with database and user configured
docker run -d --name postgresql ...

docker run -d --name operaton -p 8080:8080 --link postgresql:db \
           -e DB_DRIVER=org.postgresql.Driver \
           -e DB_URL=jdbc:postgresql://db:5432/process-engine \
           -e DB_USERNAME=operaton \
           -e DB_PASSWORD=operaton \
           -e WAIT_FOR=db:5432 \
           operaton/operaton:latest
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

```bash
docker run -d --name operaton -p 8080:8080 --link postgresql:db \
           --env-file db-env.txt operaton/operaton:latest
```

The docker image already contains drivers for `h2`, `mysql`, and `postgresql`.
If you want to use other databases, you have to add the driver to the container
and configure the database settings manually by linking the configuration file
into the container.

To skip the configuration of the database by the docker container and use your
own configuration set the environment variable `SKIP_DB_CONFIG` to a non-empty 
value:

```bash
docker run -d --name operaton -p 8080:8080 -e SKIP_DB_CONFIG=true \
           operaton/operaton:latest
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
           operaton/operaton:latest
```

### Volumes

Operaton is installed inside the `/operaton` directory. The directory
structure depends on the distribution:

- `operaton`: the configuration files are in `/operaton/configuration/`,
  additional libraries (e.g. JDBC drivers) go to `/operaton/configuration/userlib/`, 
  and BPMN resources to deploy go to `/operaton/configuration/resources/`.
- `tomcat`: the Apache Tomcat configuration files are in `/operaton/conf/`
  and the deployments are in `/operaton/webapps/`.
- `wildfly`: the WildFly configuration files are in `/operaton/standalone/configuration/`
  and the deployments are in `/operaton/standalone/deployments/`.

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

```bash
docker run -d --name operaton -p 8080:8080 \
           -e TZ=Europe/Berlin \
          operaton/operaton:latest
```

## Build

You can build a Docker image for a given Operaton version and distribution yourself.

### Build a released version

To build an image specify the `DISTRO`, `VERSION`, and `SNAPSHOT` build
arguments. Possible values for `DISTRO` are:
* `operaton` (default): the Spring Boot based standalone distribution, published as `operaton/operaton`.
  The legacy name `run` is still accepted but deprecated.
* `tomcat`: published as `operaton/tomcat`
* `wildfly`: published as `operaton/wildfly`

The `VERSION` argument is the Operaton version you want to build, 
i.e. `2.1.5`. It is required. The `SNAPSHOT` argument defaults to `true`, so
set it to `false` to build a released version.

```bash
docker build -t operaton \
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg SNAPSHOT=false \
  .
```

### Build a SNAPSHOT version

You can build `SNAPSHOT` versions for the upcoming releases by
setting the `SNAPSHOT` build argument to `true` (the default). `VERSION` is the
version without the `-SNAPSHOT` suffix, i.e. `2.2.0`.

```bash
docker build -t operaton \
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

```bash
docker build -t operaton \
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg MAVEN_PROXY_HOST=${PROXY_HOST} \
  --build-arg MAVEN_PROXY_PORT=${PROXY_PORT} \
  --build-arg MAVEN_PROXY_USER=${PROXY_USER} \
  --build-arg MAVEN_PROXY_PASSWORD=${PROXY_PASSWORD} \
  .
```
### Override MySQL and PostgreSQL driver versions
By default, the driver versions are taken from the `operaton-database-settings` POM of
the built Operaton version, or from https://github.com/operaton/operaton/blob/main/database/pom.xml
for `SNAPSHOT` builds. That can be overridden by passing `MYSQL_VERSION` and `POSTGRESQL_VERSION` build args

```bash
docker build -t operaton \
  --build-arg DISTRO=${DISTRO} \
  --build-arg VERSION=${VERSION} \
  --build-arg POSTGRESQL_VERSION=${POSTGRESQL_VERSION} \
  --build-arg MYSQL_VERSION=${MYSQL_VERSION} \
  .
```

### Override the Swagger UI version

The `operaton` image bundles [Swagger UI](https://github.com/swagger-api/swagger-ui)
from the `org.webjars:swagger-ui` artifact. Its version can be changed with the
`SWAGGER_UI_VERSION` build arg:

```bash
docker build -t operaton \
  --build-arg DISTRO=operaton \
  --build-arg VERSION=${VERSION} \
  --build-arg SWAGGER_UI_VERSION=${SWAGGER_UI_VERSION} \
  .
```

## Use cases

### Change configuration files

You can use docker volumes to link your own configuration files inside the
container.  For example, if you want to change the `bpm.xml` on 
Apache Tomcat:

```bash
docker run -d --name operaton -p 8080:8080 \
           -v $PWD/bpm.xml:/operaton/conf/bpm.xml \
           operaton/tomcat:latest
```

For the `operaton` image, mount your configuration to
`/operaton/configuration/default.yml` instead.

### Add own process application

If you want to add your own process application to the docker container, you can
use Docker volumes. For example, to deploy a process application `my-app.war`
on Apache Tomcat:

```bash
docker run -d --name operaton -p 8080:8080 \
           -v /PATH/TO/my-app.war:/operaton/webapps/my-app.war \
           operaton/tomcat:latest
```

This also allows you to modify the app outside the container, and it will
be redeployed.


### Clean distro without web apps and examples

To remove all web apps and examples from the distro and only deploy your
own applications or your own configured cockpit also use Docker volumes. You
only have to overlay the deployment folder of the application server with
a directory on your local machine. So in Apache Tomcat, you would mount a 
directory to `/operaton/webapps/`:

```bash
docker run -d --name operaton -p 8080:8080 \
           -v $PWD/webapps/:/operaton/webapps/ \
           operaton/tomcat:latest
```

For the `operaton` image, use the [startup options](#startup-options) instead.


## Extend Docker image

As we release these docker images on [Docker Hub](https://hub.docker.com/u/operaton) it is
easy to create your own image. This way you can deploy your applications
with docker or provided an own demo image. Just specify in the `FROM`
clause which Operaton image you want to use as a base image:

```dockerfile
FROM operaton/tomcat:latest

ADD my.war /operaton/webapps/my.war
```

## Branching model

Branches and their roles in this repository:

- `main` (default branch) is the branch where new features and bugfixes go.
  Images for all Operaton versions, including `SNAPSHOT` builds, are built from it.


## License

Apache License, Version 2.0

