provider "kubernetes" {
  config_path = "~/.kube/config"
}

# ConfigMap scrapyd-config
resource "kubernetes_config_map_v1" "scrapyd_config" {
  metadata {
    name      = "scrapyd-config"
    namespace = "scrapyd"
  }

  data = {
    WEB_DRIVER_URL = "http://webdriver-svc.scrapyd.svc.cluster.local:4444"
  }
}

# Secret scrapyd-secret
resource "kubernetes_secret" "scrapyd_secret" {
  metadata {
    name      = "scrapyd-secret"
    namespace = "scrapyd"
  }

  type = "Opaque"

  # string_data = {
  #   DEEPSEEK_TOKEN = "******************************"
  # }

  data = {
    DEEPSEEK_TOKEN = base64encode("******************************")
  }
}

# ConfigMap scrapyd-cache-selectors
resource "kubernetes_config_map" "scrapyd_cache_selectors" {
  metadata {
    name      = "scrapyd-cache-selectors"
    namespace = "scrapyd"
  }

  data = {
    "732b46cdef66b68ee2fbc940e79f81de.json" = jsonencode({ link_selectors = "h3.loop-card__title > a" })
    "89726dd24a4d78041c65af3b4a364b31.json" = jsonencode({ link_selectors = "a.post-card__figure-link" })
    "bc002b453215c04fa081a97f2c6679b9.json" = jsonencode({ link_selectors = "a.story-link" })
  }
}

# Deployment webdriver
resource "kubernetes_deployment" "webdriver" {
  metadata {
    name      = "webdriver"
    namespace = "scrapyd"
    labels = {
      app = "webdriver"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "webdriver"
      }
    }

    template {
      metadata {
        labels = {
          app = "webdriver"
        }
      }

      spec {
        container {
          name  = "webdriver"
          image = "selenium/standalone-chromium:latest"

          port {
            container_port = 4444
          }

          port {
            container_port = 7900
          }

          resources {
            limits = {
              memory = "2Gi"
              cpu    = "1"
            }

            requests = {
              memory = "1Gi"
              cpu    = "500m"
            }
          }

          volume_mount {
            name       = "dshm"
            mount_path = "/dev/shm"
          }
        }

        volume {
          name = "dshm"

          empty_dir {
            medium    = "Memory"
            size_limit = "2Gi"
          }
        }
      }
    }
  }
}

# Service webdriver
resource "kubernetes_service" "webdriver_svc" {
  metadata {
    name      = "webdriver-svc"
    namespace = "scrapyd"
    labels = {
      app = "webdriver"
    }
  }

  spec {
    selector = {
      app = "webdriver"
    }

    port {
      name       = "web"
      port       = 4444
      target_port = 4444
      protocol   = "TCP"
    }

    port {
      name       = "vnc"
      port       = 7900
      target_port = 7900
      protocol   = "TCP"
    }

    type = "ClusterIP"
  }
}

# Deployment scrapyd
resource "kubernetes_deployment" "scrapyd" {
  metadata {
    name      = "scrapyd"
    namespace = "scrapyd"
    labels = {
      app = "scrapyd"
    }
  }

  spec {
    replicas = 1

    selector {
      match_labels = {
        app = "scrapyd"
      }
    }

    template {
      metadata {
        labels = {
          app = "scrapyd"
        }
      }

      spec {
        image_pull_secrets {
          name = "ghcr-secret"
        }

        container {
          name  = "scrapyd"
          image = "ghcr.io/atlabyte/scrapy-parsers:latest"
          image_pull_policy = "Always"
          working_dir      = "/var/lib/scrapyd/app/"

          port {
            container_port = 6800
          }

          env {
            name = "WEB_DRIVER_URL"
            value_from {
              config_map_key_ref {
                name = kubernetes_config_map.scrapyd_config.metadata[0].name
                key  = "WEB_DRIVER_URL"
              }
            }
          }

          env {
            name = "DEEPSEEK_TOKEN"
            value_from {
              secret_key_ref {
                name = kubernetes_secret.scrapyd_secret.metadata[0].name
                key  = "DEEPSEEK_TOKEN"
              }
            }
          }

          volume_mount {
            name       = "cache-selector-volume"
            mount_path = "/var/lib/scrapyd/app/cache/"
          }
        }

        volume {
          name = "cache-selector-volume"
          config_map {
            name = kubernetes_config_map.scrapyd_cache_selectors.metadata[0].name
          }
        }
      }
    }
  }
}

# Service scrapyd
resource "kubernetes_service" "scrapyd_svc" {
  metadata {
    name      = "scrapyd-svc"
    namespace = "scrapyd"
  }

  spec {
    selector = {
      app = "scrapyd"
    }

    port {
      port        = 6800
      target_port = 6800
      protocol    = "TCP"
    }

    type = "ClusterIP"
  }
}