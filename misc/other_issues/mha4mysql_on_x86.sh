# EC2 Instance: t3a.small ( x86 )
# OS: ami-0be9dd52e05f424f3 ( RHEL-8.9.0_HVM-20240327-x86_64-4-Hourly2-GP3)

sudo su - root
yum update

yum install -y perl gcc wget
yum install -y perl-DBD-MySQL perl-DBD-Pg perl-Config-Perl-V perl-PCP-LogImport perl-PCP-LogSummary perl-Sys-Syslog perl-Unix-Syslog perl-DBD-SQLite perl-XML-Catalog perl-libnetcfg

yum install -y perl-App-cpanminus
cpan inc::Module::Install
cpanm Config::Tiny
cpanm Log::Dispatch
cpanm Parallel::ForkManager

wget https://github.com/yoshinorim/mha4mysql-node/releases/download/v0.58/mha4mysql-node-0.58-0.el7.centos.noarch.rpm
wget https://github.com/yoshinorim/mha4mysql-manager/releases/download/v0.58/mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
rpm -ivh mha4mysql-node-0.58-0.el7.centos.noarch.rpm
rpm -ivh mha4mysql-manager-0.58-0.el7.centos.noarch.rpm
