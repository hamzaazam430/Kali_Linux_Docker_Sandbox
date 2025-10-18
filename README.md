# Kali-in-Docker — README

A minimal README that explains how to build and run a Kali Linux container for safe pentesting, CTFs, learning Linux, or other security work. This repo contains a Docker Compose setup plus a script to install a curated set of Kali tools. Use it as a disposable environment or extend it into a fuller build.

---

# Requirements

* Docker Engine (desktop or server) - (Link: [Docker Engine](https://docs.docker.com/engine/install/))
* Docker Compose (v2 `docker compose` CLI) - (Link: [Docker Compose (v2)](https://docs.docker.com/compose/install/))
* OR You can just download Docker desktop - (Link: [Docker Desktop](https://docs.docker.com/desktop/))
* Basic familiarity with shell / Docker commands

---

# Purpose

Provide a safe, reproducible Kali Linux environment inside Docker for:

* Capture The Flag (CTF) practice
* Pentesting labs (non-production, legal targets only)
* Learning Linux and pentesting tools
* An easy-to-reset sandbox for experimentation

You can use the container as a minimal environment, or run the included installer script to pre-install a set of Kali tools.

---

# Quick start

## 1. Build the image

Run this to build without using any cached layers:

```bash
docker compose build --no-cache
```

## 2. Start the container (detached)

```bash
docker compose up -d
```

## 3. Access the Kali machine

```bash
docker compose exec kali bash
```

## 4. Stop the container

```bash
docker compose stop
```

---

# Installing Kali tools

There are two ways to run the included installer script.

### Option 1 — From outside (recommended if you want to automate)

Run the installer inside the already-running container from your host:

```bash
docker compose exec kali bash -lc "bash /home/sandbox/shared/install_kali_tools.sh"
```

### Option 2 — From inside the container

1. Enter the container:

```bash
docker compose exec kali bash
```

2. Run the installer:

```bash
bash shared/install_kali_tools.sh
```

> The installer script installs a curated set of extra tools. If you prefer a minimal environment, skip the script and install only what you need.

## Issue or Errors:

If you an issue like this:

```bash
$ ./install_kali_tools.sh
env: ‘bash\r’: No such file or directory
env: use -[v]S to pass options in shebang lines
```

Then install a tool `dos2unix` by running the command below:
```bash
$ sudo apt update && sudo apt install -y dos2unix
$ dos2unix shared/install_kali_tools.sh  # run with sudo if operation not permitted
```

Now run the script again:
```bash
bash shared/install_kali_tools.sh
```
---

# Persisting changes (important)

By default containers are ephemeral — changes made inside a container are lost if the container image is not rebuilt or data is not persisted. Choose one of the following methods to retain installed tools or data between runs:

### 1) Rebuild the image with tools baked in

* Modify the Dockerfile to run the install script (or `apt` installs) during `docker build`.
* Then `docker compose build --no-cache` and `docker compose up -d`.
  This makes the tools part of the image.

### 2) Commit a running container to a new image

1. Start and configure the container (install tools).
2. Find the container id:

```bash
docker ps
```

3. Commit it:

```bash
docker commit <container-id> my-kali-with-tools:latest
```

4. Update your compose file to use `my-kali-with-tools:latest` (or tag/push to a registry).

### 3) Use volumes for persistent directories

* Mount host directories into the container for home, workspace, or tool caches so important data survives container recreation.
  Example in `docker-compose.yml`:

```yaml
services:
  kali:
    ...
    volumes:
      - ./workspace:/home/sandbox/workspace
      - ./shared:/home/sandbox/shared
```

---

# Extra script / customization

* `shared/install_kali_tools.sh` — script included to install additional Kali tools.
* You may edit this script to add/remove packages you want preinstalled.
* If you want to require a password for the `sandbox` user or add extra users, implement that in the Dockerfile or run commands inside the container (and persist them using one of the methods above).

---

# Usage tips & troubleshooting

* If you installed tools but they disappear after stopping/starting the container, you likely recreated the container from the image. Use one of the "Persisting changes" methods above.
* To run a one-off shell (temporary container):

```bash
docker compose run --rm kali bash
```

* To see logs:

```bash
docker compose logs -f kali
```

* If you need networking for certain tools (e.g., to reach other VMs or the host), check Docker network settings and consider using `network_mode: "host"` (note: host mode reduces isolation).

---

# Safety & legal

Only use pentesting tools against systems and networks you own, manage, or have explicit permission to test. Unauthorized testing is illegal and its not encouraged