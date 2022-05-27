export AWS_REGION=sa-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
export APP_VERSION=1.0
