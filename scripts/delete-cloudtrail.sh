#!/bin/bash
set -e

# Supported regions
allregions="us-east-1 us-west-1 us-west-2 eu-west-1 sa-east-1 ap-northeast-1 ap-southeast-1 ap-southeast-2"

help(){
    echo "delete-cloudtrail [-a <accountname>] -b <bucket> -c <config> -r region -n"
    echo ""
    echo " -a <accountname>: optional. Used as suffix for SNS topic and trail name"
    echo " -c <config>: configuration file to contain AWS key/secret"
    echo " -n         : Dryrun. Print out the commands"
    echo " -h         : Help"
}

dryrun=0
while getopts "a:b:c:r:hn" OPTION
do
    case $OPTION in
        a)
          accoutname=$OPTARG
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

if [[ -z $config ]]; then
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

# Don't exist on non-zero code because the following aws commmands exit code
# is '1' on sucess.
set +e 
# Cloudtrail name
trailname=${accountname}-cloudtrail

# Delete SNS topics
for i in $allregions
do 
    snstopic=${trailname}-$i
    topicarn=$(aws sns list-topics --region $i |grep $snstopic | awk '{print $2}' | sed -e 's/"//g')
    if [ $dryrun -eq 1 ]; then
        echo "aws sns delete-topic --topic-arn $topicarn --region $i"
    else
        aws sns delete-topic --topic-arn $topicarn --region $i
    fi
done

# Delete Cloudtrails
for i in $allregions
do 
    snstopic=${trailname}-$i
    if [ $dryrun -eq 1 ]; then
        echo "aws cloudtrail delete-trail --region $i --name $trailname"
    else
        aws cloudtrail delete-trail --region $i --name $trailname
    fi
done
