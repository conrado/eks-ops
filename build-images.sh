export AWS_REGION=sa-east-1
export ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
ECR_PASSWORD=$(aws ecr get-login-password --region $AWS_REGION )
docker login --username --password $ECR_PASSWORD $ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com
PROJECT_NAME=eks-app-mesh-demo
export APP_VERSION=1.0

for app in catalog_detail product_catalog frontend_node
do
  aws ecr describe-repositories --repository-name $PROJECT_NAME/$app > /dev/null 2>&1 || \
  aws ecr create-repository --repository-name $PROJECT_NAME/$app > /dev/null
  TARGET=$ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$PROJECT_NAME/$app:$APP_VERSION
  docker build -t $TARGET apps/$app
  docker push $TARGET
done
