# 以前のイベントで作られ、管理外のまま残った *.vm01〜*.vm45。取り込んで次の PR で消す
locals {
  stale_vms = toset([for i in range(1, 46) : format("%02d", i)])
}

import {
  for_each = local.stale_vms
  to       = aws_route53_record.stale[each.key]
  id       = "Z080738624DO48AUL6TRM_*.vm${each.key}.handson.cloudnativedays.jp_A"
}

resource "aws_route53_record" "stale" {
  for_each = local.stale_vms
  zone_id  = aws_route53_zone.delegated.zone_id
  name     = "*.vm${each.key}.handson.cloudnativedays.jp"
  type     = "A"
  ttl      = 300
  records  = ["192.0.2.1"] # 消すだけなので値は使わない
  lifecycle {
    ignore_changes = [records]
  }
}
