#############IAM Roles and policies for Lambda function ######
# Execution role

resource "aws_iam_role" "lambda_execution_role" {
  name = "terraform-lambda-greetings-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Effect = "Allow",
        Sid    = ""
      }
    ]
  })
}

# Access policy
resource "aws_iam_policy" "lambda_s3_access_policy" {
  name        = "terraform-lambda-s3-access-policy"
  description = "Grants access to source and destination buckets"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = ["s3:GetObject"],
        Effect   = "Allow",
        Resource = [
          "${aws_s3_bucket.src_bucket.arn}/*"
        ]
      },{
        Action   = ["s3:PutObject"],
        Effect   = "Allow",
        Resource = [
          "${aws_s3_bucket.dst_bucket.arn}/*"
        ]
      }
    ]
  })
}

# Attaches the policy to the role
resource "aws_iam_role_policy_attachment" "s3_full_access_attachment" {
  policy_arn = aws_iam_policy.lambda_s3_access_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

############ create lambda dunction #######

# Create a zip file with function code
data "archive_file" "lambda_zip" {
  type        = "zip"
  source_file = "index.mjs"
  output_path = "lambda.zip"
}

# Create a Lambda function
resource "aws_lambda_function" "greeting_lambda" {
  function_name = "greetings-lambda-function"

  handler     = "index.handler"
  runtime     = "nodejs18.x"
  memory_size = 256
  role        = aws_iam_role.lambda_execution_role.arn

  environment {
    variables = {
      SRC_BUCKET = aws_s3_bucket.src_bucket.id,
      DST_BUCKET = aws_s3_bucket.dst_bucket.id
    }
  }

  filename         = data.archive_file.lambda_zip.output_path
  source_code_hash = data.archive_file.lambda_zip.output_base64sha256
}
