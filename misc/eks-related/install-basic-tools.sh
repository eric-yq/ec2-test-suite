## 安装 基础工具
sudo yum -y install jq bash-completion tree gettext moreutils

## 安装 docker-compose
COMPOSE_VERSION=$(curl -s "https://api.github.com/repos/docker/compose/releases/latest" |
  grep '"tag_name":' |
  sed -E 's/.*"v([^"]+)".*/\1/'
)
DOCKER_CONFIG=${DOCKER_CONFIG:-$HOME/.docker}
mkdir -p $DOCKER_CONFIG/cli-plugins
curl -SL https://github.com/docker/compose/releases/download/v${COMPOSE_VERSION}/docker-compose-linux-x86_64 -o $DOCKER_CONFIG/cli-plugins/docker-compose
chmod +x $DOCKER_CONFIG/cli-plugins/docker-compose

## 安装 kubectl
sudo curl -L -o /usr/local/bin/kubectl https://s3.us-west-2.amazonaws.com/amazon-eks/1.30.0/2024-05-12/bin/linux/amd64/kubectl
sudo chmod +x /usr/local/bin/kubectl
kubectl version --client
kubectl completion bash > kubectl_completion
sudo mv kubectl_completion /etc/bash_completion.d/kubectl

## 安装 eksctl 
curl -L "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/eksctl /usr/local/bin
eksctl completion bash > eksctl_completion
sudo mv eksctl_completion /etc/bash_completion.d/eksctl

####################################################################################################
## 其他小工具
sudo curl -L -o /etc/bash_completion.d/docker https://raw.githubusercontent.com/docker/cli/master/contrib/completion/bash/docker
cat <<"EOT" >> ${HOME}/.bashrc

alias k="kubectl"
complete -o default -F __start_kubectl k
EOT
git clone https://github.com/jonmosco/kube-ps1.git ~/.kube-ps1
cat <<"EOT" >> ~/.bashrc

source ~/.kube-ps1/kube-ps1.sh
function get_cluster_short() {
  echo "$1" | cut -d . -f1
}
KUBE_PS1_CLUSTER_FUNCTION=get_cluster_short
KUBE_PS1_SUFFIX=') '
PS1='$(kube_ps1)'$PS1
EOT

## kubectx / kubens
git clone https://github.com/ahmetb/kubectx.git ~/.kubectx
sudo ln -sf ~/.kubectx/completion/kubens.bash /etc/bash_completion.d/kubens
sudo ln -sf ~/.kubectx/completion/kubectx.bash /etc/bash_completion.d/kubectx
cat <<"EOT" >> ~/.bashrc

export PATH=~/.kubectx:$PATH
EOT

## stern
STERN_VERSION=$(curl -s "https://api.github.com/repos/stern/stern/releases/latest" |
  grep '"tag_name":' |
  sed -E 's/.*"v([^"]+)".*/\1/'
)
curl -L "https://github.com/stern/stern/releases/download/v${STERN_VERSION}/stern_${STERN_VERSION}_linux_amd64.tar.gz" | tar xz -C /tmp
sudo mv /tmp/stern /usr/local/bin

## 生效。
. ~/.bashrc
. /etc/profile.d/bash_completion.sh
. /etc/bash_completion.d/kubectl
. /etc/bash_completion.d/eksctl
. /etc/bash_completion.d/docker
####################################################################################################


