################################################################################
# IRSA demo: an S3 bucket + an IAM role that ONLY one Kubernetes ServiceAccount
# can assume. Written by hand (no module) so you can see every piece of IRSA.
#
# Flow: pod -> projected SA token (JWT signed by the cluster's OIDC issuer)
#       -> sts:AssumeRoleWithWebIdentity -> trust policy checks "sub" and "aud"
#       -> temporary credentials -> s3:GetObject
################################################################################

data "aws_caller_identity" "current" {}

locals {
  bucket_name = "${var.name}-demo-${data.aws_caller_identity.current.account_id}"
  role_name   = "${var.name}-demo-s3-reader"
}

resource "aws_s3_bucket" "demo" {
  bucket        = local.bucket_name
  force_destroy = true # lab only
  tags          = var.tags
}

resource "aws_s3_bucket_public_access_block" "demo" {
  bucket                  = aws_s3_bucket.demo.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_object" "hello" {
  bucket  = aws_s3_bucket.demo.id
  key     = "hello.txt"
  content = "Hello from S3 -- if you can read this from the pod, IRSA works.\n"
}

# --- Trust policy: WHO can assume the role ---------------------------------
data "aws_iam_policy_document" "trust" {
  statement {
    actions = ["sts:AssumeRoleWithWebIdentity"]

    principals {
      type        = "Federated"
      identifiers = [var.oidc_provider_arn]
    }

    # Only this exact namespace + service account
    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:sub"
      values   = ["system:serviceaccount:${var.namespace}:${var.service_account}"]
    }

    condition {
      test     = "StringEquals"
      variable = "${var.oidc_provider}:aud"
      values   = ["sts.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "s3_reader" {
  name               = local.role_name
  assume_role_policy = data.aws_iam_policy_document.trust.json
  tags               = var.tags
}

# --- Permissions policy: WHAT the role can do (least privilege) -------------
data "aws_iam_policy_document" "s3_read" {
  statement {
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.demo.arn]
  }

  statement {
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.demo.arn}/*"]
  }
}

resource "aws_iam_role_policy" "s3_read" {
  name   = "s3-read-demo-bucket"
  role   = aws_iam_role.s3_reader.id
  policy = data.aws_iam_policy_document.s3_read.json
}
