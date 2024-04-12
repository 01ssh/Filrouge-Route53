
data   "vault_generic_secret" "aws_environment" {
  namespace      = length(regexall("_",  var.ENV_WORKSPACE))>0?split("_", var.ENV_WORKSPACE)[2]:var.ENV_WORKSPACE
  path           = lower("secret/aws/environment")
}

locals {
    namespace    = length(regexall("_",  var.ENV_WORKSPACE))>0?split("_", var.ENV_WORKSPACE)[2]:var.ENV_WORKSPACE
    env          = jsondecode(data.vault_generic_secret.aws_environment.data_json)
}

locals {
  hosts_domain   = [
        for hostname in local.env["hosts_domain"]: join(".", [hostname, local.namespace, local.env["domain"]])
    ]
}

data "aws_eks_cluster" "cluster" {
    name = "CLUSTER-WORDPRESS-${local.namespace}"
}

data "aws_eks_cluster_auth" "cluster" {
    name = data.aws_eks_cluster.cluster.name
}

provider "kubernetes" {
    host                   = data.aws_eks_cluster.cluster.endpoint
    cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
    token                  = data.aws_eks_cluster_auth.cluster.token
}

data "kubernetes_ingress_v1" "ingress_alb" {
   metadata {
    name = "aws-wordpress-web"
    namespace = local.namespace
  }
}

data "aws_lb" "ingress_alb" {
 name = substr(split(".", data.kubernetes_ingress_v1.ingress_alb.status.0.load_balancer.0.ingress.0.hostname)[0], 0, 32)
}

data "aws_route53_zone" "domain" {
  name            = local.env["domain"]
  private_zone    = false
}


resource "aws_route53_record" "ingress_alb" {
  count   = length(local.env["hosts_domain"])
  zone_id = data.aws_route53_zone.domain.zone_id
  name    = local.hosts_domain[count.index]
  type    = "A"

  alias {
    name                    = data.kubernetes_ingress_v1.ingress_alb.status.0.load_balancer.0.ingress.0.hostname
    zone_id                 = data.aws_lb.ingress_alb.zone_id
    evaluate_target_health  = false
  }
}

module "acm" {
  source  = "terraform-aws-modules/acm/aws"
  version = "~> 4.0"

  domain_name  = "${local.namespace}.${local.env["domain"]}"
  zone_id      = data.aws_route53_zone.domain.zone_id

  validation_method   = "DNS"

  subject_alternative_names = [ for host in local.env["hosts_domain"]: join(".", [host, local.namespace, local.env["domain"]]) ]

  wait_for_validation = true

  tags = {
    Name = local.env["domain"]
  }
}

provider "kubectl" {
  host                   = data.aws_eks_cluster.cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cluster.certificate_authority.0.data)
  token                  = data.aws_eks_cluster_auth.cluster.token
  load_config_file       = false
}

resource "kubectl_manifest" "ingress" {
    yaml_body = <<YAML
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: aws-wordpress-web
  labels:
    app: aws-wordpress-web
  namespace: ${local.namespace}
  annotations: 
    kubernetes.io/ingress.class: "alb"
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/healthcheck-protocol: HTTP 
    alb.ingress.kubernetes.io/healthcheck-port: traffic-port
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/actions.ssl-redirect: '{"Type": "redirect", "RedirectConfig": { "Protocol": "HTTPS", "Port": "443", "StatusCode": "HTTP_301"}}'
    alb.ingress.kubernetes.io/group: aws-wordpress-web
    alb.ingress.kubernetes.io/ssl-redirect: '443'
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}, {"HTTP":80}]'
    alb.ingress.kubernetes.io/certificate-arn: ${module.acm.acm_certificate_arn}
spec:
  rules:
%{ for hostname in local.env["hosts_domain"] }
    - host: ${hostname}.${local.namespace}.${local.env["domain"]}
    - http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: aws-wordpress-web
                port:
                  number: 80
%{ endfor }
YAML
}