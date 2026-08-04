module "naming" {
  source        = "../../modules/naming"
  resource_type = "aws_s3_bucket"
  project       = "shopfront"
  environment   = "dev"
}

module "labels" {
  source      = "../../modules/labels"
  project     = "shopfront"
  environment = "dev"
  criticality = "high"
  service     = "storefront"
  owner       = "platform@example.com"
  cost_center = "eng-1201"
}

resource "aws_s3_bucket" "assets" {
  bucket = module.naming.name
  tags   = module.labels.tags
}
