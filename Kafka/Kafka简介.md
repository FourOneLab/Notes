Apache Kafka 是一个分布式的、基于发布/订阅的消息系统，由Scala语言编写而成。它具备快速、可扩展、可持久化的特点。

#### kafka 的关键特性
- Kafka具有近乎实时性的消息处理能力，海量消息也能够高效地存储和查询，Kafka将消息存储在磁盘中，在设计上并不惧怕磁盘操作，以顺序读写的方式访问磁盘，从而避免了随机读写磁盘导致的性能瓶颈。

- Kafka支持批量读写数据，会对数据进行批量压缩，提高网络利用率和压缩效率。
- Kafka支持消息分区，每个分区中的消息保证顺序传输，分区之间可以并发操作，提高kafka的并发能力。
- kafka支持在线增加分区，支持在线水平扩展。
- kafka支持为每个分区创建多个副本(其中只有一个Leader副本负责读写，其他副本只负责和Leader副本进行同步)，提高数据的容灾能力。Kafka将Leader副本均匀的分布在集群中，实现性能最大化。

#### Kafka的应用场景
- 将Kafka作为传统的消息中间件，实现消息队列和消息的发布/订阅（在某些场景下，性能会超越RabbitMQ,ActiveMQ等传统的消息中间件）。

- Kafka被用作系统中的数据总线，将其接入多个子系统中，子系统会将产生的数据发送到Kafka中保存，之后流转到目的系统中。
- Kafka作日志收集中心，多个系统产生的日志统一收集到Kafka中，然后由数据分析平台进行统一处理。日志会被Kafka持久化到磁盘，所以同时支持离线处理和实时处理。
- 基于Kafka设计数据库主从同步工具。


### 以Kafka为中心的解决方案
在大数据、高并发的系统中，为了突破瓶颈，会将系统进行水平扩展和垂直拆分、形成独立的服务。每个独立的服务背后，可能是一个独立的集群在对外提供服务。这就会遇到一个问题，整个系统是由多个服务（子系统）组成，数据需要在各个服务中不停流转。如果数据在各个子系统中传输时，速度过慢就会形成瓶颈，降低整个系统的性能。

##### 可能遇到的问题：
1. 子系统之间存在耦合性，两个存储之间要进行数据交换的话，开发人员就必须了解这两个存储系统的API，开发和运维成本高。一旦其中一个子系统发生变化，就可能影响其他多个子系统。

2. 在某些应用场景中，数据的顺序很重要，一旦数据出现乱序，会影响最终计算结果，降低用户体验，提高开发成本。
3. 需要考虑数据重传提高可靠性（毕竟通过网络进行传输并不可靠，可能会出现丢失数据的情况）
4. 进行数据交换的两个子系统，无论哪一方宕机，重新上线之后，都应该恢复到宕机之前的传输位置，继续传输。（尤其是对于非幂等性的操作，恢复到错误的传输位置，就会导致错误的结果）。
5. 随着业务量的增加，系统之间交换的数据量会不断增长，水平可扩展的数据传输方式显得尤为重要。


## 相关概念
### 解耦合
将Kafka作为整个系统的中枢，负责在任意两个系统之间传递数据。架构如下图所示，所有的存储只与kafka通信，开发人员不需要再去了解各个子系统、服务、存储的相关接口，只需要面向kafka编程即可。在需要进行数据交换的子系统之间形成了一个基于数据的接口层，只有这两者知道消息存放的Topic、消息中的数据格式。当需要扩展消息格式时，只需要修改相关子系统中kafka客户端即可。这样与kafka通信的模块可以复用，kafka承担数据总线的作用。
![image](https://kafka.apache.org/11/images/kafka-apis.png)

### 数据持久化
- 在分布式系统中，各个组件是通过网络连接起来的，一般认为网络传输是不可靠的，当数据在两个组件之间进行传递的时候，传输过程可能会失败，除非数据被持久化到磁盘，否则就可能造成数据的丢失。Kafka把数据以消息的形式持久化到磁盘，即使Kafka出现宕机，也可以保证数据不丢失。

- 为了避免磁盘上的数据不断增长，Kafka提供日志清理和日志压缩功能，对过时的、已经处理完成的数据进行清除。

- 在磁盘操作中，耗时最长的就是磁盘寻道时间，这是导致磁盘随机I/O性能很差的主要原因。为了提高消息持久化的性能， Kafka采用顺序读写的方式访问，实现了高吞吐量。

### 扩展与容灾
- Kafka的每个Topic都可以分为多个Parition，每个partition都有多个replica，实现消息冗余备份。每个partition中的消息是不同的（类似于数据库中的水平切分），提高并发读写能力。同一partition的不同副本保存的是相同的消息，副本之间是一主多从的关系。Leader副本负责处理读写请求，Follower副本只负责与Leader副本进行消息同步，当Leader副本出现故障，从Follower副本中重新选举Leader副本对外提供服务。通过提高partition的数量，就可以实现水平扩展，通过提高副本的数量，可以提高容灾能力。

- Kafka的容灾能力不仅体现在服务端，在Consumer端也有相关设计。Consumer使用pull的方式从服务端拉取消息，并且在Consumer端保存消费的具体位置，当消费者宕机后重新上线，可以根据自己保存的offset重新拉取消息进行消费，这就不会造成消息丢失。**【Kafka不决定何时、如何消费消息，而是Consumer自己决定何时、如何消费消息】**

- Kafka还支持Consumer的水平扩展能力。可以让多个Consumer加入一个Consumer Group，在一个Consumer Group中，每个partition只能分配给一个Consumer消费。一个CG中可以订阅很多不同的Topic，每个Consumer可以同时处理多个分区。
    - 当Kafka服务端通过增加分区数量进行水平扩展后，可以通过向CG中增加新的Consumer来提高整个CG的消费能力。
    - 当CG中的一个Consumer出现故障下线时，通过Rebalance操作将下线consumer负责处理的分区分配给其他Consumer继续处理，当下线Consumer重新上线加入CG时，再次进行Rebalance操作，重新分配分区。

### 顺序保证
在很多场景下，数据处理的顺序很重，不同的顺序导致不同的计算结果。Kafka保证一个Partition内消息的有序性，但是并不保证多个partition之间的数据有顺序。

### 缓冲 & 峰值处理
在访问流量剧增的情况下，应用仍然需要继续发挥作用，但是这样的突发流量并不常见。使用Kafka能够使关键组件顶住突发的访问压力，而不会因为突发的峰值请求而使系统完全奔溃。

### 异步通信
Kafka为系统提供了异步处理能力。
- 例如两个系统需要通过网络进行数据交换，其中一端可以把一个消息放入Kafka中后立即返回继续执行其他操作，不需要等待对端的响应。待后者将处理放入Kafka中之后，前者可以从其中获取并解析响应。


## Kafka核心概念
### 消息
消息是Kafka中最基本的数据单元。消息由一串字节构成，其中主要由key和value构成，key和value也都是byte数组。
- key 的主要作用是根据一定的策略，将此消息路由到指定的分区中，这样就能保证包含同一key的消息全部写入同一分区中，key可以是null。

- value 部分的数据是消息真正的有效负载。

为了提高网络和存储利用率，producer会批量发送消息到Kafka，并在发送之前对消息进行压缩。

### Topic & Partition & Log
- Topic是用于存储消息的逻辑概念，可以看作一个消息集合。每个Topic可以有多个producer向其中push消息，也可以有任意多个consumer消费其中的消息。

- 每个Topic可以划分成多个partition（每个Topic至少有一个partition），同一Topic下的不同partition包含的消息是不同的。每个消息在被添加到分区时，都会被分配一个offset，它是消息在此partition内的唯一标号（通过offset保证消息在分区内的顺序），offset的顺序性不跨分区，Kafka只保证同一个partition内的消息是有序的，同一个Topic的多个partition内的消息并不保证其顺序性。如下图所示。

![image](https://kafka.apache.org/11/images/log_anatomy.png)

同一个Topic的不同partition会分配在不同的Broker上，partition是Kafka水平扩展性的基础，通过增加服务器并在其上分配partition的方式来增加kafka的并行处理能力。

- partition在逻辑上对应着一个log，当producer将消息写入partition时，实际上是写入到了partition对应的log中（log是一个逻辑概念，可以对应到磁盘上的一个文件夹）。
- log由多个segment组成，每个segment对应一个日志文件和一个索引文件。在面对海量数据时，为避免出现超大文件，每个日志文件的大小是有限制的，当超出限制后会创建新的segment，继续对外提供服务。


**注意：**
kafka采用顺序I/O，所以只能向最新的segment追加数据。为了权衡文件大小、索引速度、占用内存大小等多方面因素，索引文件采用稀疏索引的方式，大小并不会很大，在运行时将其内容映射到内存，提高索引速度。

### 保留策略 & 日志压缩
无论消费者是否已经消费数据，kafka都会一直保存这些消息，但并不会长期保存。为了避免磁盘被占满，kafka会配置相应的保留策略（retention policy），以实现周期性地删除陈旧的消息。kafka中有两种保留策略：
- 根据消息保存时间，当消息在kafka中保存的时间超过了指定时间，就可以被删除。
- 根据Topic存储的数据大小，当Topic所占用的日志文件大于设定阈值，则可以开始删除最旧的消息。

kafka会启动一个后台线程，定期检查是否存在可以删除的消息，保留策略的配置非常灵活，可以设置全局配置，也可以针对Topic进行配置从而覆盖全局配置。

在很多场景中，消息的key和value的值之间对应关系是不断变化的，消费者只关心key对应的最新value值，此时，可以开启kafka的日志压缩功能，kafka会在后台启动一个线程，定期将相同key的消息进行合并，只保存最新的value值。压缩过程如下图所示。

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/D4F3EA7237B24792991F267BC1E7146D/3957)


### Broker
一个单独的kafka server就是一个broker，主要工作是接收producer发过来的消息，分配offset，然后保存到磁盘；同时接收consumer、其他broker的请求，根据请求类型进行相应处理并返回相应。

### Replica

Kafka对消息进行了冗余备份，每个partition（**分区的放置策略，随机选取一个节点放置第一个分区，然后在其他broker中顺序放置其他分区**）可以有多个replica，每个replica中包含的消息是一样的（在同一时刻，副本之间其实并不是完全一样的）。每个partition至少有一个replica，当只有一个replica时，只有Leader副本。

所有的读写请求都由选举（Leader副本的选举策略可以不同）出来的Leader副本处理，Follower副本仅仅是从Leader副本处把数据拉取到本地之后，同步更新到自己的Log中。一般情况下，同一个分区的多个副本被分配到不同的Broker上。

### ISR（In-Sync Replica）集合
ISR集合表示的是目前alive且消息量和Leader相差不多的replica集合， 这是整个副本集合的子集。ISR集合中的replica必须满足如下两个条件：
1. replica所在节点必须维持着与Zookeeper的连接
2. replica最后一条消息的offset与Leader replica的最后一条消息的offset之间的差值不能超过指定的阈值。 

每个partition的Leader replica都会维护此partition的ISR集合。写请求首先由Leader replica处理，之后Follower replica从Leader上拉取写入的消息，这个过程存在一定的延迟，导致Follower replica中保存的消息略少于Leader replica，只要未超出阈值都是可以容忍的。

- 如果一个Follower replica出现异常，比如：宕机，发生长时间GC导致kafka僵死或者网络断开连接导致长时间没有拉取消息进行同步，就会违反上述条件而被踢出ISR集合。当Follower replica从异常中恢复过来，会继续与Leader replica同步，当其最后一条消息的offset与Leader replica的offset的差值小于阈值时，就会重新加入到ISR中。

**需要配置的两个参数：**

```
replica.lag.max.messages：落后的消息数量

replica.lag.time.max.ms：卡住的时间
```
kafka是通过这两个参数去判断是不是一个有效的副本follower。当leader宕机以后，是从这些有效副本中进行选举的。无效的是不参加选举的。


### HW（HighWatermark） & LEO（Log End Offset）
- HW 和 LEO 与ISR集合紧密相关，HW标记了一个特殊的offset，当consumer处理消息的时候，只能拉取到HW之前的消息，HW之后的消息对consumer来说是不可见的（与ISR集合类似，HW也是由Leader replica管理）。当ISR集合中全部的Follower replica都拉取HW指定消息进行同步后，Leader replica会递增HW的值（kafka官方将HW之前的消息的状态成为commit，其含义是这些消息在多副本中同时存在，即使Leader replica损坏，也不会出现数据丢失）。

- LEO是所有replica都会有的一个offset标记，它指向追加到当前replica的最后一个消息的offset，当producer向Leader replica追加消息的时候，Leader replica的LEO标记会递增，当Follower replica成功从Leader replica拉取消息并更新到本地的时候，Follower replica的LEO会增加。


> HW & LEO 设计的优势：
在分布式存储中，冗余备份是一种常见的设计，常用的方案有同步复制和异步复制。

>1.同步复制:要求所有能工作的Follower replica都复制完，这条消息才会被认为提交成功，一旦有一个Follower replica出现故障，就会导致HW无法完成递增。消息就无法提交，生产者获取不到消息。这种情况下，故障的Follower replica会拖慢整个系统的性能，甚至导致整个系统不可用。

>2.异步复制：Leader replica收到producer推送的消息后，就认为此消息提交成功。Follower replica副本则异步地从Leader replica同步消息，这种设计虽然避免了同步复制的问题，但是同样存在风险。假设所以Follower replica的同步速度都比较慢，它们保存的消息量都远远落后于Leader replica，此时Leader replica所在的broker突然宕机，则会重新选举Leader replica，而新Leader replica中没有原来Leader replica中的消息，这样就出现了消息丢失，而有些消费者可能已经消费了这些丢失的数据，状态变的不可控。

> kafka融合了两种机制，引入了ISR集合，巧妙解决了上述缺点。当Follower replica的延迟过高时，Follower replica被踢出ISR集合，消息依然可以快速提交，producer可以快速得到响应，避免高延时的Follower replica影响整个集群的性能。当Leader replica所在broker宕机时，可以从ISR集合中选举出新的Leader replica，在新的Leader replica中包含了HW之前所有的数据，这样避免了消息丢失。

**注意：**
Follower replica可以批量从Leader replica中复制消息，这就加快了网络I/O，Follower replica在更新消息时是批量写磁盘，加速了磁盘的I/O，极大减少了Follower 和Leader之间的差距

### Cluster & Controller
多个Broker可以做成一个Cluster对外提供服务，每个Cluster中会选举出一个Broker来担任Controller,Controller是Kafka集群的指挥中心，其他broker听从controller指挥实现相应的功能。

**controller的任务：**
1. 负责每个partition的状态
2. 管理每个partition的replica状态
3. 监听Zookeeper中数据的变化等

Controller也是一主多从的设计，所有Broker都会监听controller的状态，当controller出现故障时，重新选举新的controller。

### Producer
主要工作是生产消息，并将消息按照一定的规则（选择partition的规则有很多，可以使hash选择，也可以是轮询全部partition）推送到Topic的partition中。

### Consumer
主要工作是从Topic中拉取消息，并将消息进行消费。某个consumer消费partition的哪个offset由consumer自己维护。
**这样的设计的好处：**
1. 避免了kafka server端维护consumer消费位置的开销，尤其是在consumer数量众多的时候。
2. 如果由kafka server端管理每个consumer的消费状态，一旦kafka server端出现延时或者消费状态丢失，将会影响大量的consumer。
3. 提高consumer的灵活性，consumer可以按照自己需要的顺序和模式拉取消息进行消费。例如，consumer可以通过修改其消费的位置实现针对某些特殊key的消息进行反复消费，或者跳过某些消息的需求。


### Consumer Group
- 多个consumer可以组成一个consumer group，一个consumer只能属于一个CG。CG保证其定义的Topic的每个partition只被分配给此CG中的一个consumer处理。

- 如果多个CG订阅同一个Topic，CG彼此之间不会干扰。
    - 广播：如果要实现一个消息被多个consumer同时消费，则将每个consumer单独放在一个CG中。
    - 单播：如果要实现一个消息只被一个consumer消费，则将所有consumer放在同一个CG中。

- 通过向CG中添加consumer来实现consumer的水平扩展和故障转移

**注意：**
CG中的consumer不是越多越好，当其中的consumer数量超过partition数量时，会有consumer没有分配到partition而造成浪费资源。