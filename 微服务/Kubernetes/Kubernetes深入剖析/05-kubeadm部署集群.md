1. Linux容器相关的技术可以帮助我们快速定位问题，并解决问题。
2. 要真正发挥容器技术的实力的关键在于如何使用这些技术“容器化”应用。

单单通过Docker把一个应用的镜像跑起来，并没有什么用。**关键是处理好容器之间的编排关系**。比如：
- 主从容器如何区分？
- 容器之间的自动发现和通信如何完成？
- 容器的持久化数据如何保持？

# 部署Kubernetes
云厂商的方式：SaltStack、Ansible等运维工具自动化地执行安装脚本和配置文件。

**但是，这些工具的学习成本比kubernetes项目还高。**

社区开发了一个独立部署的工具：kubeadm，执行以下两条命令就可以部署一个集群：

``` bash
# 创建一个 Master 节点
kubeadm init

# 将一个 Node 节点加入到当前集群中
kubeadm join <Master节点的 IP 和 端口 >
```
## Kubeadm原理
1. **传统部署方式**：在部署Kubernetes时，它的每一个组件都是一个需要被执行的、单独的二进制文件。使用SaltStack这样的运维工具或者社区维护的脚本，就需要把这些二进制文件传输到指定的节点上，然后编写控制脚本来启停这些组件。
2. **容器化部署方式**：给每个组件做一个容器镜像，然后在每台宿主机上运行docker run命令来启动这些组件容器。

容器化部署的一个问题：**如何容器化kubelet**？

Kubelet是Kubernetes项目用来操作Docker等容器运行时的核心组件，除了和容器运行时打交道之外，kubelet在**配置容器网络**、**管理容器数据卷**，都需要直接操作宿主机。

**如果kubelet本身就运行在一个容器中，那么直接操作宿主机就会变得很麻烦**。
- 对于**配置网络**：kubelet容器可以通过不开启Network Namespace（即Docker的host netwrok模式）的方式，直接共享宿主机的网络栈。
- 对于**操作文件系统**：让kubelet隔着容器的Mount Namespace和文件系统，操作宿主机的文件系统，就有点难了。

> 举个例子：用户想要使用NFS做容器的持久化数据卷，那么kubelet就需要在容器进行绑定挂载前，在宿主机的指定目录上，先挂载NFS的远程目录。那么问题来了，由于现在kubelet是运行在容器里的，这就意味着它要做的这个“mount -F nfs”命令，被隔离在了一个单独的Mount Namespace中。即kubelet做的挂载操作，不能被“传播”到宿主机上。

**因此，妥协的方案就是，kubelet直接运行在宿主机上，然后使用容器部署其他的kubernetes组件**。

### 使用kubeadm
使用kubeadm的第一步，在机器上手动安装 **kubeadm**、**kubelet**、**kubectl** 这三个二进制文件。kubeadm已经为各个发行版的Linux准备好了安装包，所以只需要执行如下命令：

``` bash
apt-get install kubeadm   #Debain or Ubuntu
yum install kubeadm       #Redhat or Centos

kubeadm  init   #部署Master 节点
```

### kubeadm init 工作原理
#### 第一步：Preflight Checks
确定服务器是否可以用来部署kubernetes。

主要包括：
1. Linux内核的版本必须是否是3.10以上？
2. Linux Cgroup模块是否可用？
3. 服务器的hostname是否标准？
> **在kubernetes项目中，主机名以及一切存储在Etcd中的API对象，都必须使用标准的DNS命令（RFC1123）**

4. 安装的kubeadm和kubelet的版本是否匹配？
5. 服务器上是否已经安装了 Kubernetes的二进制文件？
6. Kubernetes的工作端口**10250/10251/10252**端口是不是已经被占用？
7. ip、mount等Linux指令是否存在？
8. Docker是否已经安装？
9. 。。。。。。

#### 第二步：生成证书
当通过了Preflight Checks后，kubeadm会生成Kubernetes对外提供服务所需的各种**证书**和对应的**目录**。

> Kubernetes对外提供服务时，除非专门开启“不安全模式”，否则都需要通过**HTTPS**才能访问kube-apiserver。这就需要为Kubernetes集群配置好证书文件。

**证书存放在Master节点的/etc/kubernetes/pki目录下，其中最主要的证书是ca.crt和对应的私钥ca.key。**

> 用户使用kubectl获取容器日志等streaming操作时，需要通过kube-apiserver向kubelet发起请求，这个链接也必须是**安全**的。

kubeadm 为上述操作生成的是apiserver-kubelet-client.crt文件，对应的私钥是apiserver-kubelet-client.key。

其他的如Aggregate APIServer 等特性，也需要用生成专门的证书。同时也可以选择不让kubeadm生成证书，而是拷贝现成的证书到指定的目录中：

``` bash
/etc/kubernetes/pki/ca.{crt,key}
```
那么，此时kubeadm会跳过生成证书的步骤。

#### 第三步：生成配置文件
证书生成后，kubeadm接下来会为其他组件生成访问kube-apiserver所需的配置文件。配置文件的路径是：/etc/kubernetes/xxx.conf

``` bash
ls /etc/kubernetes/
admin.conf controller-manager.conf kubelet.conf scheduler.conf
```
这些文件里记录的是，当前这个Master节点的 **服务器地址**、**监听端口**、**证书目录** 等信息。这样，对应的客户端（如scheduler、kubelet等），可以直接加载相应的文件，使用里面的信息与kube-apiserver建立安全连接。

#### 第四步：生成pod配置文件
kubeadm为Master组件（kube-apiserver、kube-controller-manager、kube-scheduler）生成pod配置文件，它们都以pod的方式部署起来。

> 在kubernetes中，有一种特殊的容器启动方法叫 **“Static Pod”** 。它允许你把要部署的pod的yaml文件放在一个指定的目录里。这样，当这台服务器上的kubelet启动时，它会自动检查这个目录，加载所有的pod yaml文件，然后在这台服务器上启动它们。

在kubeadm中，Master组件的yaml文件会被生成在`/etc/kubernetes/manifests`路径下。如果需要修改已有集群的kubernetes组件的配置，需要修改对应的yaml文件。

#### 第五步：生成Etcd的pod yaml文件
同样通过 **Static pod** 的方式启动Etcd，所以，Master组件的pod文如下：

``` bash
ls /etc/kubernetes/manifests/

etcd.yaml kube-apiserver.yaml kube-controller-manager.yaml kube-scheduler.yaml
```
**一旦这些文件出现在被kubelet监视的`/etc/kubernetes/manifests`目录下，kubelet就会自动创建这些yaml文件中定义的pod。（即Master组件的容器）**

--------
1. Master容器启动后，kubeadm会通过检查`localhost:6443/healthz`这个Master组件的健康检查URL，等待Master组件完全运行起来。


2. kubeadm为集群生成bootstrap token。持有这个token的任何一个kubelet和kubeadm节点，都可以通过kubeadm join 加入到这个集群中。（token的值和使用方法会在kubeadm init结束后打印出来。）



3. token生成后，kubeadm会将ca.crt等Master节点的重要信息，通过ConfigMap的方式保存在Etcd中，供后续部署Node节点使用。（这个ConfigMap的名字 cluster-info）


4. kubernetes默认kube-proxy和DNS这两个插件是必须安装的，提供集群的服务发现和DNS功能。这两个插件也是两个容器镜像，创建两个pod即可。


### kubeadm join 工作原理
使用kubeadm init生成的bootstrap token 在安装了kubeadm和kubelet的服务器上执行kubeadm join。

bootstrap token的作用：
1. 一台服务器想要成为kubernetes集群中的节点，就必须在集群的kube-apiserver上注册。
2. 想要与apiserver通信，这台服务器必须获取相应的证书文件（CA文件）。
3. 为了一键安装，就不能手动去拷贝证书文件。
4. kubeadm至少要发起一次“不安全模式”的访问到kube-apiserver，从而拿到保存在ConfigMap中的cluster-info（这里保存了APIServer的授权信息）。

**bootstrap token扮演的就是这个过程中的安全验证的角色。有了cluster-info里的kube-apiserver的地址、端口、证书，kubelet就可以“安全模式”连接到apiserver上。**

### 配置kubeadm的部署参数
可以通过 --config 参数指定启动时读取的配置文件：

``` bash
kubeadm init --config kubeadm.yaml
```

这样可以给kubeadm提供一个yaml文件，例如：


``` yaml
apiVersion: kubeadm.k8s.io/v1alpha2
kind: MasterConfiguration
kubernetesVersion: v1.11.0
api:
    advertiseAddress: 192.168.0.102
    bindPort: 6443
    ...
etcd:
    local:
        dataDir: /var/lib/etcd
        image: ""
imageRepository: k8s.gcr.io
kubeProxy:
    config:
        bindAddress: 0.0.0.0
        ...
kubeletConfiguration:
    baseConfig:
        address: 0.0.0.0
        ...
networking:
    dnsDomain: cluster.local
    podSubnet: ""
    serviceSubnet: 10.96.0.0/12
nodeRegistration:
    criSocket: /var/run/dockershim.sock
    ...
```
通过指定这样一个部署参数配置文件，可以方便地在文件里填写各种自定义的部署参数。

比如，要自动化kube-apiserver的参数，添加如下信息：

``` yaml
...
apiServerExtraArgs:
    advertise-address: 192.168.0.103
    anonymous-auth: false
    enable-admission-plugins: AlwaysPullImages,DefaultStorageClass
    audit-log-path: /home/johndoe/audit.log
```
然后，kubeadm就会使用上面的信息替换`/etc/kubernetes/manifests/kube-apiserver.yaml`里的command字段里的参数。

更具体的：
1. 修改kubelet的配置
2. 修改kube-proxy 的配置
3. 修改kubernetes使用的基础镜像的URL（默认的`k8s.gcr.io/xxx`镜像URL在国内不能访问）
4. 指定自己的证书文件
5. 指定特殊的容器运行时


## Kubeadm源代码
源代码在`kubernetes/cmd/kubeadm`目录下，其中`app/phases`文件夹下的代码就是上述的步骤。


## 生产环境部署
部署规模化的生产环境，推荐使用：
1. [kops](https://github.com/kubernetes/kops)
2. saltstack
3. [ansible playbook](https://github.com/gjmzj/kubeasz)
4. [kubespray](https://github.com/kubernetes-incubator/kubespray)
5. [K8S实验平台](https://console.magicsandbox.com)
6. [谷歌镜像](https://github.com/anjia0532/gcr.io_mirror)


## 制作证书的方法
1. cfssl
2. OpenSSL
3. easyrsa
4. GnuGPG
5. keybase
