xml_content='<?xml version="1.0" encoding="UTF-8"?>
<?xml-stylesheet type="text/xsl" href="configuration.xsl"?>'
xml_content+="<configuration>
<property>
    <name>fs.defaultFS</name>
    <value>hdfs://ns1</value>
    <description>定义默认的文件系统主机和端口,这里使用zookeeper管理</description>
</property>
<property>
    <name>io.file.buffer.size</name>
    <value>131072</value>
    <final>4096</final>
    <description>流文件的缓冲区为4K</description>
</property>
<property>
    <name>hadoop.tmp.dir</name>
    <value>/opt/hadoop/data</value>
    <description>数据存储目录</description>
</property>"
if [ -n "$ZOOKEEPER_SERVER" ]; then
  zk_servers=$(echo "$ZOOKEEPER_SERVER" | sed 's/:2888:3888/:2181/g')
  xml_content+="<property>
    <name>ha.zookeeper.quorum</name>
    <value>$zk_servers</value>
    <description>zookeeper地址</description>
</property>"
fi
xml_content+="</configuration>"
echo "$xml_content" > "$HADOOP_HOME"/etc/hadoop/core-site.xml