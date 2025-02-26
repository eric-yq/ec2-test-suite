
## 创建EKS 集群
eksctl create cluster --name eks-cluster \
  --nodegroup-name eks-nodes --node-type c6i.xlarge --nodes 2 --nodes-min 1 --nodes-max 4 --managed \
  --version 1.26 --region us-west-2
  
## 查看集群
eksctl get cluster

## 查看节点
kubectl cluster-info
kubectl get nodes
kubectl describe node

## 查看 pod
kubectl get namespace
kubectl get pod -n default
kubectl get pod -A
kubectl get pod -n kube-system -o wide
POD_NAME="aws-node-pkk6l"
kubectl describe pod $POD_NAME -n kube-system
kubectl get pod ${POD_NAME} -n kube-system -o yaml
kubectl get pod ${POD_NAME} -n kube-system -o json
kubectl get pod ${POD_NAME} -n kube-system -o json | jq -r '.metadata.name'
kubectl get pod ${POD_NAME} -n kube-system -o jsonpath='{.metadata.name}'

## 命名空间
kubens kube-system ## 切换命名空间
kubectl get pod -n kube-system

## 其他
kubectl get service -A
kubectl get deployment -A
kubectl get daemonset -A

kubectl get all -A

## 
