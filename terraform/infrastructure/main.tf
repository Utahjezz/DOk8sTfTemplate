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
  version = "1.14.1-do.4"

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

resource "kubernetes_service_account" "tiller" {
  metadata {
    name      = "tiller"
    namespace = "kube-system"
  }

  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "tiller" {
  metadata {
    name = "tiller"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "cluster-admin"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "tiller"
    api_group = ""
    namespace = "kube-system"
  }
}

resource "kubernetes_role" "tiller-user" {
  metadata {
    name      = "tiller-user"
    namespace = "kube-system"
  }

  rule {
    api_groups = [""]
    resources  = ["pods/portforward"]
    verbs      = ["create"]
  }

  rule {
    api_groups = [""]
    resources  = ["pods"]
    verbs      = ["list"]
  }
}

resource "kubernetes_cluster_role_binding" "tiller-user" {
  metadata {
    name = "tiller-user-binding"
  }

  role_ref {
    kind      = "ClusterRole"
    name      = "tiller-user"
    api_group = "rbac.authorization.k8s.io"
  }

  subject {
    kind      = "ServiceAccount"
    name      = "helm"
    namespace = "kube-system"
  }
}

provider "helm" {
    version                         = "~> 0.9"
    enable_tls                      = false
    install_tiller                  = true
    tiller_image                    = "gcr.io/kubernetes-helm/tiller:v2.14.0"
    service_account                 = "tiller"
    automount_service_account_token = true

    kubernetes {
        config_path = local_file.kubeconfig.filename
    }
}