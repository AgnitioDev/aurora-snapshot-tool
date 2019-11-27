variable "vpc_id" {
}

variable "name" {
}

variable "tags" {
  default = {}
  type = map
}

variable "backup_interval" {
  default = 24
  description = "Interval for backups in hours. Default is 24"
}

variable "instance_name_pattern" {
  default = "ALL_INSTANCES"
  description = "Python regex for matching cluster identifiers to backup. Use \"ALL_INSTANCES\" to back up every RDS instance in the region."
}

variable "log_level" {
  default = "ERROR"
  description = "Log level for Lambda functions (DEBUG, INFO, WARN, ERROR, CRITICAL are valid values)."
}

variable "source_region_override" {
  default  = "NO"
  description = "Set to the region where your RDS instances run, only if such region does not support Step Functions. Leave as NO otherwise"
}

variable "tagged_instance" {
  default = "false"
  description = "Set to true to filter instances that have tag CopyDBSnapshot set to True. Set to false to disable. AllowedValues [\"true\", \"false\"]"
}

variable "destination_account" {
  default  = "000000000000"
  description = "Destination account id with no dashes."
}

variable "retentiondays" {
  default  = "7"
  description  = "Number of days to keep snapshots in retention before deleting them"
}

variable "backup_schedule" {
  default = "0 1 * * ? *"
  description = "Backup schedule in Cloudwatch Event cron format. Needs to run at least once for every Interval. The default value runs once every at 1AM UTC. More information: http://docs.aws.amazon.com/AmazonCloudWatch/latest/events/ScheduledEvents.html"
}

variable "lambda_log_retention" {
  default = "7"
  description = "Number of days to retain logs from the lambda functions in CloudWatch Logs"
}

variable "publish" {
  default = false
}

variable "codebucket" {
  default = "DEFAULT_BUCKET"
  description = "Name of the bucket that contains the lambda functions to deploy. Leave the default value to download the code from the AWS Managed buckets"
}

variable "sharesnapshots" {
  default = "true"
  description = "AllowedValues [\"true\", \"false\"]"
}

variable "delete_oldsnapshots" {
  default = "true"
  description = "Set to true to enable deletion of snapshot based on RetentionDays. Set to false to disable. AllowedValues [\"true\", \"false\"]"
}

variable "log_groupname" {
  default = "lambdaDeleteOldSnapshotsRDS-source"
  description = "Name for RDS snapshot log group."
}