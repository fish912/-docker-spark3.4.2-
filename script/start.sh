#!/bin/bash
# -*- coding: utf-8 -*-
mkdir -p /opt/hadoop
mkdir -p /opt/zookeeper
mkdir -p /opt/spark


# 判断是否第一次执行
init_flag=/run/init_flag.txt

# start zookeeper
# zookeeper有两个环境变量，ZOOKEEPER_SERVER设置服务，ZOO_DATA_DIR设置数据存储目录
if [ -z "$ZOOKEEPER_SERVER" ]; then
    echo "ZOOKEEPER_SERVER environment variable is not set, don't start zookeeper"
else
    if [ -n "$ZOO_DATA_DIR" ]; then
      ZOO_DATA_DIR="$ZOO_DATA_DIR"
    else
      ZOO_DATA_DIR="/opt/zookeeper"
    fi
    if [ ! -f "$init_flag" ]; then
      cat << EOF > "${ZOOKEEPER_HOME}"/conf/zoo.cfg
tickTime=2000
initLimit=10
syncLimit=5
dataDir=$ZOO_DATA_DIR
clientPort=2181
EOF
      if [ -z "$ZOOKEEPER_SERVER" ]; then
        echo "ZOOKEEPER_SERVER environment variable is not set."
        exit 1
      else
        mapfile -t -d ',' servers <<< "$ZOOKEEPER_SERVER"
        for ((i=0; i<${#servers[@]}; i++)); do
          idName=$(echo "${servers[$i]}"|cut -d":" -f1)
          server="server.$((i+1))=${servers[$i]}"
          echo "$server" >> "$ZOOKEEPER_HOME"/conf/zoo.cfg
          # 配置文件的dataDir所对应的目录下，必须创建一个名为myid的文件,内容必须与zoo.cfg中server.x 中的x相同
          echo $((i+1)) | ssh -o StrictHostKeyChecking=no "$idName" 'cat > '$ZOO_DATA_DIR'/myid'
        done
      fi
    fi
    cd $ZOO_DATA_DIR && zkServer.sh start
    sleep 2
    if ! pgrep -f zookeeper; then
      echo "ZooKeeper failed to start, please check."
      sleep 1000000
    fi
fi

# start hadoop
function doUtilSuccess() {
    runtime=0
    while true; do
        ((runtime++))
        if [ "$runtime" -gt 10 ]; then
            echo "retry too many times to execute command '$1', exit"
            break
        fi
        if eval "$1"; then
            echo "successfully execute command '$1'"
            break  # 如果成功，则退出循环
        else
            echo "Failed to execute command '$1', sleep 1 second and retry"
            sleep 1  # 等待1秒后继续下一次循环
        fi
    done
}

function createConf() {
    cd "$WORKDIR"/script && bash generate_core_site_xml.sh
    bash generate_hdfs_site_xml.sh
    bash generate_yarn_site_xml.sh

    cat << EOF > "${SPARK_HOME}"/conf/spark-defaults.conf
spark.eventLog.dir hdfs://ns1/spark_event_log
spark.eventLog.enabled true
spark.eventLog.compress true
EOF
    cat << EOF > "${SPARK_HOME}"/conf/spark-env.sh
JAVA_HOME=$JAVA_HOME
HADOOP_CONF_DIR=$HADOOP_HOME/etc/hadoop
YARN_CONF_DIR=$HADOOP_HOME/etc/hadoop
SPARK_LOCAL_DIRS=/opt/spark
SPARK_HISTORY_OPTS="-Dspark.history.fs.logDirectory=hdfs://ns1/spark_history -Dspark.history.fs.cleaner.enabled=true"
SPARK_DAEMON_JAVA_OPTS="-Dspark.deploy.recoveryMode=ZOOKEEPER -Dspark.deploy.zookeeper.url=$1 -Dspark.deploy.zookeeper.dir=/spark"
EOF
    mapfile -t -d ',' dataNodes <<< "$HADOOP_DFS_DATANODE_ADDRESS"
    dateNodeCount=${#dataNodes[@]}
    content=""
    for ((i=1; i<=dateNodeCount; i++)); do
      content+="${dataNodes[$((i-1))]}
"
    done
    echo "$content" > "$HADOOP_HOME"/etc/hadoop/workers
    echo "$content" > "$SPARK_HOME"/conf/workers
}


if [ -n "$HADOOP_NAMENODE_NUM" ]; then
  if [ ! -f "$init_flag" ]; then
    if [ -z "$HADOOP_DFS_NAMENODE_SERVER_ADDRESS" ]; then
      echo "HADOOP_DFS_NAMENODE_SERVER_ADDRESS environment variable is not set."
      exit 1
    fi
    createConf "$(echo "$ZOOKEEPER_SERVER" | sed 's/:2888:3888/:2181/g')"
    hdfs --daemon start journalnode
    if [ "$HADOOP_NAMENODE_MAIN_NODE" = "true" ]; then
      hdfs --daemon start journalnode
      doUtilSuccess 'yes Y | hdfs namenode -format 2>&1 | grep -q "successfully formatted"'
      hdfs --daemon start namenode
      hdfs zkfc -formatZK
      hdfs --daemon start zkfc
    else
      hdfs --daemon start journalnode
      doUtilSuccess 'yes Y | hdfs namenode -bootstrapStandby 2>&1 | grep -q "successfully formatted"'
      hdfs --daemon start namenode
      hdfs --daemon start zkfc
    fi
  else
    hdfs --daemon start journalnode
    hdfs --daemon start namenode
    hdfs --daemon start zkfc
  fi
  yarn --daemon start resourcemanager
  sleep 1
  hdfs haadmin -getAllServiceState
  jps
  hadoop fs -mkdir -p /spark_event_log
  hadoop fs -mkdir -p /spark_history
  bash "$SPARK_HOME"/sbin/start-history-server.sh

  if [ "$HADOOP_NAMENODE_MAIN_NODE" = "true" ]; then
    bash "$SPARK_HOME"/sbin/start-all.sh
  else
    bash "$SPARK_HOME"/sbin/start-master.sh
  fi
fi

if [ -n "$HADOOP_DATANODE_NUM" ]; then
  if [ ! -f "$init_flag" ]; then
    if [ -z "$HADOOP_DFS_NAMENODE_SERVER_ADDRESS" ]; then
      echo "HADOOP_DFS_NAMENODE_SERVER_ADDRESS environment variable is not set."
      exit 1
    fi
    if [ -z "$HADOOP_DFS_DATANODE_ADDRESS" ]; then
      echo "HADOOP_DFS_DATANODE_ADDRESS environment variable is not set."
      exit 1
    fi
    createConf "$HA_ZOOKEEPER_SERVER"
  fi
  hdfs --daemon start datanode
  yarn --daemon start nodemanager
  sleep 1
  jps
fi


#over
echo "this is init flag" > $init_flag
tail -f /dev/null
