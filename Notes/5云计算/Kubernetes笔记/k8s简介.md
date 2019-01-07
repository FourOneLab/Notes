Kubernetes是Google开源的容器集群管理系统，其提供应用部署、维护、 扩展机制等功能，利用Kubernetes能方便地管理跨机器运行容器化的应用，其主要功能如下：

- 使用Docker对应用程序包装(package)、实例化(instantiate)、运行(run)
- 以集群的方式运行、管理跨机器的容器
- 解决Docker跨机器容器之间的通讯问题
K- ubernetes的自我修复机制使得容器集群总是运行在用户期望的状态

当前Kubernetes支持GCE、vShpere、CoreOS、OpenShift、Azure等平台，除此之外，**也可以直接运行在物理机上**。

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/37F45B8EF26648EC9745CB6AE553B675/8458)

## Kubernetes资源对象
### Pods：
Pod是Kubernetes的基本操作单元，**把相关的一个或多个容器构成一个Pod**，通常Pod里的容器运行相同的应用。==Pod包含的容器运行在同一个Minion(Host)上==，看作一个统一管理单元，共享相同的**volumes**和**network namespace**/**IP**和**Port**空间。

### Services：
Services也是Kubernetes的基本操作单元，**是真实应用服务的抽象**，每一个服务后面都有很多对应的容器来支持，++通过Proxy的port和服务selector决定服务请求传递给后端提供服务的容器++，对外表现为一个单一访问接口，外部不需要了解后端如何运行，这给扩展或维护后端带来很大的好处。

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/C9665DD1A81E423DB4CB9E268848588D/8460)

### Replication Controllers：
Replication Controller确保任何时候Kubernetes集群中有指定数量的pod副本(replicas)在运行， 如果少于指定数量的pod副本(replicas)，Replication Controller会启动新的Container，反之会杀死多余的以保证数量不变。

Replication Controller使用预先定义的pod模板创建pods，一旦创建成功，pod 模板和创建的pods没有任何关联，**可以修改pod 模板而不会对已创建pods有任何影响**，**也可以直接更新通过Replication Controller创建的pods**。对于利用pod 模板创建的pods，Replication Controller根据label selector来关联，通过修改pods的label可以删除对应的pods。

##### Replication Controller主要有如下用法：
- **Rescheduling**：Replication Controller会确保Kubernetes集群中指定的pod副本(replicas)在运行， 即使在节点出错时。
- **Scaling**：通过修改Replication Controller的副本(replicas)数量来水平扩展或者缩小运行的pods。
- **Rolling updates**：Replication Controller的设计原则使得可以一个一个地替换pods来rolling updates服务。
- **Multiple release tracks**：如果需要在系统中运行multiple release的服务，Replication Controller使用labels来区分multiple release tracks。

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/BAE89B900D534852869F47923DCA8194/8462)

### Labels：
Labels是用于区分Pod、Service、Replication Controller的key/value键值对，Pod、Service、 Replication Controller可以有多个label，但是每个label的key只能对应一个value。

Labels是Service和Replication Controller运行的基础，为了将访问Service的请求转发给后端提供服务的多个容器，正是通过标识容器的labels来选择正确的容器。

同样，Replication Controller也使用labels来管理通过pod 模板创建的一组容器，这样Replication Controller可以更加容易，方便地管理多个容器，无论有多少容器。

## Kuberbetes构件
Kubenetes整体框架如下图，主要包括kubecfg、Master API Server、Kubelet、Minion(Host)以及Proxy。
![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/29156EDB4F2C47029E5CBE4B68AA0732/8464)

### Master：
Master定义了Kubernetes 集群Master/API Server的主要声明，包括Pod Registry、Controller Registry、Service Registry、Endpoint Registry、Minion Registry、Binding Registry、RESTStorage以及Client, 是client(Kubecfg)调用Kubernetes API，管理Kubernetes主要构件Pods、Services、Minions、容器的入口。

Master由API Server、Scheduler以及Registry等组成。

##### 下图是Master的工作流程：
![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/10E13D4C6889409FA0DAB09008F33074/8466)

1. Kubecfg将特定的请求，比如创建Pod，发送给Kubernetes Client。
2. Kubernetes Client将请求发送给API server。
3. API Server根据请求的类型，比如创建Pod时storage类型是pods，然后依此选择何种REST Storage API对请求作出处理。
4. REST Storage API对请求作相应的处理。
5. 将处理的结果存入高可用键值存储系统Etcd中。
6. 在API Server响应Kubecfg的请求后，Scheduler会根据Kubernetes Client获取集群中运行Pod及Minion信息。
7. 依据从Kubernetes Client获取的信息，Scheduler将未分发的Pod分发到可用的Minion节点上。


##### Master主要构件及工作流：
- Minion Registry：负责跟踪Kubernetes 集群中有多少Minion(Host)。Kubernetes封装Minion Registry成实现Kubernetes API Server的RESTful API接口REST，通过这些API，我们可以对Minion Registry做Create、Get、List、Delete操作，由于Minon只能被创建或删除，所以不支持Update操作，并把Minion的相关配置信息存储到etcd。除此之外，Scheduler算法根据Minion的资源容量来确定是否将新建Pod分发到该Minion节点。


- Pod Registry：负责跟踪Kubernetes集群中有多少Pod在运行，以及这些Pod跟Minion是如何的映射关系。将Pod Registry和Cloud Provider信息及其他相关信息封装成实现Kubernetes API Server的RESTful API接口REST。通过这些API，我们可以对Pod进行Create、Get、List、Update、Delete操作，并将Pod的信息存储到etcd中，而且可以通过Watch接口监视Pod的变化情况，比如一个Pod被新建、删除或者更新。

- Service Registry：负责跟踪Kubernetes集群中运行的所有服务。根据提供的Cloud Provider及Minion Registry信息把Service Registry封装成实现Kubernetes API Server需要的RESTful API接口REST。利用这些接口，我们可以对Service进行Create、Get、List、Update、Delete操作，以及监视Service变化情况的watch操作，并把Service信息存储到etcd。

- Controller Registry：负责跟踪Kubernetes集群中所有的Replication Controller，Replication Controller维护着指定数量的pod 副本(replicas)拷贝，如果其中的一个容器死掉，Replication Controller会自动启动一个新的容器，如果死掉的容器恢复，其会杀死多出的容器以保证指定的拷贝不变。通过封装Controller Registry为实现Kubernetes API Server的RESTful API接口REST， 利用这些接口，我们可以对Replication Controller进行Create、Get、List、Update、Delete操作，以及监视Replication Controller变化情况的watch操作，并把Replication Controller信息存储到etcd。

- Endpoints Registry：负责收集Service的endpoint，比如Name："mysql"，Endpoints:["10.10.1.1:1909"，"10.10.2.2:8834"]，同Pod Registry，Controller Registry也实现了Kubernetes API Server的RESTful API接口，可以做Create、Get、List、Update、Delete以及watch操作。

- Bindig Registry：包括一个需要绑定Pod的ID和Pod被绑定的Host，Scheduler写Binding Registry后，需绑定的Pod被绑定到一个host。Binding Registry也实现了Kubernetes API Server的RESTful API接口，但Binding Registry是一个write-only对象，所有只有Create操作可以使用， 否则会引起错误。

- Scheduler：收集和分析当前Kubernetes集群中所有Minion节点的资源(内存、CPU)负载情况，然后依此分发新建的Pod到Kubernetes集群中可用的节点。由于一旦Minion节点的资源被分配给Pod，那这些资源就不能再分配给其他Pod， 除非这些Pod被删除或者退出， 因此，Kubernetes需要分析集群中所有Minion的资源使用情况，保证分发的工作负载不会超出当前该Minion节点的可用资源范围。具体来说，Scheduler做以下工作：
    -  实时监测Kubernetes集群中未分发的Pod。
    - 实时监测Kubernetes集群中所有运行的Pod，Scheduler需要根据这些Pod的资源状况安全地将未分发的Pod分发到指定的Minion节点上。
    - Scheduler也监测Minion节点信息，由于会频繁查找Minion节点，Scheduler会缓存一份最新的信息在本地。
    - 最后，Scheduler在分发Pod到指定的Minion节点后，会把Pod相关的信息Binding写回API Server。

### Kubelet：
详细结构图：
![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/EF2802D815EB4148B530233A10442384/8468)

根据上图可知Kubelet是Kubernetes集群中每个Minion和Master API Server的连接点，Kubelet运行在每个Minion上，是Master API Server和Minion之间的桥梁，接收Master API Server分配给它的commands和work，与持久性键值存储etcd、file、server和http进行交互，读取配置信息。

Kubelet的主要工作是管理Pod和容器的生命周期，其包括Docker Client、Root Directory、Pod Workers、Etcd Client、Cadvisor Client以及Health Checker组件，具体工作如下：
- 通过Worker给Pod异步运行特定的Action。
- 设置容器的环境变量。
- 给容器绑定Volume。
- 给容器绑定Port。
- 根据指定的Pod运行一个单一容器。
- 杀死容器。
- 给指定的Pod创建network 容器。
- 删除Pod的所有容器。
- 同步Pod的状态。
- 从Cadvisor获取container info、 pod info、root info、machine info。
- 检测Pod的容器健康状态信息。
- 在容器中运行命令。
 
### Proxy
Proxy是为了解决外部网络能够访问跨机器集群中容器提供的应用服务而设计的，从上图可知Proxy服务也运行在每个Minion上。Proxy提供TCP/UDP sockets的proxy，每创建一种Service，Proxy主要从etcd获取Services和Endpoints的配置信息，或者也可以从file获取，然后根据配置信息在Minion上启动一个Proxy的进程并监听相应的服务端口，当外部请求发生时，Proxy会根据Load Balancer将请求分发到后端正确的容器处理。

## Kubernetes 详细架构
![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/90F6300CFF1E44A98CA7DBBAA6ECE8FF/8526)

### Kubernetes主要由以下几个核心组件组成：
- etcd保存了整个集群的状态；
- apiserver提供了资源操作的唯一入口，并提供认证、授权、访问控制、API注册和发现等机制；
- controller manager负责维护集群的状态，比如故障检测、自动扩展、滚动更新等；
- scheduler负责资源的调度，按照预定的调度策略将Pod调度到相应的机器上；
- kubelet负责维护容器的生命周期，同时也负责Volume（CVI）和网络（CNI）的管理；
- Container runtime负责镜像管理以及Pod和容器的真正运行（CRI）；
- kube-proxy负责为Service提供cluster内部的服务发现和负载均衡；

### 除了核心组件，还有一些推荐的Add-ons：
- kube-dns负责为整个集群提供DNS服务
- Ingress Controller为服务提供外网入口
- Heapster提供资源监控
- Dashboard提供GUI
- Federation提供跨可用区的集群
- Fluentd-elasticsearch提供集群日志采集、存储与查询

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/27FA87C69CD64A1E911E5C8037DDC71B/8528)

![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/0C68CEBBD97B463CAF74F959D7AC1B60/8530)

### 分层架构
Kubernetes设计理念和功能其实就是一个类似Linux的分层架构，如下图所示
![image](https://note.youdao.com/yws/public/resource/2a9d776b887651686e00ee8b72f722ff/xmlnote/9E1EDE85AE184F15B6D8D5AD35CD3688/8532)

- 核心层：Kubernetes最核心的功能，对外提供API构建高层的应用，对内提供插件式应用执行环境
- 应用层：部署（无状态应用、有状态应用、批处理任务、集群应用等）和路由（服务发现、DNS解析等）
- 管理层：系统度量（如基础设施、容器和网络的度量），自动化（如自动扩展、动态Provision等）以及策略管理（RBAC、Quota、PSP、NetworkPolicy等）
- 接口层：kubectl命令行工具、客户端SDK以及集群联邦
- 生态系统：在接口层之上的庞大容器集群管理调度的生态系统，可以划分为两个范畴
    - Kubernetes外部：日志、监控、配置管理、CI、CD、Workflow、FaaS、OTS应用、ChatOps等
    - Kubernetes内部：CRI、CNI、CVI、镜像仓库、Cloud Provider、集群自身的配置和管理等
