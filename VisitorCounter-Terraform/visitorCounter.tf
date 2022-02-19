provider "aws" {
  region = "us-east-1"
}

resource "aws_dynamodb_table" "basic-dynamodb-table" {
  name = "Counter1"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "id"

  attribute {
    name = "id"
    type = "S"
  }
}

resource "aws_api_gateway_rest_api" "counterapigw" {
  name = "test3-API"
  description = "VisitorCounter API Gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "product" {
  rest_api_id = aws_api_gateway_rest_api.counterapigw.id
  parent_id = aws_api_gateway_rest_api.counterapigw.root_resource_id
  path_part = "product"
}

resource "aws_api_gateway_method" "createCounter" {
  rest_api_id = aws_api_gateway_rest_api.counterapigw.id
  resource_id = aws_api_gateway_resource.product.id
  http_method = "POST"
  authorization = "NONE"
}

resource "aws_iam_role" "VisitorCounterLambdaRole" {
  name               = "VisitorCounterLambdaRole"
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF
}

data "template_file" "visitorcounterlambdapolicy" {
  template = "${file("${path.module}/policy.json")}"
}

resource "aws_iam_policy" "VisitorCounterPolicy" {
  name = "VisitorCounterPolicy"
  path = "/"
  description = "IAM policy for Visitor Counter lambda function"
  policy = data.template_file.visitorcounterlambdapolicy.rendered
}

resource "aws_iam_role_policy_attachment" "VisitorCounterRolePolicy" {
  role = aws_iam_role.VisitorCounterLambdaRole.name
  policy_arn = aws_iam_policy.VisitorCounterPolicy.arn
}

resource "aws_lambda_function" "CreateVisitorCounterHandler" {
  
  function_name = "test3"

  filename = "../lambda/visitorCounter.zip"

  handler = "visitorCounter.lambda_handler"
  runtime = "python3.8"

  environment {
    variables = {
      REGION = "us-east-1"
      PRODUCT_TABEL = aws_dynamodb_table.basic-dynamodb-table.name
    }
  }

  source_code_hash = filebase64sha256("../lambda/visitorCounter.zip")

  role = aws_iam_role.VisitorCounterLambdaRole.arn

  timeout = "100"
  memory_size = "128"
}

resource "aws_api_gateway_integration" "createvisitorCounter-lambda" {
  
  rest_api_id = aws_api_gateway_rest_api.counterapigw.id
    resource_id = aws_api_gateway_method.createCounter.resource_id
    http_method = aws_api_gateway_method.createCounter.http_method

    integration_http_method = "POST"
    type = "AWS_PROXY"

  uri = aws_lambda_function.CreateVisitorCounterHandler.invoke_arn
}

  resource "aws_lambda_permission" "apigw-CreateVisitorCounter" {
    
    action = "lambda:InvokeFunction"
    function_name = aws_lambda_function.CreateVisitorCounterHandler.function_name
    principal = "apigateway.amazonaws.com"

    source_arn = "${aws_api_gateway_rest_api.counterapigw.execution_arn}/*/POST/product"
  }

  resource "aws_api_gateway_deployment" "visitorcounterapistageprod" {
    depends_on = [
      aws_api_gateway_integration.createvisitorCounter-lambda
    ]

    rest_api_id = aws_api_gateway_rest_api.counterapigw.id
    stage_name = "prod"
  }
