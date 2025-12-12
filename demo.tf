provider "aws" {
  region = "us-east-2"
}

data "aws_region" "current" {}

resource "aws_dynamodb_table" "test_table_a" {
  # Added required fields to make the resource valid
  name         = "customer-data-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  # -----------------------------------------------------------
  # GOMBOC ALERT TRIGGER
  # -----------------------------------------------------------
  # Violation: Data recovery disabled.
  # Remediation: Gomboc would suggest setting this to 'true'.
  point_in_time_recovery {
    enabled = false
  }

  # Violation: Using default encryption (or disabled) rather than KMS (CMK).
  server_side_encryption {
    enabled = false
  }
}

resource "aws_lambda_function" "myfunction" {
  function_name = "test_function"
  role          = "arn:aws:iam::123456789012:role/service-role/role" # Placeholder
  handler       = "index.handler"
  runtime       = "nodejs18.x"

  # Violation: X-Ray tracing is not set to 'Active'
  tracing_config {
    mode = "PassThrough"
  }
}

resource "aws_appsync_graphql_api" "test_api" {
  name                = "test-api"
  authentication_type = "API_KEY"

  # Violation: Logging is not enabled for the API
  # (Missing log_config block implies disabled)
}

resource "aws_keyspaces_table" "mykeyspacestable" {
  keyspace_name = "my_keyspace"
  table_name    = "my_table"

  schema_definition {
    column {
      name = "id"
      type = "text"
    }
    partition_key {
      name = "id"
    }
  }

  # Violation: Client-side timestamps explicitly disabled
  client_side_timestamps {
    status = "DISABLED"
  }
}
