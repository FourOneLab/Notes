# 概念
1. Cluster：计算、存储、网络资源的合集，利用这些资源运行各种基于容器的应用
2. Master：Cluster的大脑，主要职责是调度，（为了实现高可用，可以运行多个Master）
3. Node：主要职责运行容器应用，由Master管理，负责监控并汇报容器状态，同时根据Master的要求管理容器的生命周期
4. Pod：K8S的最小工作单位，每个Pod中包含一个或多个容器，Pod中的容器作为一个整体被调度，扩展，共享资源，管理生命周期
> Kubernetes 引入Pod的目的：

>1、可管理性（提供了比容器更高层次的抽象，将他们封装在一个部署单元）

>2、通信和资源共享（Pod中的容器在一个网络命名空间下，相同的IP地址和Port空间,可以通过localhost通信，可以共享存储）

    Pod使用方式：
    - (1)运行单一容器
    - (2)运行多个容器（这些容器联系非常紧密，且需要直接共享资源）
    
5. Controller：管理Pod，定义了Pod的部署特性（副本数，运行Node位置等）
>满足不同的应用场景,Kubernetes提供了多种Controller（Deployment、ReplicaSet、DaemonSet、StatefulSet、Job等）
    
    - (1)Deployment:管理Pod多副本，并确保Pod按照期望的状态运行
    - (2)ReplicaSet：Deployment通过ReplicaSet来实现Pod多副本管理（通常不直接使用ReplicaSet）
    - (3)DaemonSet:用于每个Node只能运行一个Node副本的场景
    - (4)StatefulSet：保证Pod的每个副本在整个生命周期中名称不变（保证副本按照固定的顺序启动、更新、删除）
    - (5)Job：用于运行结束就删除的应用

6. Service:定义外界访问一组特定Pod的方式，Service有自己的IP和端口，并且为Pod提供了负载均衡

> Kubernetes 运行容器和访问容器的任务分布由Controller和Service执行。

7. Namespace：将一个物理的Cluster逻辑上会分为多个Cluster


    kubernetes 默认有两个Namespace：
    - (1)default:创建资源时如果不指定，将会放在这个地方
    - (2)kube-system:kubernetes自己创建的系统资源会放在这个地方

# Kubernetes架构
Kubernetes Cluster由Master和Node组成，节点上运行着若干Kubernetes服务
## Master
运行的Daemon服务包括：
1. kube-apiserver
2. kube-scheduler
3. kube-controller-manager
4. etcd
5. Pod网络（如flannel）

### API Server（kube-apiserver）
提供HTTP/HTTPS RESTful API，是集群的前端接口，各种客户端工具（CLI或UI）以及Kubernetes其他组件可以通过它管理集群的各种资源

### Scheduler（kube-scheduler）
负责决定将Pod放在哪个Node上运行，Scheduler在调度时会充分考虑**网络拓扑结构**，当前**各节点负载**，以及应用对**高可用**，**性能**和**数据亲和性**的需求。

### Controller Manager（kube-controller-manager）
管理集群各种资源，保证资源处于预期状态

**Controller Manager由多种Controller组成：**

controller | 作用
---|---
replication Controller | 管理Deployment、StatefulSet、DaemonSet的生命周期
namespace Controller | 管理Namespace资源

### etcd
保存集群的**配置信息**和各种资源的**状态信息**，当数据发生变化时，etcd会快速通知Kubernetes的相关组件

### Pod网络
Pod要能够正常通信，Kubernetes 集群必须部署Pod网络，flannel为其中一个可选方案

## Node
kubernetes支持Docker 、 rkt等容器Runtime，Node上运行的Daemon服务包括：
1. kubelet
2. kube-proxy
3. Pod网络（如flannel）

#### Kubelet
是Node的agent，当scheduler确定在某个Node上运行Pod后，将Pod具体的配置信息（image、volume等）发送给该节点的kubelet，kubelet根据这些信息创建并运行容器，并向Master报告运行状态

#### kube-proxy
Service在逻辑上代表了后端的多个pod，外界通过service访问pod。kube-proxy负责将访问Service的TCP/UDP数据流转发到后端的容器，如果有多个副本，kube-proxy会实现负载均衡

#### Pod网络
同上

部署完成的Kubernetes集群中运行如下pod：

```

```

这些pod都是运行在kube-system命名空间中，kube-dns组件是为集群提供DNS服务，只有kubelet没有容器化，通过systemd服务进行管理，如下图所示：

```
[root@tdc-01 ~]# systemctl status kubelet.service 
● kubelet.service - Kubernetes Kubelet
   Loaded: loaded (/usr/lib/systemd/system/kubelet.service; enabled; vendor preset: disabled)
   Active: active (running) since 五 2018-10-12 02:07:46 CST; 13h ago
 Main PID: 2586 (kubelet)
   CGroup: /system.slice/kubelet.service
           ├─2586 /opt/kubernetes/bin/kubelet --logtostderr=true --v=4 --address=0.0.0.0 --cluster_dns=10.10.0.10 --cluster_domain=transwarp.local --port=10250 --hostname_override=172.16...
           └─2671 journalctl -k -f

```
# 运行应用
## Deployment
kubernetes 支持两种创建资源的方式：
- 用kubectl命令直接创建，比如：
```
kubectl run Nginx-deployment --image=nginx：1.7.9 --replicas=2
```
- 通过配置文件和kubectl apply创建资源

> 基于命令的方式简单、直观、快捷、适合临时测试或实验

> 基于配置文件的方式描述详细，模板可重复部署，适合正式的跨环境的规模化部署

### YAML配置文件格式

```
apiVersion: extensions/v1beta1          //当前配置格式的版本
kind: Deployment            //资源的类型
metadata:           //资源的元数据
  name: wdg4f                  
  namespace: kube-system
spec:           //该Deployment的规格
  replicas: 3           //副本数
  template:         //pod的模板
    metadata：          //pod的元数据
      labels：          //至少定义一个labels
        app：server
    spec：          //该pod的规格，pod的名字和镜像地址等
      containers：
      - name：    
        images：
      nodeSelector：  ①
        type：gpu
```
### 用label控制Pod的位置
比如，不同的节点上配置不同的资源，不同的pod调度到对应的node上，使用对应的资源

```
kubectl lable node node-1 type=gpu      //给node贴label

kubectl get node --show-labels    //查看node的label

kubectl label node node-1 type-     //删除对应的label
```

node已经贴好对应的标签，在deployment中定义的pod中配置好对应的nodeSelector即可，如上配置文件中的①位置。


## DaemonSet
每个Node上最多只能运行一个副本，典型的应用场景如下：
1. 在集群的各个节点上运行存储Daemon：比如glusterd或ceph
2. 在每个节点上运行日志收集Daemon：比如flunentd或logstash
3. 在每个节点上运行监控Daemon：比如prometheus Node Exporter 或 collectd

> kubernetes 自己就在用DaemonSet运行系统组件，如kube-proxy和kube-fannel-ds

### Job
容器按照持续运行的时间可以分为：服务类容器和工作类容器
- 服务类容器（Deployment、ReplicaSet、Daemon）：持续提供服务，需要一直运行，如HTTP Server
- 工作类容器（Job）：一次性任务，如批处理程序

#### Job并行
如果希望同时执行多个pod来提高执行效率，在Job的配置文件中添加parallelism参数，类设置并发数，该参数添加在Job配置文件的spec中。

```
apiVersion: extensions/v1beta1          //当前配置格式的版本
kind: Job            //资源的类型
metadata:           //资源的元数据
  name: jobs                  
spec:           //该Job的规格
  parallelism：3           //并行数，默认为1
  completions：9          //设置Job成功完成pod的总数，默认为1
  template:         //pod的模板
```
以上配置文件的意思，每次并发运行3个pod，直到总共有9个pod成功完成。

### 定时Job
在Linux中有一个cron程序定时执行任务，kubernetes中的cronJob提供类似功能
```
apiVersion: extensions/v1beta1          //当前配置格式的版本
kind: CronJob            //资源的类型
metadata:           //资源的元数据
  name: jobs                  
spec:           //该Job的规格
  scheduler： "*/****"      //与Linux中cron的语法一致
  jobTemplate:         //pod的模板
    spec：
      template：
```

kubernetes默认没有开启定时任务功能，需要在kube-apiserver中添加配置，修改配置文件/etc/kubernetes/manifests/kube-apiserver.yaml，在command中添加

```
--runtime-config=batch/v2alpha1=true
```

或者在kube-apiserver这个pod启动的时候以启动参数的形式添加，并重启kubelet服务

# Service访问pod

Service 从逻辑上代表了一组pod，通过label来选择对应pod。
- Pod有自己的IP，这个pod-IP会随着Pod的销毁而改变，被kubernetes集群中的容器和节点访问
- Service也有自己的IP，这个cluster-IP不会变

客户端只需要访问Service的IP，kubernetes负责建立和维护Service和Pod的映射关系。


```
apiVersion: v1          //当前配置格式的版本
kind: Service            //资源的类型
metadata:           //资源的元数据
  name: svc                  
spec:           //该Service的规格
  selector：
    run：httpd
  ports:
  - protocol：TCP
    port：8080      //service暴露端口
    targetPort：80      //映射的pod的端口
```

cluster-IP和pod-IP通过iptables实现映射


## Cluster-IP 底层实现

cluster-ip是一个虚拟的IP，有kubernetes节点上的iptabels规则管理。

iptables将访问Service的流量转发到后端Pod，使用类似轮询的负载均衡策略。

> kubernetes集群中的每一个节点都配置了相同的iptables规则，这样确保整个集群都能够通过Service的Cluster IP访问到Service

## DNS访问Service
在集群中除了通过Cluster IP访问Service还可以通过DNS访问，在kube-system命名空间中运行着kube-dns组件，这是一个DNS服务器，当有新的Service创建时，kube-dns会添加该Service的DNS记录。

集群中的pod可以通过<Service_Name>.<NameSpace_Name>访问到Service，例如：

```
wget SVC.default：8080

nslookup svc.default   //查看service的DNS

Server：    10.96.0.10
Address：   10.96.0.10  kube-dns.kube-system.svc.cluster.local

Name：  SVC
Address：   10.99.229.179   svc.default.svc.cluster.local
```

- DNS服务器是kube-dns.kube-system.svc.cluster.local，这个就是kube-dns组件，它是kube-system命名空间中的一个service
- svc.default.svc.cluster.local是svc的完整域名

## 外网访问Service
除了集群内部可以访问Service，很多时候希望应用的Service能够暴露给集群外部，kubernetes提供了多种类型的Service，默认的是ClusterIP。

1. Cluster IP:Service通过集群内部的IP地址对外提供服务，只有集群内部的节点或Pod能访问
2. NodePort:Service通过集群中节点的静态端口对外提供服务，集群外部可以通过<NodeIP>.<NodePort>访问Service
3. LoadBalancer: 云提供商负责将load balancer的流量导向Servcice


**NodePort**
```
apiVersion: v1          
kind: Service
metadata
  name: svc                  
spec
  type：NodePort
  selector：
    run：httpd
  ports:
  - protocol：TCP
    nodeport：3000  //配置这个参数，则指定了service的nodeport  【节点监听的端口】
    port：8080      //service暴露端口                          【cluster IP 监听的端口】
    targetPort：80      //映射的pod的端口                      【pod监听的端口】
```
以上配置文件创建的Service中不但有cluster IP，同时还有External IP 为Nodes 并且将service的8080端口和节点的静态端口进行绑定，kubernetes会从30000~32767中随机分配一个,每个节点都会监听这个端口，并将请求转发给Service。

**同样，通过iptables将访问节点端口的流量转发给service的后台pod。**

# 健康检查
强大的自愈能力是Kubernetes这类容器编排引擎的重要特性，默认的实现是自动重启发生故障的容器。也可以使用Liveness和Readiness 探测机制设置更精细的健康检查，从而实现如下需求：
1. 零停机部署
2. 避免部署无效镜像
3. 更加安全的滚动升级

## 默认的健康检查
每个容器启动时都会执行一个进程，此进程由Dockerfile的**CMD**或**ENTRYPOINT**指定。如果该进程退出时的返回码非零，则认为容器发生故障，Kubernetes就根据restartPolicy重启容器。

restartPolicy：
- Always（默认）
- OnFailure
- Never

以上情况适用于，pod发生故障后进程退出，且退出码不为0。但是存在一些情况，pod发生故障，但是进程并没有退出，比如系统超负载或者资源死锁等，此时进程并没有异常退出的，在这种情况下重启容器是最直接有效的解决方案。

处理以上情况使用Liveness探测。

## Liveness探测
Liveness探测让用户可以**自定义判断容器是否健康**的条件。

```
apiVersion: v1          
kind: Pod
metadata
  labels：
    test：liveness
  name: liveness                  
spec
  restartPolicy：OnFailure
  containers：
  - name: liveness
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    livenessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 10
      periodSeconds: 5
```
以上pod的配置文件中，启动进程首先创建文件/tmp/healthy 30秒后删除； 判断条件为如果文件存在，则任务容器正常。

**livenessProbe部分定义了如何执行Liveness操作：**
- 探测方法：通过cat命令检查文件是否存在，如果存在返回0，否则返回非0
- initialDelaySeconds：指定容器启动后10秒开始执行Liveness探测（一般根据应用启动的准备时间来设置该参数）
- periodSeconds：指定每隔多少时间执行一次Liveness探测，如果连续执行三次都是失败则会杀掉并重启容器。

```
kubectl describe pod liveness  //查看liveness日志
```

**Liveness探测 告诉kubernetes什么时候通过重启容器实现自愈**
## Readiness探测
Readiness探测 告诉kubernetes什么时候可以将容器加入到Service负载均衡池中，对外提供服务。

Readiness语法和Liveness完全一致：

```
apiVersion: v1          
kind: Pod
metadata
  labels：
    test：readiness
  name: readiness               
spec
  restartPolicy：OnFailure
  containers：
  - name: readiness
    image: busybox
    args:
    - /bin/sh
    - -c
    - touch /tmp/healthy; sleep 30; rm -rf /tmp/healthy; sleep 600
    readinessProbe:
      exec:
        command:
        - cat
        - /tmp/healthy
      initialDelaySeconds: 10
      periodSeconds: 5
```
以上配置文件创建的pod 在经过initialDelaySeconds+periodSeconds之后开始进行Readiness探测，探测成功后pod状态被设置为Ready


```
kubectl describe pod readiness  //查看readiness日志
```


### liveness与readiness
- 如果不进行特殊的配置，kubernetes将对这两个探测采取相同的默认行为，通过判断容器启动进程的返回值是否为零来判断探测是否成功。

- 两者的配置方法一样，支持的配置参数一样，不同之处在于：
    1. liveness探测后重启容器
    2. readiness探测后将容器设置为不可用

- liveness探测和readiness探测是独立运行的，两者之间没有依赖：
    1. liveness探测判断容器是否需要重启以实现自愈
    2. readiness探测判断容器是否已经准备好对外提供服务

# 数据管理
容器销毁时，保存在容器内部文件系统中的数据会被清除，为了持久化保存容器中的数据，使用kubernetes Volume。Volume的生命周期独立于容器，Pod中的容器可能被销毁和重建，但是volume会被保留。

本质上Volume是一个目录，当volume被mount到pod中时，pod中的所有容器都可以访问这个volume。

volume支持多种backend：
- emptyDir
- hostPath
- GCE Persisten Disk
- AWS Elastic Block Store
- NFS
- Ceph
- 等

>volume提供了对各种backend的抽象，容器在使用volume读写数据时不需要关心数据到底是存放在本地节点的文件系统，还是云硬盘上。所有类型的volume都只是一个目录。

## emptyDir
最基础的volume类型，是host上的一个空目录，对于容器是持久化的，对于pod不是持久化的。当pod从节点删除时volume 的内容也会被删除。

**emptyDir Volume的生命周期与Pod一致。pod中所有容器可以共享volume，它们可以指定各自的mount路径**

emptyDir是Docker Host文件系统里的目录，其效果相当于执行了docker -v /dir ,通过docker inscept 可以查看到容器的详细配置

```
/var/lib/kubelet/pods/062b215e-c0b4-11e8-badb-0cc47aa57eee/volumes/kubernetes.io~empty-dir/dir
```
这个是emptyDir在host上的真正路径。

## hostPath
hostPath的作用是将Docker Host文件系统中已经存在的目录mount给pod的容器。

> 大部分应用都不会使用hostPath（这实际上增加了pod与节点的耦合程度），限制了Pod的使用。那些需要访问kubernetes或docker内部数据（配置文件或二进制库）的应用需要使用hostPath。

如kube-apiserver和kube-controller-manager就是这样的应用。

当pod销毁，hostPath对应的目录还是会被保留的，只有当节点奔溃才会导致hostPath不可用。

## PV & PVC
- PV：外部存储系统中的一块存储空间，具有持久性，生命周期独立于Pod
- PVC： 对PV的申请（Claim），需要为Pod分配存储资源时，用户可以创建一个PVC，指明存储资源的容量大小和访问模式等，kubernetes会查找并提供满足条件的PV

> 有了PVC用户只需要告诉kubernetes需要什么样的存储资源，而不关心真正的空间从哪里分配，如何访问等底层细节。


```
apiVersion: v1          
kind: PersistentVolume
metadata
  name：mypv1
spec:
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Recycle
  StorageClassName: nfs  //指定PV的class的分类，pvc可以指定class申请相应class的PV
  nfs:
    path: /nfs/data
    server: 192.168.1.1
```
**PV 支持的类型：**
- AWS EBS
- Ceph
- NFS
- 等

**PV有三种访问模式(accessModes)：**
1. ReadWriteOnce：以read-write模式mount到单节点
2. ReadOnlyMany：以read-only模式mount到多个节点
3. ReadWriteMany：以read-write模式mount到多个节点


**PV有三种回收策略(persistentVolumeReclaimPolicy)：**
1. Retain：手工回收
2. Recycle：清除PV中的数据,效果类似于rm -rf /the volume / *
3. Delete：删除Store Provider 上的对应存储资源，例如AWS EBS、GCE PD、Azure Disk、Openstack Cinder Volume等


```
apiVersion: v1          
kind: PersistentVolumeClaim
metadata
  name：mypvc1
spec:
  accessModes:
    - ReadWriteOnce
  resources：
    request：
      storage：1Gi
  StorageClassName:nfs  //pvc指定class申请相应class的PV
```

在pod的配置文件中使用对应的pvc即可，就像使用普通Volume的格式那样使用。

## 回收PV和PVC
当不需要使用PV时，删除PVC然后回收PV

**PV的状态：**
- Available：可以被PVC申请，可能是新创建的或者是被释放并且数据清除完成的
- Bound：已经被PVC使用
- Released：解除了pvc对该PV的bound，并根据PV的回收策略，对其中的数据进行操作：
    1. 策略为Recycle，此时正在清除其中的数据（kubernetes启动一个新的pod去删除PV中的数据）
    2. 策略为Retain，数据需要手动回收，不会被自动删除，PV一直处于released状态，不能被再次申请（删除该PV并重新创建，可以使得它能够再次本申请，此时原来的PV中的数据不会被删除，相当于重新创建了一个新的同名的PV，在物理存储介质中占用了一块新存储空间）

## PV动态供给
上面的例子都是手动创建PV，然后手动创建PVC去bound对应的PV，然后pod手动mount对应的pvc，以上过程，成为静态供给

动态供给的意思是，**如果没有满足PVC条件的PV，会动态创建PV**，相比于静态供给的优势在于++不需要提前创建好PV++，减少工作量，提高效率。

动态供给是通过StorageClass实现的，在StorageClass中定义好如何创建PV，如下：

**StrorageClass standard：**
```
apiVersion：storage.k8s.io/v1
kind：StorageClass
metadata：
  name：standard
provisioner：kubernetes.io/aws-ebs
parameters：
  type：gp2
reclaimPolicy：Retain
```
**StorageClass slow：**
```
apiVersion：storage.k8s.io/v1
kind：StorageClass
metadata：
  name：slow
provisioner：kubernetes.io/aws-ebs
parameters：
  type：io1
  zones: us-east-1d,us-east-1c
  iopsPerGB: "10"
```

StorageClass 支持delete和retain两种reclaimPolicy，默认为Delete，PVC配置文件中只需要指定storageClassName:standard/slow，其他都一样

kubernetes支持动态供给PV的provisioner如下：
https://kubernetes.io/docs/concepts/storage/storage-classes/ 官网中有表格

# Secret & Configmap
应用启动过程中可能需要一些敏感数信息，如访问数据库的用户名，密码等，将这些信息直接保存在容器镜像中显然不妥。Secret会以密文的方式存储数据，避免了直接在配置文件中保存敏感信息。

**Secret会以Volume的形式mount到pod**，容器可以通过文件的形式使用Secret中的敏感数据，容器㛑能够以环境变量的形式使用这些数据。

## 创建Secret
1. 命令行创建

每个--from-literal对应一个信息条目
```
kubectl ceate secret generic mysecret --from-literal=username=admin --from-literal=password=123456
```
每个文件内容对应一个条目

```
kubectl ceate secret generic mysecret --from-file=./username --from-file=./password
```
文件env.txt中每一行key=value对应一个信息条目

```
kubectl ceate secret generic mysecret --from-env-file=env.txt
```
2. YAML文件创建

```
apiVersion: v1
kind: secret
metadata:
  name: mysecret
data:
  username: YWRtaW4=
  password: MTIzNDU2
```
文件中的敏感数据必须通过base64编码,然后执行kubectl apply 创建secret

## 使用Secret
1. volume方式使用

```
apiVersion：v1
kind：Pod
metadata：
  name：mypod
spec：
  containers：
  - name：mypod
    image：busybox
    volumeMounts：
    - name：foo
      mountPath: "/etc/foo"
      readOnly: true
 volumes:
 - name:foo
   secret:
     secretName:mysecret
     items：        //自定义敏感数据的存储路径
     - key：username
       path: my-group/my-username
     - key: password
       path: my-group/my-password
```
kubernetes会在指定的路径下为每一条敏感数据创建一个文件，文件名就是敏感数据条目的key值，value则以明文存放在对应的文件中,**Secret动态更新，容器中的数据也会动态更新**。

2. 环境变量方式使用
通过volume使用secret，容器必须从文件读取数据，还可以通过环境变量使用Secret。

```
piVersion：v1
kind：Pod
metadata：
  name：mypod
spec：
  containers：
  - name：mypod
    image：busybox
    env：
      - name： SECRET_USERNAME
        valueFrom:
          secretkeyRef:
            name: mysecret
            key: username
      - name： SECRET_PASSWORD
        valueFrom:
          secretkeyRef:
            name: mysecret
            key: password
```

pod 通过环境变量SECRET_USERNAME和SECRET_PASSWORD成功读取到Secret中的数据。以环境变量的方式虽然读取方便，但是无法动态更新。

## 创建ConfigMap
Secret可以为Pod提供敏感数据，对于非敏感数据，如配置信息，可以使用ConfigMap。
1. 命令行创建

每个--from-literal对应一个信息条目
```
kubectl ceate configmap generic myconfigmap --from-literal=config1=xxx --from-literal=config2=yyy
```
每个文件内容对应一个条目

```
kubectl ceate configmap generic myconfigmap --from-file=./config1 --from-file=./config2
```
文件env.txt中每一行key=value对应一个信息条目

```
kubectl ceate configmap generic myconfigmap --from-env-file=env.txt
```
2. YAML文件创建

```
apiVersion: v1
kind: configmap
metadata:
  name: myconfigmap
data:
  config1: xxx
  config2: yyy
```
文件数据直接以明文输入,然后执行kubectl apply 创建configmap

## 使用ConfigMap
1. volume方式使用

```
apiVersion：v1
kind：Pod
metadata：
  name：mypod
spec：
  containers：
  - name：mypod
    image：busybox
    volumeMounts：
    - name：foo
      mountPath: "/etc"     //将volume mount到/etc路径下
      readOnly: true
 volumes:
 - name: foo
   configmap:
     name：myconfigmap
     items：
     - key: logging.conf
       path: myapp/logging.conf         //在volume中指定存放配置文件的相对路径
```

这种方式配置文件支持动态更新。

2. 环境变量方式使用

```
piVersion：v1
kind：Pod
metadata：
  name：mypod
spec：
  containers：
  - name：mypod
    image：busybox
    env：
      - name： CONFIG_1
        valueFrom:
          configMapkeyRef:
            name: myconfigmap
            key: config1
      - name： CONFIG_2
        valueFrom:
          configMapkeyRef:
            name: myconfigmap
            key: config2
```

pod 通过环境变量CONFIG_1和CONFIG_2成功读取到ConfigMap中的数据。

> 大多数情况下，配置信息以文件的形式提供，使用--from-file或YAML方式创建ConfigMap，读取ConfigMap通常采用Volume的方式

# 网络
Pod、 Service、 外部组件之间需要一种可靠的方式找到彼此并进行通信，kubernetes网络负责提供这个保障。

## kubernetes网络模型
采用基于扁平地址的网络模型，每个pod都要自己的IP，相互之间不需要配置NAT（网络地址转换）就能够直接通信，同一个Pod中的容器共享pod的IP，能够通过Localhost通信。

> 这种网络模型可以很方便的迁移传统应用到Kubernetes，每个pod可以被看做一个独立的系统，而Pod中的容器可以被看作同一系统中的不同进程。

### pod内容器之间的通信
当pod被调度到节点后，pod中的所有容器都运行在这个节点上，这些容器共享本地文件系统，IPC和网络命名空间等。

不同pod之间不存在端口冲突问题，每个pod有自己独立的IP地址。当某个容器使用localhost时，意味着使用的是容器所属pod的地址空间。

### pod之间通信
Pod的IP地址是集群可见的，任何其他Pod和节点都可以通过IP直接与Pod通信，这种通信不需要借助任何网络地址转换、隧道或代理技术。Pod内部和外部使用的是同一个IP，这也意味着标准的命名服务和法发现机制，比如DNS都可以直接使用。

### Pod与Service通信
Pod会被频繁的销毁和创建，因此pod的IP是不固定的，Service提供了访问pod的抽象层，无论后端Pod如何变化，Service都作为稳定的前端对外提供服务，同时，Service还提供了高可用和负载均衡功能，Service负责将请求转发给正确的Pod。

### 外部访问
无论Pod的IP还是Service的Cluster IP 都是集群内部的私有IP，kubernetes提供以下两种方式让外界能够与Pod通信：
1. NodePort：Service通过集群节点的静态端口对外提供服务，外部可以通过<NodeIP>.<NodePort>访问Service。
2. LoadBalancer：Service利用Cloud provider 提供的load balancer 对外提供服务，cloud provider 负责将 load balancer的流量导向service。

## CNI
为了保证网络方案的标准化、扩展性、灵活性，采用CNI规范，使用插件模型创建容器的网络栈。

CNI的优点是支持多种容器runtime，CNI的插件模型支持不同组织和公司开发的第三方插件，可以灵活选择合适的网络方案。

目前已经有多种支持Kubernetes的网络方案，比如Flannel、Calico、Canal、Weave Net等，这些不同的方案底层实现不同，有的基于VxLAN的Overlay，有的采用Underlay，性能上有区别。

## Network Policy
Network Policy是kubernetes的一种资源，通过Label来选择Pod，并制定其他Pod或外界如何与这些Pod通信。

> 默认情况下，所以Pod是非隔离的，即任何来源的网络流量都能够访问Pod，没有任何限制。当为Pod定义了Network Policy后，只有Policy允许的流量才能够访问Pod。

**不是所有的网络方案都支持Network Policy，（Fannel不支持，calico支持）。**


```
apiVersion： networing.k8s.io/v1
kind：NetworkPolicy
metadata：
  name: access-httpd
spec:
  podSelector:
    matchLabels:
      run: httpd        //规则应用到有这个label的pod上
  ingress:
  - from:
    - podSelector
        matchLabels:
          access: "true"        //只有label为access："true"的pod能访问
    ports:
    - protocol: TCP
      port: 80          //只能访问端口80
```


# 其他概念
## Service Account & User Account
- User account是为人设计的，而service account则是为Pod中的进程调用Kubernetes API而设计；
- User account是跨namespace的，而service account则是仅局限它所在的namespace；
- 每个namespace都会自动创建一个default service account
- Token controller检测service account的创建，并为它们创建secret

**开启ServiceAccount Admission Controller后:**
1. 每个Pod在创建后都会自动设置spec.serviceAccount为default（除非指定了其他ServiceAccout）
2. 验证Pod引用的service account已经存在，否则拒绝创建
3. 如果Pod没有指定ImagePullSecrets，则把service account的ImagePullSecrets加到Pod中
4. 每个container启动后都会挂载该service account的token和ca.crt到/var/run/secrets/kubernetes.io/serviceaccount/


Service Account为服务提供了一种方便的认证机制，但它不关心授权的问题。可以配合RBAC来为Service Account鉴权：

- 配置–authorization-mode=RBAC和–runtime-config=rbac.authorization.k8s.io/v1alpha1
- 配置–authorization-rbac-super-user=admin
- 定义Role、ClusterRole、RoleBinding或ClusterRoleBinding


## Security Context & PSP
Security Context的目的是限制不可信容器的行为，保护系统和其他容器不受其影响。

Kubernetes提供了三种配置Security Context的方法：

- Container-level Security Context：仅应用到指定的容器
- Pod-level Security Context：应用到Pod内所有容器以及Volume
- Pod Security Policies（PSP）：应用到集群内部所有Pod以及Volume

### Container-level Security Context
Container-level Security Context仅应用到指定的容器上，并且不会影响Volume。比如设置容器运行在特权模式。

### Pod-level Security Context
Pod-level Security Context应用到Pod内所有容器，并且还会影响Volume（包括fsGroup和selinuxOptions）。

### Pod Security Policies（PSP）
Pod Security Policies（PSP）是集群级的Pod安全策略，自动为集群内的Pod和Volume设置Security Context。

使用PSP需要API Server开启extensions/v1beta1/podsecuritypolicy，并且配置PodSecurityPolicyadmission控制器。

支持的控制项
控制项| 说明
---|---
privileged	|运行特权容器
defaultAddCapabilities|	可添加到容器的Capabilities
requiredDropCapabilities|	会从容器中删除的Capabilities
volumes	|控制容器可以使用哪些volume
hostNetwork|	host网络
hostPorts	|允许的host端口列表
hostPID	|使用host PID namespace
hostIPC	|使用host IPC namespace
seLinux	|SELinux Context
runAsUser|	user ID
supplementalGroups|	允许的补充用户组
fsGroup|	volume FSGroup
readOnlyRootFilesystem	|只读根文件系统

## Resource Quotas
资源配额（Resource Quotas）是用来限制用户资源用量的一种机制。

它的工作原理为:
- 资源配额应用在Namespace上，并且每个Namespace最多只能有一个ResourceQuota对象
- 开启计算资源配额后，创建容器时必须配置计算资源请求或限制（也可以用LimitRange设置默认值）
- 用户超额后禁止创建新的资源

### 资源配额的启用
首先，在API Server启动时配置ResourceQuota adminssion control；然后在namespace中创建ResourceQuota对象即可。

### 资源配额的类型
1. 计算资源，包括cpu和memory
    - cpu, limits.cpu, requests.cpu
    - memory, limits.memory, requests.memory
2. 存储资源，包括存储资源的总量以及指定storage class的总量
    - requests.storage：存储资源总量，如500Gi
    - persistentvolumeclaims：pvc的个数
    - .storageclass.storage.k8s.io/requests.storage
    - .storageclass.storage.k8s.io/persistentvolumeclaims
3. 对象数，即可创建的对象的个数
    - pods, replicationcontrollers, configmaps, secrets
    - resourcequotas, persistentvolumeclaims
    - services, services.loadbalancers, services.nodeports

### LimitRange
默认情况下，Kubernetes中所有容器都没有任何CPU和内存限制。LimitRange用来给Namespace增加一个资源限制，包括最小、最大和默认资源。

#### 配额范围

每个配额在创建时可以指定一系列的范围

范围|	说明
---|---
Terminating	|podSpec.ActiveDeadlineSeconds>=0的Pod
NotTerminating|	podSpec.activeDeadlineSeconds=nil的Pod
BestEffort	|所有容器的requests和limits都没有设置的Pod（Best-Effort）
NotBestEffort|	与BestEffort相反

## 什么是Ingress？
通常情况下，service和pod的IP仅可在集群内部访问。集群外部的请求需要通过负载均衡转发到service在Node上暴露的NodePort上，然后再由kube-proxy将其转发给相关的Pod。

而Ingress就是为进入集群的请求提供路由规则的集合，如下图所示：

```
graph LR
Internet--> Ingress
Ingress--> Service
```

Ingress可以给service提供集群外部访问的URL、负载均衡、SSL终止、HTTP路由等。为了配置这些Ingress规则，集群管理员需要部署一个Ingress controller，它监听Ingress和service的变化，并根据规则配置负载均衡并提供访问入口。

**Ingress格式：**

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test-ingress
spec:
  rules:
  - http:
      paths:
      - path: /testpath
        backend:
          serviceName: test
          servicePort: 80
```
每个Ingress都需要配置rules，目前Kubernetes仅支持http规则。上面的示例表示请求/testpath时转发到服务test的80端口。

根据Ingress Spec配置的不同，Ingress可以分为以下几种类型：

- 单服务Ingress

单服务Ingress即该Ingress仅指定一个没有任何规则的后端服务。

> 注：单个服务还可以通过设置Service.Type=NodePort或者Service.Type=LoadBalancer来对外暴露。

- 路由到多服务的Ingress

路由到多服务的Ingress即根据请求路径的不同转发到不同的后端服务上，比如

```
graph LR
foo.bar.com --> 178.91.123.132
178.91.123.132 --> /foo.s1:80
178.91.123.132 --> /bar.s2:80
```
可以通过下面的Ingress来定义：

```
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: test
spec:
  rules:
  - host: foo.bar.com
    http:
      paths:
      - path: /foo
        backend:
          serviceName: s1
          servicePort: 80
      - path: /bar
        backend:
          serviceName: s2
          servicePort: 80
```
- TLS Ingress

TLS Ingress通过Secret获取TLS私钥和证书(名为tls.crt和tls.key)，来执行TLS终止。如果Ingress中的TLS配置部分指定了不同的主机，则它们将根据通过SNI TLS扩展指定的主机名（假如Ingress controller支持SNI）在多个相同端口上进行复用。


## ConfigMap
ConfigMap用于保存配置数据的键值对，可以用来保存单个属性，也可以用来保存配置文件。ConfigMap跟secret很类似，但它可以更方便地处理不包含敏感信息的字符串。

### ConfigMap创建
可以使用kubectl create configmap从文件、目录或者key-value字符串创建等创建ConfigMap。

#### 从key-value字符串创建ConfigMap

```
$ kubectl create configmap special-config --from-literal=special.how=very
configmap "special-config" created
$ kubectl get configmap special-config -o go-template='{{.data}}'
map[special.how:very]
```


#### 从env文件创建

```
$ echo -e "a=b\nc=d" | tee config.env
a=b
c=d
$ kubectl create configmap special-config --from-env-file=config.env
configmap "special-config" created
$ kubectl get configmap special-config -o go-template='{{.data}}'
map[a:b c:d]
```


#### 从目录创建

```
$ mkdir config
$ echo a>config/a
$ echo b>config/b
$ kubectl create configmap special-config --from-file=config/
configmap "special-config" created
$ kubectl get configmap special-config -o go-template='{{.data}}'
map[a:a
 b:b
]
```
### ConfigMap使用
ConfigMap可以通过多种方式在Pod中使用，比如设置环境变量、设置容器命令行参数、在Volume中创建配置文件等。

**注意**

1. ConfigMap必须在Pod引用它之前创建
2. 使用envFrom时，将会自动忽略无效的键
3. Pod只能使用同一个命名空间内的ConfigMap

- 用作环境变量
- 用作命令行参数
- 使用volume将ConfigMap作为文件或目录直接挂载

