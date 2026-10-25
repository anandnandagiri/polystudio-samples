# Running the lab on a remote host (Raspberry Pi or any other server)

The README quick start is the **same-machine** path: the lab and Poly Studio
run together on one desktop, where `127.0.0.1:2222`, the license's localhost
scope and the x64 SQL Server image all line up by themselves.

This document is the **lab-over-there** path - for example a Raspberry Pi 4/5
sitting on your home LAN with Poly Studio running on your desktop. It uses
only what the repository already ships.

## What runs where

| Component | Machine | Notes |
|---|---|---|
| 5 database containers + `lab-ssh` sidecar | the lab host (e.g. the Pi) | started with Docker |
| Poly Studio (desktop app) | your workstation | imports `lab-manifest.json` and holds its own config |
| Lab SSH port `2222` | lab host -> your LAN | published so Poly Studio can reach the sidecar |

The trick is that Poly Studio only ever talks to the lab host's SSH port.
Everything else (database hostnames, the Docker socket) lives behind the
tunnel on the lab host.

> **SQL Server note:** `mcr.microsoft.com/mssql/server` (SQL Server 2022) is
> **x64-only**. On an ARM64 lab host (Raspberry Pi, most SBCs) start the
> arm64 subset instead - every other service has an arm64 image. Skip the
> SQL Server steps below; when importing, Poly Studio skips the SQL Server
> connector and card automatically on non-x64 machines.

## Step 1 - The host (e.g. the Pi)

Install Docker and clone:

```bash
curl -fsSL https://get.docker.com | sh       # installs engine + compose plugin
git clone https://github.com/VAapps/polystudio-samples.git
cd polystudio-samples
```

Publish the lab SSH beyond loopback and start the services (arm64 subset):

```bash
# expose the sidecar so Poly Studio on another machine can reach it
sed -i 's/"127.0.0.1:2222:22"/"2222:22"/' compose/polystudio-lab.yml

docker compose -f compose/polystudio-lab.yml up -d lab-ssh postgres postgres-sakila mysql mariadb
docker compose -f compose/polystudio-lab.yml logs -f
```

On an **x64** remote host you can start the full stack
(`docker compose -f compose/polystudio-lab.yml up -d`), SQL Server included -
publishing the port applies in both cases.

You are done when `lab-ssh` printed
`lab-ssh ready (root / PolyDemo123!) - TCP forwarding enabled` and the
database services show `Up` (`healthy`).

## Step 2 - Verify from the workstation

Find the host's LAN address on the host (`hostname -I`), then from the machine
Poly Studio runs on:

```powershell
Test-NetConnection 192.168.1.201 -Port 2222   # Windows
```
```bash
nc -vz 192.168.1.201 2222                     # Linux / macOS
```

## Step 3 - Wire Poly Studio (on the workstation)

1. **Connectors -> Import Lab Pack**, pick the cloned folder, **Allow & import**.
   The tunnel is created pointing at the lab host `127.0.0.1` - wrong host for
   this mode, which the next step fixes.
2. **Connectivity -> SSH Tunnels -> Lab SSH (poly-lab-ssh)** and change the
   **Host** to the lab host's LAN IP (e.g. `192.168.1.201`) -> **Save -> Test**.
   (Alternatively change `"host": "127.0.0.1"` in `lab-manifest.json`
   *before* importing; then no UI edit is needed.)
3. Use **Test** on every `Lab ...` connector. The connector hosts (`postgres`,
   `mysql`, ...) never change - they resolve inside the Docker network on the
   lab host, behind the tunnel.

Because the import and the app live on your workstation, Poly Studio's
configuration (including its encrypted passwords and the license scope) never
leaves the workstation - only the SSH connection goes to the lab host.

## What runs where, at a glance

| Aspect | Same machine | Remote host (this guide) |
|---|---|---|
| `up` command | full stack (`up -d`) | arm64 subset or full stack on the host |
| Lab SSH port binding | `127.0.0.1:2222:22` (loopback) | `2222:22` (LAN) |
| SSH tunnel host in Poly Studio | `127.0.0.1` | the lab host's LAN IP |
| SQL Server + its card | works | x64 hosts only |
| Import picker | the cloned folder | the cloned folder (on the workstation) |

## Security notes for the remote-host mode

Publishing the SSH port changes the threat model. This lab ships credentials
that are **deliberately weak and public** (`root` / `PolyDemo123!`), so:

| Rule | Why |
|---|---|
| Home / private LAN only (`2222:22`) | Anyone on the network who can reach port 2222 owns the lab |
| Shared or office LAN | Do not publish. Restore `"127.0.0.1:2222:22"` and run Poly Studio on the lab host itself |
| Restrict even on a home LAN, if you prefer | `sudo ufw allow from 192.168.1.0/24 to any port 2222 proto tcp comment 'polystudio-lab'` |
| `/var/run/docker.sock` in the sidecar | Root-equivalent on the lab host - same warning as the README |
| Production credentials | Never. The lab is reproducible exactly because its secrets are disposable |

## Tear down

```bash
cd ~/polystudio-samples
docker compose -f compose/polystudio-lab.yml down -v
```

On the workstation, delete `Lab ...` connectors and the `Lab SSH
(poly-lab-ssh)` tunnel in Poly Studio (or nothing - they are harmless rows,
and a re-import replaces them anyway).