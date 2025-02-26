## 安装AWS CLI

aws configure

## 同步数据
aws sync 


## 启动  EMR 7.1 cluster with Iceberg enabled

aws emr create-cluster \
--applications Name=Hadoop Name=Spark \
--configurations file://configurations.json \
--ec2-attributes '{"KeyName":"ericyq-global","InstanceProfile":"EMR_EC2_DefaultRole","SubnetId":"subnet-046de201cd71d1cde","EmrManagedSlaveSecurityGroup":"sg-0f63c1d8fc002c053","EmrManagedMasterSecurityGroup":"sg-0f63c1d8fc002c053"}' \
--release-label emr-7.1.0 \
--log-uri s3://$YOUR_S3_BUCKET/elasticmapreduce/ \
--instance-groups '[{"InstanceCount":4,"EbsConfiguration":{"EbsOptimized":true},"InstanceGroupType":"CORE","InstanceType":"r6id.4xlarge","Name":"Core - 2"},{"InstanceCount":1,"EbsConfiguration":{"EbsOptimized":true},"InstanceGroupType":"MASTER","InstanceType":"r6id.4xlarge","Name":"Master - 1"}]' \
--auto-scaling-role EMR_AutoScaling_DefaultRole \
--ebs-root-volume-size 10 \
--service-role EMR_DefaultRole \
--enable-debugging \
--name test-cluster \
--scale-down-behavior TERMINATE_AT_TASK_COMPLETION \
--region us-west-2

## 环境信息
export YOUR_S3_BUCKET=ericyq-bucket-us-west-2
export YOUR_CLUSTERID=j-3QPYLYH7Q7KWS  
export YOUR_REGION=us-west-2

## 创建 Iceberg 表
aws emr add-steps --cluster-id $YOUR_CLUSTERID --steps Type=Spark,Name="Create Iceberg Tables",Args=[--class,com.amazonaws.eks.tpcds.CreateIcebergTables,--conf,spark.jars=/usr/share/aws/iceberg/lib/iceberg-spark3-runtime.jar,--conf,spark.sql.extensions=org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,--conf,spark.sql.catalog.hadoop_catalog=org.apache.iceberg.spark.SparkCatalog,--conf,spark.sql.catalog.hadoop_catalog.type=hadoop,--conf,spark.sql.catalog.hadoop_catalog.warehouse=s3://$YOUR_S3_BUCKET/blog/BLOG_TPCDS-TEST-3T-partitioned/,--conf,spark.sql.catalog.hadoop_catalog.io-impl=org.apache.iceberg.aws.s3.S3FileIO,s3://$YOUR_S3_BUCKET/blog/spark-benchmark-assembly-3.5.1.jar,s3://$YOUR_S3_BUCKET/blog/BLOG_TPCDS-TEST-3T-partitioned/,/home/hadoop/tpcds-kit/tools,parquet,3000,true,tpcds-database,true,true],ActionOnFailure=CONTINUE --region $YOUR_REGION

