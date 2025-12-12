
provider "aws" {
  region = "us-east-2"
}

data "aws_region" "current" { }

resource "aws_dynamodb_table" "test_table_a" {
}

resource "aws_lambda_function" "myfunction" {
}

resource "aws_appsync_graphql_api" "test_api" {
  authentication_type = "API_KEY"
}

resource "aws_keyspaces_table" "mykeyspacestable" {
}
