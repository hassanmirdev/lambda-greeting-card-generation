########### Setting up Amazon Api gateway ########

##### Configuring API Gateway
## The following snippet configures the API Gateway to send requests as messages to an SQS queue, instead of sending directly to a Lambda function.

# Create an IAM Role for API Gateway
resource "aws_iam_role" "api_gateway_greeting_queue_role" {
  name = "api_gateway_greeting_queue_role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action = "sts:AssumeRole",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Effect = "Allow"
        Sid    = ""
      }
    ]
  })
}

# Create a policy allowing API Gateway to send messages to the SQS queue
resource "aws_iam_role_policy" "api_gateway_greeting_queue_role_policy" {
  name = "api_gateway_greeting_queue_role_policy"
  role = aws_iam_role.api_gateway_greeting_queue_role.name

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Action   = "sqs:SendMessage",
        Effect   = "Allow",
        Resource = aws_sqs_queue.greeting_queue.arn
      }
    ]
  })
}

data "aws_region" "current" {}
data "aws_caller_identity" "current" {}

# Create an integration that sends incoming request body as a message to SQS
resource "aws_api_gateway_integration" "greet_method_integration" {
  rest_api_id             = aws_api_gateway_rest_api.greeting_api.id
  resource_id             = aws_api_gateway_resource.greet_resource.id
  http_method             = aws_api_gateway_method.greet_method.http_method
  type                    = "AWS"
  integration_http_method = "POST"
  uri                     = "arn:aws:apigateway:${data.aws_region.current.name}:sqs:path/${data.aws_caller_identity.current.account_id}/${aws_sqs_queue.greeting_queue.name}"
  request_parameters = {
    "integration.request.header.Content-Type" = "'application/x-www-form-urlencoded'"
  }
  request_templates = {
    "application/json" = "Action=SendMessage&MessageBody=$input.body"
  }
  credentials = aws_iam_role.api_gateway_greeting_queue_role.arn
}

resource "aws_api_gateway_integration_response" "integration_response_200" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  resource_id = aws_api_gateway_resource.greet_resource.id
  http_method = aws_api_gateway_method.greet_method.http_method
  status_code = 200
  selection_pattern = "^2[0-9][0-9]" # Any 2xx response

  response_templates = {
    "application/json" = "{\"status\": \"success\"}"
  }

  depends_on = [aws_api_gateway_integration.greet_method_integration]
}

resource "aws_api_gateway_method_response" "method_response_200" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  resource_id = aws_api_gateway_resource.greet_resource.id
  http_method = aws_api_gateway_method.greet_method.http_method
  status_code = 200

  response_models = {
    "application/json" = "Empty"
  }
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

# Create a REST API Gateway
resource "aws_api_gateway_rest_api" "greeting_api" {
  name        = "greeting_api"
  description = "API for invoking the Greeting Lambda Function"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

# Create an API Resource
resource "aws_api_gateway_resource" "greet_resource" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  parent_id   = aws_api_gateway_rest_api.greeting_api.root_resource_id
  path_part   = "greet"
}

# Create an API Method
resource "aws_api_gateway_method" "greet_method" {
  rest_api_id   = aws_api_gateway_rest_api.greeting_api.id
  resource_id   = aws_api_gateway_resource.greet_resource.id
  http_method   = "POST"
  authorization = "NONE"
}

# Grant API Gateway permissions to invoke the Lambda function
resource "aws_lambda_permission" "allow_api_gateway" {
  statement_id  = "AllowAPIGatewayInvoke"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.greeting_lambda.function_name
  principal     = "apigateway.amazonaws.com"

  # This will only allow a specific API resource and method to invoke the Lambda function. 
  # Otherwise any API Gateway in the account will be able to invoke the Lambda function. 
  # This is required for adhering to least privileged access principle
  source_arn = "${aws_api_gateway_rest_api.greeting_api.execution_arn}/*/${aws_api_gateway_method.greet_method.http_method}${aws_api_gateway_resource.greet_resource.path}"
}

# Integrate API Gateway with the Lambda function
resource "aws_api_gateway_integration" "greet_lambda_integration" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  resource_id = aws_api_gateway_resource.greet_resource.id
  http_method = aws_api_gateway_method.greet_method.http_method

  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.greeting_lambda.invoke_arn

  depends_on = [aws_lambda_permission.allow_api_gateway]
}

# Create a new API Gateway deployment 
resource "aws_api_gateway_deployment" "greeting_api_deployment" {
  rest_api_id = aws_api_gateway_rest_api.greeting_api.id
  stage_name  = "prod"

  triggers = {
    redeployment = sha256(jsonencode(aws_api_gateway_rest_api.greeting_api.body))
  }

  lifecycle {
    create_before_destroy = true
  }
  depends_on = [
                aws_api_gateway_method.greet_method,
                aws_api_gateway_integration.greet_lambda_integration                
                ]
}

