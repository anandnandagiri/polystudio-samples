# Troubleshooting the Poly Studio evaluation lab

## Quick checklist

```bash
# 1. Are all containers up?
docker compose -f compose/polystudio-lab.yml ps

# 2. Is the SSH port listening?
#    Windows:  Test-NetConnection 127.0.0.1 -Port 2222
#    Linux:    nc -zv 127.0.0.1 2222

# 3. What did the databases do while starting?
docker compose -f compose/polystudio-lab.yml logs postgres mysql mariadb sqlserver-init
```

---

## The lab will not start

### `compose file ... is invalid: open .../compose/polystudio-lab.yml: no such file or directory`

`docker compose -f compose/polystudio-lab.yml` resolves `-f` relative to your
**current directory**. Run every compose command from the cloned repo root,
not from your home folder:

```bash
cd ~/polystudio-samples
docker compose -f compose/polystudio-lab.yml up -d
docker compose -f compose/polystudio-lab.yml logs -f
```

(The relative bind-mount paths inside the file - `../packs/...` - resolve
against the compose file's own location, so the repo root is always the right
place to invoke it.)

### `no matching manifest for linux/arm64/v8` while pulling SQL Server

`mcr.microsoft.com/mssql/server` is **x64-only**, and one failed pull aborts
the whole `up` - even the images that already finished downloading. On a
Raspberry Pi (or any ARM64 host) start the arm64 subset instead; everything
except SQL Server has an arm64 image:

```bash
docker compose -f compose/polystudio-lab.yml up -d lab-ssh postgres postgres-sakila mysql mariadb
```

`sqlserver-init` never runs in that mode either (it depends on `sqlserver`).
When you import the pack, the app skips the SQL Server connector and card
automatically on non-x64 machines, so the dormant entries never appear.

### `Bind for 0.0.0.0:2222 failed: port is already allocated`

Another container already uses port 2222. Stop it, or change the host port in
`compose/polystudio-lab.yml`:

```yaml
  lab-ssh:
    ports:
      - "127.0.0.1:2223:22"    # changed
```

If you change it, re-run the import (it rewrites the tunnel) or edit the
tunnel in **Connectivity -> SSH Tunnels**.

### `port is already allocated` for 5432 / 3306 / 1433

The lab does **not** publish those ports, so this is a different container of
yours. It does not conflict with the lab - ignore it.

---

## The databases are still loading

The first `up -d` pulls several gigabytes of images and then loads the sample
data. The SQL Server step in particular takes a minute or two. Watch it:

```bash
docker compose -f compose/polystudio-lab.yml logs -f
```

You are done when every container is `Up` (or `healthy`) and
`poly-lab-sqlserver-init` has exited with code 0.

### `poly-lab-postgres-sakila` exited with code 3

Check its log:

```bash
docker logs poly-lab-postgres-sakila
```

The usual cause is a **stale volume** from an earlier run with different
credentials. Reset it:

```bash
docker compose -f compose/polystudio-lab.yml down -v
docker compose -f compose/polystudio-lab.yml up -d
```

### `poly-lab-sqlserver-init` exited with code 1

```bash
docker logs poly-lab-sqlserver-init
```

A common cause is that the `Chinook` database already exists from a previous
run. The fix is the same: `down -v`, then `up -d`.

---

## Poly Studio cannot connect to the lab

### The connectors fail with a connection timeout

The tunnel is not open, or the sidecar is not ready. Check:

```bash
# Can you reach sshd?
ssh -p 2222 root@127.0.0.1
# password: PolyDemo123!
```

If that prompt never appears, the sidecar is not up:

```bash
docker logs poly-lab-ssh
```

You should see `lab-ssh ready (root / PolyDemo123!) - TCP forwarding enabled`.

### The tunnel opens but every query fails

This is the **classic symptom of `AllowTcpForwarding no`**.

Alpine's `openssh` package ships with TCP forwarding disabled, so `sshd`
accepts the connection but silently drops every forwarded channel. The
symptom in Poly Studio is: the tunnel reports "connected", the connector
`Test` fails with a timeout or a stream error, but `ssh` itself works fine.

The compose file already fixes this by writing a fresh `sshd_config`. If you
ever see this symptom, check it inside the container:

```bash
docker exec poly-lab-ssh grep -i allowtcpforwarding /etc/ssh/sshd_config
# must print:  AllowTcpForwarding yes
```

### The lab runs on a different machine than Poly Studio

By default the sidecar publishes `127.0.0.1:2222` - the lab's SSH port is
reachable **only from the machine the lab itself runs on**. If Poly Studio
runs on your desktop and the lab on a server/Pi, publish the port
(`2222:22`) and point the tunnel host at the lab machine's LAN IP
(**Connectivity -> SSH Tunnels**). The connectors' database hosts
(`postgres`, `mysql`, ...) never change: they are resolved on the lab host,
behind the tunnel. See [REMOTE_HOST.md](REMOTE_HOST.md).

---

## Import Lab Pack

The import lives in Poly Studio itself (Connectors page). These are its
failure modes:

### "No lab-manifest.json found in the selected folder"

The picker needs the folder that **contains** the manifest (the repo root).
If you picked a subfolder such as `packs/`, go one or more levels up. The
files must be named `lab-manifest.json` (full lab) or `lab-manifest.sqlite.json`
(SQLite-only); both sit in the repo root.

### The preview warns "Lab sidecar not detected"

The lab is not up (or not finished starting) on `127.0.0.1:2222`. This is a
**warning, not a blocker** - you can import now and start the lab later; the
connectors simply stay dormant until the tunnel opens. To go live right away:

```bash
docker compose -f compose/polystudio-lab.yml up -d
```

…then press **Re-check** in the import modal.

### "License allows 2 connector(s); importing this pack needs 6"

That is a genuine Free-tier limit: the full pack needs Pro. Either upgrade,
or import `lab-manifest.sqlite.json` (one connector), or import the full pack
and create the remaining connectors after upgrading - the import replaces
existing lab rows, so re-running it later is safe.

### "The manifest references ... but that file was not found"

You picked a partial copy of the folder. The manifest ships its SQLite
pack (`packs/chinook-sqlite/Chinook_Sqlite.sqlite`) with it - import needs
that file present. The picker only reads files you select, so pick the whole
folder, not just the manifest file.

### The connectors appear but some are locked

Poly Studio's license system marks connectors beyond your tier's limit as
locked. That is expected on Free - the same thing would happen if you created
the connectors by hand. Upgrade to Pro to use all of them.

### The connectors fail with an auth error after a machine switch

Re-run the import on the machine you are using (Connectors -> Import Lab Pack,
pick the folder again). The app stores the passwords encrypted for the current
OS user; a re-import rewrites them in place, nothing else changes.

---

## Docker Studio shows no containers

Docker Studio talks to the Docker daemon **over SSH**, so it needs the
tunnel, not a local socket. Add the tunnel **Lab SSH (poly-lab-ssh)** as a
Docker host.

If the host connects but the container list is empty, the sidecar cannot
reach the Docker socket:

```bash
docker exec poly-lab-ssh docker ps
```

That should list the lab's containers. If it errors on the socket, check that
`/var/run/docker.sock` is mounted into `lab-ssh`.

---

## Starting over

### Remove the lab only (keep Poly Studio)

```bash
docker compose -f compose/polystudio-lab.yml down -v
```

The imported connectors/tunnel/page are harmless configuration rows - delete
them in the UI (`Connectors` -> each `Lab ...` entry,
`Connectivity -> SSH Tunnels`, Query Lab page) or simply re-import later; a
re-import replaces them.

### The import wrote something twice

It should not - the import replaces rows with the same names every time. If
you see duplicates, they are from hand-created rows with slightly different
names; delete the extras in the UI.