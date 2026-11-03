# 委譲先のゾーンを特定するための一時的な確認用。plan の Outputs を見たら消す
data "aws_route53_zones" "all" {}

data "aws_route53_zone" "each" {
  for_each = toset(data.aws_route53_zones.all.ids)
  zone_id  = each.value
}

output "route53_zones" {
  value = {
    for id, z in data.aws_route53_zone.each : id => {
      name         = z.name
      name_servers = z.name_servers
      records      = z.resource_record_set_count
    }
  }
}

data "aws_route53_records" "delegated" {
  zone_id = "Z080738624DO48AUL6TRM"
}

output "delegated_zone_records" {
  value = [
    for r in data.aws_route53_records.delegated.resource_record_sets : {
      name    = r.name
      type    = r.type
      ttl     = r.ttl
      records = [for v in r.resource_records : v.value]
    }
  ]
}
