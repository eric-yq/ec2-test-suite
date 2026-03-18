#!/bin/bash

set -e

echo "Installing unzip..."
sudo yum -y install unzip

echo "Installing kiro-cli..."
curl -fsSL https://cli.kiro.dev/install | bash

echo "Logging in to kiro-cli..."
echo "You will be prompted for:"
echo "  Start URL (e.g., https://amzn.awsapps.com/start)"
echo "  Region (e.g., us-east-1)"
echo "If needed, check Link for more guidance: https://docs.hub.amazon.dev/kiro/user-guide/getting-started-cli/"
kiro-cli login --use-device-flow

echo "Verifying login..."
kiro-cli whoami

echo "Installation complete!"