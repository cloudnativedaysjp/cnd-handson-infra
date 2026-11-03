# 親ゾーンが委譲しているのは以前から使っているゾーン。state にあった空のゾーンは委譲されていない
import {
  to = aws_route53_zone.delegated
  id = "Z080738624DO48AUL6TRM"
}

# 空のゾーンは消さずに state から外す。失敗した ACME の TXT が残っていると削除に失敗するため
removed {
  from = aws_route53_zone.handson
  lifecycle {
    destroy = false
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
