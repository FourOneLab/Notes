# Service
kubernetes使用Service：
1. Pod的IP地址不固定
2. 一组Pod之间有负载均衡的需求

典型的Service如下：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: hostnames
spec:
  selector:
    app: hostnames
  ports:
  - name: default
    protocol: TCP
    port: 80            #service的端口
    targetPort: 9376    #代理的Pod的端口 
```
具体的应用的Deployment如下：
```yaml
# 这个容器的作用是每次访问9376端口，返回它自己的hostname
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hostnames
spec:
  selector:
    matchLabels:
      app: hostnames
  replicas: 3
  template:
    metadata:
      labels:
        app: hostnames
    spec:
      containers:
      - name: hostnames
        image: k8s.gcr.io/serve_hostname
        ports:
        - containerPort: 9376
          protocol: TCP
```
被选中的Pod就是Service的Endpoints，使用`kubectl get ep`可以看到如下所示：
```bash
$ kubectl get endpoints hostnames
NAME        ENDPOINTS
hostnames   10.244.0.5:9376,10.244.0.6:9376,10.244.0.7:9376

# 只有处于Running，且readinessProbe检查通过的Pod才会出现在这个Service的Endpoints列表中
# 当某个Pod出现问题时，kubernetes会自动把它从Service里去除掉
```
通过该Service的VIP地址`10.0.1.175`，就能访问到它代理的Pod：
```bash
$ kubectl get svc hostnames
NAME        TYPE        CLUSTER-IP   EXTERNAL-IP   PORT(S)   AGE
hostnames   ClusterIP   10.0.1.175   <none>        80/TCP    5s

$ curl 10.0.1.175:80
hostnames-0uton

$ curl 10.0.1.175:80
hostnames-yp2kp

$ curl 10.0.1.175:80
hostnames-bvc05
```
这个VIP地址是kubernetes自动为Service分配的。通过三次连续不断地访问Service的VIP地址和代理端口80，为我们一次返回三个Pod的hostname，Service提供的是RoundRobin方式的负载均衡。这种方式称之为ClusterIP模式的Service。

## iptables模式
**Service是由kube-proxy组件，加上iptables来共同实现**。

> 举个例子，对应创建的Service，一旦提交给kubernetes，呢么kube-proxy就可以通过Service的Informer感知到这样一个Service对象的添加。作为对这个事件的响应，就会在宿主机上创建如下所示的iptables规则。

```bash
# iptables-save命令可以查看
-A KUBE-SERVICES -d 10.0.1.175/32 -p tcp -m comment --comment "default/hostnames: cluster IP" -m tcp --dport 80 -j KUBE-SVC-NWV5X2332I4OT4T3

# 这条规则的含义是：凡是目的地址是10.0.1.175、目的端口是80的IP包，都应该跳转到另外一个名叫KUBE-SVC-NWV5X2332I4OT4T3的iptables链进行处理
# 10.0.1.175真是这个Service的VIP，这条规则就是为Service设置了一个固定的入口地址
# 由于10.0.1.175只是一条iptables规则上的配置，并没有真正的网络设备，所以ping这个地址，是不会有任何响应的
```
KUBE-SVC-NWV5X2332I4OT4T3的规则是一个规则的集合，如下所示：
```bash
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.33332999982 -j KUBE-SEP-WNBA2IHDGP2BOBGZ
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -m statistic --mode random --probability 0.50000000000 -j KUBE-SEP-X3P2623AGDH6CDF3
-A KUBE-SVC-NWV5X2332I4OT4T3 -m comment --comment "default/hostnames:" -j KUBE-SEP-57KPRZ3JQVENLNBR

# 这是一组随机模式（mode random）的iptables链
# 随机发送的目的地址，分别是KUBE-SEP-WNBA2IHDGP2BOBGZ、KUBE-SEP-X3P2623AGDH6CDF3、KUBE-SEP-57KPRZ3JQVENLNBR
```

这三条链指向的最终目的地，其实就是这个Service代理的三个pod。所以这一组规则，就是Service实现负载均衡的位置。

> iptables规则匹配是从上到下逐条进行的，所以为了保证上述三条规则，每条被选中的概率一样，应该将他们的probability字段的值分别设置为1/3（0.333）、1/2和1。第一条选中的概率是三分之一，第一条没选择剩下两条的概率是二分之一，最后一条为1。

Service进行转发的具体原理如下所示：
```bash
-A KUBE-SEP-57KPRZ3JQVENLNBR -s 10.244.3.6/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
-A KUBE-SEP-57KPRZ3JQVENLNBR -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.3.6:9376

-A KUBE-SEP-WNBA2IHDGP2BOBGZ -s 10.244.1.7/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
-A KUBE-SEP-WNBA2IHDGP2BOBGZ -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.1.7:9376

-A KUBE-SEP-X3P2623AGDH6CDF3 -s 10.244.2.3/32 -m comment --comment "default/hostnames:" -j MARK --set-xmark 0x00004000/0x00004000
-A KUBE-SEP-X3P2623AGDH6CDF3 -p tcp -m comment --comment "default/hostnames:" -m tcp -j DNAT --to-destination 10.244.2.3:9376

```

这是三条DNAT规则，在DNAT规则之前，iptables对流入的IP包还设置了一个标志（`--set-xmark`）。DNAT规则的作用就是在PREROUTING检查点之前，即路由之前，将流入IP包的目的地址和端口，改成`--to-destination`所指定的新的目的地址和端口。

这样访问Service VIP的IP包经过上述iptables处理之后，就已经成了访问具体某一个后端Pod的IP包了。这些Endpoints对应的iptables规则，正式kube-proxy通过监听Pod的变化时间，在宿主机上生成并维护的。

> kube-proxy通过iptables处理Service的过程，需要在宿主机上设置相当多的iptables规则，而且，kube-proxy还需要在控制循环里不断地刷新这些规则来始终保持正确。当宿主机上有大量pod的时候，成百上千条iptables规则在不断地刷新，会大量占用该宿主机的CPU资源，甚至会让宿主机“卡”在这个过程中。**一直以来，基于iptables的Service实现，都是制约kubernetes项目承载更多量级的Pod的主要障碍**。

IPVS模式的Service是解决这个问题行之有效的方法。

## IPVS模式
工作原理，与iptables模式类似，创建了Service之后，kube-proxy首先会在宿主机上创建一个虚拟网卡（kube-ipvs0），并为它分配Service VIP作为IP地址，如下所示：
```bash
# ip addr
  ...
  73：kube-ipvs0：<BROADCAST,NOARP>  mtu 1500 qdisc noop state DOWN qlen 1000
  link/ether  1a:ce:f5:5f:c1:4d brd ff:ff:ff:ff:ff:ff
  inet 10.0.1.175/32  scope global kube-ipvs0
  valid_lft forever  preferred_lft forever

```
kube-proxy就会通过Linux的IPVS模式，为这个IP地址设置三个IPVS虚拟主机，并设置这个虚拟主机之间使用的轮询模式（rr）来作为负载均衡策略，通过ipvsadm查看这个设置，如下所示：
```bash
# ipvsadm -ln
 IP Virtual Server version 1.2.1 (size=4096)
  Prot LocalAddress:Port Scheduler Flags
    ->  RemoteAddress:Port           Forward  Weight ActiveConn InActConn     
  TCP  10.102.128.4:80 rr
    ->  10.244.3.6:9376    Masq    1       0          0         
    ->  10.244.1.7:9376    Masq    1       0          0
    ->  10.244.2.3:9376    Masq    1       0          0

```
这三个IPVS虚拟主机的IP地址和端口，对应的正是三个被代理的Pod。这样任何发往`10.102.128.4:80`的请求，就都会被IPVS模块转发到某一个后端Pod上了。

相比于iptables，IPVS在内核中的实现其实也是基于Netfilter的NAT模式，所以在转发这一层上，理论上IPVS并没有显著的性能提升。但是，IPVS并不需要在宿主机上为每个Pod设置iptables规则，而是把这些“规则”的处理放在内核态，从而极大地降低了维护这些规则的代价。

**将重要操作放在内核态**是提高性能的重要手段。

IPVS模块只负责上述的负载均衡和代理功能。而一个完整的Service流程正常工作所需要的包过滤，SNAT等操作，还是依靠iptables来实现，不过这些副主席的iptables数量有限，也不会随着pod数量的增加而增加。

> 在大规模集群里，建议kube-proxy设置`--proxy-mode=ipvs`来开启这个功能，它为kubernetes集群规模带来的提升是非常巨大的。

# DNS
Service与DNS也有关系，在kubernetes中，Service和Pod都会被分配对应的DNS A记录（从域名解析IP的记录）。

- 对于**ClusterIP模式**的Service来说，它的A记录的格式是：`..svc.cluster.local`。当你访问这个A记录的时候，它解析到的就是该Service的VIP地址。它代理的Pod被自动分配的A记录格式是：`..pod.cluster.local`，这条记录指向Pod的IP地址。
- 对于执行**clusterIP=None**的Headless Service来说，它的A记录的格式也是：`..svc.cluster.local`，但是访问这个A记录的时候，它返回的是所代理的Pod的IP地址集合。（如果客户端无法解析这个集合，那可能只会拿到第一个Pod的IP地址）。它代理的Pod被自动分配的A记录的格式是：`..svc.cluster.local`。这条记录指向Pod的IP地址。
> 如果为pod指定了Headless Service，并且Pod本身声明了`hostname`和`subdomain`字段，那么Pod的A记录就会变成：`<pod的hostname>...svc.cluster.local`，如下所示。、

```yaml
apiVersion: v1
kind: Service
metadata:
  name: default-subdomain
spec:
  selector:
    name: busybox
  clusterIP: None
  ports:
  - name: foo
    port: 1234
    targetPort: 1234
---
apiVersion: v1
kind: Pod
metadata:
  name: busybox1
  labels:
    name: busybox
spec:
  hostname: busybox-1
  subdomain: default-subdomain
  containers:
  - image: busybox
    command:
      - sleep
      - "3600"
    name: busybox

```
通过`busybox-1.default-subdomain.default.svc.cluster.local`解析到这个pod的IP地址。

**在kubernetes中，`/etc/hosts`文件是单独挂载的，所有kubelet能够对hostname进行修改并且pod重建后依然有效。与Docker的init层是一个原理。**

# 小结
Service机制和DNS插件都是为了解决同一个问题，如何找到某个容器。在平台级项目中称为**服务发现**，即当一个服务（Pod）的IP堵住是不固定的且没办法提前获知时，该如何通过固定的方式访问到这个Pod。

- **ClusterIP模式的Service**，提供的是一个Pod的**稳定的IP地址**，即VIP，并且pod和Service的关系通过Label确定。
- **Headless Service**，提供的是一个Pod的**稳定的DNS名字**，并且这个名字可以通过Pod名字和Service名字拼接出来。

# Service 调试
**Service的访问信息在kubernetes集群之外是无效的**。

> Service的访问入库，就是每台宿主机上由kube-proxy生成的iptables规则，以及kube-dns生成的DNS记录。一旦离开这个集群，这些信息对用户来说，是没有作用的。

如何从kubernetes集群之外，访问到Kubernetes里创建的Service？
1. Nodeport
2. LoadBalancer
3. ExternalName
4. externalIPs

## Nodeport
```yaml
apiVersion: v1
kind: Service
metadata:
  name: my-nginx
  labels:
    run: my-nginx
spec:
  type: NodePort    # 声明类型
  ports:
  - nodePort: 8080  # service的端口
    targetPort: 80
    protocol: TCP
    name: http
  - nodePort: 443   # Service的端口
    protocol: TCP
    name: https
  selector:
    run: my-nginx
```
不显示声明nodePort字段，会随机分配`30000-32767`之间的端口，通过kube-apiserver的`--service-node-port-range`参数来修改它。

访问以上Service`<任何一台宿主机的IP地址>：8080`，就能够访问到某一个被代理的Pod的80端口。

NodePort模式的工作原理，是kube-proxy在每台宿主机上生成一条iptables规则，如下所示：
```bash
-A KUBE-NODEPORTS -p tcp -m comment --comment "default/my-nginx: nodePort" -m tcp --dport 8080 -j KUBE-SVC-67RL4FN6JRUPOJYM

# KUBE-SVC-67RL4FN6JRUPOJYM是一组随机模式的iptables规则
```
在NodePort模式下，kubernetes会在IP包离开宿主机发往目的Pod时，对这个IP包做一次SNAT操作，如下所示：
```
-A KUBE-POSTROUTING -m comment --comment "kubernetes service traffic requiring SNAT" -m mark --mark 0x4000/0x4000 -j MASQUERADE

# 这条规则设置在POSTROUTING检查点，为即将离开这台主机的IP包，进行一次SNAT操作，
# 将这个IP包的源地址替换成了这个宿主机的CNI网桥地址，或者宿主机本身的IP地址（CNI网桥不存在时）
```
SNAT操作只需要对Service转发出来的IP包进行（否则普通的IP包就被影响了）。iptables做这个判断的依据就是查看该IP包是否有一个`0x4000`的标志，这个标志是在IP包被执行DNAT操作之前被打上的。

原理如下图：
```
           client
             \ ^
              \ \
               v \
   node 1 <--- node 2
    | ^   SNAT
    | |   --->
    v |
 endpoint

```
当一个外部的Client通过node2的地址访问一个Service的时候，node2上的负载均衡规则就可能把这个IP包转发给一个node1上的pod，当node1上的这个pod处理完请求之后，它就会按照这个IP包的源地址发出回复。
  
如果没有SNAT操作，这个时候被转发的IP包源地址就是client的IP地址，**pod就会直接回复client**，对于client来说，它的请求明明是发给node2，收到的回复却来自node1，此时client可能会报错。

> 所有当IP包离开node2之后，它的源IP地址就会被SNAT改成node2的CNI网桥或者node2自己的地址。这样pod处理完成后就会先回复给node2（而不是直接给client），然后node2发送给client。

**这样的话pod只知道这个IP包来自node2，而不是外部client，对于pod需要知道所有请求来源的场景来说，这是不行的**。需要将Service的`spec.externalTrafficPolicy`字段设置为`local`，保证所有pod通过Service收到请求之后，一定可以看到真正的、外部client的源地址。

这个机制的实现原理：**一台宿主机上的iptables规则会设置为只将IP包转发给运行在这台宿主机上的Pod**。这样pod就可以直接使用源地址将回复包发出，不需要事先进行SNAT。操作流程如下：
```bash
       client
       ^ /   \
      / /     \
     / v       X
   node 1     node 2
    ^ |
    | |
    | v
 endpoint

# 如果在一台宿主机上没有任何被代理的pod存在（如图中node2），那么使用node2的IP地址访问这个Service是无效的，请求会被DROP掉
```

## LoadBalancer
适用于公有云上的Kubernetes集群的访问方式，指定一个LoadBalancer类型的Service，如下所示：
```yaml
---
kind: Service
apiVersion: v1
metadata:
  name: example-service
spec:
  ports:
  - port: 8765
    targetPort: 9376
  selector:
    app: example
  type: LoadBalancer

```
在公有云提供的kubernetes服务里，都是用了CloudProvider的转接层，来跟公有云本身的API进行对接。所有在LoadBalancer类型的Service被提交后，kubernetes就会调用CloudProvider在公有云上创建一个负载均衡服务，并且被代理的Pod的IP地址配置给负载均衡服务器做后端。

## ExternalName
kubernetes v1.7之后支持的新特性，ExternalName，如下：
```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  type: ExternalName
  externalName: my.database.example.com

```
指定一个`externalName=my.database.example.com`字段，并且不需要指定selector。通过Service的DNS名字（如`my-service.service.default.svc.cluster.local`）访问的时候，kubernetes返回的是`my.database.example.com`，所有externalName类型的Service，其实是在kube-dns里添加一条CNAME记录，此时访问`my-service.service.default.svc.cluster.local`和访问`my.database.example.com`是一个效果。


## externalIPs
同时，kubernetes的Service还可以为Service分配公有IP地址，如下：
```yaml
kind: Service
apiVersion: v1
metadata:
  name: my-service
spec:
  selector:
    app: MyApp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 9376
  externalIPs:
  - 80.11.12.10

```
指定`externalIPs=80.11.12.10`,此时通过访问`80.11.12.10`来方位被代理的pod。**在这里kubernetes要求externalIPs必须是至少能够路由到一个kubernetes节点的**。

## 解决问题
> 很多与Service相关的问题，都可以通过分享Service在宿主机上对应的iptables规则（或者IPVS配置）得到解决。

1. 问题1
当Service无法通过DNS访问时，区分是Service本身的配置问题还是集群的DNS出现问题。**通过检查kubernetes自己Master节点的Service DNS是否正常**：
```bash
# 在一个 Pod 里执行
$ nslookup kubernetes.default
Server:    10.0.0.10
Address 1: 10.0.0.10 kube-dns.kube-system.svc.cluster.local

Name:      kubernetes.default
Address 1: 10.0.0.1 kubernetes.default.svc.cluster.local

```
如果上述访问`kubernetes.default`返回的值都有问题，那么就需要检查kube-dns的运行状态和日志。否则就应该去检查Service定义是否有问题。

2. 问题2
如果Service没办法通过ClusterIP访问到，首先应该检查这个Service是否有Endpoints：
```bash
$ kubectl get endpoints hostnames
NAME        ENDPOINTS
hostnames   10.244.0.5:9376,10.244.0.6:9376,10.244.0.7:9376

# 如果pod的readinessProbe没有通过，它是不会出现在Endpoints列表里。
```
如果Endpoints正常，就需要确认kube-proxy是否正确运行。通过kubeadm部署的集群中，kube-proxy的输出日志如下：
```bash
I1027 22:14:53.995134    5063 server.go:200] Running in resource-only container "/kube-proxy"
I1027 22:14:53.998163    5063 server.go:247] Using iptables Proxier.
I1027 22:14:53.999055    5063 server.go:255] Tearing down userspace rules. Errors here are acceptable.
I1027 22:14:54.038140    5063 proxier.go:352] Setting endpoints for "kube-system/kube-dns:dns-tcp" to [10.244.1.3:53]
I1027 22:14:54.038164    5063 proxier.go:352] Setting endpoints for "kube-system/kube-dns:dns" to [10.244.1.3:53]
I1027 22:14:54.038209    5063 proxier.go:352] Setting endpoints for "default/kubernetes:https" to [10.240.0.2:443]
I1027 22:14:54.038238    5063 proxier.go:429] Not syncing iptables until Services and Endpoints have been received from master
I1027 22:14:54.040048    5063 proxier.go:294] Adding new service "default/kubernetes:https" at 10.0.0.1:443/TCP
I1027 22:14:54.040154    5063 proxier.go:294] Adding new service "kube-system/kube-dns:dns" at 10.0.0.10:53/UDP
I1027 22:14:54.040223    5063 proxier.go:294] Adding new service "kube-system/kube-dns:dns-tcp" at 10.0.0.10:53/TCP

```
如果kube-proxy一起正常，就应该查看宿主机上iptables。一个iptables模式的Service对应的规则应该包括：
1. KUBE-SERVICES或者KUBE-NODEPORTS规则对应的Service入口链，这个规则应该与VIP和Service端口一一对应
2. KUBE-SEP-（hash）规则对应的DNAT链，这些规则应该与Endpoints一一对应
3. KUBE-SVC-（hash）规则对应的负载均衡链,这些规则的数目应该与Endpoints数目一致
4. 如果NodePort模式的话，还有POSTROUTING处的SNAT链

通过查看链的数量、转发目的地址、端口、过滤条件等信息，能发现异常的原因。

3. 问题3
Pod无法通过Service访问到自己。这是因为kubelet的hairpin-mode没有被正确的设置，只需要将kubelet的hairpin-mode设置为hairpin-veth或者promiscuous-bridge即可。

- hairpin-veth模式下，应该看到CNI网桥对应的各个VETH设备，都将Hairpin模式设置为1，如下所示；
```
$ for d in /sys/devices/virtual/net/cni0/brif/veth*/hairpin_mode; do echo "$d = $(cat $d)"; done
/sys/devices/virtual/net/cni0/brif/veth4bfbfe74/hairpin_mode = 1
/sys/devices/virtual/net/cni0/brif/vethfc2a18c5/hairpin_mode = 1

```

- promiscuous-bride模式。应该看到CNI网桥的混杂模式（PROMISC）被开启，如下所示：
```
$ ifconfig cni0 |grep PROMISC
UP BROADCAST RUNNING PROMISC MULTICAST  MTU:1460  Metric:1
  
```

# 总结
所谓Service就是kubernetes为Pod分配的、固定的、基于iptables（或者IPVS）的访问入口，这些访问入口代理的Pod信息，来自Etcd，由kube-proxy通过控制循环来维护。

kubernetes里的Service和DNS机制，都不具备强多租户能力。在多租户情况下：
- 每个租户应该拥有一套独立的Service规则（Service只应该看到和代理同一个租户下的Pod）
- 每个租户应该拥有自己的kube-dns（kube-dns只应该为同一个租户下的Service和Pod创建DNS Entry）

> 在kubernetes中，kube-proxy和kube-dns都只是普通的插件，可以根据自己的需求，实现符合自己预期的Service。

