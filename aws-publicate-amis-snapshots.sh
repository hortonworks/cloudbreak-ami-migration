#!/bin/bash

set -x

for region in `aws ec2 describe-regions --output text | cut -f3`
do
    for snapshot in `aws ec2 --region $region describe-images --owners 958145178466 --filters Name=name,Values="cb-*" Name=architecture,Values=x86_64 Name=root-device-type,Values=ebs Name=virtualization-type,Values=hvm --query 'sort_by(Images,&Name)[].BlockDeviceMappings[].Ebs.SnapshotId' --output text`
    do
        echo "setting snapshot to public: $snapshot"
        aws ec2 --region $region modify-snapshot-attribute --snapshot-id $snapshot --attribute createVolumePermission --operation-type add --group-names all
    done
done
