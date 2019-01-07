# 语法规则

```
kubectl [command] [TYPE] [NAME] [flags]
```

- command：指定要在一个或多个资源上执行的操作，例如create，get，describe，delete。
- TYPE：指定资源类型。资源类型区分大小写，可以指定单数，复数或缩写形式。

例如，以下命令产生相同的输出：
```
$ kubectl get pod pod1 
$ kubectl get pods pod1 
$ kubectl get po pod1
```

- NAME：指定资源的名称。==名称区分大小写==。如果省略名称，将显示所有资源的详细信息，例如

```
$ kubectl get pod
```

在多个资源上执行操作时，可以按类型和名称指定每个资源，或指定一个或多个文件：
1. 按类型和名称指定资源：属于同一类型的资源划分在一个组，TYPE1 name1 name2 name<#>。例如：

```
$ kubectl get pod example-pod1 example-pod2
```

2. 分别指定多种资源，TYPE1/name1 TYPE1/name2 TYPE2/name3 TYPE<#>/name<#>。例如：

```
$ kubectl get pod/example-pod1 replicationcontroller/example-rc1
```

3. 使用一个或多个文件指定资源，-f file1 -f file2 -f file<#>，（使用YAML而不是JSON，因为YAML往往更加用户友好，特别是对于配置文件），例如：

```
$ kubectl get pod -f ./pod.yaml
```

- flags：指定可选标志。例如，您可以使用-s或--server标志来指定Kubernetes API服务器的地址和端口。

**重要提示：从命令行指定的标志将覆盖默认值和任何相应的环境变量。**

## 基础命令（初级）

命令 | 描述
---|---
  create      |   通过文件名或stdin创建一个资源
  expose       |采取副本控制器，服务，部署或pod，并将其作为新的Kubernetes服务公开
  run           |  在集群上运行特定映像
  set           |   设置对象上的特定功能
## 基础命令（中级）

命令 | 描述
---|---
  get         |     显示一个或多个资源
  explain      |  资源记录
  edit          |   在服务器上编辑资源
  delete         |通过文件名，stdin，资源和名称，或资源和标签选择器删除资源
## 部署命令

命令| 描述
---|---
  rollout        |        管理Deployment rollout
  rolling-update  | 执行给定副本控制器的滚动更新
  scale           |       为Deployment，ReplicaSet，副本控制器或作业设置新的大小
  autoscale        |   自动为Deployment, ReplicaSet, or ReplicationController设置新的大小
## 集群管理命令

命令|描述
---|---
certificate      |修改证书资源
  cluster-info    |显示群集信息
  top            |    显示资源（CPU /内存/存储）使用情况
  cordon          |将节点标记为不可用
  uncordon     | 将节点标记为可用
  drain        |     设定节点进入维护模式
  taint        |      更新一个或多个节点上的阴影
## 检修和调试命令
命令|描述
---|---
  describe        |   显示特定资源或资源组的详细信息
  logs            |      打印一个pod中一个容器的日志
  attach      |        附加到正在运行的容器
  exec      |           在容器中执行命令
  port-forward | 将一个或多个本地端口转发到pod
  proxy      |       运行代理到Kubernetes API服务器
  cp         |         将文件和目录复制到容器中
## 高级命令
命令|描述
---|---
  apply    |       通过文件名或stdin将配置应用于资源
  patch    |      使用策略合并补丁更新资源的字段
  replace  |      用文件名或stdin替换一个资源
  convert   |    在不同API版本之间转换配置文件
## 设置命令
命令|描述
---|---
  label     |          更新资源上的标签
  annotate  |      更新资源上的注释
  completion   |  输出shell完成代码到指定的shell中（如bash或zsh）
## 其他命令
命令|描述
---|---
  api-versions  | 在服务器上打印受支持的API版本，形式为“group / version”
  config        |    修改kubeconfig文件
  help         |      帮助
  version      |    打印客户端和服务器版本信息
