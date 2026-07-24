module "cdn" {
  source  = "terraform-aws-modules/cloudfront/aws"
  version = "6.7.0"

  create              = var.create_cdn
  price_class         = var.cloudfront_price_class
  retain_on_delete    = false
  wait_for_deployment = false

  vpc_origin = var.create_cdn ? {
    alb = {
      arn                    = module.alb_ecs.arn
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols = {
        items    = ["TLSv1.2"]
        quantity = 1
      }
    }
  } : null

  origin = var.create_cdn ? {
    alb_cdn = {
      domain_name = module.alb_ecs.dns_name
      vpc_origin_config = {
        vpc_origin_key = "alb"
      }
    }
  } : {}

  default_cache_behavior = {
    target_origin_id       = "alb_cdn"
    viewer_protocol_policy = "redirect-to-https"

    allowed_methods = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods  = ["GET", "HEAD"]
    compress        = true

    use_forwarded_values = true
    query_string         = true
    headers              = ["*"]
    cookies_forward      = "all"

    min_ttl     = 0
    default_ttl = 0
    max_ttl     = 0
  }

  restrictions = {
    geo_restriction = {
      restriction_type = length(var.cloudfront_geo_restriction_locations) == 0 ? "none" : "whitelist"
      locations        = var.cloudfront_geo_restriction_locations
    }
  }

  tags = local.tags
}
