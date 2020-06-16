variable "region" {
    type = string
    default = "eu-west-2"
}

provider "aws" {
  region = var.region
  # region  = "eu-west-2"
  version = "~>2.66.0"
}

resource "aws_iam_role" "iam_for_lambda" {
  name = "iam_for_lambda"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": [
          "lambda.amazonaws.com",
          "apigateway.amazonaws.com"
        ]
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

resource "aws_lambda_function" "express_lambda_test" {
  filename      = "express-lambda-test.zip"
  function_name = "express_lambda_test"
  role          = aws_iam_role.iam_for_lambda.arn
  handler       = "src/index.handler"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("express-lambda-test.zip")

  runtime = "nodejs12.x"

  # environment {
  #   variables = {
  #     foo = "bar"
  #   }
  # }
}

resource "aws_api_gateway_rest_api" "gateway_rest_api" {
  name        = "express-lambda-test-rest-api"
  description = "express lambda test rest api"
}

resource "aws_api_gateway_resource" "proxy" {
   rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
   parent_id   = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
   path_part   = "{proxy+}"
}

resource "aws_api_gateway_method" "proxy" {
   rest_api_id   = aws_api_gateway_rest_api.gateway_rest_api.id
   resource_id   = aws_api_gateway_resource.proxy.id
   http_method   = "ANY"
   authorization = "NONE"
}

resource "aws_api_gateway_integration" "lambda" {
   rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
   resource_id = aws_api_gateway_method.proxy.resource_id
   http_method = aws_api_gateway_method.proxy.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.express_lambda_test.invoke_arn
 }

resource "aws_api_gateway_integration" "lambda_root" {
   rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
   resource_id = aws_api_gateway_method.proxy_root.resource_id
   http_method = aws_api_gateway_method.proxy_root.http_method

   integration_http_method = "POST"
   type                    = "AWS_PROXY"
   uri                     = aws_lambda_function.express_lambda_test.invoke_arn
}

resource "aws_api_gateway_method" "proxy_root" {
   rest_api_id   = aws_api_gateway_rest_api.gateway_rest_api.id
   resource_id   = aws_api_gateway_rest_api.gateway_rest_api.root_resource_id
   http_method   = "ANY"
   authorization = "NONE"
}


resource "aws_api_gateway_deployment" "express_lambda_test" {
   depends_on = [
     aws_api_gateway_integration.lambda,
     aws_api_gateway_integration.lambda_root,
   ]

   rest_api_id = aws_api_gateway_rest_api.gateway_rest_api.id
   stage_name  = "test"
}

resource "aws_lambda_permission" "lambda_permission" {
  statement_id  = "AllowMyDemoAPIInvoke"
  action        = "lambda:InvokeFunction"
  function_name = "express_lambda_test"
  principal     = "apigateway.amazonaws.com"

  # The /*/*/* part allows invocation from any stage, method and resource path
  # within API Gateway REST API.
  source_arn = "${aws_api_gateway_rest_api.gateway_rest_api.execution_arn}/*/*/*"
}

output "test_url" {
  value = "https://${aws_api_gateway_deployment.express_lambda_test.rest_api_id}.execute-api.${var.region}.amazonaws.com/${aws_api_gateway_deployment.express_lambda_test.stage_name}"
}