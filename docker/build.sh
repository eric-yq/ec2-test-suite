#!/bin/bash
# Build script for loadgen Docker images with ECR support
# - PUSH_TO_ECR=public  → push to ECR Public
# - PUSH_TO_ECR=private → push to ECR Private
# - PUSH_TO_ECR=both    → push to both ECR Public and Private
# - unset / other       → build only, no push

set -e

# Configuration
IMAGE_NAME="loadgen-tools"
VERSION="1.0.0"
PUSH_TO_ECR="${PUSH_TO_ECR:-}"  # "public", "private", or "both"
ECR_PUBLIC_ALIAS="${ECR_PUBLIC_ALIAS:-$(aws ecr-public describe-registries --region us-east-1 --query 'registries[0].aliases[?primaryRegistryAlias==`true`].name' --output text 2>/dev/null || echo '')}"
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo 'us-east-1')}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo '')}"
ECR_REPO_NAME="${IMAGE_NAME}"

# Detect architecture
ARCH=$(uname -m)
if [ "$ARCH" = "aarch64" ]; then
    PLATFORM="linux/arm64"
    DOCKERFILE="Dockerfile.arm64"
    TAG_SUFFIX="-arm64"
elif [ "$ARCH" = "x86_64" ]; then
    PLATFORM="linux/amd64"
    DOCKERFILE="Dockerfile"
    TAG_SUFFIX="-amd64"
else
    echo "Unsupported architecture: $ARCH"
    exit 1
fi

###############################################################################
# Push functions
###############################################################################

push_to_ecr_public() {
    local registry="public.ecr.aws/${ECR_PUBLIC_ALIAS}"

    echo "================================"
    echo "Pushing to Amazon ECR Public..."
    echo "================================"
    echo ""

    if [ -z "$ECR_PUBLIC_ALIAS" ]; then
        echo "Error: ECR_PUBLIC_ALIAS is empty and could not be auto-detected"
        echo "Please set it: export ECR_PUBLIC_ALIAS=<your-alias>"
        echo "Or check: https://us-east-1.console.aws.amazon.com/ecr/public-registry"
        return 1
    fi

    echo "Checking ECR Public repository..."
    echo "  Repository: ${ECR_REPO_NAME}"
    echo "  Registry:   ${registry}"
    echo ""

    if ! aws ecr-public describe-repositories --repository-names ${ECR_REPO_NAME} --region us-east-1 &> /dev/null; then
        echo "ECR Public repository '${ECR_REPO_NAME}' does not exist. Creating..."
        aws ecr-public create-repository \
            --repository-name ${ECR_REPO_NAME} \
            --region us-east-1 \
            --catalog-data '{
                "description": "Loadgen tools for EC2 benchmark automation",
                "architectures": ["x86-64", "ARM 64"],
                "operatingSystems": ["Linux"]
            }' \
            --tags Key=Name,Value=${ECR_REPO_NAME} Key=ManagedBy,Value=build-script
        echo "✓ ECR Public repository created successfully"
    else
        echo "✓ ECR Public repository '${ECR_REPO_NAME}' already exists"
    fi

    echo ""
    echo "Logging in to ECR Public..."
    aws ecr-public get-login-password --region us-east-1 | \
        docker login --username AWS --password-stdin public.ecr.aws
    echo "✓ Successfully logged in to ECR Public"

    echo ""
    echo "Tagging and pushing images..."
    docker tag ${IMAGE_NAME}:${VERSION}${TAG_SUFFIX} ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    docker tag ${IMAGE_NAME}:latest${TAG_SUFFIX} ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}
    docker push ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    docker push ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}

    echo ""
    echo "✓ ECR Public push complete"
    echo "  ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}"
    echo "  ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
    echo "  Pull (no auth): docker pull ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
    echo "  Console: https://gallery.ecr.aws/${ECR_PUBLIC_ALIAS}/${ECR_REPO_NAME}"
    echo ""

    # Save for manifest creation
    ECR_PUBLIC_REGISTRY="${registry}"
}

push_to_ecr_private() {
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        echo "Error: AWS credentials not configured"
        echo "Please run: aws configure"
        return 1
    fi

    local registry="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

    echo "================================"
    echo "Pushing to Amazon ECR Private..."
    echo "================================"
    echo ""

    echo "Checking ECR Private repository..."
    echo "  Repository: ${ECR_REPO_NAME}"
    echo "  Registry:   ${registry}"
    echo ""

    if ! aws ecr describe-repositories --repository-names ${ECR_REPO_NAME} --region ${AWS_REGION} &> /dev/null; then
        echo "ECR repository '${ECR_REPO_NAME}' does not exist. Creating..."
        aws ecr create-repository \
            --repository-name ${ECR_REPO_NAME} \
            --region ${AWS_REGION} \
            --image-scanning-configuration scanOnPush=true \
            --encryption-configuration encryptionType=AES256 \
            --tags Key=Name,Value=${ECR_REPO_NAME} Key=ManagedBy,Value=build-script
        echo "✓ ECR repository created successfully"

        echo "Setting lifecycle policy..."
        aws ecr put-lifecycle-policy \
            --repository-name ${ECR_REPO_NAME} \
            --region ${AWS_REGION} \
            --lifecycle-policy-text '{"rules": [{"rulePriority": 1,"description": "Keep last 10 images","selection": {"tagStatus": "any","countType": "imageCountMoreThan","countNumber": 10},"action": {"type": "expire"}}]}' > /dev/null
        echo "✓ Lifecycle policy set"
    else
        echo "✓ ECR repository '${ECR_REPO_NAME}' already exists"
    fi

    echo ""
    echo "Logging in to ECR Private..."
    aws ecr get-login-password --region ${AWS_REGION} | \
        docker login --username AWS --password-stdin ${registry}
    echo "✓ Successfully logged in to ECR"

    echo ""
    echo "Tagging and pushing images..."
    docker tag ${IMAGE_NAME}:${VERSION}${TAG_SUFFIX} ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    docker tag ${IMAGE_NAME}:latest${TAG_SUFFIX} ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}
    docker push ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    docker push ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}

    echo ""
    echo "✓ ECR Private push complete"
    echo "  ${registry}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}"
    echo "  ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
    echo "  Pull: docker pull ${registry}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
    echo "  Console: https://${AWS_REGION}.console.aws.amazon.com/ecr/repositories/private/${AWS_ACCOUNT_ID}/${ECR_REPO_NAME}"
    echo ""

    # Save for manifest creation
    ECR_PRIVATE_REGISTRY="${registry}"
}

create_manifest() {
    local registry="$1"
    echo ""
    echo "================================"
    echo "Creating multi-arch manifest for ${registry}..."
    echo "================================"
    echo ""

    docker manifest create ${registry}/${ECR_REPO_NAME}:${VERSION} \
        --amend ${registry}/${ECR_REPO_NAME}:${VERSION}-amd64 \
        --amend ${registry}/${ECR_REPO_NAME}:${VERSION}-arm64 2>/dev/null || \
        echo "Note: Both amd64 and arm64 images must be pushed to create manifest"

    docker manifest create ${registry}/${ECR_REPO_NAME}:latest \
        --amend ${registry}/${ECR_REPO_NAME}:latest-amd64 \
        --amend ${registry}/${ECR_REPO_NAME}:latest-arm64 2>/dev/null || \
        echo "Note: Both amd64 and arm64 images must be pushed to create manifest"

    docker manifest push ${registry}/${ECR_REPO_NAME}:${VERSION} || true
    docker manifest push ${registry}/${ECR_REPO_NAME}:latest || true

    echo ""
    echo "✓ Manifest pushed:"
    echo "  ${registry}/${ECR_REPO_NAME}:${VERSION}"
    echo "  ${registry}/${ECR_REPO_NAME}:latest"
    echo "  (Docker will automatically pull the correct architecture)"
    echo ""
}

###############################################################################
# Main
###############################################################################

echo "Building loadgen Docker image..."
echo "================================"
echo "Architecture: $ARCH"
echo "Platform: $PLATFORM"
echo "Dockerfile: $DOCKERFILE"
echo "AWS Region: $AWS_REGION"
echo "Push Mode: ${PUSH_TO_ECR:-none}"
if [ -n "$ECR_PUBLIC_ALIAS" ]; then
    echo "ECR Public Alias: $ECR_PUBLIC_ALIAS"
fi
if [ -n "$AWS_ACCOUNT_ID" ]; then
    echo "AWS Account: $AWS_ACCOUNT_ID"
fi
echo ""

# Build the image
echo "Step 1: Building Docker image..."
echo "--------------------------------"
docker build \
    --platform $PLATFORM \
    -f $DOCKERFILE \
    -t ${IMAGE_NAME}:${VERSION}${TAG_SUFFIX} \
    -t ${IMAGE_NAME}:latest${TAG_SUFFIX} \
    .

echo ""
echo "================================"
echo "Build complete!"
echo "================================"
echo ""
echo "Local image tags:"
echo "  ${IMAGE_NAME}:${VERSION}${TAG_SUFFIX}"
echo "  ${IMAGE_NAME}:latest${TAG_SUFFIX}"
echo ""
echo "To run the container:"
echo "  docker run -it --rm --name loadgen"
echo "    -v ~/.aws:/root/.aws:ro"
echo "    -v /run/cloud-init:/run/cloud-init:ro"
echo "    -v /root/ec2-test-suite:/root/ec2-test-suite"
echo "    ${IMAGE_NAME}:latest${TAG_SUFFIX}"
echo ""

# Push to ECR
if [ "$PUSH_TO_ECR" = "public" ] || [ "$PUSH_TO_ECR" = "private" ] || [ "$PUSH_TO_ECR" = "both" ]; then

    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed"
        echo "Please install AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi

    case "$PUSH_TO_ECR" in
        public)
            push_to_ecr_public
            ;;
        private)
            push_to_ecr_private
            ;;
        both)
            push_to_ecr_private
            push_to_ecr_public
            ;;
    esac
fi

echo "================================"
echo "All done!"
echo "================================"

# Create multi-arch manifest if requested
if [ "$CREATE_MANIFEST" = "true" ]; then
    case "$PUSH_TO_ECR" in
        public)
            create_manifest "${ECR_PUBLIC_REGISTRY}"
            ;;
        private)
            create_manifest "${ECR_PRIVATE_REGISTRY}"
            ;;
        both)
            create_manifest "${ECR_PRIVATE_REGISTRY}"
            create_manifest "${ECR_PUBLIC_REGISTRY}"
            ;;
    esac
fi
