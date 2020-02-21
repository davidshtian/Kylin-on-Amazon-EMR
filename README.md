# Kylin-on-Amazon-EMR
快速在Amazon EMR集群中部署Apache Kylin。

通过脚本kylin-on-emr.sh可以在EMR集群中通过步骤的方式快速地完成Kylin的部署，可以使用如下的AWS CLI命令进行一键安装：

```
aws emr create-cluster \
--name <replace with your cluster name> \
--release-label emr-5.29.0 \
--applications Name=Hadoop Name=Hive Name=HBase Name=Spark \
--use-default-roles \
--auto-scaling-role EMR_AutoScaling_DefaultRole \
--ec2-attributes KeyName=<replace with your ssh key> \
--instance-type m5.xlarge \
--instance-count 3 \
--enable-debugging \
--log-uri <replace with s3 bucket for cluster logging> \
--configurations '[{"Classification":"hive-site","Properties":{"hive.metastore.client.factory.class":"com.amazonaws.glue.catalog.metastore.AWSGlueDataCatalogHiveClientFactory"}}]' \
--steps Type=CUSTOM_JAR,Name=CustomJAR,ActionOnFailure=CONTINUE,Jar=s3:// <replace with your region>.elasticmapreduce/libs/script-runner/script-runner.jar,Args=["<replace with your script kylin-on-emr.sh s3 location>","<Kylin version>","<location>","<whether use Glue as Hive metastore>"]

```

目前脚本接收3个参数（后续会逐渐规范化脚本）：
* 第一个参数是Kylin的版本如"3.0.0"、"2.6.5"等；
* 第二个参数是所在的区域，可以填写"cn"或者是"global"，脚本会根据不同区域选择不同的Kylin下载源；
* 第三个参数是是否使用AWS Glue作为Hive的metastore，可以设置的值为"glue"或者留空。如果不使用Glue，则无需添加上述AWS CLI中的configurations配置选项；如果使用Glue，第一个参数需要修改为"3.1.0-SNAPSHOT"，并且需要添加如上命令的EMR配置。

*注：以上脚本使用基于HBase1x 的Apache Kylin v3.0.0和v2.6.5在美国东部 (弗吉尼亚北部) us-east-1的EMR 5.29.0版本中测试通过，如果使用其他Apache Kylin在EMR 版本根据实际情况可能需要微调。

*注：基于HBase1x 的Apache Kylin 3.1.0-SNAPSHOT版本在美国东部 (弗吉尼亚北部) us-east-1的EMR 5.29.0版本中测试通过。该版本是根据Apache Kylin目前GitHub源码进行修改后进行编译打包的版本，仅供测试使用，官方版本需要等待3.1.0版本的正式发布。

*注：AWS Glue 是一种完全托管的服务，提供数据目录以使数据湖中的数据可被发现，并且能够执行提取、转换和加载 (ETL) 以准备数据进行分析。数据目录会自动创建为所有数据资产的持久元数据存储，支持在一个视图中搜索和查询所有数据。数据湖是一个集中式存储库，允许以任意规模存储所有结构化和非结构化数据，数据可以按原样进行存储（无需将其转换为预先定义的数据结构）。在数据湖之上可以运行不同类型的分析 – 从控制面板和可视化到大数据处理、实时分析和机器学习，以指导做出更好的决策。
