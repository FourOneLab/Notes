成功的软平台都有一个优秀的打包系统，比如Debain、Ubuntu的apt，Read Hat、Centos的yum等。

> Kubernetes能够很好的组织和编排容器，但是缺少一个更高层次的应用打包工具。Helm是Kubernetes上的包管理工具。

# 举个例子
部署一个Mysql服务，Kubernetes需要部署下面这些对象：
1. **Service**：让外界能够访问Mysql服务；
2. **Secret**：定义Mysql的密码；
3. **PersistentVolumeClaim**：为Mysql申请持久化存储空间；
4. **Deployment**：部署Mysql Pod，并使用上面的三种支持对象。

需要将上面这些配置文件保存到对象各自的文件中，或者集中卸载一个配置文件中，然后通过如下命令进行部署：
```
kubectl apply -f <配置文件.yaml>
```

> 目前来看，kubernetes对服务的部署支持度挺高的，如果一个应用由上面的**一个或几个**这样的服务组成，这样的方式足够，但是如果开发的微服务架构的应用，组成应用的服务可能多达**十几个甚至上百个**，这样的组织方式就很不友好。

有以下缺点：
1. ++很难管理、编辑和维护如此多的服务++。每个服务都有若干层次的抽象。**缺乏一个更高层次的工具将这些配置组织起来**。
2. ++不容易将这些服务作为一个整体统一发布++。部署人员需要首先理解应用包含哪些服务，按照逻辑顺序依次执行kubectl apply。**缺少一种工具来定义应用和服务，以及服务与服务之间的依赖关系**。
3. ++不能高效地共享和重用服务++。比如两个应用都用到Mysql服务，但是配置的参数不同，这两个应用只能分别复制一套标准的Mysql配置文件，修改后通过kubectl apply继续部署。**不支持参数化配置和多环境部署**。
4. ++不支持应用级别的版本管理++。虽然可以通过kubectl rollout undo 继续回滚，但这个只能针对单个Deployment，不能针对整个应用的回滚。
5. ++不支持对部署的应用状态进行验证++。比如能否通过预定义的账号访问Mysql服务。**虽然kubernetes有健康检查，但是那个只是针对单个容器的，没有应用（服务）级别的健康检查**。

# Helm架构
## chart
创建一个应用的信息集合，包括：
- 各种kubernetes对象的配置模板
- 参数定义
- 依赖关系
- 文档说明

chart是应用部署的自包含逻辑单元，可以想象成apt、yum中的软件安装包。

## release
release是chart的运行实例，代表了一个正在运行的应用。当chart被安装到Kubernetes集群中，就生成了一个release。chart能够多次安装到同一个集群，每次安装都生成一个release。

Helm是一个包管理工具，这里的包指的就是chart，有如下功能：
1. 从零创建新chart
2. 与存储chart的仓库交互、拉取、保存和更新chart
3. 在kubernetes集群中安装和卸载release
4. 更新、回滚和测试release

Helm包含两个组件：Helm客户端和Tiller服务器，如下图所示：
![image](http://tech.honestbee.com/img/posts/drone_helm_repo/overview.png)

Helm 客户端是终端用户使用的命令行工具，用户可以：
1. 在本地开发chart
2. 管理chart仓库
3. 与Tiller服务器交互
4. 在远程kubernetes集群上安装chart
5. 查看release信息
6. 升级或卸载已有的release

Tiller 服务器运行在kubernetes集群中，它会处理Helm客户端的请求，与kubernetes API Server交互。Tiller服务器负责：
1. 监听来自Helm客户端的请求
2. 通过chart构建release
3. 在kubernetes集群中安装chart，并跟踪release的状态
4. 通过API Server 升级或卸载已有的release

**简单来说，Helm客户端负责管理chart，Tiller服务器负责管理release。**

[Helm官方文档](https://docs.helm.sh/)：链接如下 https://docs.helm.sh/

Helm安装时已经默认配置好了两个仓库:
- stable(官方仓库)
- local（用户存放自己开发的chart的本地仓库）