terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 2.0" //3.0.1
    }
  }
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

resource "time_sleep" "wait_50_seconds" {
  depends_on = [docker_container.mongodb]

  create_duration = "50s"
}

resource "docker_container" "did-verifier-silo" {
  image = "portkeydid/did-server-silo:mainnet-latest"
  name  = "did-verifier-silo"

  depends_on = [time_sleep.wait_50_seconds]

  # ports {
  #   internal = 80
  #   external = 8002 //debug what ports are used by DID-verifier
  # }
}

resource "docker_container" "did-verifier-api" {
  image = "portkeydid/did-server-api:mainnet-latest"
  name  = "did-verifier-api"

  depends_on = [docker_container.did-verifier-silo]

  ports {
    internal = 4200
    external = 4200 //debug what ports are used by DID-verifier
  }
}

resource "docker_container" "nginx" {
  image = docker_image.nginx.image_id
  name  = "ngnix"

  ports {
    internal = 80
    external = 8000
  }
}
