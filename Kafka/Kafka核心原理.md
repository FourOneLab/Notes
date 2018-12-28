# 负载均衡

负载均衡的两种策略（消费端配置）

```
partition.assignment.strategy = range | round-robin
```


在kafka中partition分发消息给消费者不是以消费为力度进行分配的，是以消费者线程为力度进行分配的。

![image](http://p3.pstatp.com/large/pgc-image/152835703345809cec6eec2)

## Range

kafka中的每个Topic的分区是独立进行分配的，++topic间不受到任何影响++。Topic中先是对partition进行数字排序，线程==按照字典排序==。接下来用

> **分区的数量** / **线程数量** = **每个线程能够分到的消息数量**

> (partition_per_thread= 分区数量/线程数量)

- 如果整除了，那么每个线程依次分配partition_per_thread个分区

- 如果不整除，==低位==的几个thread会多消费分区

如果分区个数少于线程数量，就会出现线程空闲的时候，因为kafka会保证一个分区只能被一个消费者进行消费。++所以建议在配置的时候分区数量和消费者线程数量相等最好。++

## Round-robin

在kafka中一个消费者组是可以订阅多个topic的。当订阅了多个topic后，==内部会把所有topic进行shuffle再按照range策略走一遍==，会保证每个topic在consumer中的线程数量必须相等。

Tips：一般应用range的比较多，如果consumer组中有个线程shutdown了，那么kafka会自动的重新进行负载均衡的分配。这个负载均衡增加了下游的消费能力。而且非常方便的进行消费者的扩展。当然kafka也可以去除这样的负载均衡策略，默认消费端分为**high level**的客户端（启用负载均衡机制）和**simple**的客户端（不启用负载均衡，需要自己决定消费哪个分区的消息）。

# Kafka的持久化

## 消息格式
kafka的消息格式如图

![image](http://p3.pstatp.com/large/pgc-image/1528357031180c1baa379b5)

## 文件系统
kafka会将消息组织到硬盘上，在broker的数据目录中会有以topic名称-分区号命名的文件夹，

在文件夹中存在成对出现的文件。kafka不是将所有消息放到一个大文件里，而是根据消息的offset进行了分段。每一个段内放多少消息是可以配置的。**文件名字代表此文件中的第一个数据的offset**。==index为索引文件==，==log为数据文件==，存放的消息格式见上图。对于index文件维护的是一个**稀疏索引**，由消息的编号指向物理偏移，运行时会被加载到内存。

![image](http://p3.pstatp.com/large/pgc-image/1528357033902d5d61805a3)

# 过期数据清理

kafka既然支持了持久化，它对磁盘空间是有要求的。对于删除过期数据kafka提供了两种策略
## 1. 默认策略为直接删除

- 超过指定的时间的消息：

> log.retention.hours=168

- 超过指定大小后，删除旧的消息：

> log.retention.bytes=1073741824

## 2.压缩（只在特定的业务场景下有意义）

> 全局：log.cleaner.enable=true

> 在特定的topic上：log.cleanup.policy=compact,保留每个key最后一个版本的信息，若最后一个版本消息内容为空，这个key被删除

![image](http://p1.pstatp.com/large/pgc-image/152835703115181d084d041)