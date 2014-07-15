#!/bin/bash

# Supported regions
allregions="us-east-1 us-west-1 us-west-2 eu-west-1 sa-east-1 ap-northeast-1 ap-southeast-1 ap-southeast-2"

help(){
    echo "create-cloudtrail [-a <accountname>] -b <bucket> -c <config> -r region -n"
    echo ""
    echo " -a <accountname>: optional. Used as suffix for SNS topic and trail name"
    echo " -b <bucket>: bucket name to get all trail reports."
    echo " -c <config>: configuration file to contain AWS key/secret"
    echo " -r <region>: region to get AWS global events, e.g. IAM"
    echo " -n         : Dryrun. Print out the commands"
    echo " -h         : Help"
}

while getopts "a:b:c:r:hn" OPTION
do
    case $OPTION in
        a)
          accoutname=$OPTARG
          ;;
        b)
          bucket=$OPTARG
          ;;
        c)
          config=$OPTARG
          ;;
        r)
          region=$OPTARG
          ;;
        n)
          dryrun=1
          ;;
        [h?])
          help
          exit
          ;;
    esac
done

if [[ -z $bucket ]] && [[ -z $config ]] && [[ -z $region ]]; then
    help
    exit 1
fi

if [ -z "$accountname" ]; then
    answer='N'
    accountname=$(aws iam get-user --query User.UserName| sed -s 's/"//g')
    echo -n "Do you accept the default name: $accountname? [Y/N]"
    read answer
    echo ""
    if [ "X$answer" != "XY" ]; then
        echo "Do nothing. Quit."
        exit 0
    fi
fi

# Cloudtrail name
trailname=${accountname}-cloudtrail

# Create one primary cloudtrail which will include other trails logs
snstopic=${trailname}-${region}
if [ $dryrun -eq 1 ]; then  
    echo "aws cloudtrail create-subscription --region ${region} --name $trailname  --s3-use-bucket $bucket --sns-new-topic $snstopic  --include-global-service-events true"
else
    aws cloudtrail create-subscription --region ${region} \
        --name $trailname \
        --s3-use-bucket $bucket --sns-new-topic $snstopic \
        --include-global-service-events true
fi

# Create other cloudtrails, but set no-include-global-service-events to 
# avoid global service log duplications
for i in $allregions
do 
    snstopic=${trailname}-$i
    if [ $dryrun -eq 1 ]; then
        echo "aws cloudtrail create-subscription --region $i --name $trailname --s3-use-bucket $bucket --sns-new-topic $snstopic --include-global-service-events false"
    else
        aws cloudtrail create-subscription --region $i \
            --name $trailname \
            --s3-use-bucket $bucket --sns-new-topic $snstopic \
            --include-global-service-events false
    fi
done
