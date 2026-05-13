resource "aws_route53_zone" "handson" {
  name = "handson.cloudnativedays.jp"
}
resource "aws_route53_record" "wildcard_records" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "*.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}

resource "aws_route53_record" "argocd_wildcard_records" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "*.argocd.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}

resource "aws_route53_record" "kustomize_argocd_wildcard_records" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "*.kustomize.argocd.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}

resource "aws_route53_record" "cilium_wildcard_records" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "*.cilium.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}

resource "aws_route53_record" "cicd_wildcard_records" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "*.cicd.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}
