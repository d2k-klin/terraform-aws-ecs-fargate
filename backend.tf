terraform {
  backend "s3" {
    bucket = "my-terraform-backend-store-20210315"
    key    = "tf.state"
    region = "eu-central-1"
  }
}
