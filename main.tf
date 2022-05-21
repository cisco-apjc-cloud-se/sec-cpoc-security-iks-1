terraform {
  backend "remote" {
    hostname = "app.terraform.io"
    organization = "mel-ciscolabs-com"
    workspaces {
      name = "sec-cpoc-security-iks-1"
    }
  }
  required_providers {
    helm = {
      source = "hashicorp/helm"
    }
    kubernetes = {
      source = "hashicorp/kubernetes"
    }
  }
}

### Remote State - Import Kube Config ###
data "terraform_remote_state" "iks-1" {
  backend = "remote"

  config = {
    organization = "mel-ciscolabs-com"
    workspaces = {
      name = "iks-cpoc-syd-demo-1"
    }
  }
}

### Decode Kube Config ###
# Assumes kube_config is passed as b64 encoded
locals {
  kube_config = yamldecode(base64decode(data.terraform_remote_state.iks-1.outputs.kube_config))
}

### Providers ###
provider "kubernetes" {
  # alias = "iks-k8s"
  host                   = local.kube_config.clusters[0].cluster.server
  cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
  client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
  client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
}

provider "helm" {
  kubernetes {
    host                   = local.kube_config.clusters[0].cluster.server
    cluster_ca_certificate = base64decode(local.kube_config.clusters[0].cluster.certificate-authority-data)
    client_certificate     = base64decode(local.kube_config.users[0].user.client-certificate-data)
    client_key             = base64decode(local.kube_config.users[0].user.client-key-data)
  }
}

### Kubernetes Security Services ###

module "security" {
  source = "github.com/cisco-apjc-cloud-se/terraform-helm-security"

  ### Secure Cloud Analytics ###
  sca = {
    enabled = true
    kubernetes = {
      namespace     = "sca"
    }
    helm = {
      release_name  = "sca"
      service_key   = var.sca_service_key   # Passed from Workspace Variable
      chart_url     = var.sca_chart_url     # Passed from Workspace Variable
    }
  }
}
