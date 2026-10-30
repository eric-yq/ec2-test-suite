#!/bin/bash

# 本次要测试的实例家族类型，通过脚本执行时的环境变量带入
# INSTANCE_FAMILY="r9g" bash deploy-tidb-cluster-on-eks.sh  带入

# 准备配置文件
cp -r template ${INSTANCE_FAMILY}
cd ${INSTANCE_FAMILY}
sed -i "s/8g/${INSTANCE_FAMILY: -2}/g" eks/tidb-cluster.yaml

###################################################################################################
# 创建集群：测试选择 us-east-2 region
echo "[Info] Create EKS cluster ..." 
eksctl create cluster -f eks/tidb-cluster.yaml 

# 创建 IAM
eksctl utils associate-iam-oidc-provider --region=us-east-2 --cluster=tidb-${INSTANCE_FAMILY} --approve
eksctl create iamserviceaccount \
        --name ebs-csi-controller-sa \
        --namespace kube-system \
        --cluster tidb-${INSTANCE_FAMILY} \
        --role-name AmazonEKS_EBS_CSI_DriverRole-${INSTANCE_FAMILY} \
        --role-only \
        --attach-policy-arn arn:aws:iam::aws:policy/service-role/AmazonEBSCSIDriverPolicy \
        --approve

# 设置 ebs-csi-node toleration
kubectl patch -n kube-system ds ebs-csi-node -p '{"spec":{"template":{"spec":{"tolerations":[{"operator":"Exists"}]}}}}'

# 应用这 3 个 StorageClass
kubectl apply -f eks/tikv-gp3-storageclass.yaml
kubectl apply -f eks/tiflash-gp3-storageclass.yaml
kubectl apply -f eks/default-gp3-storageclass.yaml
kubectl get storageclass gp3-tikv gp3-tiflash gp3-default
kubectl get sc

###################################################################################################
# 部署 TiDB Operator
## 安装 TiDB Operator CRDs
echo "[Info] Create TiDB Operator CRDs ..." 
kubectl create -f https://raw.githubusercontent.com/pingcap/tidb-operator/v1.6.3/manifests/crd.yaml
## 添加 PingCAP 仓库
helm repo add pingcap https://charts.pingcap.com/
## 为 TiDB Operator 创建一个命名空间
kubectl create namespace tidb-admin
## 安装 TiDB Operator
helm install --namespace tidb-admin tidb-operator pingcap/tidb-operator --version v1.6.3
## 查看 TiDB Operator Pod 状态
kubectl get pods --namespace tidb-admin -l app.kubernetes.io/instance=tidb-operator

###################################################################################################
# 部署 TiDB 集群
## 创建 TiDB 集群命名空间
echo "[Info] Deploy TiDB cluster ..." 
kubectl create namespace tidb-${INSTANCE_FAMILY}
## 执行部署 TiDB 集群
kubectl apply -f tidb/tidb-cluster.yaml -n tidb-${INSTANCE_FAMILY}
## 查看 TiDB 集群 Pod 状态
kubectl get pvc  -n tidb-${INSTANCE_FAMILY} -o wide
kubectl get pods -n tidb-${INSTANCE_FAMILY} -o wide

# 查询 TiDB 访问地址
tidb_host=$(kubectl get svc basic-tidb -n tidb-${INSTANCE_FAMILY} \
  -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "[Info] TiDB Host(${INSTANCE_FAMILY}): $tidb_host" 
echo "$tidb_host" >> tidb_host.txt
