# Download and install nvm:
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash

# in lieu of restarting the shell
\. "$HOME/.nvm/nvm.sh"

# Download and install Node.js:
nvm install 24

# Verify the Node.js version:
node -v # Should print "v24.12.0".

# Verify npm version:
npm -v # Should print "11.6.2".

# 安装各种开发工具包
yum group install -yq development
yum install -yq java-11-amazon-corretto-devel java-11-amazon-corretto docker 
systemctl enable docker
systemctl start  docker
# 更新 cmake
cd /root/
ARCH=$(arch) 
VER=3.29.6
wget https://github.com/Kitware/CMake/releases/download/v${VER}/cmake-${VER}-linux-${ARCH}.sh
sh cmake-${VER}-linux-${ARCH}.sh --skip-license --prefix=/usr
cmake -version
# 更新 maven
cd /root/
VER=3.9.11
wget https://dlcdn.apache.org/maven/maven-3/${VER}/binaries/apache-maven-${VER}-bin.tar.gz
tar zxf apache-maven-${VER}-bin.tar.gz -C /usr/ --strip-components 1
mvn -v

# 配置AWS CLI
aws_ak_value="xxx"
aws_sk_value="xxx"
aws_region_name=$(cloud-init query region)
aws configure set aws_access_key_id ${aws_ak_value}
aws configure set aws_secret_access_key ${aws_sk_value}
aws configure set default.region ${aws_region_name}

## 安装 ATX 
curl -fsSL https://desktop-release.transform.us-east-1.api.aws/install.sh | bash
atx --version

## 下载代码库
git clone https://github.com/eric-yq/ec2-test-suite.git
cp -r ec2-test-suite/misc/demo-code-for-graviton-migration /root/

## 初始化需要porting的代码库
cd /root/demo-code-for-graviton-migration
git init
git add .
git commit -m "Initial commit before Graviton migration"

## 开始
