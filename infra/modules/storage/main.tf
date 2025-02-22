# Bucket 1: create source bucket, This bucket is used for storing the source images for employees

resource "aws_s3_bucket" "src_bucket" {
  bucket = var.src_bucket_name
  tags = {
    environment = var.tag_environment
  }

}

# ensures that bucket cannot be accessed without proper permissions.

resource "aws_s3_bucket_ownership_controls" "src_bucket_ownership_controls" {
  bucket = aws_s3_bucket.src_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

# Ensures that the bucket is private.

resource "aws_s3_bucket_acl" "src_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.src_bucket_ownership_controls]
  bucket = aws_s3_bucket.src_bucket.id
  acl    = "private"
}

# Bucket 2: create destination bucket, This bucket will be used to store the generated greeting cards.

resource "aws_s3_bucket" "dst_bucket" {
bucket = var.dst_bucket_name

  tags = {
    environment = var.tag_environment
  }

}
# ensures that bucket cannot be accessed without proper permissions.

resource "aws_s3_bucket_ownership_controls" "dst_bucket_ownership_controls" {
  bucket = aws_s3_bucket.dst_bucket.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}
# Ensures that the bucket is private.

resource "aws_s3_bucket_acl" "dst_bucket_acl" {
  depends_on = [aws_s3_bucket_ownership_controls.dst_bucket_ownership_controls]
  bucket = aws_s3_bucket.dst_bucket.id
  acl    = "private"
}
