## tidb-cluster.yaml 
apiVersion: eksctl.io/v1alpha5
kind: ClusterConfig
metadata:
  name: tidb-cluster
  region: us-east-2
addons:
  - name: aws-ebs-csi-driver

nodeGroups:
  - name: admin
    desiredCapacity: 1
    privateNetworking: true
    availabilityZones: ["us-east-2a"]
    instanceType: c6i.large
    labels:
      dedicated: admin
    iam:
      withAddonPolicies:
        ebs: true
    
  - name: tidb
    desiredCapacity: 2
    privateNetworking: true
    availabilityZones: ["us-east-2a"]
    instanceType: c6i.2xlarge
    labels:
      dedicated: tidb
    taints:
      dedicated: tidb:NoSchedule
    iam:
      withAddonPolicies:
        ebs: true
    
  - name: pd
    desiredCapacity: 1
    privateNetworking: true
    availabilityZones: ["us-east-2a"]
    instanceType: c6i.large
    labels:
      dedicated: pd
    taints:
      dedicated: pd:NoSchedule
    iam:
      withAddonPolicies:
        ebs: true
    
  - name: tikv
    desiredCapacity: 3
    privateNetworking: true
    availabilityZones: ["us-east-2a"]
    instanceType: r6i.2xlarge
    labels:
      dedicated: tikv
    taints:
      dedicated: tikv:NoSchedule
    iam:
      withAddonPolicies:
        ebs: true
    
  - name: tiflash
    desiredCapacity: 3
    privateNetworking: true
    availabilityZones: ["us-east-2a"]
    instanceType: r6i.2xlarge
    labels:
      dedicated: tiflash
    taints:
      dedicated: tiflash:NoSchedule
    iam:
      withAddonPolicies:
        ebs: true

# 创建集群
eksctl create cluster -f tidb-cluster.yaml 

# 创建 IAM
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=tidb-cluster --approve
eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster tidb-cluster \
        --role-name AmazonEKS_EBS_CSI_DriverRole \
        --role-only \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve

# 设置 ebs-csi-node toleration
kubectl patch -n kube-system ds ebs-csi-node -p '{"spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}'


cat  > tikv-gp3-storageclass.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp3-tikv
provisioner: ebs.csi.aws.com
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  fsType: ext4
  iops: "4000"
  throughput: "400"
mountOptions:
  - nodelalloc
  - noatime
EOF

cat > tiflash-gp3-storageclass.yaml << EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: gp3-tiflash
provisioner: ebs.csi.aws.com
allowVolumeExpansion: true
volumeBindingMode: WaitForFirstConsumer
parameters:
  type: gp3
  fsType: ext4
  iops: "6000"
  throughput: "600"
mountOptions:
  - nodelalloc
  - noatime
EOF

# 应用这两个 StorageClass
kubectl apply -f tikv-gp3-storageclass.yaml
kubectl apply -f tiflash-gp3-storageclass.yaml
kubectl apply -f default-gp3-storageclass.yaml
kubectl get storageclass gp3-tikv gp3-tiflash gp3-default
kubectl get sc

# 部署 TiDB Operator
## 安装 TiDB Operator CRDs
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/manifests/crd.yaml
## 添加 PingCAP 仓库。
helm repo add pingcap https://charts.pingcap.org/
## 为 TiDB Operator 创建一个命名空间。
kubectl create namespace tidb-admin
## 安装 TiDB Operator
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.6.3
## 查看 TiDB Operator Pod 状态
kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator

# 部署 TiDB 集群
## 创建 TiDB 集群命名空间
kubectl create namespace tidb-cluster
## 下载 TidbCluster 和 TidbMonitor CR 的配置文件。
mkdir -p tidb-cluster-software-config
cd tidb-cluster-software-config
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-cluster.yaml
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-monitor.yaml
curl -O https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/examples/aws/tidb-dashboard.yaml
###### 修改参数，参考 tidb-cluster-software-config/tidb-cluster.yaml ######
# ......
## 执行部署 TiDB 集群
kubectl apply -f tidb-cluster.yaml -n tidb-cluster
## 查看 TiDB 集群 Pod 状态
kubectl get pods -n tidb-cluster
kubectl get pvc  -n tidb-cluster 

## 附加：删除 TiDB 集群
kubectl delete tc basic -n tidb-cluster


# 测试 mysql 客户端远程访问
EXTERNAL_IP=$(kubectl get svc basic-tidb -n tidb-cluster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo $EXTERNAL_IP

mysql --comments -h a69ffeedf46f247f8bb0203acd486c43-78d600dac3ead463.elb.us-east-2.amazonaws.com -P 4000 -u root