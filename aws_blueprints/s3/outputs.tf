# Output para o ID (nome) do bucket S3
output "bucket_id" {
  description = "O ID (nome) do bucket S3."
  value       = aws_s3_bucket.example_bucket.id
}

# Output para o ARN (Amazon Resource Name) do bucket S3
output "bucket_arn" {
  description = "O ARN do bucket S3."
  value       = aws_s3_bucket.example_bucket.arn
}
