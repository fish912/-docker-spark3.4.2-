# docker-spark3.4.2
基于docker的zookeeper3.8.4下的hadoop3.3.6-spark3.4.2部署

***

# 构建镜像

```
# 依赖镜像ubuntu:22.04
docker pull ubuntu:22.04

# 下载需要的服务及版本（官网均提供下载，这里整合到了release，需要的自行下载）
1. spark-3.4.2-bin-hadoop3-scala2.13.tgz
2. scala-2.13.1.tgz
3. Python-3.10.12.tgz
4. jdk-8u401-linux-x64.tar.gz
5. hadoop-3.3.6.tar.gz
6. apache-zookeeper-3.8.4-bin.tar.gz

# 构建镜像
docker build -t sparkenv:3.4.2 .
```
**务必将所需的以上环境包放在Dockerfile同级目录下**

***
## 启动服务
`docker-compose up -d`

hadoop web ui: http://127.0.0.1:8088/cluster/cluster  
spark web ui: http://127.0.0.1:8081/  
spark history web: http://127.0.0.1:18080/

***所有内容仅供学习使用，其他用途概不负责***