provider "helm" {
  kubernetes {
    config_path = var.config_path
  }
}
provider "kubernetes" {
  config_path = var.config_path
  experiments {
    manifest_resource = true
  }
}

variable "config_path" {
  description = "This is simply to create dependency, actual value is not used"
  type        = string
  default     = "~/.kube/config"
}

variable "helm_depends_on" {
  description = "This is simply to create dependency, actual value is not used"
  type        = string
  default     = ""
}




/** 
* helm-tekton
*/

variable "kubernetes_namespace_tkn" {
  description = "Namespace of the kubernetes resource"
  type        = string
  default     = "tekton-pipelines"
}

variable "kubernetes_name_tkn" {
  description = "Name of the kubernetes resource."
  type        = string
  default     = "tekton"
}


resource "kubernetes_namespace" "tekton" {
  depends_on = [var.helm_depends_on]
  metadata {
    name = var.kubernetes_namespace_tkn

    labels = {
      name = var.kubernetes_name_tkn
    }
  }
}

resource "helm_release" "tekton" {
  name       = var.kubernetes_name_tkn
  namespace  = var.kubernetes_namespace_tkn
  repository = "./tekton"
  chart      = ""
  depends_on = [var.helm_depends_on]
}

/** 
* helm-tekton-resources
*/

resource "helm_release" "tekton-resources" {
  name       = "tekton-resources"
  namespace  = var.kubernetes_namespace_tkn
  repository = "./tekton-resources"
  chart      = ""
  depends_on = [var.helm_depends_on, helm_release.tekton ]
}

/** 
* helm-tekton-resources-pipelines
*/

resource "helm_release" "tekton-resources-pipelines" {
  name       = "tekton-resource-pipelines"
  namespace  = var.kubernetes_namespace_tkn
  repository = "./tekton-resources-pipelines"
  chart      = ""
  depends_on = [var.helm_depends_on, helm_release.tekton,  helm_release.tekton-resources]
}

/** 
* helm-tekton-resources-pipelines-runs
*/

resource "helm_release" "tekton-resources-pipelines-runs" {
  name       = "tekton-resource-pipelines-runs"
  namespace  = var.kubernetes_namespace_tkn
  repository = "./tekton-resources-pipelines-runs"
  chart      = ""
  depends_on = [var.helm_depends_on, helm_release.tekton, helm_release.tekton-resources , helm_release.tekton-resources-pipelines ]
}


# /**
# * Run job to watch for Kibana to come online
# */
# resource "kubernetes_job" "iskibanaupjob" {
#   metadata {
#     name      = "job-with-wait"
#     namespace = "monitor-secops"
#   }
#   spec {
#     completions = 1
#     template {
#       metadata {}
#       spec {
#         service_account_name            = "default"
#         automount_service_account_token = true
#         container {
#           name    = "iskibanaup"
#           image   = "curlimages/curl:latest" #"busybox:latest"
#           command = ["/bin/sh", "-c", "while [[ \"$(curl -sL -o /dev/null --insecure -w ''%%{http_code}'' https://kibana-secops-kb-http.monitor-secops.svc.cluster.local:5601)\" != \"200\" ]]; do sleep 5; done"]
#         }
#         restart_policy = "Never"
#       }
#     }
#   }
#   wait_for_completion = true
#   timeouts {
#     create = "1200s"
#   }
#   depends_on = [var.helm_depends_on, kubernetes_namespace.monitor-secops, helm_release.elastic-operator, helm_release.elastic-instances]
# }

# resource "kubernetes_job" "import-dashboard" {
#   metadata {
#     name      = "import-dashboard"
#     namespace = "monitor-secops"
#     labels = {
#       "app.orgname.io/eai" = "3690963"
#     }
#   }
#   spec {
#     completions = 1
#     template {
#       metadata {}
#       spec {
#         service_account_name            = "default"
#         automount_service_account_token = true
#         container {
#           name    = "import-dashboard"
#           image   = "curlimages/curl:latest" #"busybox:latest"
#           command = ["/bin/sh", "-c", /* "while [[ \"$(curl -sL -o /dev/null --insecure -w ''%%{http_code}'' https://kibana-secops-kb-http.monitor-secops.svc.cluster.local:5601)\" != \"200\" ]]; do sleep 5; done", */ "cd /import && curl --user secmin:secureAccess --insecure -X POST https://kibana-secops-kb-http.monitor-secops.svc.cluster.local:5601/api/saved_objects/_import?createNewCopies=true -H \"kbn-xsrf: true\" --form file=@dashboard.ndjson"]
#           volume_mount {
#             name       = "cacert"
#             mount_path = "/srccode/cacert"
#             read_only  = true
#           }
#           volume_mount {
#             name       = "dashboard"
#             mount_path = "/import"
#             read_only  = true
#           }
#         }
#         volume {
#           name = "cacert"
#           secret {
#             secret_name = "es-secops-es-http-certs-public"
#           }
#         }
#         volume {
#           name = "dashboard"
#           config_map {
#             name = "dashboard"
#           }
#         }
#         restart_policy = "Never"
#       }
#     }
#   }
#   #}
#   wait_for_completion = true
#   timeouts {
#     create = "1200s"
#   }
#   depends_on = [var.helm_depends_on, kubernetes_namespace.monitor-secops, helm_release.elastic-operator, helm_release.elastic-instances, kubernetes_job.iskibanaupjob]
# }


# /**
# * Post deployment jobs to complete dashboard and load data.
# */

# resource "helm_release" "elastic-post-deploy-jobs" {
#   name       = "elastic-post-deploy-jobs"
#   namespace  = var.kubernetes_namespace_esi
#   repository = "./elastic-post-deploy-jobs"
#   # version    = var.kubernetes_chart_version_eso
#   chart      = ""
#   depends_on = [var.helm_depends_on, kubernetes_namespace.monitor-secops, helm_release.elastic-operator, kubernetes_job.iskibanaupjob]
# }


/**
* Deploy Trow for internal registry
*/
resource "helm_release" "trow" {
  name       = "trow"
  namespace  = "kube-public"
  repository = "https://trow.io"
  version = "0.3.3"
  chart      = "trow" #"trow-0.3.3"
  depends_on = [var.helm_depends_on]

  # [values](https://github.com/ContainerSolutions/trow/blob/main/docs/HELM_INSTALL.md)
  set {
    name = "trow.domain"
    value = "trow.kube-public.svc.cluster.local"
  }

  set {
    name = "service.type"
    value = "ClusterIP"
  }
}
