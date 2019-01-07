# Kafka Connect
Kafka Connect是一款高可靠，可扩展的在Apache Kafka和其他系统之间传输数据的工具。它可以简单快速的定义Connectors并使用定义好的Connector向kafka导入或者从kafka导出大量的数据。Kafka Connect可以接收整个数据库或将所有应用程序服务器的指标收集到Kafka topics中，使数据可用于低延迟的流处理。一个数据导出作业可以将来自Kafka topic的数据传送到辅助存储、查询系统或批量系统中进行离线分析。

## Kafka Connect功能特性包括：

- Kafka连接器的通用框架：
Kafka Connect将其他数据系统与Kafka的集成标准化，简化了连接器的开发，部署和管理。

- 分布式和单机模式： 可以扩展到支持整个组织的大型集中管理服务，或者缩小到开发，测试和小型生产部署。

- REST接口：通过简单易用的REST API提交并管理Kafka Connect群集中的connectors。

- 自动偏移管理：仅使用connector提供的一些信息，Kafka Connect可以自动管理offset的提交过程，因此connector开发人员无需担心connector开发中容易出错的部分。

- 默认情况下是分布式和可扩展的：Kafka Connect基于现有的组管理协议（group management protocol）构建。可以通过添加更多的工作节点来扩展Kafka Connect群集。

- 整合流和微批 - 利用Kafka现有的功能，Kafka Connect是数据流和批量数据系统的理想解决方案。


## 示例运行Kafka Connect
Kafka Connect目前支持两种执行模式：单机（单进程）和分布式。

在单机模式下，所有任务都在一个进程中执行。这种配置容易设置和使用，并且在只有一名节点的情况下（例如收集日志文件）非常有用，但这样配置的话就不能利用Kafka Connect的某些功能（例如容错功能）。

### connect-standalone.sh

```
bin/connect-standalone.sh config/connect-standalone.properties connector1.properties [connector2.properties ...]
```
第一个参数是节点的配置。 这包括诸如Kafka连接参数，序列化格式以及提交offset的频率等设置。 
- bootstrap.servers - 列出Kafka服务器列。

- key.converter - converter类，用于在Kafka Connect格式和写入Kafka的序列化表单之间进行转换。 这将控制写入kafka或从lafka读取的消息中的密钥格式，这与连接器无关，所以允许任何connector使用任何序列化格式。 常见格式的例子包括JSON和Avro。

- value.converter - Converter类，用于在Kafka Connect格式和写入Kafka的序列化表单之间进行转换。 这将控制写入Kafka或从Kafka读取的消息中的值的格式，并且由于这与连接器无关，所以它允许任何连接器使用任何序列化格式。 常见格式的例子包括JSON和Avro。

下面的是单机模式的重要配置：
- offset.storage.file.filename - 用于存储offset数据的文件。

上面这个参数适用于通过Kafka Connect访问配置、offset和topic状态的生产者和消费者。 要配置Kafka源和Kafka sink任务，可以使用相同的参数，但需要分别以consumer或producer为前缀。 从节点配置继承的唯一参数是bootstrap.servers，在大多数情况下这就够了，因为同一个集群通常用于所有情况。

**一个值得注意的例外是安全集群，它需要配置额外的参数来允许连接。 这些参数需要在节点配置中设置为三次，一次用于管理访问，一次用于kafka connect，一次用于kafka源。**

其余参数是连connector配置文件。你可以配置所有你需要的参数，但所有这些参数将在同一个进程内（不同的线程上）执行。

### connect-distributed.sh
分布式模式处理节点的自动负载平衡，允许动态扩展（或缩小），并提供活动任务以及配置和offset提交数据的错误容错。执行与独立模式非常相似：


```
bin/connect-distributed.sh config/connect-distributed.properties
```

不同之处在于启动的类以及Kafka Connect的配置参数，这些参数决定了 进程存储配置的位置、如何分配工作和存储offset和任务状态的位置。 在分布式模式下，Kafka Connect将offset，配置信息和任务状态存储在Kafka topic中。 建议手动创建offset，配置信息和状态的topic以实现所需的分区数量和复制因子。 如果在启动Kafka Connect时尚未创建 topic，则会使用默认分区数和复制因子自动创建topic。

除了上面提到的常用设置之外，以下配置参数在启动集群之前对设置至关重要：

- group.id（默认connect-cluster） - 集群的唯一名称，用于形成Connect集群组; **请注意，这不得与消费者组ID相冲突**

- config.storage.topic（默认connect-configs） - 用于存储connector和任务配置的topic; **请注意，这应该是单个分区，设置冗余因子，被压缩的topic** 

- offset.storage.topic（默认connect-offsets） - 用于存储offset的topic; 这个topic应该有许多分区，被复制，并被配置为压缩

status.storage.topic（默认connect-status） - 用于存储状态的topic; topic题可以有多个分区，应该进行复制和配置以进行压缩

请注意，在分布式模式下，连接器配置不会在命令行上传递。相反，请使用下面描述的REST API来创建，修改和销毁连接器。



### kafka-acls.sh
### kafka-broker-api-versions.sh
### kafka-broker-topics.sh
### kafka-configs.sh
### kafka-console-consumer.sh
### kafka-console-producer.sh
### kafka-consumer-groups.sh
### kafka-consumer-offset-checker.sh
### kafka-consumer-perf-test.sh
### kafka-guardian-acls.sh
### kafka-mirror-maker.sh
### kafka-preferred-replica-election.sh
### kafka-producer-perf-test.sh
### kafka-reassign-partitions.sh
### kafka-replay-log-producer.sh
### kafka-replica-verification.sh
## kafka-run-class.sh
## kafka-server-start.sh
## kafka-server-stop.sh
## kafka-simple-consumer-shell.sh
## kafka-streams-application-reset.sh
## kafka-topics.sh
## kafka-verifiable-consumer.sh
## kafka-verifiable-producer.sh




