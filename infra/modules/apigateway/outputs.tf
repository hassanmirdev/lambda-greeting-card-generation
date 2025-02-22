# Output the API Gateway invocation endpoint
output "greeting_api_endpoint" {
  value = "${aws_api_gateway_deployment.greeting_api_deployment.invoke_url}/greet"
}
# Output the REST API ID
output "greeting_api_rest_api_id" {
  value = aws_api_gateway_rest_api.greeting_api.id
}

# Output the Resource ID for the greet resource
output "greeting_api_resource_id" {
  value = aws_api_gateway_resource.greet_resource.id
}

# Output the Method HTTP Method
output "greeting_api_method_http" {
  value = aws_api_gateway_method.greet_method.http_method
}

# If you want to output the Lambda invoke URI (used in integration)
output "greeting_lambda_invoke_arn" {
  value = aws_lambda_function.greeting_lambda.invoke_arn
}
