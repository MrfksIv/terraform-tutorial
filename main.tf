provider "aws" {
  shared_credentials_file = "~/.aws/credentials"
  profile = "own"
  region = "eu-west-1"
}

resource "aws_instance" "test" {
  ami = "ami-0220a3a426e69bb5"
  instance_type = "t2.nano"
}
