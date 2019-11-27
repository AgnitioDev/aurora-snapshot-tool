locals {
  buckets = {
      us-east-1 = "snapshots-tool-aurora-us-east-1"
      us-west-2 = "snapshots-tool-aurora-us-west-2"
      us-east-2 = "snapshots-tool-aurora-us-east-2"
      ap-southeast-2 = "snapshots-tool-aurora-ap-southeast-2"
      ap-northeast-1 = "snapshots-tool-auora-ap-northeast-1"
      eu-west-1 = "snapshots-tool-aurora-eu-west-1"
      eu-central-1 = "snapshots-tool-aurora-eu-central-1"
      ca-central-1 = "snapshots-tool-aurora-ca-central-1"
      eu-west-2 = "snapshots-tool-aurora-eu-west-2"
      us-west-1 = "snapshots-tool-aurora-us-west-1"
      ap-northeast-2 = "snapshots-tool-aurora-ap-northeast-2"
      ap-southeast-1 = "snapshots-tool-aurora-ap-southeast-1-real"
  }

  lambda-take-snapshots-aurora_name = "${var.name}-lambda-take-snapshots"
  lambda-share-snapshots-aurora_name = "${var.name}-lambda-share-snapshots"
  lambda-delete-snapshots-aurora_name = "${var.name}-lambda-delete-snapshots"
}

# Get current region
data "aws_region" "current" {}

## Get current Account ID
data "aws_caller_identity" "current" {}

## SNS Topics
resource "aws_sns_topic" "topicBackupsFailed" {
  name = "${var.name}-backups_failed"
  tags = var.tags
}

resource "aws_sns_topic" "topicShareFailed" {
  count = var.sharesnapshots == "true" ? 1 : 0

  name = "${var.name}-share_failed"
  tags = var.tags
}

resource "aws_sns_topic" "topicDeleteFailed" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  name = "${var.name}-delete_failed"
  tags = var.tags
}

## SNS Topic Policy assigment
resource "aws_sns_topic_policy" "topicBackupsFailed" {
  arn = aws_sns_topic.topicBackupsFailed.arn
  policy = data.aws_iam_policy_document.sns-topic-policy.json
}

resource "aws_sns_topic_policy" "topicShareFailed" {
  count = var.sharesnapshots == "true" ? 1 : 0

  arn = aws_sns_topic.topicShareFailed[0].arn
  policy = data.aws_iam_policy_document.sns-topic-policy.json
}

resource "aws_sns_topic_policy" "topicDeleteFailed" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  arn = aws_sns_topic.topicDeleteFailed[0].arn
  policy = data.aws_iam_policy_document.sns-topic-policy.json
}

## SNS Topic policy definition
data "aws_iam_policy_document" "sns-topic-policy" {
  policy_id = "__default_policy_ID"

  statement {
    actions = [
      "SNS:GetTopicAttributes",
      "SNS:SetTopicAttributes",
      "SNS:AddPermission",
      "SNS:RemovePermission",
      "SNS:DeleteTopic",
      "SNS:Subscribe",
      "SNS:ListSubscriptionsByTopic",
      "SNS:Publish",
      "SNS:Receive"
    ]

    condition {
      test = "StringEquals"
      variable = "AWS:SourceOwner"
      values = [
        data.aws_caller_identity.current.account_id
      ]
    }

    effect = "Allow"

    principals {
      type = "AWS"
      identifiers = [
        "*"
      ]
    }

    resources = [
      "*"
    ]
  }

  #sid = "__default_policy_ID"

  #tags = var.tags
}

## Cloudwatch alarms
resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_backup_failed" {
  alarm_name = "${var.name}-cloudwatch_metric_alarm_backup_failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "1"
  metric_name = "ExecutionsFailed"
  namespace = "AWS/States"
  period = "300"
  statistic = "Sum"
  threshold = "1.0"
  insufficient_data_actions = []
  actions_enabled = "true"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine-take-snapshots-aurora.name
  }

  alarm_actions = [
    aws_sns_topic.topicBackupsFailed.arn
  ]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_share_failed" {
  count = var.sharesnapshots == "true" ? 1 : 0

  alarm_name = "${var.name}-cloudwatch_metric_alarm_share_failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "ExecutionsFailed"
  namespace = "AWS/States"
  period = "3600"
  statistic = "Sum"
  threshold = "2.0"
  insufficient_data_actions = []
  actions_enabled = "true"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine-share-snapshots-aurora[0].name
  }

  alarm_actions = [
    aws_sns_topic.topicShareFailed[0].arn
  ]

  tags = var.tags
}

resource "aws_cloudwatch_metric_alarm" "cloudwatch_metric_alarm_delete_failed" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  alarm_name = "${var.name}-cloudwatch_metric_alarm-delete-failed"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods = "2"
  metric_name = "ExecutionsFailed"
  namespace = "AWS/States"
  period = "3600"
  statistic = "Sum"
  threshold = "2.0"
  insufficient_data_actions = []
  actions_enabled = "true"

  dimensions = {
    StateMachineArn = aws_sfn_state_machine.statemachine-delete-snapshots-aurora[0].name
  }

  alarm_actions = [
    aws_sns_topic.topicDeleteFailed[0].arn
  ]

  tags = var.tags
}

## Lambda functions
data "aws_iam_policy_document" "iam_policy_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["lambda.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role_snapshots_aurora" {
  name = "${var.name}-snapshot-aurora-role"
  assume_role_policy = data.aws_iam_policy_document.iam_policy_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "iam_policy_snapshots_aurora" {
  statement {
    actions = [
      "logs:CreateLogGroup",
      "logs:CreateLogStream",
      "logs:PutLogEvents"
    ]
    resources = [
      "arn:aws:logs:*:*:*"
    ]
  }

  statement {
    actions = [
      "rds:CreateDBClusterSnapshot",
      "rds:DeleteDBClusterSnapshot",
      "rds:DescribeDBClusters",
      "rds:DescribeDBClusterSnapshots",
      "rds:ModifyDBClusterSnapshotAttribute",
      "rds:DescribeDBClusterSnapshotAttributes",
      "rds:ListTagsForResource"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "iam-policy-snapshot-aurora" {
  name = "${var.name}-iam-policy-snapshot-aurora"
  path = "/"
  policy = data.aws_iam_policy_document.iam_policy_snapshots_aurora.json

  #tags = var.tags
}

resource "aws_iam_role_policy_attachment" "snapshots_aurora-role-policy-atachement" {
  role       = aws_iam_role.iam_role_snapshots_aurora.name
  policy_arn = aws_iam_policy.iam-policy-snapshot-aurora.arn
}

resource "aws_lambda_function" "lambda-take-snapshots-aurora" {
  function_name = local.lambda-take-snapshots-aurora_name
  role = aws_iam_role.iam_role_snapshots_aurora.arn

  publish = var.publish

  description = "This functions triggers snapshots creation for Aurora clusters. It checks for existing snapshots following the pattern and interval specified in the environment variables with the following format: <dbcluster-identifier>-YYYY-MM-DD-HH-MM"
  memory_size = "512"
  timeout = 300

  s3_bucket = var.codebucket == "DEFAULT_BUCKET" ? lookup(local.buckets,data.aws_region.current.name,"Unsupported region") : var.codebucket
  s3_key = "take_snapshots_aurora.zip"

  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"

  environment {
    variables = {
      INTERVAL = var.backup_interval
      PATTERN = var.instance_name_pattern
      LOG_LEVEL = var.log_level
      REGION_OVERRIDE = var.source_region_override
      TAGGEDINSTANCE = var.tagged_instance
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "lambda-share-snapshots-aurora" {
  count = var.sharesnapshots == "true" ? 1 : 0

  function_name = local.lambda-share-snapshots-aurora_name
  role = aws_iam_role.iam_role_snapshots_aurora.arn

  publish = var.publish

  description = "This function shares snapshots created by the ${local.lambda-share-snapshots-aurora_name} function with DEST_ACCOUNT specified in the environment variables. "
  memory_size = "512"
  timeout = 300

  s3_bucket = var.codebucket == "DEFAULT_BUCKET" ? lookup(local.buckets,data.aws_region.current.name,"Unsupported region") : var.codebucket
  s3_key = "share_snapshots_aurora.zip"

  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"

  environment {
    variables = {
      DEST_ACCOUNT = var.destination_account,
      LOG_LEVEL = var.log_level,
      PATTERN = var.instance_name_pattern,
      REGION_OVERRIDE = var.source_region_override
    }
  }

  tags = var.tags
}

resource "aws_lambda_function" "lambda-delete-snapshots-aurora" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  function_name = "${var.name}-lambda-delete-snapshots-aurora"
  role = aws_iam_role.iam_role_snapshots_aurora.arn

  publish = var.publish

  description = "This function deletes snapshots created by the ${local.lambda-delete-snapshots-aurora_name} function."
  memory_size = "512"
  timeout = 300

  s3_bucket = var.codebucket == "DEFAULT_BUCKET" ? lookup(local.buckets,data.aws_region.current.name,"Unsupported region") : var.codebucket
  s3_key = "delete_old_snapshots_aurora.zip"

  runtime = "python3.7"
  handler = "lambda_function.lambda_handler"

  environment {
    variables = {
      RETENTION_DAYS = var.retentiondays,
      PATTERN = var.instance_name_pattern,
      LOG_LEVEL = var.log_level,
      REGION_OVERRIDE = var.source_region_override
    }
  }

  tags = var.tags
}

## State machines
data "aws_iam_policy_document" "iam_policy_state_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = [join("",["states.${data.aws_region.current.name}.amazonaws.com"])]
    }
  }
}

resource "aws_iam_role" "iam_role_state_snapshots_aurora" {
  name = "${var.name}-iam_role_state_snapshots_aurora"
  assume_role_policy = data.aws_iam_policy_document.iam_policy_state_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "iam_policy_state_snapshots_aurora" {
  statement {
    actions = [
      "lambda:InvokeFunction"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "iam-policy-state-snapshot-aurora" {
  name = "${var.name}-iam-policy-state-snapshot-aurora"
  path = "/"
  policy = data.aws_iam_policy_document.iam_policy_state_snapshots_aurora.json

  #tags = var.tags
}

resource "aws_iam_role_policy_attachment" "iam_role-policy-atachement-state-snapshots_aurora" {
  role       = aws_iam_role.iam_role_state_snapshots_aurora.name
  policy_arn = aws_iam_policy.iam-policy-state-snapshot-aurora.arn
}

resource "aws_sfn_state_machine" "statemachine-take-snapshots-aurora" {
  name = "${var.name}-statemachine-take-snapshots"
  role_arn = aws_iam_role.iam_role_state_snapshots_aurora.arn
  definition = <<EOF
{
  "Comment": "Triggers snapshot backup for RDS instances",
  "StartAt": "TakeSnapshots",
  "States": {
    "TakeSnapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda-take-snapshots-aurora.arn}",
      "Retry": [ {
          "ErrorEquals": ["SnapshotToolException"],
          "IntervalSeconds": 300,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }, {
          "ErrorEquals": ["States.AL"],
          "IntervalSeconds": 30,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }
      ],
      "End": true
    }
  }
}
EOF
  tags = var.tags
}

resource "aws_sfn_state_machine" "statemachine-share-snapshots-aurora" {
  count = var.sharesnapshots == "true" ? 1 : 0

  name = "${var.name}-statemachine-share-snapshots"
  role_arn = aws_iam_role.iam_role_state_snapshots_aurora.arn
  definition = <<EOF
{
  "Comment": "Shares snapshots with DEST_ACCOUNT",
  "StartAt": "ShareSnapshots",
  "States": {
    "ShareSnapshots": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda-share-snapshots-aurora[0].arn}",
      "Retry": [ {
          "ErrorEquals": ["SnapshotToolException"],
          "IntervalSeconds": 300,
          "MaxAttempts": 3,
          "BackoffRate": 1
        }, {
          "ErrorEquals": ["States.AL"],
          "IntervalSeconds": 30,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }
      ],
      "End": true
    }
  }
}
EOF
  tags = var.tags
}

resource "aws_sfn_state_machine" "statemachine-delete-snapshots-aurora" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  name = "${var.name}-statemachine-delete-snapshots"
  role_arn = aws_iam_role.iam_role_state_snapshots_aurora.arn
  definition = <<EOF
{
  "Comment": "DeleteOld management for RDS snapshots",
  "StartAt": "DeleteOld",
  "States": {
    "DeleteOld": {
      "Type": "Task",
      "Resource": "${aws_lambda_function.lambda-delete-snapshots-aurora[0].arn}",
      "Retry": [ {
          "ErrorEquals": ["SnapshotToolException"],
          "IntervalSeconds": 300,
          "MaxAttempts": 7,
          "BackoffRate": 1
        }, {
          "ErrorEquals": ["States.AL"],
          "IntervalSeconds": 30,
          "MaxAttempts": 20,
          "BackoffRate": 1
        }
      ],
      "End": true
    }
  }
}
EOF
  tags = var.tags
}

## Cloudwatch event rules
data "aws_iam_policy_document" "iam_policy_execute_lambda_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "iam_role_execute_lambda_aurora" {
  name = "${var.name}-iam-role-execute-snapshots"
  assume_role_policy = data.aws_iam_policy_document.iam_policy_execute_lambda_assume_role.json

  tags = var.tags
}

data "aws_iam_policy_document" "iam_policy_execute_lambda_aurora" {
  statement {
    actions = [
      "states:StartExecution"
    ]
    resources = [
      "*"
    ]
  }
}

resource "aws_iam_policy" "iam-policy-execute-lambda-aurora" {
  name = "${var.name}-iam-policy-execute-lambda"
  path = "/"
  policy = data.aws_iam_policy_document.iam_policy_execute_lambda_aurora.json

  #tags = var.tags
}

resource "aws_iam_role_policy_attachment" "iam_role-policy-atachement-execute_lambda_aurora" {
  role       = aws_iam_role.iam_role_execute_lambda_aurora.name
  policy_arn = aws_iam_policy.iam-policy-execute-lambda-aurora.arn
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule-backup" {
  name        = "${var.name}-cloudwatch-event-rule-backup"
  description = "Triggers the ${aws_sfn_state_machine.statemachine-take-snapshots-aurora.name} state machine"
  schedule_expression = "cron(${var.backup_schedule})"
  is_enabled = true

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_rule-backup-target" {
  target_id = "Target1"
  rule      = aws_cloudwatch_event_rule.cloudwatch_event_rule-backup.id
  arn       = aws_sfn_state_machine.statemachine-take-snapshots-aurora.id
  role_arn = aws_iam_role.iam_role_execute_lambda_aurora.arn
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule-share" {
  count = var.sharesnapshots == "true" ? 1 : 0

  name        = "${var.name}-cloudwatch-event-rule-share"
  description = "Triggers the ${aws_sfn_state_machine.statemachine-take-snapshots-aurora.name} state machine"
  schedule_expression = "cron(/10 * * * ? *)"
  is_enabled = true

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_rule-share-target" {
  count = var.sharesnapshots == "true" ? 1 : 0

  target_id = "Target1"
  rule = aws_cloudwatch_event_rule.cloudwatch_event_rule-share[0].id
  arn = aws_sfn_state_machine.statemachine-share-snapshots-aurora[0].id
  role_arn = aws_iam_role.iam_role_execute_lambda_aurora.arn
}

resource "aws_cloudwatch_event_rule" "cloudwatch_event_rule-delete" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  name = "${var.name}-cloudwatch-event-rule-delete"
  description = "Triggers the ${aws_sfn_state_machine.statemachine-delete-snapshots-aurora[0].name} state machine"
  schedule_expression = "cron(0 /1 * * ? *)"
  is_enabled = true

  tags = var.tags
}

resource "aws_cloudwatch_event_target" "cloudwatch_event_rule-delete-target" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  target_id = "Target1"
  rule = aws_cloudwatch_event_rule.cloudwatch_event_rule-delete[0].id
  arn = aws_sfn_state_machine.statemachine-delete-snapshots-aurora[0].id
  role_arn = aws_iam_role.iam_role_execute_lambda_aurora.arn
}

## Cloudwatch log Groups
resource "aws_cloudwatch_log_group" "cloudwatch_log_group-take-snapshots" {
  name = "/aws/lambda/${aws_lambda_function.lambda-take-snapshots-aurora.function_name}"
  depends_on = [aws_lambda_function.lambda-take-snapshots-aurora]
  retention_in_days = var.lambda_log_retention

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_group-share-snapshots" {
  count = var.sharesnapshots == "true" ? 1 : 0

  name = "/aws/lambda/${aws_lambda_function.lambda-share-snapshots-aurora[0].function_name}"
  depends_on = [aws_lambda_function.lambda-share-snapshots-aurora]
  retention_in_days = var.lambda_log_retention

  tags = var.tags
}

resource "aws_cloudwatch_log_group" "cloudwatch_log_group-delete-snapshots" {
  count = var.delete_oldsnapshots == "true" ? 1 : 0

  name = "/aws/lambda/${aws_lambda_function.lambda-delete-snapshots-aurora[0].function_name}"
  depends_on = [aws_lambda_function.lambda-delete-snapshots-aurora]
  retention_in_days = var.lambda_log_retention

  tags = var.tags
}