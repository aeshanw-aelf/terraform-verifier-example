terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.0" //3.0.1
    }
  }
}

# Define an absolute path for the volume mount
locals {
  logs_volume_host_path = pathexpand("./did-verifier-silo/Logs")
}

provider "docker" {}
provider "time" {}

resource "docker_image" "nginx" {
  name         = "nginx"
  keep_locally = true
}

module "redis" {
  source  = "selftechio/redis/docker"
  version = "0.1.0"
}

# resource "docker_image" "redis" {
#   name         = "redis"
#   keep_locally = true
# }

resource "docker_image" "mongo" {
  name         = "mongo"
  keep_locally = true
}

resource "docker_container" "mongodb" {
  image = docker_image.mongo.image_id
  name  = "mongodb"

  ports {
    internal = 27017
    external = 27017
  }
}

# resource "docker_container" "redis" {
#   image = docker_image.redis.image_id
#   name  = "redis"

#   ports {
#     internal = var.internal_port
#     external = var.external_port
#     protocol = "tcp"
#     ip       = var.ip
#   }
# }

resource "time_sleep" "mongodb_wait_50_seconds" {
  depends_on = [docker_container.mongodb]

  create_duration = "50s"
}

# Define a Docker network
resource "docker_network" "verifier" {
  name = "verifier"
}

# Define a Docker container for did-verifier-silo
resource "docker_container" "did_verifier_silo" {
  name         = "did-verifier-silo"
  image        = "portkeydid/did-verifier-silo:mainnet-latest"
  restart      = "always"

  depends_on = [time_sleep.mongodb_wait_50_seconds]

  network_mode = docker_network.verifier.name

  ports {
    internal = 9010
    external = 9010
  }

  ports {
    internal = 10010
    external = 10010
  }

  ports {
    internal = 20010
    external = 20010
  }

  volumes {
    container_path = "/etc/localtime"
    host_path      = "/etc/localtime"
    read_only      = true
  }

  # TODO need to fix these paths
  volumes {
    container_path = "/app/appsettings.json"
    host_path      = pathexpand("~/did-verifier-silo/appsettings.json")
  }

  volumes {
    container_path = "/app/Logs"
    host_path      = local.logs_volume_host_path
  }

  privileged = true
}

# Define a Docker container for did-verifier-api
resource "docker_container" "did_verifier_api" {
  name         = "did-verifier-api"
  image        = "portkeydid/did-verifier-api:mainnet-latest"
  restart      = "always"

  network_mode = docker_network.verifier.name

  ports {
    internal = 8010
    external = 8010
  }

  volumes {
    container_path = "/etc/localtime"
    host_path      = "/etc/localtime"
    read_only      = true
  }

  # TODO need to fix these paths
  volumes {
    container_path = "/app/appsettings.json"
    host_path      = "./did-verifier-api/appsettings.json"
  }

  volumes {
    container_path = "/app/Logs"
    host_path      = "./did-verifier-api/Logs"
  }

  depends_on = [docker_container.did_verifier_silo]

  privileged = true
}


resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "ngnix"

  ports {
    internal = 80
    external = 8000
  }
}
