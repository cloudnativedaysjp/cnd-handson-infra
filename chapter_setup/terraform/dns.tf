resource "aws_route53_zone" "handson" {
  name = "handson.cloudnativedays.jp"
}

resource "aws_route53_record" "www" {
  count = length(aws_instance.ubuntu_instance)

  zone_id = aws_route53_zone.handson.zone_id
  name    = "www.vm0${count.index + 1}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}
