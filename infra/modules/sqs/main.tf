############## create amazon sqs queue ####

resource "aws_sqs_queue" "greeting_queue" {
  name                    = "greetings_queue"
  sqs_managed_sse_enabled = true
}



