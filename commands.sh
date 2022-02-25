# SSH to host
# Remember to update the IP address here to the one output by
# the Terraform initialization code when it builds your EC2 instance
ssh -i ~/.ssh/KylerSSHKey.pem ec2-user@1.2.3.4

# Install jq
sudo yum -y install jq

# Install terraform v1.1.6
wget https://releases.hashicorp.com/terraform/1.1.6/terraform_1.1.6_linux_amd64.zip
unzip terraform_1.1.6_linux_amd64.zip
sudo mv terraform /usr/bin/

# Export ec2's local region as default
export AWS_DEFAULT_REGION=$(curl -s http://169.254.169.254/latest/dynamic/instance-identity/document | jq -c -r .region)

# Set variables for AWS STS commands
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
ACCOUNT_ID=$(curl -s http://169.254.169.254/latest/meta-data/identity-credentials/ec2/info | jq -r '.AccountId')

# Can also use the AWS cli STS command to get our identity when running commands (probs have to block out account ID)
aws sts get-caller-identity

# Try to do AWS ec2 thing, which will fail
aws ec2 describe-instances --instance-id $INSTANCE_ID

# Look at AWS STS command and response
aws sts assume-role \
--role-arn arn:aws:iam::$ACCOUNT_ID:role/PulseSTS-Deity-AssumedRole \
--role-session-name AssumedRoleSession

# Assume role super command! - Use STS assume role, then write credentials back to file
eval $(aws sts assume-role --role-arn arn:aws:iam::$ACCOUNT_ID:role/PulseSTS-Deity-AssumedRole --role-session-name AssumedRoleSession | jq -r '.Credentials | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId) AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey) AWS_SESSION_TOKEN=\(.SessionToken)"')

# Check our permissions now
aws sts get-caller-identity

# Try to do AWS ec2 thing, which will succeed!
aws ec2 describe-instances --instance-id $INSTANCE_ID

# Show the ec2 metadata node response
curl http://169.254.169.254/latest/meta-data/iam/security-credentials/PulseSTS-Assigned-IAM-Role

# Reset to assigned IAM role
eval $(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/PulseSTS-Assigned-IAM-Role | jq -r '. | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId) AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey) AWS_SESSION_TOKEN=\(.Token)"')

# Check our permissions now
aws sts get-caller-identity

# Try to do AWS ec2 thing, which will fail
aws ec2 describe-instances --instance-id $INSTANCE_ID

# Apply the terraform to output IAM user
terraform apply --auto-approve

##
# Troubleshooting
##

# Fix error: "An error occurred (ExpiredToken) when calling the GetSessionToken operation: The security token included in the request is expired"
eval $(curl http://169.254.169.254/latest/meta-data/iam/security-credentials/PulseSTS-Assigned-IAM-Role | jq -r '. | "export AWS_ACCESS_KEY_ID=\(.AccessKeyId) AWS_SECRET_ACCESS_KEY=\(.SecretAccessKey) AWS_SESSION_TOKEN=\(.Token)"')
