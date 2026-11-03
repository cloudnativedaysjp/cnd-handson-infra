# 親ゾーンが委譲しているのは以前から使っているゾーン。state にあった空のゾーンは委譲されていない
import {
  to = aws_route53_zone.delegated
  id = "Z080738624DO48AUL6TRM"
}

# 委譲されていない空のゾーンは消す。中身は SOA と NS だけ
removed {
  from = aws_route53_zone.handson
  lifecycle {
    destroy = true
  }
}

resource "aws_route53_zone" "delegated" {
  name = "handson.cloudnativedays.jp"
}

resource "aws_route53_record" "wildcard_records" {
  count = local.num_vms

  zone_id = aws_route53_zone.delegated.zone_id
  name    = "*.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]

  # the adopted zone still has unmanaged records from earlier events
  allow_overwrite = true
}

# kp2 を開く名前。*.vmXX は apex に一致しない
resource "aws_route53_record" "apex_records" {
  count = local.num_vms

  zone_id = aws_route53_zone.delegated.zone_id
  name    = "vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  type    = "A"
  ttl     = 300
  records = [aws_instance.ubuntu_instance[count.index].public_ip]
}
