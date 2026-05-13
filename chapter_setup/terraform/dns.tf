resource "aws_route53_zone" "handson" {
  name = "handson.cloudnativedays.jp"
}

resource "aws_route53_record" "www" {
  count = var.num_students

  zone_id = aws_route53_zone.handson.zone_id
  name    = "www.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[var.num_students].public_ip]
}
