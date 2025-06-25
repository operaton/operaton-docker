# Operaton WildFly

This Docker image provides a process automation engine running on **WildFly**, suitable for both quick development and scalable production deployments. It supports both an embedded **H2** database and connection to an external **relational database** (RDBMS) such as PostgreSQL or MySQL.

---

## 🔧 Usage

You can run this container in two modes:

- With an **embedded H2** database (default, for development and evaluation)
- With an **external RDBMS** (e.g., PostgreSQL, MySQL) for production use

---

## 🧪 Running with Embedded H2 (Development)

To quickly launch the engine using an in-memory H2 database:

```bash
docker run -d --name operaton \
  -p 8080:8080 \
  operaton/wildfly
```

Once running, access the web interface at:  
[http://localhost:8080/operaton](http://localhost:8080/operaton)

You can customize the webapp path with the `OPERATON_WEBAPP_NAME` environment variable.

---

## 🏗️ Running with an External Database (Production)

To connect Operaton to an external RDBMS, set the proper JDBC driver and connection properties.

---

## 🐬 Example: Using MySQL

```yaml
services:
  operaton:
    image: operaton/wildfly
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

---

## 🐘 Example: Using PostgreSQL

```yaml
services:
  operaton:
    image: operaton/wildfly
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

## ⚙️ Configuration

Supported environment variables:

| Variable              | Description                                     | Example                                     |
|-----------------------|-------------------------------------------------|---------------------------------------------|
| `DB_DRIVER`           | JDBC driver class name                          | `org.postgresql.Driver`                     |
| `DB_URL`              | JDBC connection URL                             | `jdbc:mysql://...` or `jdbc:postgresql://`  |
| `DB_USERNAME`         | Database username                               | `root`, `postgres`, etc.                    |
| `DB_PASSWORD`         | Database password                               | `your-password`                             |
| `OPERATON_WEBAPP_NAME`| Webapp context path                             | `operaton`                                  |

---

## 📂 Default Credentials

The application ships with default login credentials:

- **Username:** `demo`
- **Password:** `demo`

---

## 📄 License

This project is distributed under the terms of the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).