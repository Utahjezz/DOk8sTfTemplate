terraform {
  required_version = ">= 0.12.0"
}

variable "do_token" {}

variable "cluster_name" {
    default = "test1"
}


provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_kubernetes_cluster" "k8s_cluster" {
  name = var.cluster_name
  region = "fra1"
  version = "1.18.8-do.1"

  node_pool {
    name       = "main-pool"
    size       = "s-1vcpu-2gb"
    node_count = 1
  }
}

provider "kubernetes" {
  host = "${digitalocean_kubernetes_cluster.k8s_cluster.endpoint}"

  client_certificate     = "${base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config.0.client_certificate)}"
  client_key             = "${base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config.0.client_key)}"
  cluster_ca_certificate = "${base64decode(digitalocean_kubernetes_cluster.k8s_cluster.kube_config.0.cluster_ca_certificate)}"
}


resource "local_file" "kubeconfig" {
    content     = digitalocean_kubernetes_cluster.k8s_cluster.kube_config.0.raw_config
    filename = "${path.module}/kubeconfig"
}