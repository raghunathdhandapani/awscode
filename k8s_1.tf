provider "kubernetes" {
  config_context_cluster   = "minikube"
}

resource "kubernetes_pod" "myk8spod" {
  metadata {
    name = "myk8swebpod"
  }

  spec {
    container {
      image = "vimal13/apache-webserver-php"
      name  = "web"
    }
  }
}
