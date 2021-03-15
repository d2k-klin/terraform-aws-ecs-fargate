terraform {
  backend "s3" {
    bucket = "terraform-davor-10.03"
    key    = "tf.state"
    region = "eu-central-1"
  }
}
