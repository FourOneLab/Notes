# 操作系统配置
## 配置防火墙
Kubernetes的Master与Node之间有大量的网络通信，安全的做法是在防火墙上配置各组件需要相互通信的端口号，在一个安全的内网环境中可以关闭防护墙。

```
systemctl stop firewalld.service
systemctl disable firewalld.service
```
## 配置Selinux
禁用主机上的Selinux，使得容器能够读取主机文件系统。

```
setenforce 0  //临时关闭Selinux

getenforce    //查看当前Selinux的安全策略

sestatus      //查看当前Selinux的状态
```

修改Selinux的配置文件，可以永久关闭

```
vim /etc/sysconfig/selinux

SELINUX=disabled  //enforcing为开启状态

sed -i "s/SELINUX=enforcing/SELINUX=disabled/g" /etc/selinux/config
```
对Selinux配置完成后，需要重启服务器。


# 安装Kubernetes集群
在Centos系统上，最简单的安装方式是通过YUM安装工具进行安装，即执行如下命令：

```
yum install kubernetes 
```
以上安装方式存在明显的缺点，安装完成后需要对整个集群进行配置，整个过程复杂，且容易出错。因此采用**kubeadm**工具进行安装。

## kubeadm安装集群
### 配置yum源
国内可以从阿里云的镜像仓库中下载相关的yum源

#### 下载docker的yum源
在阿里云镜像仓库找到docker的yum源
```
wget https://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

#### 安装docker

安装依赖组件：

```
yum install -y yum-utils device-mapper-persistent-data lvm2
```

##### 使用官方安装脚本自动安装

```
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

##### 手动安装

```
//step 1: 安装必要的一些系统工具
sudo yum install -y yum-utils device-mapper-persistent-data lvm2
// Step 2: 添加软件源信息
sudo yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
//Step 3: 更新并安装 Docker-CE
sudo yum makecache fast
sudo yum -y install docker-ce
//Step 4: 开启Docker服务
sudo service docker start
```
**注意：**
官方软件源默认启用了**最新的软件**，可以通过编辑软件源的方式获取各个版本的软件包。例如官方并没有将测试版本的软件源置为可用，可以通过以下方式开启。同理可以开启各种测试版本等。
```
vim /etc/yum.repos.d/docker-ce.repo     //将 [docker-ce-test] 下方的 enabled=0 修改为 enabled=1
```
安装指定版本的Docker-CE:
```
// Step 1: 查找Docker-CE的版本:
yum list docker-ce.x86_64 --showduplicates | sort -r
Loading mirror speeds from cached hostfile
Loaded plugins: branch, fastestmirror, langpacks
docker-ce.x86_64            17.03.1.ce-1.el7.centos            docker-ce-stable
docker-ce.x86_64            17.03.1.ce-1.el7.centos            @docker-ce-stable
docker-ce.x86_64            17.03.0.ce-1.el7.centos            docker-ce-stable
Available Packages

// Step2 : 安装指定版本的Docker-CE: (VERSION 例如上面的 17.03.0.ce.1-1.el7.centos)
sudo yum -y install docker-ce-[VERSION]
```

##### 安装校验

```
$ docker version
Client:
 Version:      17.03.0-ce
 API version:  1.26
 Go version:   go1.7.5
 Git commit:   3a232c8
 Built:        Tue Feb 28 07:52:04 2017
 OS/Arch:      linux/amd64

Server:
 Version:      17.03.0-ce
 API version:  1.26 (minimum version 1.12)
 Go version:   go1.7.5
 Git commit:   3a232c8
 Built:        Tue Feb 28 07:52:04 2017
 OS/Arch:      linux/amd64
 Experimental: false
```


#### 下载kubernetes的yum源

```
cat <<EOF > /etc/yum.repos.d/kubernetes.repo
[kubernetes]
name=Kubernetes
baseurl=https://mirrors.aliyun.com/kubernetes/yum/repos/kubernetes-el7-x86_64/
enabled=1
gpgcheck=1
repo_gpgcheck=1
gpgkey=https://mirrors.aliyun.com/kubernetes/yum/doc/yum-key.gpg https://mirrors.aliyun.com/kubernetes/yum/doc/rpm-package-key.gpg
EOF
```


#### 安装kubernetes

```
yum install -y kubelet kubeadm kubectl
```

### 启动服务

```
systemctl enable docker && systemctl start docker
systemctl enable kubelet && systemctl start kubelet
```

#### 修改docker镜像地址
默认情况下是从gcr.io进行下载的，从国外下载可能失败或者很慢，所以将镜像地址修改为国内的镜像，修改docker 的配置文件 /etc/docker/daemon.json

```
{"registry-mirrors": ["https://gn6g9no6.mirror.aliyuncs.com"]}
```
或者

```
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://gn6g9no6.mirror.aliyuncs.com"]
}
EOF
```

以上加速地址为阿里云的加速地址，登录阿里云docker hub 首页 https://dev.aliyun.com/search.html ，点击管理中心，找到镜像加速器，复制加速器地址。


重启docker服务

```
sudo systemctl daemon-reload
sudo systemctl restart docker
```


### 运行kubeadm init 安装Master
#### 安装前的准备工作
RHEL / CentOS 7存在由于iptables被绕过而导致流量路由不正确的问题。应确保在sysctl配置中将net.bridge.bridge-nf-call-iptables设置为1，例如：

```
cat <<EOF >  /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-ip6tables = 1
net.bridge.bridge-nf-call-iptables = 1
EOF

sysctl --system

modprobe br_netfilter
sysctl -p /etc/sysctl.d/k8s.conf
```

kubernetes1.8开始需要关闭swap：

```
swapoff -a
```
修改 /etc/fstab 文件，注释掉 SWAP 的自动挂载，使用free -m确认swap已经关闭

wappiness参数调整，修改/etc/sysctl.d/k8s.conf添加下面一行：


```
vm.swappiness=0

sysctl -p /etc/sysctl.d/k8s.conf  //使参数生效
```
也可以在kubelet的启动文件中添加参数来关闭swap

```
vim /etc/sysconfig/kubelet

KUBELET_EXTRA_ARGS=--fail-swap-on=false
```


#### 如果使用其他容器Runtime
使用Docker时，kubeadm会自动检测kubelet的cgroup驱动程序，并在运行时将其设置在/var/lib/kubelet/kubeadm-flags.env文件中。

如果您使用的是其他CRI，则必须使用cgroup-driver值修改文件/etc/default/kubelet，如下所示：


```
KUBELET_KUBEADM_EXTRA_ARGS= - cgroup-driver=<value>
```
kubeadm init和kubeadm join将使用此文件为kubelet提供额外的用户定义参数

请注意，如果您的CRI的cgroup驱动程序不是cgroupfs，您只需要这样做，因为这已经是kubelet中的默认值。

需要重新启动kubelet：


```
systemctl daemon-reload
systemctl restart kubelet
```

#### 查看配置文件
/etc/systemd/system/kubelet.service.d/10-kubeadm.conf，内容如下：
```
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
```
上面显示kubeadm部署的kubelet的配置文件–config=/var/lib/kubelet/config.yaml，实际去查看/var/lib/kubelet和这个config.yaml的配置文件都没有被创建。 可以猜想肯定是运行kubeadm初始化集群时会自动生成这个配置文件，而如果我们不关闭Swap的话，第一次初始化集群肯定会失败的。

## 安装Harbor私有仓库
参考Harbor安装

### docker 配置私有源

```
cd /etc/docker

echo -e '{\n"insecure-registries":["k8s.gcr.io", "gcr.io", "quay.io"]\n}' > /etc/docker/daemon.json

systemctl restart docker
```
### 配置其他接待的hosts文件，使得访问私有源的地址都指向Harbor
```
HARBOR_HOST="安装Host的IP地址"

echo """$HARBOR_HOST gcr.io harbor.io k8s.gcr.io quay.io """ >> /etc/hosts
```

### harbor 启动私有镜像库

```
docker load -i /path/to/k8s-repo-1.11.0
docker run --restart=always -d -p 80:5000 --name repo harbor.io:1180/system/k8s-repo:v1.11.0
```

查看镜像库中的镜像：

```
docker run -it harbor.io:1180/system/k8s-repo:v1.11.0 list
 
k8s.gcr.io/kube-apiserver-amd64:v1.11.0
k8s.gcr.io/kube-scheduler-amd64:v1.11.0
k8s.gcr.io/kube-controller-manager-amd64:v1.11.0
k8s.gcr.io/kube-proxy-amd64:v1.11.0
k8s.gcr.io/coredns:1.1.3
k8s.gcr.io/etcd-amd64:3.2.18
k8s.gcr.io/pause-amd64:3.1
k8s.gcr.io/pause:3.1

quay.io/calico/node:v3.1.3
quay.io/calico/cni:v3.1.3

k8s.gcr.io/heapster-influxdb-amd64:v1.3.3
k8s.gcr.io/heapster-grafana-amd64:v4.4.3
k8s.gcr.io/heapster-amd64:v1.4.2
k8s.gcr.io/kubernetes-dashboard-amd64:v1.8.3
k8s.gcr.io/traefik:1.6.5
k8s.gcr.io/prometheus:v2.3.1
```





#### 安装Master

```
kubeadm init --apiserver-advertise-address 192.168.1.111 --pod-network-cidr 10.244.0.0/16  --kubernetes-version=1.6.0
```
**参数说明**
-  --apiserver-advertise-address：指明Master使用哪个interface与Cluster其他节点通信（不指定会使用带有默认网关的interface）
-  --pod-network-cidr：指定pod网络范围，不同网络方案对该参数要求不同，这里使用flannel，必须设置为这个CIDR
-  --kubernetes-version=1.6.0 ：指定需要安装的版本


执行的时候如果报错，可以强制忽略错误：
添加如下参数 --ignore-preflight-errors=Swap
```
[init] using Kubernetes version: v1.12.0
[preflight] running pre-flight checks
[preflight] Some fatal errors occurred:
        [ERROR Swap]: running with swap on is not supported. Please disable swap
[preflight] If you know what you are doing, you can make a check non-fatal with `--ignore-preflight-errors=...`
```

安装成功显示如下：

```
Your Kubernetes master has initialized successfully!

To start using your cluster, you need to run the following as a regular user:

  mkdir -p $HOME/.kube
  sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
  sudo chown $(id -u):$(id -g) $HOME/.kube/config

You should now deploy a pod network to the cluster.
Run "kubectl apply -f [podnetwork].yaml" with one of the options listed at:
  https://kubernetes.io/docs/concepts/cluster-administration/addons/

You can now join any number of machines by running the following on each node
as root:

  kubeadm join 192.168.50.2:6443 --token afh07i.hxfrpdy2v84u53qq --discovery-token-ca-cert-hash sha256:d2ab827fdd91bc33039a73433bfad6fe22628df65fd9328b6e8a495634f4d463

```
### 部署容器网络插件

```
kubectl apply -f https://git.io/weave-kube-1.6
```
刚刚部署的 Weave 网络插件则在 kube-system 下面新建了一个Pod，一般来说，这些 Pod 就是容器网络插件在每个节点上的控制组件。
Kubernetes 支持容器网络插件，使用的是一个名叫CNI的通用接口，它也是当前容器网络的事实标准，市面上的所有容器网络开源项目都可以通过 CNI 接入Kubernetes，比如Flannel、Calico、Canal、Romana等等，它们的部署方式也都是类似的“一键部署”。关于这些开源项目的实现细节和差异，

在默认情况下，Kubernetes 的 Master 节点是不能运行用户 Pod 的，所以还需要额外做一个小操作:

### 通过 Taint/Toleration 调整 Master 执行 Pod 的策略
默认情况下 Master 节点是不允许运行用户 Pod 的。而 Kubernetes 做到这一点，依靠的是 Kubernetes 的 Taint/Toleration 机制。

> 原理：一旦某个节点被加上了一个 Taint，即被“打上了污点”，那么所有 Pod 就都不能在这个节点上运行，因为 Kubernetes 的 Pod 都有“洁癖”。除非，有个别的 Pod 声明自己能“容忍”这个“污点”，即声明了 Toleration，它才可以在这个节点上运行。

其中，为节点打上“污点”（Taint）的命令是：

```
$ kubectl taint nodes node1 foo=bar:NoSchedule
```
这时，该 node1 节点上就会增加一个键值对格式的Taint，即：foo=bar:NoSchedule。其中值里面的 **NoSchedule**，意味着这个 Taint 只会在调度新Pod时产生作用，而不会影响已经在 node1上运行的 Pod，哪怕它们没有 Toleration。

#### Pod 声明 Toleration 
在 Pod 的.yaml 文件中的 spec 部分，加入 tolerations 字段即可：

```
apiVersion: v1
kind: Pod
...
spec:
  tolerations:
  - key: "foo"
    operator: "Equal"
    value: "bar"
    effect: "NoSchedule"
```

这个 Toleration 的含义是，这个 Pod 能“容忍”所有键值对为 foo=bar 的 Taint（ operator:“Equal”，“等于”操作）。

通过 kubectl describe 检查一下 Master 节点的Taint 字段：

```
$ kubectl describe node master

Name:               master
Roles:              master
Taints:             node-role.kubernetes.io/master:NoSchedule
```
Master节点默认被加上了 **node-role.kubernetes.io/master:NoSchedule** 这样一个“污点”，其中“键”是 **node-role.kubernetes.io/master** ，而没有提供“值”。

此时，用“Exists”操作符（operator: “Exists”，“存在”即可）来说明，该Pod能够容忍所有以 foo 为键的 Taint，才能让这个 Pod 运行在该 Master 节点上：

```
apiVersion: v1
kind: Pod
...
spec:
  tolerations:
  - key: "foo"
    operator: "Exists"
    effect: "NoSchedule"
```

删除这个 Taint ：

```
$ kubectl taint nodes --all node-role.kubernetes.io/master-
```

如上所示，我们在“node-role.kubernetes.io/master”这个键后面加上了一个短横线“-”，这个格式就意味着移除所有以“node-role.kubernetes.io/master”为键的Taint。

### 部署Dashboard可视化插件

```
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml
```
需要注意的是，由于 Dashboard 是一个 Web Server，很多人经常会在自己的公有云上无意地暴露
Dashboard 的端口，从而造成安全隐患。所以，1.7 版本之后的 Dashboard 项目部署完成后，默认只能通过 Proxy 的方式在本地访问。具体的操作，你可以查看 Dashboard 项目的[官方文档](https://github.com/kubernetes/dashboard)。

修改dashboard的yaml文件，通过端口访问：

```
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  # 添加Service的type为NodePort
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      # 添加映射到虚拟机的端口,k8s只支持30000以上的端口
      nodePort: 30001
  selector:
    k8s-app: kubernetes-dashboard
```

### 部署容器存储插件
需要用数据卷（Volume）把外面宿主机上的目录或者文件挂载进容器的 Mount Namespace 中，
从而达到容器和宿主机共享这些目录或者文件的目的。容器里的应用，也就可以在这些数据卷中新建和写入文件。

可是，如果在某一台机器上启动的一个容器，显然无法看到其他机器上的容器在它们的数据卷里写入的文件。**这是容器最典型的特征之一：无状态。**


而容器的持久化存储，就是用来保存容器存储状态的重要手段：存储插件会在容器里挂载一个基于网络或者其他机制的**远程数据卷**，使得在容器里创建的文件，实际上是保存在远程存储服务器上，或者以分布式的方式保存在多个节点上，而与当前宿主机没有任何绑定关系。这样，无论你在其他哪个宿主机上启动新的容器，都可以请求挂载指定的持久化存储卷，从而访问到数据卷里保存的内容。**这就是“持久化”的含义**。

由于 Kubernetes 本身的松耦合设计，绝大多数存储项目，比如 Ceph、GlusterFS、NFS 等，都可以为 Kubernetes提供持久化存储能力。在这次的部署实战中，我会选择部署一个很重要的Kubernetes 存储插件项目：Rook。

> Rook 项目是一个基于 Ceph 的 Kubernetes存储插件（它后期也在加入对更多存储实现的支持）。不过，不同于对 Ceph 的简单封装，Rook 在自己的实现中加入了水平扩展、迁移、灾难备份、监控
等大量的企业级功能，使得这个项目变成了一个完整的、生产级别可用的容器存储插件。


得益于容器化技术，用两条指令，Rook 就可以把复杂的 Ceph 存储后端部署起来：


```
kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/operator.yaml

kubectl apply -f https://raw.githubusercontent.com/rook/rook/master/cluster/examples/kubernetes/ceph/cluster.yaml
```
一个基于 Rook 持久化存储集群就以容器的方式运行起来了，而接下来在 Kubernetes 项目上创建的所有 Pod 就能够通过 Persistent Volume（PV）和 Persistent Volume Claim（PVC）的方式，在容器里挂载由 Ceph 提供的数据卷了。

而 Rook 项目，则会负责这些数据卷的生命周期管理、灾难备份等运维工作。