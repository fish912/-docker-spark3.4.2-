#!/usr/bin/env bash
# -*- coding: utf-8 -*-

mapfile -t -d ',' servers <<< "$HADOOP_DFS_NAMENODE_SERVER_ADDRESS"
nameNodeCount=${#servers[@]}

if [ -z "$HADOOP_DFS_NAMENODE_NAME_DIR" ]; then
  HADOOP_DFS_NAMENODE_NAME_DIR=/opt/hadoop/hdfs/namenode
fi
if [ -z "$HADOOP_DFS_DATANODE_DATA_DIR" ]; then
  HADOOP_DFS_DATANODE_DATA_DIR=/opt/hadoop/hdfs/datanode
fi
if [ -z "$HADOOP_DFS_NAMENODE_HANDLER_COUNT" ]; then
  HADOOP_DFS_NAMENODE_HANDLER_COUNT=50
fi
if [ -z "$HADOOP_DFS_JOURNALNODE_EDITS_DIR" ]; then
  HADOOP_DFS_JOURNALNODE_EDITS_DIR=/opt/hadoop/hdfs/journalnode
fi

mkdir -p $HADOOP_DFS_NAMENODE_NAME_DIR
mkdir -p $HADOOP_DFS_DATANODE_DATA_DIR
mkdir -p $HADOOP_DFS_JOURNALNODE_EDITS_DIR
# 生成hdfs-site.xml内容
xml_content="<?xml version=\"1.0\" encoding=\"UTF-8\"?>
<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>
<configuration>
    <property>
        <name>dfs.namenode.name.dir</name>
        <value>$HADOOP_DFS_NAMENODE_NAME_DIR</value>
        <description>指定 HDFS NameNode 存储元数据的目录路径</description>
    </property>
    <property>
        <name>dfs.datanode.data.dir</name>
        <value>$HADOOP_DFS_DATANODE_DATA_DIR</value>
        <description>指定 HDFS DataNode 存储数据块的目录路径</description>
    </property>
    <property>
        <name>dfs.replication</name>
        <value>3</value>
        <description>文件副本数</description>
    </property>
    <property>
        <name>dfs.namenode.datanode.registration.ip-hostname-check</name>
        <value>false</value>
    </property>
    <property>
        <name>dfs.nameservices</name>
        <value>ns1</value>
        <description>指定 HDFS 的逻辑名称服务，与core-site.xml里的对应</description>
    </property>
    <property>
        <name>dfs.ha.namenodes.ns1</name>
        <value>"

for ((i=1; i<=nameNodeCount; i++))
do
    xml_content+="nn$i"
    if [ $i -lt $nameNodeCount ]; then
        xml_content+=","
    fi
done

xml_content+="</value>
        <description>为逻辑名称服务指定逻辑名称和具体的 NameNode</description>
    </property>"

# 生成dfs.namenode.shared.edits.dir配置项
shared_edits_dir="<property>
        <name>dfs.namenode.shared.edits.dir</name>
        <value>qjournal://"

for ((i=1; i<=nameNodeCount; i++))
do
    rpc_address_property="dfs.namenode.rpc-address.ns1.nn$i"
    http_address_property="dfs.namenode.http-address.ns1.nn$i"

    temp=$(echo "${servers[$((i-1))]}" | tr -d '[:space:]')
    rpc_address_value="$temp:8020"
    http_address_value="$temp:50070"

    xml_content+="
    <property>
        <name>$rpc_address_property</name>
        <value>$rpc_address_value</value>
    </property>
    <property>
        <name>$http_address_property</name>
        <value>$http_address_value</value>
    </property>"
    shared_edits_dir+="$temp:8485"
    if [ "$i" -lt "$nameNodeCount" ]; then
        shared_edits_dir+=";"
    fi
done

xml_content+="
    <property>
        <name>dfs.namenode.handler.count</name>
        <value>$HADOOP_DFS_NAMENODE_HANDLER_COUNT</value>
        <description>namenode的工作线程数</description>
    </property>"


shared_edits_dir+="/ns1</value>
    </property>
    <property>
        <name>ipc.client.connect.max.retries</name>
        <value>10</value>
        <description>namenode和journalnode的链接重试次数</description>
    </property>
    <property>
        <name>ipc.client.connect.retry.interval</name>
        <value>5000</value>
        <description>重试间隔时间5秒</description>
    </property>
    <property>
        <name>dfs.journalnode.edits.dir</name>
        <value>$HADOOP_DFS_JOURNALNODE_EDITS_DIR</value>
    </property>"
xml_content+="$shared_edits_dir"
if [ -n "$ZOOKEEPER_SERVER" ]; then
    xml_content+="
    <!-- 配置隔离机制 -->
    <property>
        <name>dfs.ha.fencing.methods</name>
        <value>sshfence</value>
    </property>

    <!-- 配置隔离机制时需要的ssh密钥登录 -->
    <property>
        <name>dfs.ha.fencing.ssh.private-key-files</name>
        <value>/root/.ssh/id_rsa</value>
    </property>
    <!-- 访问代理类：访问ns1时，client用于确定哪个NameNode为Active，将请求转发过去 -->
    <property>
        <name>dfs.client.failover.proxy.provider.ns1</name>
        <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
    </property>
    <property>
        <name>dfs.client.failover.proxy.provider.auto-ha</name>
        <value>org.apache.hadoop.hdfs.server.namenode.ha.ConfiguredFailoverProxyProvider</value>
    </property>

    <!-- 启动namenode故障自动转移 -->
    <property>
        <name>dfs.ha.automatic-failover.enabled</name>
        <value>true</value>
    </property>"

fi

xml_content+="
</configuration>"

# 将配置写入hdfs-site.xml文件
echo "$xml_content" > "$HADOOP_HOME"/etc/hadoop/hdfs-site.xml