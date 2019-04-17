在完成调度之后，kubernetes就需要负责将这个调度城管的Pod，在宿主机上创建出来，并把它所定义的各个容器启动起来。这是kubelet这个核心组件的主要功能。

> 与kubelet以及容器运行时管理相关的内容，都属于SIG-Node的范畴。SIG-Node和kubelet是kubernetes整套体系里非常核心的一部分，它们才是kubernetes容器编排与管理系统跟容器打交道的主要场所。

在kubernetes中有两个不可被替代的组件：
1. kube-apiserver
2. kubelet

**不建议对kubelet的代码进行大量的改动，保持kubelet跟上游基本一致的重要性，就跟保持kube-apiserver跟上游一致是一个道理**。

kubelet也是按照控制器模式工作的，工作原理如下图所示：

![image](https://static001.geekbang.org/resource/image/91/03/914e097aed10b9ff39b509759f8b1d03.png)

kubelet的工作核心，就是一个控制循环（即SyncLoop大圈），驱动这个控制循环运行的实践包括：
1. Pod更新事件
2. Pod生命周期变化
3. kubelet本身设置的执行周期
4. 定时的清理事件

与其他控制器类似，kubelet启动的时候：
1. 做的第一件事情，就是设置Listers，注册它所关心的各种事件的Informer，这些Informer就是SyncLoop需要处理的数据的来源。
2. kubelet负责维护很多其他的子控制循环（小圈），这些小的控制循序的责任就是通过控制器模式，完成kubelet的某项具体职责，如：
   1. Volume Manager
   2. Image Manager
   3. Node Status Manager：负责响应Node的状态变化，然后将Node的状态收集起来，并通过Heartbeat的方式上报给APIServer
   4. CPU Manager：负责维护Node的CPU核的信息，以便在Pod通过cpuset的方式请求CPU核的时候，能够正确地管理CPU核的使用量和可用量


kubelet通过WATCH机制（WATCH的过滤条件是该Pod的nodeName字段与自己是否相同）监听与自己相关的Pod对象的变化：
1. kubelet会把这些Pod的信息缓存在自己的内存里
2. 当Pod完成调度与Node绑定后，Pod的变化会触发kubelet在控制循环里注册的Handler（即图中HandlePods部分）
3. 通过检查Pod在kubelet内存里的状态，kubelet能够判断出这是一个新调度过来的Pod，从而触发Handler里ADD事件对应的处理逻辑

具体的处理过程中，kubelet会启动一个叫Pod Updata Worker的单独的Goroutine来完成Pod的处理工作。

如果是ADD事件：
1. kubelet为这个新的Pod生成对应的Pod Status
2. 检查Pod所声明使用的Volume是否准备好
3. 调用下层的容器运行时（如Docker），开始创建这个Pod所定义的容器

如果是Update事件：
1. kubelet会根据Pod对象具体的变更情况，调用下层容器运行时进行容器的重建工作

> 注意，**kubelet调用下层容器运行时的执行过程，并不会直接调动Docker的API，而是通过一组叫作CRI的gRPC接口来间接执行**。之所以要在kubelet中引入这样一层单独的抽象，是为了对kubernetes屏蔽下层容器运行时的差异。在v1.6之前的版本，都是直接调用Docker的API来创建和管理容器的。

把kubelet对容器的操作，统一地抽象成一个接口（即CRI），这样kubelet就只需要跟这个接口打交道，具体的容器项目，Docker、rkt、runV（基于虚拟化技术的强隔离容器），只需要自己提供该接口的实现，然后对kubelet暴露出gRPC服务即可。

增加了CRI之后，kubernetes以及kubelet本身的架构，如下图所示：

![image](https://static001.geekbang.org/resource/image/51/fe/5161bd6201942f7a1ed6d70d7d55acfe.png)

kubernetes通过编排能力创建了一个Pod之后，调度器会为这个Pod选择一个具体的节点来运行：
1. kubelet通过SyncLoop来判断需要执行的具体操作，如创建一个Pod，那么kubelet调用GenericRuntime的通用组件来发起创建Pod 的CRI请求。
2. 如果使用的是Docker项目，负责想用这个请求的是dockershim组件，它把CRI请求里的内容拿出来，组装成Dcoker API请求发送给Docker Daemon

> 目前dockershim是kubelet代码的一部分，将来会被移出来，更普遍的场景是，需要在每台宿主机上单独安装一个负责响应CRI的组件（CRI shim），它扮演的是kubelet和容器项目之间的垫片，它的作用是实现CRI规定的每个接口，然后把具体的CRI请求翻译成对后端容器项目的请求或操作。

kubelet将kubernetes对应用的定义，一步步转换成最终对Docker或者其他容器项目的API请求的过程中，kubelet的SyncLoop和CRI的设计是最重要的关键点。

基于以上设计，SyncLoop本身就要求这个控制循环是绝对不可以被阻塞的，所以凡是在kubelet里有可能会消耗大量时间的操作，如准备Pod 的Volume，拉取镜像等，SyncLoop都会开启单独的Goroutine来进行操作。

# CRI设计与工作原理
CRI机制能够发挥作用的核心，就在于每一种容器项目现在都可以自己实现一个CRI shim，自行对CRI请求进行处理。这样，kubernetes就有了一个统一的容易抽象层，使得下层容器运行时可以自由地对接进入kubernetes中。

> CRI shim就是容器项目的维护者们自由发挥的场地，除了dockershim之外，其他容器运行时的CRI shim都需要额外部署在宿主机上。

CNCF的containerd项目，可以通过一个典型的CRi shim能力，将kubernetes发出的CRI请求，转换成对containerd的调用，然后创建出runC容器。而runC项目才是入职执行设置容器Namespace、Cgroups和chroot等基础操作的组件，这几层的关系如下图所示：

![image](https://static001.geekbang.org/resource/image/62/3d/62c591c4d832d44fed6f76f60be88e3d.png)


CRI待实现的接口如下图所示：

![image](https://static001.geekbang.org/resource/image/f7/16/f7e86505c09239b80ad05aecfb032e16.png)

作为一个CRI shim，containerd对CRI的具体实现如下，把CRI分为两组：
1. RuntimeService,它提供的接口，主要是容器相关的操作，如创建、启动和删除容器，执行exec命令等
2. ImageService，它提供的接口，主要是容器镜像相关的操作，如拉取和除镜像等

## RuntimeService
### 容器声明周期的实现
在这一部分CRI设计的一个重要原则，就是确保这个接口本身，之关注容器不关注Pod，原因是：
1. Pod是kubernetes的编排概念，而不是容器运行时的概念，所以不能假设所以下层容器项目，都能够暴露出可以直接映射为Pod的API。
2. 如果CRI中引入了关于Pod的概念，那么接下来只要Pod API对象的字段发生编号，那么CRI就可能需要跟着变更。早起kubernetes开发中，Pod对象的变化比较频繁，对于CRI这样的标准接口来说，这样的变更率有点麻烦。

所以在CRI的设计中，并没有一个直接创建Pod或者启动Pod的接口。在CRI中有**RunPodSandbox**的接口，其中的PodSandbox它并不是kubernetes里Pod的API对象，只是抽取了Pod中一部分与容器运行时有关的字段，如`HostName`、`DnsConfig`、`CgroupParent`等。

PodSandbox这个接口其实是kubernetes将Pod这个概念映射到容器运行时层面所需要的字段，是一个Pod对象的子集。作为容器项目，需要自己决定如何使用这些字段来实现kubernetes期望的Pod模型，它的原理如下图所示：

![image](https://static001.geekbang.org/resource/image/d9/61/d9fb7404c5dc9e0b5c902f74df9d7a61.png)

1. 比如执行`kubectl run`创建一个包含A和B两个容器的叫作foo的Pod之后，这个Pod的信息最后来到kubelet，kubelet会按照图中所示的顺序调用CRI接口。

> 在具体的CRI shim中，这些接口的实现是完全不同的：
> - 如Docker项目的Dockershim就会创建一个叫作foo的Infra容器（pause容器），用来hold住整个Pod的Network Namespace
> - 如基于虚拟化技术的容器Kata Containers项目的CRI实现会直接创建出一个轻量级虚拟机来充当Pod

2. 在RunPodSandbox接口的实现中，还需要调用networkPlugin.SetUpPod（...）来为整个Sandbox设置网络。这个SetUpPod（...）方法，实际上就在执行CNI插件里的add（...）方法，即CNI插件为Pod创建网络，并且把Infra容器加入到网络中的操作。

3. kubelet继续调用CreateContainer和StartContainer接口来创建和启动容器A、B:对应到dockershim里，就直接启动A、B两个Docker容器。最后宿主机上出现三个Docker容器组成的这个Pod。

4. 如果是Kata Container，CreateContainer和StartContainer接口的实现就之后在创建的轻量级虚拟机中创建A、B容器对应的Mount Namespace，最后在宿主机上，只会用一个叫作foo的轻量级虚拟机在运行。

### 实现exec和logs接口
除了上述对容器声明周期的实现之外，CRI shim的另一个重要工作就是实现exec和logs等接口，这些接口与前面的操作有一个很大的不同，这些gRPC接口调用期间，kubelet需要跟容器项目维护一个长连接来传输数据，这种API成为Streaming API。

CRI shim中对Streaming API的实现，依赖于一套独立的Streaming Server机制，如下图所示：

![image](https://static001.geekbang.org/resource/image/a8/ef/a8e7ff6a6b0c9591a0a4f2b8e9e9bdef.png)

对一个容器执行kubectl exec 命令的时候:
1. 这个请求首先被交给APIServer
2. APIServer会调用kubelet的Exec API
3. kubelet调用CRI的Exec接口
4. CRI shim负责响应kubelet的这个调用请求，它不会直接去调用后端的容器项目来进行处理，之后返回一个URL（这个URL是该CRI shim对应的Streaming Server的地址和端口）给kubelet
5. kubelet拿到这个URL后，以REdirect的方式返回给APIServer
6. APIServer通过重定向来想Streaming Server发起真正的`/exec`请求，与它建立长连接

> 此处的Streaming Server只需要通过使用SIG-Node维护的Streaming API库来实现，Streaming Server会在CRI shim启动时一起启动，一起启动的这一部分如何实现，由CRI shim自行决定，如Docker的dockershim就直接调用Docker的Exec API来作为实现。

## ImageService
这个比较简单。

# 总结
CRI接口的设计相对比较宽松，容器项目在实现CRI的具体接口时，拥有很高的自由，包括：
1. 容器的声明周期管理
2. 如何将Pod映射成为自己的实现
3. 如何调动CNI插件为Pod设置网络

**当对容器有特殊的需求是，优先考虑实现自己的CRI shim，而不是修改kubelet甚至容器项目的代码**。