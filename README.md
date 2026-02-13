# Project Development Environment

This project uses **Docker + PostgreSQL** to provide a reproducible development environment that works the same on any computer (personal laptop, work PC, or new developer machine).

No local installation of PostgreSQL is required.

---

## Requirements

Install the following:

* [Docker Desktop](https://www.docker.com/products/docker-desktop/)
* Git

After installing Docker, make sure it is running.

Verify:

```bash
docker --version
docker compose version
```

---

## First Time Setup

Clone the repository:

```bash
git clone https://github.com/mariopp126/docker-postgres.git
cd docker-postgres
```

Create the environment variables file:

```bash
cp .env.example .env
```

*(Windows PowerShell)*

```powershell
copy .env.example .env
```

---

## Start the Database

Run:

```bash
docker compose up -d
```

The first startup may take ~15–25 seconds.

Docker will automatically:

* download PostgreSQL image
* create the database
* create the `auth` schema
* create all authentication tables

No manual SQL setup is required.

---

## Verify the Container

Check that PostgreSQL is running:

```bash
docker ps
```

You should see a container named:

```
dev-postgres
```

You can also check logs:

```bash
docker logs dev-postgres
```

You should see:

```
database system is ready to accept connections
```

---

## Database Connection

Use any database client (DBeaver, pgAdmin, TablePlus, etc.):

| Setting  | Value        |
| -------- | ------------ |
| Host     | localhost    |
| Port     | 5432         |
| Database | app_db       |
| User     | app_user     |
| Password | app_password |

---

## Connect via Terminal

```bash
docker exec -it dev-postgres psql -U app_user -d app_db
```

Exit with:

```
\q
```

---

## Stop the Database

```bash
docker compose down
```

Database data will be preserved.

---

## Reset the Database (Clean Install)

⚠️ This deletes all local data.

```bash
docker compose down -v
docker compose up -d
```

The schema will be recreated automatically.

---

## Database Initialization

All database structure is automatically created using SQL migration files located in:

```
codia_app_db/
```

These scripts run only on the first initialization of the database volume.

---

## Sharing Data Between Computers (Optional)

Export database:

```bash
docker exec dev-postgres pg_dump -U app_user -d app_db > backup.sql
```

Import database:

```bash
docker exec -i dev-postgres psql -U app_user -d app_db < backup.sql
```

---

## Environment Variables

File:

```
docker/postgres/.env
```

Example:

```
POSTGRES_DB=app_db
POSTGRES_USER=app_user
POSTGRES_PASSWORD=app_password
```

Do **NOT** commit `.env` to Git.
Only `.env.example` is tracked.

---

## Project Structure

```
docker/postgres
├── docker-compose.yml
├── .env.example
└── codia_app_db/
    └── 001_auth_schema.sql
```

---

## Troubleshooting

### Container keeps restarting

Run:

```bash
docker compose down -v
docker compose up -d
```

### Port 5432 already in use

Another PostgreSQL installation is running locally.
Stop it or change the port mapping in `docker-compose.yml`.

---

## Why Docker?

This ensures:

* identical environment on every computer
* no dependency conflicts
* easy onboarding
* safe database isolation
* CI/CD ready infrastructure
