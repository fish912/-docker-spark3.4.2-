FROM ubuntu:22.04
# docker4.27.2中ADD会自动解压并删除压缩包
RUN apt-get update -qqy && \
    apt-get -qqy install vim  net-tools  iputils-ping  openssh-server build-essential zlib1g-dev libncurses5-dev libgdbm-dev libnss3-dev libssl-dev libreadline-dev libffi-dev libsqlite3-dev libbz2-dev

#添加压缩文件
ADD ./*gz /usr/local

#安装python
RUN cd /usr/local/Python-3.10.12 && \
    ./configure --enable-optimizations && \
    make && \
    make install && \
    ln -s /usr/local/bin/python3 /usr/bin/python && \
    ln -s /usr/local/bin/pip3 /usr/bin/pip

RUN ssh-keygen -t rsa -f ~/.ssh/id_rsa -P '' && \
    cat ~/.ssh/id_rsa.pub >> ~/.ssh/authorized_keys && \
    chmod 600 ~/.ssh/authorized_keys && service ssh start

#添加环境变量
ENV JAVA_HOME /usr/local/jdk1.8.0_401
ENV HADOOP_HOME /usr/local/hadoop-3.3.6
ENV SCALA_HOME /usr/local/scala-2.13.1
ENV ZOOKEEPER_HOME /usr/local/apache-zookeeper-3.8.4-bin
ENV SPARK_HOME /usr/local/spark-3.4.2-bin-hadoop3-scala2.13
ENV HADOOP_CONF_DIR $HADOOP_HOME/etc/hadoop
ENV WORKDIR /opt
ENV HDFS_DATANODE_USER=root
ENV HDFS_NAMENODE_USER=root
ENV HDFS_JOURNALNODE_USER=root
ENV HDFS_SECONDARYNAMENODE_USER=root
ENV HDFS_ZKFC_USER=root
ENV YARN_RESOURCEMANAGER_USER=root
ENV YARN_NODEMANAGER_USER=root
#将环境变量添加到系统变量中
ENV PATH $SCALA_HOME/bin:$ZOOKEEPER_HOME/bin:$SPARK_HOME/bin:$HADOOP_HOME/bin:$JAVA_HOME/bin:$JAVA_HOME/lib/dt.jar:$JAVA_HOME/lib/tools.jar:$PATH
COPY ./script /opt/script
WORKDIR /opt
CMD service ssh start && /bin/bash $WORKDIR/script/start.sh