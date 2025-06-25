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
[http://localhost:8080](http://localhost:8080)

---

## 🏗️ Running with an External Database (Production)

To connect the application to a production-grade RDBMS, provide the required environment variables at runtime.

---

## 🐬 Example: Using MySQL

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
    ports:
      - "5432:5432"
    volumes:
      - postgres-data:/var/lib/postgresql/data
    restart: always

volumes:
  postgres-data:
    driver: local
```

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