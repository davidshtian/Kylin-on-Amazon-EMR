#!/bin/bash
set -e

# Get script args
VERSION=$1
LOCATION=$2

# Set basic variables used in this script
KYLIN_HOME=/usr/local/kylin/apache-kylin-$VERSION-bin-hbase1x
HIVE_HOME=/usr/lib/hive
SPARK_HOME=/usr/lib/spark
HBASE_HOME=/usr/lib/hbase
HOSTNAME=`hostname`

# Download and install Kylin
sudo mkdir -p /usr/local/kylin
sudo chown hadoop /usr/local/kylin
cd /usr/local/kylin

# Choose software URL based on the version and location
if [ $VERSION = "3.1.0-SNAPSHOT" ];then
wget http://d6zijbkibsp09.cloudfront.net/shtian/apache-kylin-3.1.0-SNAPSHOT-bin-hbase1x.tar.gz
elif [ $LOCATION = "cn" ];then
wget http://mirror.bit.edu.cn/apache/kylin/apache-kylin-$VERSION/apache-kylin-$VERSION-bin-hbase1x.tar.gz
elif [ $LOCATION = "global" ];then
wget http://us.mirrors.quenda.co/apache/kylin/apache-kylin-$VERSION/apache-kylin-$VERSION-bin-hbase1x.tar.gz
fi

# Unarchive the tarball
tar -zxvf apache-kylin-$VERSION-bin-hbase1x.tar.gz

# Modify Kylin HBase configuration
sed -i "/<configuration>/a\<property>\n  <name>hbase.zookeeper.quorum</name>\n  <value>$HOSTNAME</value>\n</property>" $KYLIN_HOME/conf/kylin_job_conf.xml

# Create the working-dir folder if it doesn’t exist
hadoop fs -mkdir -p /kylin/package/ 

# Solve jar conflict - Configure the environment
cat >> ~/.bashrc << EOF

# Kylin environment
export HIVE_HOME=/usr/lib/hive
export HADOOP_HOME=/usr/lib/hadoop
export HBASE_HOME=/usr/lib/hbase
export SPARK_HOME=/usr/lib/spark

export KYLIN_HOME=/usr/local/kylin/apache-kylin-$VERSION-bin-hbase1x
export HCAT_HOME=/usr/lib/hive-hcatalog
export KYLIN_CONF_HOME=$KYLIN_HOME/conf
export tomcat_root=$KYLIN_HOME/tomcat
export hive_dependency=$HIVE_HOME/conf:$HIVE_HOME/lib/:$HIVE_HOME/lib/hive-hcatalog-core*.jar:$SPARK_HOME/jars/
export PATH=$KYLIN_HOME/bin:$PATH

export hive_dependency=$HIVE_HOME/conf:$HIVE_HOME/lib/*:$HIVE_HOME/lib/hive-hcatalog-core*.jar:/usr/share/aws/hmclient/lib/*:$SPARK_HOME/jars/*:$HBASE_HOME/lib/*.jar:$HBASE_HOME/*.jar
EOF

# Source the env
source ~/.bashrc

# Solve jar conflict - Remove joda.jar
if [ -f "$HIVE_HOME/lib/jackson-datatype-joda-2.4.6.jar" ];then
sudo mv $HIVE_HOME/lib/jackson-datatype-joda-2.4.6.jar $HIVE_HOME/lib/jackson-datatype-joda-2.4.6.jar.backup
fi

# Solve jar conflict - Add following content on the top of bin/kylin.sh
sed -i '2i export HBASE_CLASSPATH_PREFIX=${tomcat_root}/bin/bootstrap.jar:${tomcat_root}/bin/tomcat-juli.jar:${tomcat_root}/lib/*:$hive_dependency:$HBASE_CLASSPATH_PREFIX' $KYLIN_HOME/bin/kylin.sh

# Build a Spark’s flat jar
rm -rf $KYLIN_HOME/spark_jars
mkdir $KYLIN_HOME/spark_jars
cp /usr/lib/spark/jars/*.jar $KYLIN_HOME/spark_jars
cp -f /usr/lib/hbase/lib/*.jar $KYLIN_HOME/spark_jars

rm -f $KYLIN_HOME/spark_jars/netty-[0-9]*.jar

jar cv0f spark-libs.jar -C $KYLIN_HOME/spark_jars .
hadoop fs -put -f spark-libs.jar /kylin/package/ 

cat >> $KYLIN_HOME/conf/kylin.properties << EOF
kylin.engine.spark-conf.spark.yarn.archive=hdfs://$HOSTNAME:8020/kylin/package/spark-libs.jar
EOF

# Copy Spark jar to tomcat lib
cp /usr/lib/spark/jars/spark-core_* $KYLIN_HOME/tomcat/lib/
cp /usr/lib/spark/jars/scala-library-* $KYLIN_HOME/tomcat/lib/

# Configure if Glue is used as Hive Metadata store
if [ $3 = "glue" ];then
cp -d /usr/share/aws/hmclient/lib/aws-glue-datacatalog-*.jar $KYLIN_HOME/lib

cat >> $KYLIN_HOME/conf/kylin.properties << EOF
kylin.source.hive.metadata-type=gluecatalog
EOF
fi

# Start Kylin
$KYLIN_HOME/bin/sample.sh
$KYLIN_HOME/bin/kylin.sh start
