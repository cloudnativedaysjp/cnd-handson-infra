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
resource "acme_certificate" "vm" {
  count = var.num_students

  account_key_pem = acme_registration.handson.account_key_pem
  key_type        = "P256"
  common_name     = "*.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  subject_alternative_names = [
    for sub in ["argocd", "kustomize.argocd", "cilium", "cicd"] :
    "*.${sub}.vm${format("%02d", count.index + 1)}.handson.cloudnativedays.jp"
  ]

  dns_challenge {
    provider = "route53"
    config = {
      AWS_HOSTED_ZONE_ID = aws_route53_zone.handson.zone_id
    }
  }
}
