# EC2 Instance: c6g.large ( Graviton 2 )
# OS: ami-09250b61092f883c3 ( RHEL-8.9.0_HVM-20240327-arm64-4-Hourly2-GP3 )

sudo su - root
yum update

# 1. Install node

yum install -y perl-DBD-MySQL

## Get MHA Node rpm package 
yum install -y wget
wget https://github.com/yoshinorim/mha4mysql-node/releases/download/v0.58/mha4mysql-node-0.58-0.el7.centos.noarch.rpm
rpm -ivh mha4mysql-node-0.58-0.el7.centos.noarch.rpm

# 2. Install manager
## Install EPEL-Release repository
wget https://dl.fedoraproject.org/pub/epel/8/Everything/aarch64/Packages/e/epel-release-8-21.el8.noarch.rpm
rpm -ivh epel-release-8-21.el8.noarch.rpm 

## Enable codeready-builder-for-rhel-8 repository
yum repolist codeready-builder-*
# repo id                                                                     repo name                                                                                                status
# codeready-builder-for-rhel-8-rhui-debug-rpms                                Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (Debug RPMs) from RHUI                                disabled
# codeready-builder-for-rhel-8-rhui-rpms                                      Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (RPMs) from RHUI                                      disabled
# codeready-builder-for-rhel-8-rhui-source-rpms                               Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (Source RPMs) from RHUI                               disabled

yum-config-manager --enable codeready-builder-*

yum repolist codeready-builder-*
# repo id                                                                     repo name                                                                                                status                                                                 repo name                                                                                                 status
# codeready-builder-for-rhel-8-rhui-debug-rpms                                Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (Debug RPMs) from RHUI                                 enabled
# codeready-builder-for-rhel-8-rhui-rpms                                      Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (RPMs) from RHUI                                       enabled
# codeready-builder-for-rhel-8-rhui-source-rpms                               Red Hat CodeReady Linux Builder for RHEL 8 aarch64 (Source RPMs) from RHUI                                enabled

## Install Perf dependency
yum install -y perl-DBD-MySQL
yum install -y perl-Config-Tiny
yum install -y perl-Log-Dispatch
yum install -y perl-Parallel-ForkManager
yum install -y perl-Time-HiRes

## Finally, download/install MHA node and Manager
wget https://github.com/yoshinorim/mha4mysql-node/releases/download/v0.58/mha4mysql-node-0.58-0.el7.centos.noarch.rpm
wget https://github.com/yoshinorim/mha4mysql-manager/releases/download/v0.58/mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
rpm -ivh mha4mysql-node-0.58-0.el7.centos.noarch.rpm
rpm -ivh mha4mysql-manager-0.58-0.el7.centos.noarch.rpm

# [root@ip-172-31-56-109 ~]# rpm -ivh mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
# Verifying...                          ################################# [100%]
# Preparing...                          ################################# [100%]
# Updating / installing...
#    1:mha4mysql-manager-0.58-0.el7.cent################################# [100%]


####################################################################################################
### Register personal account, country use USA.
# https://www.redhat.com/wapps/ugc/register.html
### Redhat trial
# https://www.redhat.com/en/technologies/linux-platforms/enterprise-linux/server/trial
### Register in OS:
# [20241012-191726.930] [root@ip-172-31-49-60 ~]# sudo subscription-manager register
# [20241012-191727.297] Registering to: subscription.rhsm.redhat.com:443/subscription
# [20241012-191729.882] Username: ericyq
# [20241012-191733.443] Password: 
# [20241012-191737.959] The system has been registered with ID: 2d962e1d-ea36-4200-b7b3-ab50daf807a4
# [20241012-191737.960] The registered system name is: ip-172-31-49-60.us-west-2.compute.internal
####################################################################################################

