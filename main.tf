# Провайдери
terraform {
  required_providers {
    google = {
      source  = "hashicorp/google"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
    }
    helm = {
      source  = "hashicorp/helm"
    }
    kubectl = {
      source  = "gavinbunney/kubectl"
      version = ">= 1.14.0"
    }
  }
}

# Провайдер Google Cloud
provider "google" {
  project = "artful-bonito-436711-i7"
  region  = "us-central1"
}

# Провайдер Kubernetes
provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

# Провайдер Helm
provider "helm" {
  kubernetes {
    host                   = "https://${google_container_cluster.primary.endpoint}"
    token                  = data.google_client_config.default.access_token
    cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  }
}

# Провайдер kubectl
provider "kubectl" {
  host                   = google_container_cluster.primary.endpoint
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
  token                  = data.google_client_config.default.access_token
  load_config_file       = false
}

# Отримання даних про поточну конфігурацію Google Cloud
data "google_client_config" "default" {}

# Створення GKE кластера
resource "google_container_cluster" "primary" {
  name     = "my-gke-cluster"
  location = "us-central1-a"

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "my-node-pool"
  location   = "us-central1-a"
  cluster    = google_container_cluster.primary.name
  node_count = 3

  node_config {
    preemptible  = true
    machine_type = "e2-medium"
  }
}

# ConfigMap для App1
resource "kubernetes_config_map" "app1_html" {
  metadata {
    name = "app1-html"
  }

  data = {
    "index.html" = <<-EOF
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to App 1</title>
        <style>
            body {
                font-family: Arial, sans-serif;
                background: linear-gradient(120deg, #84fab0 0%, #8fd3f4 100%);
                height: 100vh;
                margin: 0;
                display: flex;
                justify-content: center;
                align-items: center;
            }
            .container {
                background-color: rgba(255, 255, 255, 0.8);
                padding: 2rem;
                border-radius: 10px;
                box-shadow: 0 4px 6px rgba(0, 0, 0, 0.1);
                text-align: center;
            }
            h1 {
                color: #333;
                margin-bottom: 1rem;
            }
            p {
                color: #666;
                line-height: 1.6;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Welcome to App 1!</h1>
            <p>This is page served by Nginx in Kubernetes.</p>
        </div>
    </body>
    </html>
    EOF
  }
}

# ConfigMap для App2
resource "kubernetes_config_map" "app2_html" {
  metadata {
    name = "app2-html"
  }

  data = {
    "index.html" = <<-EOF
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Welcome to App 2</title>
        <style>
            body {
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                background: linear-gradient(120deg, #f093fb 0%, #f5576c 100%);
                height: 100vh;
                margin: 0;
                display: flex;
                justify-content: center;
                align-items: center;
            }
            .container {
                background-color: rgba(255, 255, 255, 0.9);
                padding: 2rem;
                border-radius: 15px;
                box-shadow: 0 8px 32px rgba(0, 0, 0, 0.1);
                text-align: center;
            }
            h1 {
                color: #333;
                margin-bottom: 1rem;
                font-size: 2.5rem;
            }
            p {
                color: #555;
                line-height: 1.8;
                font-size: 1.1rem;
            }
        </style>
    </head>
    <body>
        <div class="container">
            <h1>Welcome to App 2!</h1>
            <p>This is page served by Nginx in Kubernetes.</p>
        </div>
    </body>
    </html>
    EOF
  }
}

# Deployment для App1
resource "kubernetes_deployment" "app1" {
  metadata {
    name = "app1"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "app1"
      }
    }

    template {
      metadata {
        labels = {
          app = "app1"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "app1"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "html-content"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html-content"
          config_map {
            name = kubernetes_config_map.app1_html.metadata[0].name
          }
        }
      }
    }
  }
}

# Deployment для App2
resource "kubernetes_deployment" "app2" {
  metadata {
    name = "app2"
  }

  spec {
    replicas = 2

    selector {
      match_labels = {
        app = "app2"
      }
    }

    template {
      metadata {
        labels = {
          app = "app2"
        }
      }

      spec {
        container {
          image = "nginx:latest"
          name  = "app2"

          port {
            container_port = 80
          }

          volume_mount {
            name       = "html-content"
            mount_path = "/usr/share/nginx/html"
          }
        }

        volume {
          name = "html-content"
          config_map {
            name = kubernetes_config_map.app2_html.metadata[0].name
          }
        }
      }
    }
  }
}

# Service для App1
resource "kubernetes_service" "app1" {
  metadata {
    name = "app1"
  }

  spec {
    selector = {
      app = kubernetes_deployment.app1.metadata[0].name
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

# Service для App2
resource "kubernetes_service" "app2" {
  metadata {
    name = "app2"
  }

  spec {
    selector = {
      app = kubernetes_deployment.app2.metadata[0].name
    }

    port {
      port        = 80
      target_port = 80
    }

    type = "ClusterIP"
  }
}

# Встановлення NGINX Ingress Controller
resource "helm_release" "nginx_ingress" {
  name       = "nginx-ingress"
  repository = "https://kubernetes.github.io/ingress-nginx"
  chart      = "ingress-nginx"
  namespace  = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.type"
    value = "LoadBalancer"
  }
  set {
    name  = "controller.ingressClassResource.name"
    value = "nginx"
  }
  set {
    name  = "controller.ingressClassResource.enabled"
    value = "true"
  }
  set {
    name  = "controller.ingressClassResource.default"
    value = "true"
  }
  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }
  set {
    name  = "controller.metrics.serviceMonitor.enabled"
    value = "true"
  }
  set {
    name  = "controller.metrics.serviceMonitor.additionalLabels.release"
    value = "prometheus"
  }
}

# Встановлення cert-manager
resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"
  create_namespace = true

  set {
    name  = "installCRDs"
    value = "true"
  }
}

# Створення ClusterIssuer для Let's Encrypt
resource "kubectl_manifest" "cluster_issuer" {
  yaml_body = <<YAML
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: alazze91@gmail.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
YAML

  depends_on = [helm_release.cert_manager]
}

# Налаштування Ingress
resource "kubernetes_ingress_v1" "example_ingress" {
  metadata {
    name = "example-ingress"
    annotations = {
      "kubernetes.io/ingress.class" = "nginx"
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "nginx.ingress.kubernetes.io/ssl-redirect" = "true"
      "nginx.ingress.kubernetes.io/rewrite-target" = "/$2"
    }
  }

  spec {
    tls {
      hosts       = ["stassorokolat.fun", "www.stassorokolat.fun"]
      secret_name = "stassorokolat-tls"
    }
    rule {
      host = "stassorokolat.fun"
      http {
        path {
          path = "/app1(/|$)(.*)"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app1.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/app2(/|$)(.*)"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app2.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }

    rule {
      host = "www.stassorokolat.fun"
      http {
        path {
          path = "/app1(/|$)(.*)"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app1.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
        path {
          path = "/app2(/|$)(.*)"
          path_type = "Prefix"
          backend {
            service {
              name = kubernetes_service.app2.metadata[0].name
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }

  depends_on = [helm_release.nginx_ingress, kubectl_manifest.cluster_issuer]
}

# Налаштування Prometheus для моніторингу
resource "helm_release" "prometheus" {
  name       = "prometheus"
  repository = "https://prometheus-community.github.io/helm-charts"
  chart      = "kube-prometheus-stack"
  namespace  = "monitoring"
  create_namespace = true

  set {
    name  = "grafana.enabled"
    value = "true"
  }

  set {
    name  = "grafana.service.type"
    value = "LoadBalancer"
  }

  set {
    name  = "grafana.service.port"
    value = "80"
  }

  set {
    name  = "prometheus.service.type"
    value = "ClusterIP"
  }
}

# Виведення зовнішньої IP-адреси NGINX Ingress Controller
data "kubernetes_service" "nginx_ingress" {
  metadata {
    name = "nginx-ingress-ingress-nginx-controller"
    namespace = "ingress-nginx"
  }
  depends_on = [helm_release.nginx_ingress]
}

output "load_balancer_ip" {
  value = data.kubernetes_service.nginx_ingress.status[0].load_balancer[0].ingress[0].ip
}

# Виведення пароля Grafana
output "prometheus_grafana_password" {
  value = nonsensitive(data.kubernetes_secret.grafana.data["admin-password"])
  description = "Grafana admin password"
}

data "kubernetes_secret" "grafana" {
  metadata {
    name      = "prometheus-grafana"
    namespace = "monitoring"
  }
  depends_on = [helm_release.prometheus]
}

# Виведення IP-адреси Grafana
data "kubernetes_service" "grafana" {
  metadata {
    name      = "prometheus-grafana"
    namespace = "monitoring"
  }
  depends_on = [helm_release.prometheus]
}

output "grafana_ip" {
  value = data.kubernetes_service.grafana.status[0].load_balancer[0].ingress[0].ip
}
