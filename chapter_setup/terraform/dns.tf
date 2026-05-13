resource "aws_route53_zone" "handson" {
  name = "handson.cloudnativedays.jp"
}
locals {
  host_subdomains = [
    "hello-world",
    "rollout",
    "blue",
    "green",
    "app",
    "cnd-web",
    "prometheus",
    "grafana",
    "jaeger",
    "argocd",
    "app.argocd",
    "dev.kustomize.argocd",
    "prd.kustomize.argocd",
    "helm.argocd",
    "app-preview.argocd",
    "kiali",
    "kiali-ambient",
    "app.cilium",
    "hubble.cilium",
    "pyroscope",
    "app.cicd",
  ]

  dns_records = {
    for pair in flatten([
      for i in range(var.num_students) : [
        for host in local.host_subdomains : {
          key = "${host}.vm${format("%02d", i + 1)}"
          idx = i
        }
      ]
    ]) : pair.key => pair
  }
}

resource "aws_route53_record" "host_records" {
  for_each = local.dns_records

  zone_id = aws_route53_zone.handson.zone_id
  name    = "${each.key}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[each.value.idx].public_ip]
}
