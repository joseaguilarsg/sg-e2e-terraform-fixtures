# Several PRICED resources in one plan, so a breakdown has more than one line to show.
#
# TC-044/045 (the cost table and its ordering) and TC-302/303 (a destroy's breakdown, and one
# mixing cloud with utility resources) all need a breakdown covering more than one resource.
# `wfr-infracost-priced` carries a single `aws_instance`, so every one of them is skipped today.
#
# ⚠️ **Nothing here is ever applied, and that is the point.** Infracost estimates from the PLAN,
# so a plan-only run produces the whole breakdown without creating a single resource. The fixture
# is free to keep and impossible to leave running by accident.
#
# The mix is deliberate:
#   · two instances of different sizes  → two priced lines, and an ordering to assert
#   · an EBS volume                     → a second resource TYPE, priced per GB-month
#   · a random_pet                      → a resource with NO price, which is what "mixing cloud
#                                         with utility resources" (TC-303) actually means

terraform {
  required_providers {
    aws    = { source = "hashicorp/aws", version = "~> 5.0" }
    random = { source = "hashicorp/random", version = "~> 3.0" }
  }
}

variable "region" {
  type    = string
  default = "eu-central-1"
}

provider "aws" {
  region = var.region
}

resource "aws_instance" "small" {
  ami           = "ami-0a261c0e5f51090b1"
  instance_type = "t3.small"

  tags = { Name = "sg-e2e-cost-small", Fixture = "wfr-infracost-multi" }
}

resource "aws_instance" "medium" {
  ami           = "ami-0a261c0e5f51090b1"
  instance_type = "t3.medium"

  tags = { Name = "sg-e2e-cost-medium", Fixture = "wfr-infracost-multi" }
}

resource "aws_ebs_volume" "data" {
  availability_zone = "${var.region}a"
  size              = 100
  type              = "gp3"

  tags = { Name = "sg-e2e-cost-volume", Fixture = "wfr-infracost-multi" }
}

# Priced at nothing — the utility half of TC-303.
resource "random_pet" "label" {
  length = 2
}
