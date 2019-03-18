

# DaemonSet
主要作用是让Kubernetes集群中运行一个Daemon Pod，这个Pod有如下三个特征:
1. 这个Pod运行在Kubernetes集群里的每一个节点（Node）上
2. 每个节点上只有一个这样的Pod实例
3. 当有新节点计入Kubernetes集群后，该Pod会自动地在新节点上被创建出来；而当旧节点被删除后，它上面的Pod也相应地会被回收掉

## 举一些例子
1. 各种网络插件的Agent组件，都必须运行在每一个节点上，用来处理这个节点上的容器网络
2. 各种存储插件的Agent组件，也必须运行在每一个节点上，用来在这个节点上挂载远程存储目录，操作容器的Volume目录
3. 各种监控组件和日志组件，也必须运行在每一个节点上，负责这个节点上的监控信息和日志搜集

**更重要的是，与其他编排对象不同，DaemonSet开始运行的时机，很多时候比整个kubernetes集群出现的时机都要早**。

> 例如这个DaemonSet是网络存储插件的Agent组件，在整个kubernetes集群中还没有可用的容器网络时，所有的worker节点的状态都是NotReady。这个时候普通的Pod肯定不能运行的，所以DaemonSet要先于其他的。

## 例子yaml
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: fluentd-elasticsearch
  namespace: kube-system
  labels:
    k8s-app: fluentd-logging
spec:
  selector:
    matchLabels:
      name: fluentd-elasticsearch
  template:
    metadata:
      labels:
        name: fluentd-elasticsearch
    spec:
      tolerations:
      - key: node-role.kubernetes.io/master
        effect: NoSchedule
      containers:
      - name: fluentd-elasticsearch
        image: k8s.gcr.io/fluentd-elasticsearch:1.20
        resources:
          limits:
            memory: 200Mi
          requests:
            cpu: 100m
            memory: 200Mi
        volumeMounts:
        - name: varlog
          mountPath: /var/log
        - name: varlibdockercontainers
          mountPath: /var/lib/docker/containers
          readOnly: true
      terminationGracePeriodSeconds: 30
      volumes:
      - name: varlog
        hostPath:
          path: /var/log
      - name: varlibdockercontainers
        hostPath:
          path: /var/lib/docker/containers
```

这个DaemonSet管理一个fluented-elasticsearch镜像的Pod，功能是通过fluented将Docker容器里的日志转发到ElasticSearch。

**DaemonSet与Deployment很类似，只是没有`replicas`字段，也是使用selector管理pod**。

在`template`中定义Pod的模板，包含一个镜像，这个镜像挂载了两个hostPath类型的Volume，分别对应宿主机的`/var/log`目录和`/var/lin/docker/containers`目录。

fluented启动后，它会从这两个目录里搜集日志信息，并转发给ElasticSearch保存，这样就可有通过ElasticSearch方便地检索这些日志了。

> 注意，DOcker容器里应用的日志，默认会保存在宿主机的`/var/lib/docker/containers/{{.容器ID}}/{{.容器ID}}-json.log`文件里，这个目录就是fluented搜集的目标之一。

## 如何保证每个Node上有且仅有一个被管理的Pod
1. DaemonSet Controller首先从Etcd里获取所有的Node列表
2. 遍历所有的Node，遍历的过程中可以检查当前节点上是否有携带了对应标签的Pod在运行。

### 检查结果有三种情况：
1. 没有被管理的pod，所有需要在这个节点上新建一个
2. 有被管理的pod，但是数量超过1，直接调用kubernetes API这个节点上删除多余的pod
3. 有且只有一个，真个节点很正常

第一种情况，新建Pod的时候，利用Pod API，通过`nodeSelector`选择Node的名字即可。新版本中`nodeSelector`将被弃用，使用新的`nodeAffinity`字段。如下例子：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-node-affinity
spec:
  affinity:
    nodeAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      # 这个nodeAffinity必须在被调度的时候予以考虑，同时也可以设置在某些情况下不予考虑这个nodeAffinity
        nodeSelectorTerms:
        - matchExpressions:
          - key: metadata.name
            # 这个pod只允许运行在“metadata.name”是“node-1”的节点上
            operator: In
            values:
            - node-1
```
在这个pod中，声明一个`spec.affinity`字段，然后定义一个`nodeAffinity`。其中`spec.Affinity`字段是Pod里跟调度相关的一个字段。

nodeAffinity的定义支持丰富的语法：
- operator：In（即，部分匹配）
- operator：Equal（即，完全匹配）

> 丰富的语法，是其取代前一代的原因之一。其实大多数时候，Operator语义没啥用。

**所以，DaemonSet Controller会在创建Pod的时候，自动在这个Pod的API对象里加上这个nodeAffinity定义，nodeAffinity中需要绑定的节点名字，正是当前正在遍历的这个节点**。

1. DaemonSet并不修改用户提交的YAML文件里的Pod模板，而是在想kubernetes发起请求之前，直接修改根据模板生成的Pod对象。
2. DaemonSet会给这个Pod自动加上另一个与调度相关的字段的字段`tolerations`，这就意味着这个Pod能够容忍（toleration）某些Node上的污点（taint）。会自动加入如下字段：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: with-toleration
spec:
  tolerations:
  - key: node.kubernetes.io/unschedulable
    operator: Exists
    effect: NoSchedule
```
这个Toleration的含义是：容忍所有被标记为`unschedulable`污点的节点，容忍的效果是允许调度。

> 在正常情况下，被标记了`unschedulable`污点（effect：NoSchedule）的节点，是不会有任何Pod被调度上去的。添加了容忍之后就可以忽略这个限制，这样就能保证每个节点都有一个pod。**如果这个节点存在故障，那么pod可能会启动失败，DaemonSet则会始终尝试直到Pod启动成功**。

### DaemonSet如何比其他pod运行的早？
通过Toleration机制实现。在Kubernetes项目中，当一个节点的网络插件尚未安装时，这个节点就会被自定加上一个“污点”：`node.kubernetes.io/network-unavailable`。

DaemonSet通过添加容忍的方式就可以跳过这个限制，从而成功的启动一个网络插件的pod在这个节点：
```yaml
...
template:
    metadata:
      labels:
        name: network-plugin-agent
    spec:
      tolerations:
      - key: node.kubernetes.io/network-unavailable
        operator: Exists
        effect: NoSchedule
```

> 这种机制正是在部署kubernetes集群的时候，能够现部署kubernetes本身，再部署网络插件的分根本原因。因为网络插件本身就是一个DaemonSet。

# 技巧
可以在Pod的模板中添加更多种类的Toleration，从而利用DaemonSet实现自己的目的。比如添加下面的容忍：
```yaml
tolerations:
- key: node-role.kubernetes.io/master
  effect: NoSchedule
```
这样的话pod可以被调度到主节点，默认主节点有“node-role.kubernetes.io/master”的污点，pod是不能运行的。

> 一般在DaemonSet上都要加上resource字段，来限制CPU和内存的使用，防止占用过多的宿主机资源。

## 版本管理（ControllerRevision）
> ControllerRevision 其实是一个通用的版本管理对象，这样可以巧妙的避免每种控制器都要维护一套荣誉的代码和逻辑。

DaemonSet也可以想Deployment那样进行版本管理：
```bash
#查看版本历史
$ kubectl rollout history daemonset fluentd-elasticsearch -n kube-system
daemonsets "fluentd-elasticsearch"
REVISION  CHANGE-CAUSE
1         <none>

# 更新镜像版本
$ kubectl set image ds/fluentd-elasticsearch fluentd-elasticsearch=k8s.gcr.io/fluentd-elasticsearch:v2.2.0 --record -n=kube-system
# 增加--record参数，升级指令会直接出现在history中

# 查看滚动更新的过程
$ kubectl rollout status ds/fluentd-elasticsearch -n kube-system
Waiting for daemon set "fluentd-elasticsearch" rollout to finish: 0 out of 2 new pods have been updated...
Waiting for daemon set "fluentd-elasticsearch" rollout to finish: 0 out of 2 new pods have been updated...
Waiting for daemon set "fluentd-elasticsearch" rollout to finish: 1 of 2 updated pods are available...
daemon set "fluentd-elasticsearch" successfully rolled out

```
有了版本号，就可以像Deployment那样进行历史版本回滚。Deployment通过每一个版本对应一个ReplicaSet来控制不同的版本，DaemonSet没有ReplicaSet，使用ControllerRevision进行控制。

> Kubernetes v1.7 之后添加的API对象，ControllerRevision专门用来记录某种Controller对象的版本。

查看对应的ControllerRevision：
```bash
# 获取集群中存在的ControllerRevision
$ kubectl get controllerrevision -n kube-system -l name=fluentd-elasticsearch
NAME                               CONTROLLER                             REVISION   AGE
fluentd-elasticsearch-64dc6799c9   daemonset.apps/fluentd-elasticsearch   2          1h

# 查看详细信息
$ kubectl describe controllerrevision fluentd-elasticsearch-64dc6799c9 -n kube-system
Name:         fluentd-elasticsearch-64dc6799c9
Namespace:    kube-system
Labels:       controller-revision-hash=2087235575
              name=fluentd-elasticsearch
Annotations:  deprecated.daemonset.template.generation=2
              kubernetes.io/change-cause=kubectl set image ds/fluentd-elasticsearch fluentd-elasticsearch=k8s.gcr.io/fluentd-elasticsearch:v2.2.0 --record=true --namespace=kube-system
API Version:  apps/v1
Data:
  Spec:
    Template:
      $ Patch:  replace
      Metadata:
        Creation Timestamp:  <nil>
        Labels:
          Name:  fluentd-elasticsearch
      Spec:
        Containers:
          Image:              k8s.gcr.io/fluentd-elasticsearch:v2.2.0
          Image Pull Policy:  IfNotPresent
          Name:               fluentd-elasticsearch
...
Revision:                  2
Events:                    <none>

# 对DaemonSet进行版本回滚
$ kubectl rollout undo daemonset fluentd-elasticsearch --to-revision=1 -n kube-system
daemonset.extensions/fluentd-elasticsearch rolled back
# undo操作读取Revision=1的ControllerRevision对象保存的Data字段
```
> 注意，执行了上述undo操作后，DaemonSet的Revision并不会从2变回1，而是编程3，每一个操作都是一个新的ControllerRevision对象被创建。

ControllerRevision对象：
- 在`Data`字段保存了该本班对用的完整的**DaemonSet的API对象**，
- 在`Annotation`字段保存了创建这个对象所使用的**kubectl命令**。

