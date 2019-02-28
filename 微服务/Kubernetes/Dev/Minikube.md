在笔记本电脑上的虚拟机中运行单节点Kubernetes群集的工具。

# 安装前检查
必须在计算机的BIOS中启用VT-x或AMD-v虚拟化。

要在Linux上检查这一点，请运行以下命令并验证输出是否为空：
```bash
egrep --color 'vmx|svm' /proc/cpuinfo
```
# 安装管理工具
|操作系统|支持的管理工具
|---|---|
|macOS	|VirtualBox, VMware Fusion, HyperKit
|Linux	|VirtualBox, KVM
|Windows	|VirtualBox, Hyper-V

> 注意：Minikube还支持`--vm-driver = none`选项，该选项在主机上而不是在VM中运行Kubernetes组件。使用此驱动程序需要Docker和Linux环境，但不需要管理工具。

# 开始安装
> 注意：本文档介绍如何使用静态二进制文件在Linux上安装Minikube。

下载二级制安装文件：
```bash
curl -Lo minikube https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64  && chmod +x minikube
```

添加Minikube可执行文件到路径中：
```bash
sudo cp minikube /usr/local/bin && rm minikube
```

# Minikube的特点
Minikube支持的kubernetes特性如下：
- DNS
- NodePorts
- ConfigMaps and Secrets
- Dashboards
- Container Runtime: Docker, rkt, CRI-O and containerd
- Enabling CNI (Container Network Interface)
- Ingress

# 快速开始
## 启动集群：
```bash
minikube start --vm-driver = none

minikube start -p cluster2

minikube stop

minikube delete
```

> 如果要更改VM驱动程序，请将相应的`--vm-driver = xxx`标志添加到minikube start。
### 支持的驱动
- virtualbox
- vmwarefusion
- kvm2 (driver installation)
- kvm (driver installation)
- hyperkit (driver installation)
- xhyve (driver installation) (deprecated)
- hyperv (driver installation) 请注意，下面的IP是动态的，可以更改。使用`minikube ip`检索它。
- none (在主机上运行Kubernetes组件，而不是在VM中运行。使用此驱动程序需要Docker（docker install）和Linux环境)

## 替换容器运行时
1. 使用containerd：
```bash
minikube start \
    --network-plugin=cni \
    --enable-default-cni \
    --container-runtime=containerd \
    --bootstrapper=kubeadm

# 或者使用扩展版本

minikube start \
    --network-plugin=cni \
    --enable-default-cni \
    --extra-config=kubelet.container-runtime=remote \
    --extra-config=kubelet.container-runtime-endpoint=unix:///run/containerd/containerd.sock \
    --extra-config=kubelet.image-service-endpoint=unix:///run/containerd/containerd.sock \
    --bootstrapper=kubeadm
```

2. 使用CRI-O：
```bash
 minikube start \
    --network-plugin=cni \
    --enable-default-cni \
    --container-runtime=cri-o \
    --bootstrapper=kubeadm

# 或者使用扩展版本

minikube start \
    --network-plugin=cni \
    --enable-default-cni \
    --extra-config=kubelet.container-runtime=remote \
    --extra-config=kubelet.container-runtime-endpoint=/var/run/crio.sock \
    --extra-config=kubelet.image-service-endpoint=/var/run/crio.sock \
    --bootstrapper=kubeadm
```

3. 使用rkt
```bash
minikube start \
    --network-plugin=cni \
    --enable-default-cni \
    --container-runtime=rkt
```
> 这将使用另一个minikube iso镜像（包含rkt和docker）并且启动CNI网络。


## 安装其他驱动看这里
https://github.com/kubernetes/minikube/blob/master/docs/drivers.md

## 重用docker daemon 来使用本地镜像
当使用Kubernetes的单个VM时，重用Minikube的内置Docker daemon非常方便。这意味着不必在主机上构建`docker registry`并将image push 进去。可以在与minikube相同的docker daemon内部构建，从而加速本地实验。只需确保使用`“latest”`之外的其他 tag 来标记Docker 镜像，并在pull 镜像时使用该tag。

如果没有指定镜像的tag，pull 策略将会认为是`latest`，这可能最终会导致ErrImagePull，因为可能在默认的docker registry（通常是DockerHub）中没有任何版本的Docker镜像。

为了能够在mac / linux主机上使用docker daemon，请在shell中使用docker-env命令：
```bash
eval $(minikube docker-env)
```

现在应该可以在主机mac / linux机器上的命令行上使用docker与minikube VM内的docker daemon通信：
```bash
docker ps
```

On Centos 7, docker可能有如下报错:
```bash
Could not read CA certificate "/etc/docker/ca.pem": open /etc/docker/ca.pem: no such file or directory
```
解决方案： 更新`/etc/sysconfig/docker`以确保遵守Minikube的环境更改：
```bash
< DOCKER_CERT_PATH=/etc/docker
---
> if [ -z "${DOCKER_CERT_PATH}" ]; then
>   DOCKER_CERT_PATH=/etc/docker
> fi
```

> 注意：关闭 imagePullPolicy：Always，否则kubernetes将不会使用本地构建的镜像。


