Deployment并不足以覆盖所有的应用编排问题，因为它对应用做了一个简单的假设：
> 一个应用的所有Pod是完全一样的，他们互相之间没有顺序也无所谓运行在哪台宿主机上。需要的时候Deployment通过Pod模板创建新的Pod，不需要的时候，就可以“杀掉”任意一个Pod。

1. 在分布式应用中，多个实例之间并不是这样的关系，有很多的**依赖关系**（主从关系、主备关系）。
2. 数据存储类应用，它的多个实例往往都会在本地磁盘上保存一份数据。这些实例一旦被“杀掉”，即便重建出来，实例与数据之间的对应关系也丢失了，从而导致应用失败。

## 有状态应用（Stateful Application）
- 实例之间有不对等关系
- 实例对外部数据有依赖关系

> 容器技术用于封装“无状态应用”尤其是Web服务，非常好，但是“有状态应用”就很困难。


kubernetes得益于“控制器模式”，在Deployment的基础上扩展出StatefulSet，它将应用抽象为两种情况：
1. 拓扑状态：应用的多个实例之间不是完全对等的关系。这些应用实例必须按照某些顺序启动。

  > 比如应用的主节点A要先于从节点B启动，如果把A和B两个Pod删掉，它们被再次创建出来时，必须**严格按照这个顺序才行**，并且新建的Pod必须与原来的Pod的**网络标识一样**，这样原先的访问者才能使用同样的方法访问到这个新的Pod。

2. 存储状态：应用的多个实例分别绑定了不同的存储数据。

  > 比如Pod A 第一次读取到的数据应该和十分钟之后读取到的是同一份数据，哪怕在这期间Pod A 被重新创建过，典型的例子就是一个数据库应用的多个存储实例。

**StatefulSet的核心功能，通过某种方式记录这些状态， 然后在Pod被创建时，能够为新的Pod恢复这些状态。**

## Headless Service
通过Service，可以访问对应的Deployment所包含的Pod。那么Service是如何被访问的：
1. 以Service的VIP（Virtual IP）方式：访问Service的VIP时，会把请求转发到该Servcice所代理的某一个Pod上。
2. 以Service 的DNS方式：比如通过my-svc.my-namespace.svc.cluster.local这条DNS可以访问到名为my-svc的Service所代理的某个Pod。**通过DNS具体可以分为两种方式**：
    1. Normal Service，访问my-svc.my-namespace.svc.cluster.local，解析到my-svc这个Service的VIP，然后与访问VIP的方式一样。
    2. Headless Service，访问my-svc.my-namespace.svc.cluster.local，解析到的直接就是my-svc代理的某个pod的IP地址。

**区别在于，Headless Servcice不需要分配VIP，可以直接以DNS记录的方式解析出被代理Pod的IP地址。**

### Headless Service 的例子

```yaml
apiVersion: v1
kind: Service
metadata:
  name: nginx
  labels:
    app: nginx
spec:
  ports:
  - port: 80
    name: web
  clusterIP: None
  selector:
    app: nginx
```
Headless Service仍然是一个标准的Service的YAML文件，**只不过clusterIP字段为None**。这样的话，这个Service没有VIP作为头，被创建后不会被分配VIP，而是以DNS记录的方式暴露出它所代理的Pod。

1. 通过Label Selector筛选出需要被代理的Pod
2. 以上述方式创建的Headless Service之后，它所代理的Pod的IP地址，会被绑一个如下格式的DNS记录：

```bash
<pod-name>.<svc-name>.<namespace>.svc.cluster.local    //这个DNS是kubernetes为Pod分配的唯一的“可解析身份”
```
有了可解析身份，只要知道Pod的名字和对应的Service名字，就可以通过DNS记录访问到Pod 的IP地址。

## StatefulSet 如何使用DNS记录来维持Pod的拓扑状态？

```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.9.1
        ports:
        - containerPort: 80
          name: web
```
这个StatefulSet的YAML文件与同类型的Deployment的YAML文件的唯一区别是**多了一个`serviceName=nginx`字段**。

> 这个字段的作用，告诉StatefulSet控制器，在执行控制循环（control loop）的时候，使用nginx这个Headless Service来保证Pod的“可解析身份”。

此时执行创建任务，分别创建service和对应的StatefulSet：

```bash
$ kubectl create -f svc.yaml
$ kubectl get service nginx
NAME      TYPE         CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
nginx     ClusterIP    None         <none>        80/TCP    10s

$ kubectl create -f statefulset.yaml
$ kubectl get statefulset web
NAME      DESIRED   CURRENT   AGE
web       2         1         19s
```
查看StatefulSet的创建事件，或者使用kubectl的-w参数查看StatefulSet对应的Pod的创建过程：

```bash
$ kubectl get pods -w -l app=nginx
NAME      READY     STATUS    RESTARTS   AGE
web-0     0/1       Pending   0          0s
web-0     0/1       Pending   0         0s
web-0     0/1       ContainerCreating   0         0s
web-0     1/1       Running   0         19s
web-1     0/1       Pending   0         0s
web-1     0/1       Pending   0         0s
web-1     0/1       ContainerCreating   0         0s
web-1     1/1       Running   0         20s
```
StatefulSet给它所管理的Pod的名字进行了编号，从0开始，短横（-）相接，每个Pod实例一个，**绝不重复**。

> Pod的创建也按照编号顺序进行，只有当编号为0的Pod进入Running状态，并且细分状态为Ready之前，编号为1的pod都会一直处于pending状态。


**为Pod设置livenessProbe和readinessProbe很重要。**

当两个Pod都进入Running状态后，可以查看他们各自唯一的“网络身份”。


```bash
$ kubectl exec web-0 -- sh -c 'hostname'
web-0   //pod的名字与hostname一致
$ kubectl exec web-1 -- sh -c 'hostname'
web-1
```
以DNS的方式访问Headless Service：

```bash
$ kubectl run -i --tty --image busybox dns-test --restart=Never --rm /bin/sh
```
在启动的Pod的容器中，使用nslookup命令来解析Pod对应的Headlesss Service：

```bash
$ kubectl run -i --tty --image busybox dns-test --restart=Never --rm /bin/sh
$ nslookup web-0.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-0.nginx
Address 1: 10.244.1.7

$ nslookup web-1.nginx
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      web-1.nginx
Address 1: 10.244.2.7
```
从nslookup命令的输出结果中发现，在访问web-0.nginx的时候，最后解析到的正是web-0这个pod的IP地址。

当删除这两个Pod后，会按照原先编号的顺序重新创建两个新的Pod，并且依然会分配与原来相同的“网络身份”。

**通过这种严格的对应规则，StatefulSet就保证了Pod网络标识的稳定性。**

> 通过这种方法，Kubernetes就成功地将Pod的拓扑状态（比如：哪个节点先启动，哪个节点后启动），按照“Pod名字+编号”的方式固定下来。并且Kubernetes还为每一个Pod提供了一个固定并且唯一的访问入口，即：**这个Pod对应的DNS记录**。

这些状态，在StatefulSet的整个生命周期里都保持不变，绝不会因为对应Pod的删除或重新创建而失效。

### 注意
虽然web-0.nginx这条记录本身不会变化，但是它解析到的Pod的IP地址，并不是固定的，所以对于“有状态应用”实例的访问，必须使用DNS记录或者hostname的方式，绝不应该直接访问这些Pod的IP地址。


StatefulSet其实是Deployment的改良。通过Headless Service的方式，StatefulSet为每个Pod创建了一个固定并且稳定的DNS记录，来作为它的访问入口。
