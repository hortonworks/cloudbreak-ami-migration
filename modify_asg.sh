#!/bin/bash
 set -x

# The script…
#     - takes two inputs, the list of the original AMI-s and the list of the already migrated AMI (we are providing these inputs)
#     - for each region, it searches the available LaunchConfigurations in the region created with the given AMI
#     - creates a copy based on each found such LaunchConfiguration, with two differences:
#         - The name of the new launch config will be "$original_launch_config_name-COPY"
#         - The ImageId is set to the migrated AMI
#     - Searches for all the AutoScalingGroups created with the found LaunchConfiguration
#     - Updates the found AutoScalingGroup by replacing the original LaunchConfiguration to the newly created one with the migrated AMI-id
#     - Deletes the original LaunchConfiguration

#env vars
profile=${AWS_PROFILE_NAME:-poweruser}
input=${AWS_INPUT_FILE:-aws-merged-images.yml}

while IFS=': ' read region original_ami_id new_ami_id 
do
    if [ "$region" = "aws" ]; then
        continue
    fi 
    echo $region
    echo $original_ami_id
    echo $new_ami_id

    aws autoscaling describe-launch-configurations --region $region --profile $profile --query "LaunchConfigurations[?ImageId == '$original_ami_id']" | jq '. | .[].ImageId |= "'$new_ami_id'" | del(.[].KernelId, .[].RamdiskId, .[].LaunchConfigurationARN, .[].CreatedTime)' > launch_config_list.json
    jq -e '.[] | has("LaunchConfigurationName")' launch_config_list.json > /dev/null
    if [ $? != 0 ]; then
        echo "WARN: No matching launch config for $original_ami_id"
        continue
    fi

    for original_launch_config_name in $(jq -r '.[].LaunchConfigurationName' launch_config_list.json ) 
    do 

        launch_config_name=$original_launch_config_name-MIGRATED
        jq -r '.[] | select(.LaunchConfigurationName =="'$original_launch_config_name'")' launch_config_list.json > launch_config.json
        aws autoscaling create-launch-configuration --region $region  --profile $profile --launch-configuration-name $launch_config_name --cli-input-json file://launch_config.json
        

        for autoscaling_group_name in $(aws autoscaling describe-auto-scaling-groups --region $region  --profile $profile --query "AutoScalingGroups[?LaunchConfigurationName == '$original_launch_config_name']" | jq -r '.[0].AutoScalingGroupName ') 
        do
            if [ "$autoscaling_group_name" == "null" ]; then
                echo "WARN: No matching autoscaling group for $original_launch_config_name"
                continue
            fi
            echo $autoscaling_group_name
            aws autoscaling update-auto-scaling-group --region $region  --profile $profile --auto-scaling-group-name $autoscaling_group_name --launch-configuration-name $launch_config_name
        done
        aws autoscaling  --region $region  --profile $profile delete-launch-configuration --launch-configuration-name $original_launch_config_name
    done

done < "$input"

