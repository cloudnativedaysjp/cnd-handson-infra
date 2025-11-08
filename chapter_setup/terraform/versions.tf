terraform {
  cloud {
    organization = "cloudnativedaysjp"

    workspaces {
      name = "cnd-handson-infra"
    }
  }
}
