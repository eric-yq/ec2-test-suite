#!/bin/bash
# Build script for loadgen Docker images with ECR support
# - PUSH_TO_ECR=public  → push to ECR Public
# - PUSH_TO_ECR=private → push to ECR Private
# - unset / other       → build only, no push

set -e

# Configuration
IMAGE_NAME="loadgen-tools"
VERSION="1.0.0"
PUSH_TO_ECR="${PUSH_TO_ECR:-}"  # "public" or "private"
ECR_PUBLIC_ALIAS="${ECR_PUBLIC_ALIAS:-$(aws ecr-public describe-registries --region us-east-1 --query 'registries[0].aliases[?primaryRegistryAlias==`true`].name' --output text 2>/dev/null || echo '')}"
AWS_REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo 'us-east-1')}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo '')}"

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

echo "Building loadgen Docker image..."
echo "================================"
echo "Architecture: $ARCH"
echo "Platform: $PLATFORM"
echo "Dockerfile: $DOCKERFILE"
echo "AWS Region: $AWS_REGION"
if [ -n "$ECR_PUBLIC_ALIAS" ]; then
    echo "ECR Public Alias: $ECR_PUBLIC_ALIAS"
elif [ -n "$AWS_ACCOUNT_ID" ]; then
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

# Push to ECR if requested
if [ "$PUSH_TO_ECR" = "public" ] || [ "$PUSH_TO_ECR" = "private" ]; then

    # Check if AWS CLI is installed
    if ! command -v aws &> /dev/null; then
        echo "Error: AWS CLI is not installed"
        echo "Please install AWS CLI: https://aws.amazon.com/cli/"
        exit 1
    fi

    ECR_REPO_NAME="${IMAGE_NAME}"

    # Determine push target
    if [ "$PUSH_TO_ECR" = "public" ]; then
        #############################
        # ECR Public
        #############################
        # ecr-public API calls must use us-east-1
        if [ -z "$ECR_PUBLIC_ALIAS" ]; then
            echo "Error: ECR_PUBLIC_ALIAS is empty and could not be auto-detected"
            echo "Please set it: export ECR_PUBLIC_ALIAS=<your-alias>"
            echo "Or check: https://us-east-1.console.aws.amazon.com/ecr/public-registry"
            exit 1
        fi

        ECR_REGISTRY="public.ecr.aws/${ECR_PUBLIC_ALIAS}"

        echo "================================"
        echo "Pushing to Amazon ECR Public..."
        echo "================================"
        echo ""

        echo "Step 2: Checking ECR Public repository..."
        echo "--------------------------------"
        echo "Repository: ${ECR_REPO_NAME}"
        echo "Registry: ${ECR_REGISTRY}"
        echo ""

        # ecr-public API calls must use us-east-1
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
        echo "Step 3: Logging in to ECR Public..."
        echo "--------------------------------"
        aws ecr-public get-login-password --region us-east-1 | \
            docker login --username AWS --password-stdin public.ecr.aws
        echo "✓ Successfully logged in to ECR Public"

    else
        #############################
        # ECR Private
        #############################
        if [ -z "$AWS_ACCOUNT_ID" ]; then
            echo "Error: AWS credentials not configured"
            echo "Please run: aws configure"
            exit 1
        fi

        ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

        echo "================================"
        echo "Pushing to Amazon ECR Private..."
        echo "================================"
        echo ""

        echo "Step 2: Checking ECR Private repository..."
        echo "--------------------------------"
        echo "Repository: ${ECR_REPO_NAME}"
        echo "Registry: ${ECR_REGISTRY}"
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

            # Set lifecycle policy to keep only last 10 images
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
        echo "Step 3: Logging in to ECR Private..."
        echo "--------------------------------"
        aws ecr get-login-password --region ${AWS_REGION} | \
            docker login --username AWS --password-stdin ${ECR_REGISTRY}
        echo "✓ Successfully logged in to ECR"
    fi

    # Common: tag, push, and print results
    echo ""
    echo "Step 4: Tagging images..."
    echo "--------------------------------"
    docker tag ${IMAGE_NAME}:${VERSION}${TAG_SUFFIX} ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    docker tag ${IMAGE_NAME}:latest${TAG_SUFFIX} ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}
    echo "✓ Images tagged"

    echo ""
    echo "Step 5: Pushing images..."
    echo "--------------------------------"
    echo "Pushing ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}..."
    docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}
    echo ""
    echo "Pushing ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}..."
    docker push ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}

    echo ""
    echo "================================"
    echo "Push complete!"
    echo "================================"
    echo ""
    echo "Image URIs:"
    echo "  ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}${TAG_SUFFIX}"
    echo "  ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
    echo ""

    if [ "$PUSH_TO_ECR" = "public" ]; then
        echo "To pull (no auth needed):"
        echo "  docker pull ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
        echo ""
        echo "Console: https://gallery.ecr.aws/${ECR_PUBLIC_ALIAS}/${ECR_REPO_NAME}"
    else
        echo "To pull:"
        echo "  docker pull ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest${TAG_SUFFIX}"
        echo ""
        echo "Console: https://${AWS_REGION}.console.aws.amazon.com/ecr/repositories/private/${AWS_ACCOUNT_ID}/${ECR_REPO_NAME}"
    fi
    echo ""
fi

echo "================================"
echo "All done!"
echo "================================"

# Create multi-arch manifest if requested
if [ "$CREATE_MANIFEST" = "true" ] && ([ "$PUSH_TO_ECR" = "public" ] || [ "$PUSH_TO_ECR" = "private" ]); then
    echo ""
    echo "================================"
    echo "Creating multi-arch manifest..."
    echo "================================"
    echo ""

    MANIFEST_TAG="${VERSION}"
    MANIFEST_LATEST="latest"

    echo "Step 6: Creating manifest for version ${MANIFEST_TAG}..."
    echo "--------------------------------"

    docker manifest create ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_TAG} \
        --amend ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}-amd64 \
        --amend ${ECR_REGISTRY}/${ECR_REPO_NAME}:${VERSION}-arm64 2>/dev/null || \
        echo "Note: Both amd64 and arm64 images must be pushed to create manifest"

    docker manifest create ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_LATEST} \
        --amend ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest-amd64 \
        --amend ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest-arm64 2>/dev/null || \
        echo "Note: Both amd64 and arm64 images must be pushed to create manifest"

    echo ""
    echo "Step 7: Pushing manifests..."
    echo "--------------------------------"

    docker manifest push ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_TAG} || true
    docker manifest push ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_LATEST} || true

    echo ""
    echo "================================"
    echo "Multi-arch manifest created!"
    echo "================================"
    echo ""
    echo "Manifest URIs:"
    echo "  ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_TAG}"
    echo "  ${ECR_REGISTRY}/${ECR_REPO_NAME}:${MANIFEST_LATEST}"
    echo ""
    echo "To use the multi-arch image:"
    echo "  docker pull ${ECR_REGISTRY}/${ECR_REPO_NAME}:latest"
    echo "  (Docker will automatically pull the correct architecture)"
    echo ""
fi
