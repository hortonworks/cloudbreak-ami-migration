#!/bin/bash
set -x 

# env vars
input=aws-new-images.2.yml
profile=poweruser

while IFS=':' read region ami_id 
do
    if [ "$region" = "aws" ]; then
        continue
    fi 
    aws ec2 modify-image-attribute --image-id $ami_id --region $region --profile poweruser --launch-permission "{\"Add\":[{\"Group\":\"all\"}]}"
done < "$input"

