variable "bucket_name"    { type = string }
variable "environment"    { type = string }
variable "kms_key_alias"  { type = string }
variable "lifecycle_days" { type = number; default = 2555 }

resource "aws_kms_key" "recordings" {
  description             = "KMS key for telco recordings encryption"
  deletion_window_in_days = 30
  enable_key_rotation     = true
  tags                    = { Name = var.kms_key_alias }
}

resource "aws_kms_alias" "recordings" {
  name          = var.kms_key_alias
  target_key_id = aws_kms_key.recordings.key_id
}

resource "aws_s3_bucket" "recordings" {
  bucket        = var.bucket_name
  force_destroy = false
}

resource "aws_s3_bucket_versioning" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.recordings.arn
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "recordings" {
  bucket = aws_s3_bucket.recordings.id
  rule {
    id     = "tiered-storage"
    status = "Enabled"
    transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
    transition {
      days          = 90
      storage_class = "GLACIER_IR"
    }
    transition {
      days          = 365
      storage_class = "DEEP_ARCHIVE"
    }
    expiration {
      days = var.lifecycle_days
    }
  }
}

resource "aws_s3_bucket_public_access_block" "recordings" {
  bucket                  = aws_s3_bucket.recordings.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

output "bucket_name" { value = aws_s3_bucket.recordings.id }
output "kms_key_arn" { value = aws_kms_key.recordings.arn }
