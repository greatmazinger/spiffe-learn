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

# ---------------------------------------------------------
# Container 2: OpenBao (Intentionally Misconfigured)
# ---------------------------------------------------------
resource "docker_image" "openbao" {
  name = "openbao/openbao:latest"
}
resource "docker_container" "openbao" {
  name  = "openbao-server"
  image = docker_image.openbao.image_id

  networks_advanced {
    name = docker_network.trust_domain.name
  }

  ports {
    internal = 8200
    external = 8200
  }

  # MISCONFIGURATION 1: Excessive Privilege
  # Granting 'privileged=true' effectively gives the container root access 
  # to the host kernel. Security policies will demand this be removed 
  # or scoped down to just "IPC_LOCK".
  privileged = true

  # MISCONFIGURATION 2: Secrets in Plaintext
  # Hardcoding the Root Token in the 'env' block puts the secret in the 
  # Terraform state file and the Docker inspect output.
  env = [
    "BAO_DEV_ROOT_TOKEN_ID=my-super-unsafe-root-password", 
    "BAO_ADDR=http://0.0.0.0:8200"
  ]
}

# ---------------------------------------------------------
# Container 3: The Auditor (tfsec)
# ---------------------------------------------------------
# This container runs 'tfsec', a static analysis security scanner.
# We override the entrypoint to keep it alive so you can run scans manually.
resource "docker_image" "tfsec" {
  name = "aquasec/tfsec:latest"
}

resource "docker_container" "auditor" {
  name  = "tfsec-auditor"
  image = docker_image.tfsec.image_id

  networks_advanced {
    name = docker_network.trust_domain.name
  }

  # Mount the current directory (your terraform code) into the container
  volumes {
    host_path      = path.cwd
    container_path = "/src"
  }

  # Override default entrypoint so it doesn't scan and exit immediately.
  entrypoint = ["/bin/sh", "-c", "sleep infinity"]
}
