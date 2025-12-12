terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0"
    }
  }
}

provider "docker" {}

resource "docker_network" "trust_domain" {
  name = "spiffe-trust-domain"
}

# --- SPIRE SERVER ---
resource "docker_image" "spire_server" {
  name = "ghcr.io/spiffe/spire-server:1.8.0"
}

resource "docker_container" "spire_server" {
  name  = "spire-server"
  image = docker_image.spire_server.image_id
  networks_advanced { name = docker_network.trust_domain.name }
  ports {
    internal = 8081
    external = 8081
  }
  command = ["-config", "/opt/spire/conf/server/server.conf"]
  volumes {
    host_path      = "${path.cwd}/config/spire-server.conf"
    container_path = "/opt/spire/conf/server/server.conf"
  }
  # Share the socket so the Workload can access it (simulating Agent on host)
  volumes {
    host_path      = "${path.cwd}/sockets"
    container_path = "/tmp/spire-server/private"
  }
}

# --- OPENBAO (Secret Store) ---
resource "docker_image" "openbao" {
  name = "openbao/openbao:latest"
}

resource "docker_container" "openbao" {
  name  = "openbao-server"
  image = docker_image.openbao.image_id
  networks_advanced { name = docker_network.trust_domain.name }
  ports {
    internal = 8200
    external = 8200
  }
  env = [
    "BAO_DEV_ROOT_TOKEN_ID=root",
    "BAO_ADDR=http://0.0.0.0:8200",
    "BAO_DEV_LISTEN_ADDRESS=0.0.0.0:8200"
  ]
  capabilities { add = ["IPC_LOCK"] }
}

# --- WORKLOAD (Legacy App) ---
resource "docker_image" "workload" {
  name = "ubuntu:latest"
}

resource "docker_container" "workload" {
  name  = "backend-workload"
  image = docker_image.workload.image_id
  networks_advanced { name = docker_network.trust_domain.name }
  
  # Installs tools to interact with Spire/Bao
  entrypoint = ["/bin/sh", "-c"]
  command    = ["apt-get update && apt-get install -y curl jq && sleep infinity"]

  # Mount the SPIRE socket here so the workload can fetch its identity
  volumes {
    host_path      = "${path.cwd}/sockets"
    container_path = "/tmp/spire-server/private"
  }
}
