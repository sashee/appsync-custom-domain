provider "aws" {
}

resource "aws_iam_role" "appsync" {
  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "appsync.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF
}

resource "aws_appsync_graphql_api" "appsync" {
  name                = "appsync_test"
  schema              = file("schema.graphql")
  authentication_type = "API_KEY"
  log_config {
    cloudwatch_logs_role_arn = aws_iam_role.appsync_logs.arn
    field_log_level          = "ALL"
  }
}

data "aws_iam_policy_document" "appsync_push_logs" {
  statement {
    actions = [
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }
}

resource "aws_iam_role" "appsync_logs" {
  assume_role_policy = <<POLICY
{
	"Version": "2012-10-17",
	"Statement": [
		{
		"Effect": "Allow",
		"Principal": {
			"Service": "appsync.amazonaws.com"
		},
		"Action": "sts:AssumeRole"
		}
	]
}
POLICY
}

resource "aws_iam_role_policy" "appsync_logs" {
  role   = aws_iam_role.appsync_logs.id
  policy = data.aws_iam_policy_document.appsync_push_logs.json
}

resource "aws_cloudwatch_log_group" "loggroup" {
  name              = "/aws/appsync/apis/${aws_appsync_graphql_api.appsync.id}"
  retention_in_days = 14
}

resource "aws_appsync_datasource" "ds" {
  api_id = aws_appsync_graphql_api.appsync.id
  name   = "ds"
  type   = "NONE"
}

# resolvers

resource "aws_appsync_resolver" "Query_test" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "Query"
  field             = "test"
  data_source       = aws_appsync_datasource.ds.name
  request_template  = <<EOF
{
	"version" : "2018-05-29",
	"payload": {
		"test": "value"
	}
}
EOF
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_resolver" "Mutation_test" {
  api_id            = aws_appsync_graphql_api.appsync.id
  type              = "Mutation"
  field             = "test"
  data_source       = aws_appsync_datasource.ds.name
  request_template  = <<EOF
{
	"version" : "2018-05-29",
	"payload": {
		"test": "value"
	}
}
EOF
  response_template = <<EOF
$util.toJson($ctx.result)
EOF
}

resource "aws_appsync_api_key" "key" {
  api_id = aws_appsync_graphql_api.appsync.id
}

output "query" {
  value = <<EOF
curl -XPOST -H "Content-Type:application/graphql" -H "x-api-key:${nonsensitive(aws_appsync_api_key.key.key)}  " -d '{ "query": "query { test }" }' \
https://${data.aws_route53_zone.domain.name}/graphql
EOF
}
