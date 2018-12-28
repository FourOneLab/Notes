# 概述
RPC(Remote Procedure Call)即远程过程调用，也就是说两台服务器A，B，一个应用部署在A服务器上，想要调用B服务器上应用提供的**函数/方法**，++由于不在一个内存空间，不能直接调用++，需要通过网络来表达调用的语义和传达调用的数据。

RPC使用的是TCP/IP层协议，相对于HTTP要快很多。
- 大型企业使用RPC
- 小型企业使用HTTP

# RPC框架原理
在RPC框架中主要有三个角色：
- **Provider**
- **Consumer**
- **Registry**

![image](http://p3.pstatp.com/large/pgc-image/153490411184517a44f1bb5)
- **Server**: 暴露服务的服务提供方
- **Client**: 调用远程服务的服务消费方
- **Registry**: 服务注册与发现的注册中心

## 服务注册与发现

**服务提供者** 启动后主动向注册中心注册机器 **ip**、**port** 以及提供的 **服务列表**；

**服务消费者** 启动时向注册中心获取服务提供方 **地址列表**，可实现软 **负载均衡** 和 **Failover**；

# RCP调用流程
![image](http://p99.pstatp.com/large/pgc-image/1534904111913a9c1fafe74)
1. 调用客户端句柄；执行传送参数
2. 调用本地系统内核发送网络消息
3. 消息传送到远程主机
4. 服务器句柄得到消息并取得参数
5. 执行远程过程
6. 执行的过程将结果返回服务器句柄
7. 服务器句柄返回结果，调用远程系统内核
8. 消息传回本地主机
9. 客户句柄由内核接收消息
10. 客户接收句柄返回的数据


# 使用的技术
### 1、动态代理

生成 client stub和server stub需要用到Java动态代理技术，可以使用JDK原生的动态代理机制，可以使用一些开源字节码工具框架 如：CgLib、Javassist等。

### 2、序列化

为了能在网络上传输和接收Java对象，需要对它进行 **序列化** 和 **反序列化** 操作。

- **序列化**：将Java对象转换成byte[]的过程，也就是编码的过程；
- **反序列化**：将byte[]转换成Java对象的过程；

可以使用Java原生的序列化机制，但是效率非常低，推荐使用一些开源的、成熟的序列化技术，例如：protobuf、Thrift、hessian、Kryo、Msgpack

关于序列化工具性能比较可以参考：jvm-serializers

### 3、NIO

当前很多RPC框架都直接基于netty这一IO通信框架，比如阿里巴巴的HSF、dubbo，Hadoop Avro，推荐使用Netty 作为底层通信框架。

### 4、服务注册中心

可选技术：
- Redis
- Zookeeper
- Consul
- Etcd
