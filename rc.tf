provider "kubernetes" {
  config_context_cluster   = "minikube"
}

resource "kubernetes_replication_controller" "rc" {
  metadata {
    name = "rcweb1"
    }

spec {
    replicas = 3
    selector = {
      env: "dev"
      dc: "US"
    }
    template {
      metadata {
        labels = {
          env: "dev"
          dc: "US"
        }
        annotations = {
          "key1" = "value1"
        }
      }

      spec {
        container {
          image = "vimal13/apache-webserver-php"
          name  = "mycon1"
        }
      }
    }
  }
}
