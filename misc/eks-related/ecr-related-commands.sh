aws ecr create-repository --repository-name frontend
aws ecr create-repository --repository-name backend

frontend_repo=$(aws ecr describe-repositories --repository-names frontend --query 'repositories[0].repositoryUri' --output text)
backend_repo=$(aws ecr describe-repositories --repository-names backend --query 'repositories[0].repositoryUri' --output text)

## images 打 tag
docker tag frontend:latest ${frontend_repo}:latest
docker tag backend:latest ${backend_repo}:latest

## 登录 ECR
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --output text --query Account)
AWS_REGION=$(aws configure get region)
aws ecr get-login-password | docker login --username AWS --password-stdin https://${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com

## 拖送
docker push ${frontend_repo}:latest
docker push ${backend_repo}:latest



