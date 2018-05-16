#!/bin/bash
set -x 

# env vars
input=aws-images.yml
output=aws-new-images.2.yml
profile=seq
account_id=958145178466

echo "aws:" > $output

while IFS=':' read region ami_id 
do
    if [ "$region" = "aws" ]; then
        continue
    fi 
    aws ec2 describe-images --region $region --image-ids $ami_id --profile $profile > image_data.json  
    snap_id=$(jq -r '.Images[0]."BlockDeviceMappings"[0]."Ebs"."SnapshotId"' image_data.json)
    image_name=$(jq -r '.Images[0]."Name"' image_data.json)
    echo Adding rights for image: $image_name and snapshot $snap_id for ami $ami_id in region $region 

    aws ec2 modify-snapshot-attribute  --region $region --snapshot-id $snap_id  --profile $profile --attribute createVolumePermission --operation-type add --user-ids $account_id
    new_ami_id=$(aws ec2 copy-image --name $image_name --source-image-id $ami_id --source-region $region --region $region --profile poweruser | jq -r ".ImageId")    
    if [ "$new_ami_id" = "null" ]; then
        echo "Warning, new AMI copy failed!"
        exit 1
    fi 
    echo "$region: $new_ami_id" >> $output

done < "$input"

