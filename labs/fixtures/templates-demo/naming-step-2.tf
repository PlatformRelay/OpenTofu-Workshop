module "naming" {
  source        = "../../modules/naming"
  resource_type = "aws_s3_bucket"
  project       = "shopfront"
  environment   = "dev"
}

resource "aws_s3_bucket" "assets" {
  bucket = module.naming.name # s3-shopfront-d-...-a1f3
}
