# 1. RPC 入门
## 1.1 RPC 框架原理
RPC 框架的目标就是让**远程服务调用更加简单、透明**，RPC框架负责++屏蔽底层的传输方式++（**TCP**或者**UDP**）、++序列化方式++（**XML**/**Json**/**二进制**）和++通信细节++。==服务调用者可以像调用本地接口一样调用远程的服务提供者==，而不需要关心底层通信细节和调用过程。

RPC 框架的调用原理图如下所示：
![image](https://static001.geekbang.org/resource/image/b2/fb/b265dc0bd6eae1b88b236f517609c9fb.png)

## 1.2 业界主流的 RPC 框架
业界主流的 RPC 框架整体上分为三类：
1. 支持**多语言**的 RPC 框架，比较成熟的有 Google 的 **gRPC**、Apache（Facebook）的 **Thrift**；
2. 只支持特定语言的 RPC 框架，例如新浪微博的 **Motan**；
3. 支持**服务治理**等服务化特性的分布式服务框架，其++底层内核仍然是 RPC 框架++, 例如阿里的
**Dubbo**。

随着微服务的发展，基于语言中立性原则构建微服务，逐渐成为一种主流模式，例如:
- 对于后端并发处理要求高的微服务，比较适合采用 **Go 语言**构建，
- 对于前端的 Web 界面，则更适合 **Java** 和 **JavaScript**。

因此，基于多语言的 RPC 框架来构建微服务，是一种比较好的技术选择。

>例如 Netflix，API 服务编排层和后端的微服务之间就采用 gRPC 进行通信。

## 1.3 gRPC 简介
gRPC 是一个高性能、开源和通用的 RPC 框架，面向服务端和移动端，基于 HTTP/2 设计。

### 1.3.1 gRPC 概览
gRPC 是由 Google 开发并开源的一种**语言中立**的 RPC 框架，当前支持 C、Java 和 Go 语言，其中
C 版本支持 C、C++、Node.js、C# 等。

当前 Java 版本最新 Release 版为 1.5.0，Git 地址如下：https://github.com/grpc/grpc-java

gRPC 的调用示例如下所示：
![image](https://static001.geekbang.org/resource/image/6d/d9/6d9a335ad96491e4d610a31b5089a2d9.png)

### 1.3.2 gRPC 特点
1. 语言中立，支持多种语言；
2. 基于 IDL 文件定义服务，通过 proto3 工具生成指定语言的数据结构、服务端接口以及客户端Stub；
3. 通信协议基于标准的 HTTP/2 设计，支持双向流、消息头压缩、单 TCP 的多路复用、服务端推送等特性，++这些特性使得 gRPC 在移动端设备上更加省电和节省网络流量++；
4. 序列化支持 PB（Protocol Buffer）和 JSON，PB 是一种语言无关的高性能序列化框架，基于HTTP/2 + PB, 保障了 RPC 调用的高性能。
# 2. gRPC 服务端创建
以官方的 helloworld 为例，介绍 gRPC服务端创建以及 service 调用流程（采用简单 RPC 模式）。

## 2.1 服务端创建业务代码
服务定义如下（helloworld.proto）：

```
service Greeter {
  rpc SayHello (HelloRequest) returns (HelloReply) {}
}
message HelloRequest {
  string name = 1;
}
message HelloReply {
  string message = 1;
}
```
服务端创建代码如下（HelloWorldServer类）：

```
private void start() throws IOException {
    /* The port on which the server should run */
    int port = 50051;
    server = ServerBuilder.forPort(port)
        .addService(new GreeterImpl())
        .build()
        .start();
...
```
其中，服务端接口实现类（Greeterlpml）如下所示：

```
static class GreeterImpl extends GreeterGrpc.GreeterImplBase {
    @Override
    public void sayHello(HelloRequest req, StreamObserver<HelloReply> responseObserver) {
      HelloReply reply = HelloReply.newBuilder().setMessage("Hello " + req.getName()).build();
      responseObserver.onNext(reply);
      responseObserver.onCompleted();
    }
  }
```

## 2.2 服务端创建流程
gRPC 服务端创建采用 Build 模式，对底层服务绑定、transportServer 和 NettyServer 的创建和实例化做了封装和屏蔽，让服务调用者不用关心 RPC 调用细节，整体上分为三个过程：
1. 创建 Netty HTTP/2 服务端；
2. 将需要调用的服务端接口实现类注册到内部的 Registry 中，RPC 调用时，可以根据 RPC 请求消息中的服务定义信息查询到服务接口实现类；
3. 创建 gRPC Server，它是 gRPC 服务端的抽象，聚合了各种 Listener，用于 RPC 消息的统一调度和处理。

下面我们看下 gRPC 服务端创建流程：
![image](https://static001.geekbang.org/resource/image/c6/37/c64c0e8e97711dc62e866861cd5c2e37.png)