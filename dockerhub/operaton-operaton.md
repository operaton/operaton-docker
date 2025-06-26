# Operaton

This Docker image provides a self-contained process automation engine, packaged as a **lightweight Spring Boot application**. Ideal for both local development and streamlined production deployments.

The image runs out-of-the-box with an embedded **H2** database, and can also be configured to connect to an external **RDBMS** such as PostgreSQL or MySQL.

---

## 🔧 Usage

You can run this container in two modes:

- With an **embedded H2** database (default)
- With an **external relational database** (e.g., PostgreSQL, MySQL)

---

## 🧪 Running with Embedded H2 (Development)

Quick start with the default in-memory H2 database:

```bash
docker run -d --name operaton \
  -p 8080:8080 \
  operaton/operaton
```

Access the application at:  
[http://localhost:8080/operaton](http://localhost:8080/operaton)

---

## 🏗️ Running with an External Database

Depending on your database of choice, copy one of the configurations below into a file named `docker-compose.yaml`. Then, in the same directory, run:

```bash
docker compose up -d
```

The application will be accessible at [http://localhost:8080/operaton](http://localhost:8080/operaton)


### 🐬 docker-compose.yaml for MySQL

```yaml
services:
  operaton:
    image: operaton/operaton
    container_name: operaton
    environment:
      - DB_DRIVER=com.mysql.cj.jdbc.Driver
      - DB_URL=jdbc:mysql://mysql:3306/operaton?autoReconnect=true&sessionVariables=transaction_isolation='READ-COMMITTED'
      - DB_USERNAME=root
      - DB_PASSWORD=rootpassword
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
    volumes:
      - mysql-data:/var/lib/mysql
    restart: always

volumes:
  mysql-data:
    driver: local
```

### 🐘 docker-compose.yaml for PostgreSQL

```yaml
services:
  operaton:
    image: operaton/operaton
    container_name: operaton
    environment:
      - DB_DRIVER=org.postgresql.Driver
      - DB_URL=jdbc:postgresql://postgres:5432/operaton
      - DB_USERNAME=postgres
      - DB_PASSWORD=postgrespassword
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
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: always

volumes:
  postgres-data:
    driver: local
```

---
## 🔄 Port 8080 Already in Use?

If port `8080` is already being used on your machine, the container will fail to start because it cannot bind to that port. This is a common issue when running multiple services or development environments locally.

To resolve this, **change the host port** in the port mapping section of your `docker run` or `docker-compose.yaml` file.

### 🔧 Example (Inline Docker Run)

Change:

```bash
-p 8080:8080
```

To use a different host port, like `8081`:

```bash
-p 8081:8080
```

In this example, `8081` is the port on your local machine, and `8080` is the port inside the container.


### 🔧 Example (Docker Compose)

In your `docker-compose.yaml`, change:

```yaml
ports:
  - "8080:8080"
```

To something like:

```yaml
ports:
  - "8081:8080"
```

This tells Docker to forward traffic from your host’s port `8081` to the container’s internal port `8080`.

Save the changes, and re-run:

```bash
docker compose up -d
```


After the port has been changed to `8081` (inline or in `docker-compose.yaml`), access the application at:  
[http://localhost:8081/operaton](http://localhost:8081/operaton)

---

## ⚙️ Configuration

Supported environment variables:

| Variable      | Description                  | Example                                     |
|---------------|------------------------------|---------------------------------------------|
| `DB_DRIVER`   | JDBC driver class            | `org.postgresql.Driver`                     |
| `DB_URL`      | JDBC connection URL          | `jdbc:mysql://...` or `jdbc:postgresql://`  |
| `DB_USERNAME` | Database username            | `root`, `postgres`, etc.                    |
| `DB_PASSWORD` | Database password            | `your-password`                             |

---

## 📂 Default Credentials

Login with:

- **Username:** `demo`
- **Password:** `demo`

---

## 📄 License

This project is distributed under the terms of the [Apache 2.0 License](https://www.apache.org/licenses/LICENSE-2.0).