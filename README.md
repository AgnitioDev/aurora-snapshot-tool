# Snapshot Tool for Amazon Aurora - Terraform version

The Snapshot Tool for Amazon Aurora automates the task of creating manual snapshots, copying them into a different account and a different region, and deleting them after a specified number of days. It also allows you to specify the backup schedule (at what times and how often) and a retention period in days. This version will only work with Amazon Aurora MySQL and PostgreSQL instances. For a version that works with other Amazon RDS instances, please visit the [Snapshot Tool for Amazon RDS](https://github.com/awslabs/rds-snapshot-tool).

## Getting Started

Include the module in your IaC project. Configure the variables as needed and run terraform init as usual.


### Source Account
#### Components
The following components will be created in the source account: 
* 3 Lambda functions (TakeSnapshotsAurora, ShareSnapshotsAurora, DeleteOldSnapshotsAurora)
* 3 State Machines (Amazon Step Functions) to trigger execution of each Lambda function (stateMachineTakeSnapshotAurora, stateMachineShareSnapshotAurora, stateMachineDeleteOldSnapshotsAurora)
* 3 Cloudwatch Event Rules to trigger the state functions
* 3 Cloudwatch Alarms and 1 associated SNS Topic to alert on State Machines failures

If your clusters are encrypted, you will need to provide access to the KMS Key to the destination account. You can read more on how to do that here: https://aws.amazon.com/premiumsupport/knowledge-center/share-cmk-account/

Here is a break down of each parameter for the source template:

* **backup_interval** - how many hours between backup
* **backup_schedule** - at what times and how often to run backups. Set in accordance with **BackupInterval**. For example, set **BackupInterval** to 8 hours and **BackupSchedule** 0 0,8,16 * * ? * if you want backups to run at 0, 8 and 16 UTC. If your backups run more often than **BackupInterval**, snapshots will only be created when the latest snapshot is older than **BackupInterval**
* **instance_namepattern** - set to the names of the clusters you want this tool to back up. You can use a Python regex that will be searched in the cluster identifier. For example, if your clusters are named *prod-01*, *prod-02*, etc, you can set **ClusterNamePattern** to *prod*. The string you specify will be searched anywhere in the name unless you use an anchor such as ^ or $. In most cases, a simple name like "prod" or "dev" will suffice. More information on Python regular expressions here: https://docs.python.org/2/howto/regex.html
* **destination_account** - the account where you want snapshots to be copied to
* **log_level** - The log level you want as output to the Lambda functions. ERROR is usually enough. You can increase to INFO or DEBUG. 
* **log_groupname** - Name for RDS snapshot log group
* **retention_days** - the amount of days you want your snapshots to be kept. Snapshots created more than **RetentionDays** ago will be automatically deleted (only if they contain a tag with Key: CreatedBy, Value: Snapshot Tool for Aurora)
* **sharesnapshots** - Set to TRUE if you are sharing snapshots with a different account. If you set to FALSE, StateMachine, Lambda functions and associated Cloudwatch Alarms related to sharing across accounts will not be created. It is useful if you only want to take backups and manage the retention, but do not need to copy them across accounts or regions.
* **source_region_override** - if you are running Aurora on a region where Step Functions is not available, this parameter will allow you to override the source region. For example, at the time of this writing, you may be running Aurora in Northern California (us-west-1) and would like to copy your snapshots to Montreal (ca-central-1). Neither region supports Step Functions at the time of this writing so deploying this tool there will not work. The solution is to run this template in a region that supports Step Functions (such as North Virginia or Ohio) and set **SourceRegionOverride** to *us-west-1*. 
**IMPORTANT** - deploy to the closest regions for best results.
* **lambda_log_retention**: Number of days to retain logs from the lambda functions in CloudWatch Logs
* **codebucket** - this parameter specifies the bucket where the code for the Lambda functions is located. Leave to DEFAULT_BUCKET to download from an AWS-managed bucket. The Lambda function code is located in the ```lambda``` directory. These files need to be on the **root* of the bucket or the CloudFormation templates will fail. 
* **delete_oldsnapshots** - Set to TRUE to enable functionanility that will delete snapshots after **RetentionDays**. Set to FALSE if you want to disable this functionality completely. (Associated Lambda and State Machine resources will not be created in the account). **WARNING** If you decide to enable this functionality later on, bear in mind it will delete **all snapshots**, older than **RetentionDays**, created by this tool; not just the ones created after **DeleteOldSnapshots** is set to TRUE.
* **publish** - If true updates to the lambda is published when updating 

## Updating

This tool is fundamentally stateless. The state is mainly in the tags on the snapshots themselves and the parameters to the CloudFormation stack. If you make changes to the parameters or make changes to the Lambda function code, it is best to delete the stack and then launch the stack again. 

## Authors

* **Martin Frederiksen** 

## License

This project is licensed under the Apache License - see the [LICENSE.txt](LICENSE.txt) file for details
