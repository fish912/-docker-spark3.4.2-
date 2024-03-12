JAVA_HOME=/usr/local/jdk1.8.0_401
HADOOP_CONF_DIR=/usr/local/hadoop-3.3.6/etc/hadoop
YARN_CONF_DIR=/usr/local/hadoop-3.3.6/etc/hadoop
SPARK_LOCAL_DIRS=/opt/spark
SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://ns1/spark_history -Dspark.history.fs.cleaner.enabled=true"
SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER -Dspark.deploy.zookeeper.url=znr1:2181,znr2:2181,znr3:2181 -Dspark.deploy.zookeeper.dir=/spark"
