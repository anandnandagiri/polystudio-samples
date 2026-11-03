# Poly Studio - Evaluation Lab

A ready-to-run stack of **official sample databases** plus an **SSH sidecar**
that Poly Studio connects to exactly the way it would connect to a real
production server.

Everything here runs on **your** machine. Nothing is hosted and nothing phones
home.

> **One command and one click.** `docker compose up` starts the lab, then
> Poly Studio's **Import Lab Pack** button wires it in completely - SSH tunnel,
> 5 database connectors and a pre-seeded Query Lab dashboard with 6 live
> charts. Poly Studio reads the `lab-manifest.json` in this folder and configures
> itself; no scripts, no tooling.

---

## What you get

| In Poly Studio | What it is |
|---|---|
| **5 database connectors** | PostgreSQL (x2), MySQL, MariaDB, SQL Server - all reached through one SSH tunnel |
| **1 SSH tunnel** | `Lab SSH (poly-lab-ssh)` - a real `sshd` on a container, exactly like a remote PROD host |
| **1 Query Lab page** | "Evaluation Lab" - 6 chart cards that run against the live data |
| **Docker Studio** | Lists the lab's real containers (the sidecar has the Docker socket mounted) |

Every database connection travels over the SSH tunnel. The databases are
**not** published to your host - only the SSH port is, and it is bound to
`127.0.0.1`.

### The sample data

All datasets are the **canonical, vendor-published** ones:

| Engine | Dataset | Source | Size |
|---|---|---|---|
| PostgreSQL | **Chinook** | [lerocha/chinook-database](https://github.com/lerocha/chinook-database) (MIT) | 347 albums / 275 artists / 3,503 tracks |
| PostgreSQL | **Sakila** | [sakiladb/postgres](https://github.com/sakiladb/postgres) | 1,000 films / 599 customers / 16,049 payments |
| MySQL | **Sakila** | [sakiladb/mysql](https://github.com/sakiladb/mysql) (Oracle, BSD-2) | 16 tables + views + procedures + functions + triggers |
| MariaDB | **Sakila** | same | same |
| SQL Server | **Chinook** | [lerocha/chinook-database](https://github.com/lerocha/chinook-database) | 11 tables, 3,503 tracks |
| SQLite (no Docker) | **Chinook** | same | ready-made `.sqlite` file, no server needed |

---

## Requirements

- **Docker** with Compose v2 (`docker compose version`) - for the full lab
- **Poly Studio** (Trial is full-featured for 14 days)

No PowerShell, Python or sqlite tooling needed anywhere - the app does the
wiring itself.

---

## Quick start

```bash
git clone https://github.com/anandnandagiri/polystudio-samples.git
cd polystudio-samples

# 1. Start the lab (Postgres x2, MySQL, MariaDB + SSH sidecar)
#    On x64 (Intel/AMD) add the SQL Server profile:
docker compose -f compose/polystudio-lab.yml --profile x64 up -d

#    On arm64 (Raspberry Pi, Apple Silicon) leave the profile off:
docker compose -f compose/polystudio-lab.yml up -d
```

2. Start **Poly Studio** and open **Connectors**.
3. Click **Import Lab Pack** and pick this folder.
4. Review the preview (it verifies the lab is reachable and your license
   allows the count) and press **Allow & import**.
5. Open the Connectors page - the lab is wired up. Try **Query Lab** for the
   pre-built "Evaluation Lab" dashboard.

Poly Studio shows you the exact command for the machine it runs on, with the
right profile already included.

### Why the `--profile x64` difference

`mcr.microsoft.com/mssql/server:2022-latest` is published for **linux/amd64
only** - the tag has no arm64 variant at all. On a Raspberry Pi, pulling it
either fails or drags in a 600 MB amd64 image that then has to run under
emulation. The SQL Server services therefore sit behind a Compose profile, so
`docker compose up` simply leaves them out on arm64 instead of failing the
whole stack. Poly Studio skips the SQL Server **connector** on non-x64
machines on its own, so both layers agree.

### The first start takes a few minutes

The sample data is loaded by the containers themselves, and the Sakila
datasets are big (about 160,000 rows for PostgreSQL, 600,000 for MySQL and
MariaDB). While a container is loading them it stays in `health: starting` -
that is the honest state, because the health check tests the TCP port that
Poly Studio actually reaches through the tunnel.

```bash
docker compose -f compose/polystudio-lab.yml ps          # watch it become healthy
docker compose -f compose/polystudio-lab.yml logs -f      # or follow the loading
```

If a connector fails with *"the database closed the connection"*, the usual
cause is that the container is still seeding. Wait for it to report healthy
and press **Test** again.

### Running less of the lab on a small machine

Four databases at once is a lot for a 4-8 GB Raspberry Pi. Start only what
you need by naming the services you want:

```bash
docker compose -f compose/polystudio-lab.yml up -d lab-ssh postgres
```

The containers are tuned down for small machines already (64 MB shared
buffers, 64 MB InnoDB buffer pool, 50 connections per database).

When you are done:

```bash
docker compose -f compose/polystudio-lab.yml down -v
```

### What the import does

- Reads `lab-manifest.json` from the folder you pick and shows a **preview** -
  nothing is written until you confirm.
- Creates the SSH tunnel + connectors and encrypts the passwords **the app's
  own way** (plaintext never touches disk).
- Creates the "Evaluation Lab" Query Lab page and cards.
- **Copies the pack's files onto the machine that runs Poly Studio** - the
  seed scripts, the compose stack and the sample database - into
  `<app data>/packs/<pack>/`. The layout is preserved (`packs/...` and
  `compose/...`), so the folder is ready to run as a lab on its own. The
  files are shared by every user of the app.
- **Re-running is safe**: lab rows with the same names are replaced, never
  duplicated, and a file whose checksum has not changed is left untouched.
  That is how you update the lab data: pull the new repo, import again.
- The app **never runs `docker` for you** - it shows you the exact command to
  start the lab from the folder it just filled in.
- Your **license limits apply** - on a Free license the extra connectors stay
  locked until you upgrade, exactly as if you had created them by hand.
- On ARM64 machines (Raspberry Pi, Apple Silicon) the SQL Server connector and
  its card are skipped automatically - that image has no `linux/arm64` build.
  The start command Poly Studio shows you matches: the SQL Server Compose
  profile is left off on arm64 and enabled on x64, so the stack never tries
  to pull a 600 MB image that cannot run there.

### Importing from a URL instead of a folder

The manifest can also live on GitHub. Open **Connectors -> Setup Packs ->
Import a pack**, paste the address of a `lab-manifest.json` (a `raw.githubusercontent.com`
link works), and the app fetches it. Relative file paths in the manifest are
resolved against the manifest's own folder, so the same manifest works from a
clone and from a URL. Remote files must declare their SHA-256 - the app
verifies it before writing anything.

Copy and paste either of the following raw GitHub URLs into Poly Studio:

- **Full Evaluation Lab (Docker):**
  ```text
  https://raw.githubusercontent.com/anandnandagiri/polystudio-samples/main/lab-manifest.json
  ```

- **SQLite-only Lab (No Docker):**
  ```text
  https://raw.githubusercontent.com/anandnandagiri/polystudio-samples/main/lab-manifest.sqlite.json
  ```

---

## No Docker? Import the SQLite-only pack

The Chinook SQLite database is a single file, so it works with no Docker, no
ports and no firewall rules:

1. **Connectors -> Import Lab Pack** and pick this folder.
2. When the modal offers a manifest choice, select **`lab-manifest.sqlite.json`**.
3. **Allow & import** - a `Sample SQLite (Chinook)` connector pointing at a
   copy of the pack (kept in the app's data root) and a small
   "Evaluation Lab (SQLite)" dashboard are created.

Or skip the import entirely: point a new SQLite connector at
`packs/chinook-sqlite/Chinook_Sqlite.sqlite` by hand (SHA-256 sums are in
`packs/chinook-sqlite/SHA256SUMS.txt`).

---

## Manual setup (no import)

Everything the manifest ships is public on purpose - this is a throwaway lab.
You can wire it all by hand in a few minutes:

### The SSH tunnel

| Field | Value |
|---|---|
| Label | `Lab SSH (poly-lab-ssh)` |
| Host | `127.0.0.1` |
| Port | `2222` |
| Username | `root` |
| Password | `PolyDemo123!` |

### The connectors (all through the tunnel above)

| Label | Kind | Host (inside Docker network) | Port | Database | Username | Password |
|---|---|---|---|---|---|---|
| `Lab PostgreSQL (Chinook)` | Postgres | `postgres` | 5432 | `chinook` | `poly` | `poly` |
| `Lab PostgreSQL (Sakila)` | Postgres | `postgres-sakila` | 5432 | `sakila` | `poly` | `poly` |
| `Lab MySQL (Sakila)` | MySQL | `mysql` | 3306 | `sakila` | `root` | `poly` |
| `Lab MariaDB (Sakila)` | MariaDB | `mariadb` | 3306 | `sakila` | `root` | `poly` |
| `Lab SQL Server (Chinook)` | SQL Server | `sqlserver` | 1433 | `Chinook` | `sa` | `PolyDemo123!` |

The `Test` button in Poly Studio should light up each one once the lab is up.

### Running the lab on a remote host (Raspberry Pi)

The lab and Poly Studio can run on different machines - the SSH tunnel makes
this transparent. The exact commands and security notes are in
[docs/REMOTE_HOST.md](docs/REMOTE_HOST.md).

---

## Repository layout

```
polystudio-samples/
├── compose/
│   └── polystudio-lab.yml         # the whole lab (databases + SSH sidecar)
├── packs/                         # official sample datasets (container-safe)
│   ├── chinook-sqlite/            #   incl. SHA256SUMS.txt
│   ├── chinook-postgres/
│   ├── chinook-mysql/
│   ├── chinook-sqlserver/
│   ├── sakila-mysql/
│   └── sakila-postgres/
├── lab-manifest.json              # what "Import Lab Pack" wires into Poly Studio
├── lab-manifest.sqlite.json       # the no-Docker variant of the same idea
└── docs/
    ├── REMOTE_HOST.md             # running the lab on a remote host / Raspberry Pi
    └── TROUBLESHOOTING.md
```

The `packs/` scripts are the upstream SQL with container-hostile statements
(`CREATE DATABASE`, `\c`, the SQL Server drop-guard) removed so the
`/docker-entrypoint-initdb.d` loader can run them. The datasets themselves are
unmodified.

---

## Security notes

This is a throwaway lab on your own machine, but a few things are worth
knowing:

- The SSH port is published on **`127.0.0.1` only** - it is not reachable
  from your LAN.
- The credentials are deliberately weak (`root` / `PolyDemo123!`) so they are
  easy to see in a demo. **Do not reuse them anywhere.**
- The sidecar mounts `/var/run/docker.sock`, which is effectively root on
  your Docker host. That is what makes Docker Studio show the real
  containers. It is the same trick CI runners use.
- The databases are **not** published to the host, so nothing listens on
  5432 / 3306 / 1433 outside the Docker network.
- The import flow never opens a network port and never runs local commands -
  it only writes Poly Studio's own configuration, with passwords encrypted by
  the app.

> **Do not put real production credentials into the evaluation lab.** The lab
> credentials are published in this README on purpose so a demo is
> reproducible. The point of the lab is the *shape* of a real environment, not
> real secrets.

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) - it covers the lab
containers as well as the import flow (manifest not found, license caps, a lab
that is not up yet).

---

## Licence and attribution

The sample datasets belong to their respective authors and are redistributed
under their own licences:

- **Chinook** - [lerocha/chinook-database](https://github.com/lerocha/chinook-database), MIT
- **Sakila** - originally by MySQL AB / Oracle, redistributed by
  [sakiladb](https://github.com/sakiladb) under BSD-2-Clause

The lab definition in this repository is provided as-is for evaluating Poly
Studio.