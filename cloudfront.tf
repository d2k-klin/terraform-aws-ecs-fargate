module "cdn" {
  source = "github.com/terraform-aws-modules/terraform-aws-cloudfront.git?ref=v1.8.0"

  create_distribution = var.create_cdn
  price_class         = "PriceClass_All"
  retain_on_delete    = false
  wait_for_deployment = false

  origin = {
    alb_cdn = {
      domain_name = module.alb_ecs.this_lb_dns_name
      custom_origin_config = {
        http_port              = 80
        https_port             = 443
        origin_protocol_policy = "http-only"
        origin_ssl_protocols   = ["TLSv1"]
      }

    custom_header = [
        {
          name  = "X-Frame-Options"
          value = var.custom_header
        }
      ]
    }
  }

  default_cache_behavior = {
    target_origin_id       = "alb_cdn"
    viewer_protocol_policy = "allow-all"

    allowed_methods = ["GET", "HEAD", "OPTIONS"]
    cached_methods  = ["GET", "HEAD"]
    compress        = false
    query_string    = true
  }

  geo_restriction = {
    restriction_type = "whitelist"
    locations        = ["DE"]
  }

}