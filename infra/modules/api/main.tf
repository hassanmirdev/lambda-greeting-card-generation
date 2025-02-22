########### SETTINg up Amazon Api gateway ########


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

