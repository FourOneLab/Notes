Requirements
------------

1. [Kafka 0.8.*.* or 0.9.*.* or 0.10.*.* or 0.11.*.*](http://kafka.apache.org/downloads.html)
2. Java 8+

Configuration
-------------

至少需要配置kafka需要连接的zookeeper集群相关的信息，在conf目录下的application.conf文件中进行配置。

    kafka-manager.zkhosts="my.zookeeper.host.com:2181"

通过逗号分隔多个zookeeper主机：

    kafka-manager.zkhosts="my.zookeeper.host.com:2181,other.zookeeper.host.com:2181"

不想对值进行硬编码的话，可以使用变量`ZK_HOSTS`：

    ZK_HOSTS="my.zookeeper.host.com:2181"

可以通过修改application.conf中的默认列表来启用/禁用以下功能 :

    application.features=["KMClusterManagerFeature","KMTopicManagerFeature","KMPreferredReplicaElectionFeature","KMReassignPartitionsFeature"]

 - KMClusterManagerFeature - 允许从Kafka Manager添加，更新，删除集群
 - KMTopicManagerFeature - 允许从Kafka群集添加，更新，删除主题
 - KMPreferredReplicaElectionFeature - 允许为Kafka集群运行首选副本选举
 - KMReassignPartitionsFeature - 允许生成分区分配和重新分配分区

为启用jmx的大群集设置这些参数：

 - kafka-manager.broker-view-thread-pool-size=< 3 * number_of_brokers>
 - kafka-manager.broker-view-max-queue-size=< 3 * total # of partitions across all topics>
 - kafka-manager.broker-view-update-seconds=< kafka-manager.broker-view-max-queue-size / (10 * number_of_brokers) >

下面是一个包含10个代理，100个主题的kafka集群的示例，每个主题有10个分区，在启用JMX的情况下提供1000个总分区：

 - kafka-manager.broker-view-thread-pool-size=30
 - kafka-manager.broker-view-max-queue-size=3000
 - kafka-manager.broker-view-update-seconds=30


下面的参数控制consumer的offset的cache的线程池和队列：

 - kafka-manager.offset-cache-thread-pool-size=< default is # of processors>
 - kafka-manager.offset-cache-max-queue-size=< default is 1000>
 - kafka-manager.kafka-admin-client-thread-pool-size=< default is # of processors>
 - kafka-manager.kafka-admin-client-max-queue-size=< default is 1000>

为启用消费者轮询的大量consumer增加上述参数， 这些参数主要影响基于zk的消费者投票选举。

现在版本，kafka消费者的offset由“_consumer_offsets”这个主题管理。需要注意的是，这个设置并没有通过大规模的测试。每个群集都有一个单独的线程来消耗此主题，因此可能无法跟上被推送到topic的大量offset。


Deployment
----------

下面的命令将创建一个zip文件，可用于部署应用程序。

    ./sbt clean dist

请参阅[production deployment/configuration](https://www.playframework.com/documentation/2.4.x/ProductionConfiguration).

如果java不在您的路径中，或者您需要针对特定的Java版本进行构建，请使用以下方式（示例假设oracle java8）：

    $ PATH=/usr/local/oracle-java-8/bin:$PATH \
      JAVA_HOME=/usr/local/oracle-java-8 \
      /path/to/sbt -java-home /usr/local/oracle-java-8 clean dist

这可以确保在oracle java8 发行版中首先在查找路径中的“java”和“javac”二进制文件。接下来，对于只监听JAVA_HOME的所有下游工具，它指向他们到oracle java8的位置。最后，它也会告诉sbt使用oracle java8位置。

Starting the service
--------------------

解压缩生成的zip文件后，将工作目录更改为它，即可像这样运行服务：

    $ bin/kafka-manager

默认情况下，它将选择端口9000.这是可覆盖的，在配置文件中修改。例如：

    $ bin/kafka-manager -Dconfig.file=/path/to/application.conf -Dhttp.port=8080

同样，如果java不在您的路径中，或者您需要针对不同版本的java运行，添加-java-home选项，如下所示：

    $ bin/kafka-manager -java-home /usr/local/oracle-java-8

Starting the service with Security
----------------------------------

要为SASL添加JAAS配置，请在启动时添加配置文件位置：

    $ bin/kafka-manager -Djava.security.auth.login.config=/path/to/my-jaas.conf

注意：确保运行kafka manager的用户对jaas配置文件具有读取权限


Packaging
---------

如果您想要创建Debian或RPM软件包，可以运行以下方法之一：

    sbt debian:packageBin

    sbt rpm:packageBin


