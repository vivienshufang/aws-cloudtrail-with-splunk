# How to Setup AWS CouldTrail with Splunk

This document describes how to setup AWS Cloudtail services to audit API calls and how to setup SpunkAppForAWS app to generate reports in Splunk.

## What is CloudTrail
[AWS CloudTrail] (http://aws.amazon.com/cloudtrail/) is an AWS service. When enabled, it captures AWS API calls made by or on behalf of an AWS account and delivers log files to an Amazon S3 bucket. 

## Why use CloudTrail
Traditionally system administrators monitor a system's integrity using intrusion detection tools such as Tripwire. System logs are usually sent to 
a central log server for auditing and security analysis.

For services running on AWS, another important operation and security related auditing is to monitor API calls that can change services and environments. 
Use cases enabled by CloudTrail service:

* Security Analysis
* Track Changes to AWS Resources
* Troubleshoot Operational Issues
* Compliance Aid

Here is an example of API call recorded by CloudTrail and how Spunk reports it (when, what, who, where, etc.)

	{ [-]
	   awsRegion: us-west-2
	   eventID: 7ad60379-0e2e-4b6c-8a6f-100f00fc5df1
	   eventName: ModifyReservedInstances
	   eventSource: ec2.amazonaws.com
	   eventTime: 2014-07-14T19:29:42Z
	   eventVersion: 1.01
	   requestID: 900f0797-0f2d-43dd-bcf5-41e1cfbc5c9f
	   requestParameters: { [-]
	     clientToken: fa8494bb-8546-4fc4-9bb8-8dc84e7d0015
	     reservedInstancesSet: { [+]
	     }
	     targetConfigurationSet: { [+]
	     }
	   }
	   responseElements: { [-]
	     reservedInstancesModificationId: rimod-f0713af8-0984-42ff-8016-3dfea813b209
	   }
	   sourceIPAddress: 171.66.221.130
	   userAgent: console.ec2.amazonaws.com
	   userIdentity: { [-]
	     accessKeyId: ASIAJYFJCMKALLLUR36Q
	     accountId: 972569769453
	     arn: arn:aws:sts::972569769453:assumed-role/admin-saml/john
	     principalId: AROAIVEEFBU3CT2SWXT3Y:jonh
	     sessionContext: { [+]
	     }
	     type: AssumedRole
	   }
	}

## Visualized reporting tools
Many tools are available to generate visualized reports using the CloudTrail files stored in S3 bucket. Here are listed 
[AWS partners](http://aws.amazon.com/cloudtrail/partners/). This documentation describes how to use [SplunkAppforAWS](http://apps.splunk.com/app/1274/) to consume Cloudtrail data and generate reports. 

## The CloudTrail and Spunk integration

In this integration, we create CloudService for each region and Simple Notification Service (SNS) topic for each CloudService. The reports from all regions are aggregated to one S3 bucket. One Simple Queue Service (SQS) is subscribed to all the SNS topics. 

![](./images/splunk-aws-integration.png)

## Prerequisites for this setup

All the setups can be done through AWS console, but we use a script for CloudTrail setup to make sure we have naming schema consistency cross
all regions.

* Install AWSCLI 

    [AWSCLI] (https://github.com/aws/aws-cli) command line tool is used to create Cloudtrail. To install(or upgrade) the package

        pip install awscli [--upgrade]

    This will install _aws_ command under /usr/local/bin. There are three ways to setup AWS CLI AWS credentials. The examples here assumes you run the Cloudtrail creation code on an on-premise system and use a configuration file for key id and key secret. If you run it on EC2, you need to create an IAM role and
the aws cli can use role-based token automatically.

* Create a S3 bucket for CloudTrail report

    We will aggregate CloudTrail reports from different regions into one S3 bucket. A bucket name used in this example is:
_accountname.myfqdn_. 

Follow the instructions here (http://docs.aws.amazon.com/awscloudtrail/latest/userguide/create_trail_using_the_console.html), but skip the optional steps. We will setup SNS using [create-cloudtrail](./scripts/create-cloudtrail.sh). 

* Create an IAM user

    You should create an IAM user with the minimum access privileges needed. 

For example, you can create an IAM user _cloudtrail-splunkapp_  which has permission to read SQS, delete message from SQS, and get data from S3 bucket. The following polices should work if you use canned AWS policy generator:

* Readonly access to S3 bucket
* Readonly access to CloudTrail
* Full access to the SQS (it deletes messages after read stuff from the message queue)

## Create AWS CloudTrail

For security auditing, you should monitor all regions that CloudTrail service is available. These are the current supported regions:

* us-east-1
* us-west-1
* us-west-2
* eu-west-1
* sa-east-1
* ap-northeast-1
* ap-southeast-1	
* ap-southeast-2

To enable CloudTrail on these regions, download and run [create-cloudtrail](./scripts/create-cloudtrail.sh)

The script calls AWSCLI cloudtrail command to:

* Enable Cloudtrail service in each region
* Create Simple Notification Service (SNS) topic for the Cloudtrail service in each region
* Aggregate all regions audit reports in one S3 bucket (pre-created)

The script has a dryrun option to generate the commands so you can see what the actual commands without having to run it. 

We consolidate all CloudTrails reports into one S3 bucket that you give at the command line. The script takes care of creating necessary access policies. Global events - generated by services that don't have a regional endpoint, e.g. Identity and Access Management (IAM) - will be logged in one region that you defined at the command line. 

## Create a Simple Queue Service (SQS) 

We will setup one message queue named _accountname-cloudtrail_ in one region. It subscribes to multiple SNS cloudtrail SNS topics created by the create-cloudetrail script.  With one message queue, you only need to setup one data input for Splunk to consume. 

SQS is needed in Splunk AWS app configuration. Splunk AWS app runs at 1 minute interval to retrieve messages from AWS SQS service. The message body contains the S3 bucket location for the Cloudtrail report. Splunk then calls S3 API to get Cloudtrail reports from the S3 bucket.


## Setup Splunk

### Billing and usage module

This requires to setup billing to send CSV files to a S3 bucket. If you have consolidated billing setup, ask the payer to create an IAM that
has read access to the S3 bucket that collect billing csv files. If you want to monitor the subaccounts's running status, you also need to create
an IAM users in each sub-accounts that has access to check EC2 status. 

### CloudTrail module

The SplunkAppForAWS needs to be installed on the search head and indexers. The data input only need to be configured on indexers where the app will retrieve audit reports and build the indexes. Splunk search head does search against the logindex servers. 

Setup data input either on Splunk Settings->Data Input console. If you do it on Splunk console, following the following steps:

* Go to "Settings->Data Inputs" 
* Create a new data input
* Fill out the IAM user's key, secret, SQS name, and the region
* In the "Script iterations" box, type "relaunch", otherwise, the app script will stop running after 2048 runs.
* Click "More Advanced Setting", check Source Type to Manual, and "Source" to aws-cloudtrail

It will generate a __inputs.conf__ file, that can be managed by a configuration tool such as Puppet. Here is an example:

    logindex-dev:/opt/splunk/etc/apps/launcher/local# more inputs.conf 
    exclude_describe_events = 0
	index = aws-cloudtrail
	interval = 1
	remove_files_when_done = 0
	key_id = key
	secret_key = secret
	sqs_queue = accountname-cloudtrail
	sqs_queue_region = us-west-2
	sourcetype = aws-cloudtrail
	script_iterations = relaunch

 