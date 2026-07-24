module "cdn" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "~> 6.0"

  create              = var.create_cdn
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    alb_cdn = {
      domain_name = module.alb_ecs.dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1.2"]
      }

      custom_header = {
        "X-Frame-Options" = var.custom_header
      }
    }
  }

  default_cache_behavior = {
    target_origin_id       = "alb_cdn"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = false

    use_forwarded_values = true
    query_string         = true
    cookies_forward      = "none"
  }

  restrictions = {
    geo_restriction = {
      restriction_type = "whitelist"
      locations        = ["DE"]
    }
  }

  tags = local.tags
}
