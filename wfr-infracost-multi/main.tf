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
    tls    = { source = "hashicorp/tls",    version = "~> 4.0" }
    null   = { source = "hashicorp/null",   version = "~> 3.0" }
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

# ── the utility half of TC-303 ────────────────────────────────────────────────────────────────
# The case names these three by name, and the distinction it draws is precise: `Service` must be
# BLANK for them, not a capitalised version of their prefix. Anything outside the known provider
# list falls through to nothing, so a new cloud provider reads blank until somebody adds it —
# which is the behaviour the case guards.
#
# ⚠️ `random_pet` was here first and did NOT work: Infracost reported `totalDetectedResources: 0`
# for it — it is not merely unpriced, it is not detected at all, so it never reaches the table.
# These three are the ones the case asks for; whether they surface is measured, not assumed.
resource "random_password" "secret" {
  length = 24
}

resource "tls_private_key" "key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

resource "null_resource" "noop" {
  triggers = { always = "static" }
}
