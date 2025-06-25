# Operaton Tomcat

This Docker image provides a process automation engine running on **Apache Tomcat**, designed to support both lightweight development setups and more robust production environments.

---

## 🔧 Usage

You can run this container in two modes:

- With an **embedded H2** database (default, for development and evaluation)
- With an **external relational database** such as MySQL, PostgreSQL, etc. (for production)

---

## 🧪 Running with Embedded H2 (Development)

No external configuration is required. To get started quickly:

```bash
docker run -d --name operaton \
  -p 8080:8080 \
  operaton/tomcat
```

Access the web interface at: [http://localhost:8080/operaton](http://localhost:8080/operaton)

The webapp context path can be customized using the `OPERATON_WEBAPP_NAME` environment variable.

---

## 🏗️ Running with an External Database (Production)

To connect to an external RDBMS (e.g., MySQL, PostgreSQL), set the appropriate JDBC configuration.

For example, to use **MySQL**, you might use the following `docker-compose.yml`:

```yaml
services:
  operaton:
    image: operaton/tomcat
    container_name: operaton
    environment:
      - DB_DRIVER=com.mysql.cj.jdbc.Driver
      - DB_URL=jdbc:mysql://mysql:3306/operaton?autoReconnect=true&sessionVariables=transaction_isolation='READ-COMMITTED'
      - DB_USERNAME=root
      - DB_PASSWORD=rootpassword
      - OPERATON_WEBAPP_NAME=operaton
    ports:
      - "8080:8080"
    depends_on:
      - mysql
    restart: always

  mysql:
    image: mysql:8.0
    container_name: mysql
    environment:
      - MYSQL_ROOT_PASSWORD=rootpassword
      - MYSQL_DATABASE=operaton
      - MYSQL_INITDB_EXTRA_ARGS=--transaction-isolation=READ-COMMITTED
    ports:
      - "3306:3306"
    volumes:
      - mysql-data:/var/lib/mysql
    restart: always

volumes:
  mysql-data:
    driver: local
```

Modify the driver and JDBC URL accordingly for other databases such as PostgreSQL.

---

## ⚙️ Configuration

You can configure the container using the following environment variables:

| Variable              | Description                                     | Example                                     |
|-----------------------|-------------------------------------------------|---------------------------------------------|
| `DB_DRIVER`           | JDBC driver class name                          | `org.postgresql.Driver`                     |
| `DB_URL`              | JDBC connection URL                             | `jdbc:postgresql://db:5432/operaton`        |
| `DB_USERNAME`         | Database username                               | `admin`                                     |
| `DB_PASSWORD`         | Database password                               | `secret`                                    |
| `OPERATON_WEBAPP_NAME`| Webapp context path                             | `operaton`                                  |

---

## 🐘 Example: Using PostgreSQL

To run Operaton with a PostgreSQL database, use the following `docker-compose.yml` example:

```yaml
services:
  operaton:
    image: operaton/tomcat
    container_name: operaton
    environment:
      - DB_DRIVER=org.postgresql.Driver
      - DB_URL=jdbc:postgresql://postgres:5432/operaton
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgrespassword
      - OPERATON_WEBAPP_NAME=operaton
    ports:
      - "8080:8080"
    depends_on:
      - postgres
    restart: always

  postgres:
    image: postgres:15
    container_name: postgres
    environment:
      - POSTGRES_DB=operaton
      - POSTGRES_USER=postgres
      - POSTGRES_PASSWORD=postgrespassword
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: always

volumes:
  postgres-data:
    driver: local
```

This setup initializes a PostgreSQL database and connects the application to it using standard JDBC settings.
---

## 📂 Default Credentials

The default user for login is:

- **Username:** `demo`
- **Password:** `demo`

---

## 📄 License

This project is distributed under the terms of the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).