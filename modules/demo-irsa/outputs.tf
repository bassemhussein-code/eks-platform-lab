output "bucket_name" {
  value = aws_s3_bucket.demo.bucket
}

output "role_arn" {
  value = aws_iam_role.s3_reader.arn
}
