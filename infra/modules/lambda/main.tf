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


######## Configuring Lambda event source mapping
##### The following snippet configures the Lambda function to poll messages from the queue for processing.
# Create a policy with permissions required to poll messages from an SQS queue
resource "aws_iam_policy" "greeting_lambda_sqs_policy" {
  name        = "greeting_lambda_ssqs_policy"
  description = "Grants access to read messages from SQS"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = ["sqs:ReceiveMessage", "sqs:DeleteMEssage", "sqs:GetQueueAttributes"],
        Effect = "Allow",
        Resource = [aws_sqs_queue.greeting_queue.arn]
      }
    ]
  })
}

# Attach the policy to Lambda execution role created previously
resource "aws_iam_role_policy_attachment" "greeting_lambda_sqs_policy_attachment" {
  policy_arn = aws_iam_policy.greeting_lambda_sqs_policy.arn
  role       = aws_iam_role.lambda_execution_role.name
}

# Create a Lambda event-source mapping to enable Lambda to poll from the queue
resource "aws_lambda_event_source_mapping" "greeting_sqs_mapping" {
  event_source_arn = aws_sqs_queue.greeting_queue.arn
  function_name    = aws_lambda_function.greeting_lambda.function_name
  batch_size       = 1

  depends_on = [aws_iam_role_policy_attachment.greeting_lambda_sqs_policy_attachment ]
}
