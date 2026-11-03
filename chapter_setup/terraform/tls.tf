provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "acme_account" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P256"
}

resource "acme_registration" "handson" {
  account_key_pem = tls_private_key.acme_account.private_key_pem
}

# Let's Encrypt の発行上限は同じ登録ドメインで週 50 枚。1 VM に 1 枚へまとめる
# サブドメインは 1 段にそろえる前提なので、ワイルドカードは 1 つで足りる (cnd-handson#594)
resource "acme_certificate" "vm" {
  count = var.num_students

  account_key_pem = acme_registration.handson.account_key_pem
  key_type        = "P256"
  common_name     = "*.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"

  dns_challenge {
    provider = "route53"
    # the aws provider's region does not reach the solver, and STS for dynamic credentials needs one
    config = {
      AWS_HOSTED_ZONE_ID = aws_route53_zone.handson.zone_id
      AWS_REGION         = var.region
    }
  }
}
