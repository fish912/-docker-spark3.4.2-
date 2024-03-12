#!/usr/bin/env bash
# -*- coding: utf-8 -*-

mapfile -t -d ',' servers <<< "$HADOOP_DFS_NAMENODE_SERVER_ADDRESS"
masterNodeCount=${#servers[@]}
if [ -z "$YARN_DIR" ]; then
  YARN_DIR=/opt/hadoop/yarn
fi
mkdir -p $YARN_DIR

xml_content="<configuration>
<!-- yarn ha start -->
<property>
    <name>yarn.resourcemanager.ha.enabled</name>
    <value>true</value>
    <description>是否开启yarn ha</description>
</property>

<property>
    <name>yarn.resourcemanager.ha.automatic-failover.embedded</name>
    <value>true</value>
    <description>ha状态切换为自动切换</description>
</property>

<property>
    <name>yarn.resourcemanager.ha.rm-ids</name>
    <value>rm1,rm2,rm3</value>
    <description>RMs的逻辑id列表</description>
</property>
<!-- yarn ha end -->
<!-- 元数据存储共享 -->
<property>
    <name>yarn.resourcemanager.cluster-id</name>
    <value>pseudo-yarn-rm-cluster</value>
    <description>集群的Id</description>
</property>

<property>
    <name>yarn.resourcemanager.recovery.enabled</name>
    <value>true</value>
    <description>默认值为false，也就是说resourcemanager挂了相应的正在运行的任务在rm恢复后不能重新启动</description>
</property>
<!-- 元数据存储共享 -->
<property>
    <name>yarn.resourcemanager.store.class</name>
    <value>org.apache.hadoop.yarn.server.resourcemanager.recovery.ZKRMStateStore</value>
    <description>配置RM状态信息存储方式3有两种，一种是FileSystemRMStateStore,另一种是MemoryRMStateStore，还有一种目前较为主流的是zkstore</description>
</property>
"

if [ -n "$ZOOKEEPER_SERVER" ]; then
  zk_servers=$(echo "$ZOOKEEPER_SERVER" | sed 's/:2888:3888/:2181/g')
  xml_content+="<property>
    <name>yarn.resourcemanager.zk-address</name>
    <value>$zk_servers</value>
    <description>zookeeper地址</description>
</property>
<property>
    <name>yarn.resourcemanager.zk.state-store.address</name>
    <value>$zk_servers</value>
    <description>当使用ZK存储时，指定在ZK上的存储地址。</description>
</property>"
fi

for ((i=1; i<=masterNodeCount; i++))
do
  trimmed=${servers[$((i-1))]}
  server="${trimmed%"${trimmed##*[![:space:]]}"}"
  xml_content+="
<property>
    <name>yarn.resourcemanager.address.rm$i</name>
    <value>$server:8032</value>
    <description>ResourceManager 对客户端暴露的地址。客户端通过该地址向RM提交应用程序，杀死应用程序等</description>
</property>
<property>
    <name>yarn.resourcemanager.hostname.rm$i</name>
    <value>$server</value>
    <description>ResourceManager主机名</description>
</property>
<property>
    <name>yarn.resourcemanager.scheduler.address.rm$i</name>
    <value>$server:8030</value>
    <description>ResourceManager 对ApplicationMaster暴露的访问地址。ApplicationMaster通过该地址向RM申请资源、释放资源等。</description>
</property>

<property>
    <name>yarn.resourcemanager.webapp.https.address.rm$i</name>
    <value>$server:8089</value>
</property>

<property>
    <name>yarn.resourcemanager.webapp.address.rm$i</name>
    <value>$server:8088</value>
    <description>ResourceManager对外web ui地址。用户可通过该地址在浏览器中查看集群各类信息。</description>
</property>

<property>
    <name>yarn.resourcemanager.resource-tracker.address.rm$i</name>
    <value>$server:8031</value>
    <description>ResourceManager 对NodeManager暴露的地址.。NodeManager通过该地址向RM汇报心跳，领取任务等。</description>
</property>

<property>
    <name>yarn.resourcemanager.admin.address.rm$i</name>
    <value>$server:8033</value>
    <description>ResourceManager 对管理员暴露的访问地址。管理员通过该地址向RM发送管理命令等</description>
</property>
"
done

xml_content+="
<property>
    <name>yarn.nodemanager.local-dirs</name>
    <value>$YARN_DIR/local</value>
    <description>中间结果存放位置，存放执行Container所需的数据如可执行程序或jar包，配置文件等和运行过程中产生的临时数据</description>
</property>

<property>
    <name>yarn.nodemanager.log-dirs</name>
    <value>$YARN_DIR/logs</value>
    <description>Container运行日志存放地址（可配置多个目录）</description>
</property>

<property>
    <name>yarn.nodemanager.address</name>
    <value>0.0.0.0:9103</value>
</property>

<property>
    <name>yarn.nodemanager.aux-services</name>
    <value>mapreduce_shuffle</value>
    <description>NodeManager上运行的附属服务。需配置成mapreduce_shuffle，才可运行MapReduce程序</description>
</property>
<property>
    <name>yarn.nodemanager.webapp.address</name>
    <value>0.0.0.0:8042</value>
</property>

<property>
    <name>yarn.nodemanager.localizer.address</name>
    <value>0.0.0.0:8040</value>
</property>

<property>
    <name>yarn.nodemanager.aux-services.mapreduce.shuffle.class</name>
    <value>org.apache.hadoop.mapred.ShuffleHandler</value>
</property>

<property>
    <name>mapreduce.shuffle.port</name>
    <value>23080</value>
</property>
</configuration>"


# 将配置写入yarn-site.xml文件
echo "$xml_content" > "$HADOOP_HOME"/etc/hadoop/yarn-site.xml