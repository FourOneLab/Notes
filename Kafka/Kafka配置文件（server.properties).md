>server.properties是kafka的主要配置文件，**其中必须修改的配置项是log.dirs**，其他配置项根据需要修改。

# Server Basics
参数 & 配置| 描述
---|---
broker.id=0 | 每一个Broker在集群中的唯一标识，即使broker的ip发生了变化，只要这个参数不变，就不会影响consumer 的消费情况
delete.topic.enable=true | 是否允许删除topic，设置为false时，使用管理工具删除topic时并没有真正的删除

# Socket Server Settings
参数 & 配置| 描述
---|---
listeners=PLAINTEXT://hostname:9092 | kafka server 使用的协议、主机名以及端口的格式 , 参考示例1
num.network.threads=3| 接收请求的线程数
num.io.threads=8 | 执行请求的线程数

### 参考示例1：
```
java.net.InetAddress.getCanonicalHostName() if not configured.
FORMAT : listeners = listener_name://host_name:port
EXAMPLE : listeners = PLAINTEXT://your.host.name:9092
```

参数 & 配置| 描述
---|---
advertised.listeners=PLAINTEXT://your.host.name:9092 | broker向生产者和消费者进行广播，如果没有设置，将使用listeners，如果设置了，将使用java.net.InetAddress.getCanonicalHostName()的返回值
listener.security.protocol.map=PLAINTEXT:PLAINTEXT,SSL:SSL,SASL_PLAINTEXT:SASL_PLAINTEXT,SASL_SSL:SASL_SSL | 监听器名称映射到安全协议
socket.send.buffer.bytes=102400 | TCP连接的SO_SNDBUFF缓冲区大小，默认为100KB，如果是-1就是使用擦作系统默认的值
socket.receive.buffer.bytes=102400 | TCP连接的SO_RCVBUFF缓冲区大小，默认为100KB，如果是-1就是使用擦作系统默认的值
socket.request.max.bytes=104857600 |请求的最大长度

### 与缓冲区相关的背景知识

每个TCP socket 在内核中都有一个发送缓冲区（SO_SNDBUFF）和一个接收缓冲区（SO_RCVBUFF）。

- 接收缓冲区：把数据缓冲入内核，应用进程一直没有调用read进行读取的话，此数据会一直缓存在相应socket的接收缓冲区内。无论进程是否读取socket，对端发来的数据都会经由内核接收并且缓存到socket的内核接收缓冲区中。read所做的工作是把内核缓冲区中的数据复制到应用层用户的buffer里面。

- 发送缓冲区：进程调用send发送数据时，将数据复制进socket的内核发送缓冲区中，任何send就会在上层返回，在send返回之时，数据不一定会发送到对端去，send仅仅是把应用层buffer的数据复制进socket的内核发送buffer中。

# Log Basics 
参数 & 配置| 描述
---|---
log.dirs=/tmp/kafka-logs | 用于存储log文件的目录，可以将多个目录用逗号分隔形成一个列表
num.partitions=1 | 每个Topic默认的partition数量，默认为1
num.recovery.threads.per.data.dir=1 | 用来恢复log文件以及关闭时将log数据刷新到磁盘的线程数量，每个目录对应num.recovery.threads.per.data.dir个线程

# Log Flush Policy 
> 以下配置都是全局的，可以在Topic中重新设置，并覆盖这两个配置

参数 & 配置| 描述
---|---
log.flush.interval.messages=10000 | 每隔多少个消息触发一次flush操作，将内存中的消息刷新到硬盘上
log.flush.interval.ms=1000 | 每隔多少毫米触发一次flush操作，将内存中的消息刷新到硬盘上


# Log Retention Policy
>注意，下面有两种配置，一种是基于时间的策略，另一种是基于日志文件大小的策略，两种策略同时配置的话，满足其中一种策略就触发删除Log的操作（总是先删除最旧的日志）

参数 & 配置| 描述
---|---
log.retention.hours=168 | 消息在Kafka中保存时间，168小时之前的log，可以被删除
log.retention.bytes=1073741824 （1G）| 当剩余空间小于log.retention.bytes字节，开始删除log
log.segment.bytes=1073741824 （1G）| segment日志文件大小的上限，当超过这个值会创建新的segment日志文件
log.retention.check.interval.ms=300000 | 每个5分钟，logcleaner线程将检查一次，查看是否有符合上述保留策略的消息可以被删除

# Zookeeper 

参数 & 配置| 描述
---|---
zookeeper.connect=localhost:2181 | Kafka依赖的Zookeeper集群地址，可以配置多个Zookeeper地址，使用逗号分隔
zookeeper.connection.timeout.ms=6000 | Zookeeper连接的超时时间