output "backup_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failed backups"
  value = aws_sns_topic.topicBackupsFailed
}

output "share_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at sharing snapshots with destination account"
  value = aws_sns_topic.topicShareFailed
}

output "delete_failed_topic" {
  description = "Subscribe to this topic to receive alerts of failures at deleting old snapshotss"
  value = aws_sns_topic.topicDeleteFailed
}

output "sourceurl" {
  description = "For more information and documentation, see the source repository at GitHub."
  value = "https://github.com/awslabs/rds-snapshot-tool"
}