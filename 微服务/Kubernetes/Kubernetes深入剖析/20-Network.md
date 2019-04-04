# Network Namespace
Linux容器能够看见的“网络栈”，是被隔离在它自己的Network Namespace当中的。

网络栈，包括：
1. 网卡（Network Interface）
2. 回环设备（Loopback Device）
3. 路由表（Routing Table）
4. iptables规则

**对于一个进程来说，这些要素就构成了它发起和响应网络请求的基本环境**。

作为一个容器，可以直接使用宿主机的网络栈，即**不开启Network Namespace**，如下：
```
$ docker run -d -net=host --name nginx-host nginx
# 这个容器启动后，直接箭筒的是宿主机的80端口
```

这样直接使用宿主机网络栈的方式：
- 好处：为容器提供良好的网络性能
- 缺点：引入共享网络资源的问题，比如端口冲突

所以在大多数情况下，都希望容器进程能使用自己的Network Namespace里的网络栈，**即拥有自己的IP地址和端口**。

# 容器网络

## 容器通信
被隔离的容器进程，该如何与其他Network Namespace里的容器进程进行交互？

> 将一个容器理解为一台主机，拥有独立的网络栈，那么主机之间通信最直接的方式就是通过网线，当有多台主机时，通过网线连接到交换机再进行通信。

在Linux中，能够起到虚拟交换机作用的网络设备，就是**网桥**（Bridge），工作在**数据链路层**（Data Link）的设备，主要功能**根据MAC地址学习来将数据包转发到王巧的不同端口（Port）上**。

Docker项目默认在宿主机上创建一个**docker0网桥**，凡是连接在docker0网桥上的容器，就可以通过它来进行通信。使用`Veth Pair`的虚拟设备把容器都连接到docker0网桥上。

> `Veth Pair`设备的特点：它被创建后，总是以两张虚拟网卡（`Veth Peer`）的形式成对出现的，并且从其中一个“网卡”发出的数据包，可以直接出现在与它对应的另一张“网卡”上，哪怕这两个“网卡”在不同的Network Namespace中。所有`Veth Pair`常被用作连接不同Network Namespace的“网线”。

### 例子
启动一个容器，并进入后查看它的网络设备，然后回到宿主机查看网络设备：
```bash
$ docker run –d --name nginx-1 nginx

# 在宿主机上
$ docker exec -it nginx-1 /bin/bash
# 在容器里
root@2b3c181aecf1:/# ifconfig
# 这张网卡是Veth Pair设备在容器里的一端
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.17.0.2  netmask 255.255.0.0  broadcast 0.0.0.0
        inet6 fe80::42:acff:fe11:2  prefixlen 64  scopeid 0x20<link>
        ether 02:42:ac:11:00:02  txqueuelen 0  (Ethernet)
        RX packets 364  bytes 8137175 (7.7 MiB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 281  bytes 21161 (20.6 KiB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        
lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0
        
$ route     # 查看路由表
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
# 这是容器里的默认路由设备，是eth0这张网卡
default         172.17.0.1      0.0.0.0         UG    0      0        0 eth0   
# 所有对172.17.0.0/16这个网段的请求，也会被交给eth0来处理
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0
# 网关为0.0.0.0表示这是一条直连规则，凡是匹配到这个规则的IP包，应该经过本机的eth0网卡，通过二层网络直接发往目的主机

# 在宿主机上
$ ifconfig
...
docker0   Link encap:Ethernet  HWaddr 02:42:d8:e4:df:c1  
          inet addr:172.17.0.1  Bcast:0.0.0.0  Mask:255.255.0.0
          inet6 addr: fe80::42:d8ff:fee4:dfc1/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:309 errors:0 dropped:0 overruns:0 frame:0
          TX packets:372 errors:0 dropped:0 overruns:0 carrier:0
 collisions:0 txqueuelen:0 
          RX bytes:18944 (18.9 KB)  TX bytes:8137789 (8.1 MB)
# nginx-1容器对应的Veth Pair设备，在宿主机上是这个虚拟网卡
veth9c02e56 Link encap:Ethernet  HWaddr 52:81:0b:24:3d:da  
          inet6 addr: fe80::5081:bff:fe24:3dda/64 Scope:Link
          UP BROADCAST RUNNING MULTICAST  MTU:1500  Metric:1
          RX packets:288 errors:0 dropped:0 overruns:0 frame:0
          TX packets:371 errors:0 dropped:0 overruns:0 carrier:0
 collisions:0 txqueuelen:0 
          RX bytes:21608 (21.6 KB)  TX bytes:8137719 (8.1 MB)
          
$ brctl show
# 查看网桥，可以看到上面的虚拟网卡被连接到了docker0网桥上
bridge name bridge id  STP enabled interfaces
docker0  8000.0242d8e4dfc1 no  veth9c02e56

```
新创建容器nginx-2的Veth Pair的一端在容器中，另一端在docker0网桥上，所以同一个宿主机上的两个容器默认就是互相连通的。

### 容器间访问（同宿主机）
![](https://static001.geekbang.org/resource/image/e0/66/e0d28e0371f93af619e91a86eda99a66.png)

1. 当nginx-1访问nginx-2的IP地址（172.17.0.3）时，目标IP地址会匹配容器-1里面的第二条路由规则。这条规则的网关是0.0.0.0，这是一条直连规则，凡是匹配到这条规则的IP包，应该经过本机的eth0网卡，通过二层网络直接发往目的主机。
2. 通过二层网络到达nginx-2容器，就需要有172.17.0.3这个IP地址对应的MAC地址，所以nginx-1容器的网络协议栈需要通过eth0网卡发送一个ARP广播，来通过IP地址查找对应的MAC地址。
> ARP(Address Resoultion Protocol)，是通过三层的IP地址找到对应的二层MAC地址的协议
3. eth0网卡是Veth Pair，它的一端在容器的Network Namespace中，另一端在宿主机上（Host Namespace），并且被插在宿主机docker0网桥上。
> 虚拟网卡被插在网桥上就会变成网桥的从设备（被剥夺调用网络协议栈处理数据包的资格），从而降级为网桥上的一个端口，这个端口的唯一作用就是接受流入的数据包，然后把数据包的**转发**或**丢弃**全部交给对应的网桥。
4. 在收到nginx-1容器中发出的ARP请求后，docker0网桥就会扮演二层交换机的角色，把ARP广播转发到其他插在docker0网桥上的虚拟网卡。nginx-2容器内的网络协议栈就会收到这个ARP请求，从而将172.17.0.3所对应的MAC地址回复给nginx-1容器。
5. nginx-1容器获取MAC地址后，就能把数据包从eth0网卡发送出去。根据Veth Pair设备的原理，这个数据包会立刻出现在宿主机的虚拟网卡veth9c02e56上，因为虚拟网卡的网络协议栈资格被剥夺，数据就直接流入docker0网桥里。
6. docker0处理转发的过程，继续扮演二层交换机的角色，网桥根据数据包目的MAC地址，在它的CAM表（交换机通过MAC地址学习维护的端口和MAC地址的对应表）里查到对应的端口为nginx-2的虚拟网卡，然后把数据发送到这个端口。
7. 这个虚拟网卡也是一个Veth Pair设备，所有数据直接进入到nginx-2容器的Network Namespace中。
8. nginx-2容器看到的情况是，它自己的eth0网卡上出现了流入的数据包，这样nginx-2的网络协议栈就会对请求进行处理，最后将响应返回给nginx-1。

> 需要主要的是，在实际的数据传递时，数据的传递过程在网络协议的不同层次，都有Linux内核Netfilter参与其中。可以使用iptables的TRACE功能，查看数据包的传输过程，如下所示：
```bash
# 在宿主机上执行
$ iptables -t raw -A OUTPUT -p icmp -j TRACE
$ iptables -t raw -A PREROUTING -p icmp -j TRACE

# 在宿主机的/var/log/syslog里看到数据包传输的日志
```
**被限制在Network Namespace里的容器进程，实际上是通过Veth Pair设备和宿主机网桥的方式，实现了跟其他容器的数据交换**。

### 宿主机访问容器

![](https://static001.geekbang.org/resource/image/9f/01/9fb381d1e49318bb6a67bda3f9db6901.png)

访问宿主机上的容器的IP地址时，这个请求的数据包下根据路由规则到达Docker0网桥，然后被转发到对应的Veth Pair设备，最后出现在容器里。

### 容器访问宿主机
宿主机之间网络需要互通。

![](https://static001.geekbang.org/resource/image/90/95/90bd630c0723ea8a1fb7ccd738ad1f95.png)

当一个容器试图连接到另外一个宿主机（10.168.0.3）时，发出的请求数据包，首先经过docker0网桥出现在宿主机上，然后根据路由表里的直连路由规则（10.168.0.0/24 via eth0）,对10.168.0.3的访问请求就会交给宿主机的eth0处理。这个数据包经过宿主机的eth0网卡转发到宿主机网络上，最终到达10.168.0.3对应的宿主机上。

> 当出现容器不能访问外网的时候，先试一下能不能ping通dokcer0网桥，然后查看一下docker0和Veth Pair设备相关的iptables规则是否有异常。

### 容器间访问（跨主机）
在Docker默认的配置下，一台宿主机上的docker0网桥，和其它宿主机上的docker0网桥，没有任何关联。它们互相之间也没有办法连通、**所以连接在网桥上的容器，没有办法进行通信**。

> 如果通过网络创建一个整个集群“公用”的网桥，然后把集群里的所有容器都连接到整个网络上，就可以互通了。如下图所示。

![](https://static001.geekbang.org/resource/image/b4/3d/b4387a992352109398a66d1dbe6e413d.png)

构建这种网络的核心在于：需要在已有的宿主机网络上，再通过软件构建一个覆盖在已有宿主机网络之上的、可以把所有容器连通在一起的**虚拟网络**。这种技术称为Overlay Network（覆盖网络）。

> Overlay Network本身，可以由每台宿主机上的一个“特殊网桥”共同组成。比如，当node1上的容器1要访问node2上的容器3时，node1上的“特殊网桥”在收到数据包之后，能够通过某种方式，把数据包发送到正确的宿主机node2上。在node2上的“特殊网桥”在收到数据包后，也能够通过某种方式，把数据包转发给正确的容器，容器3。

**甚至，每台宿主机上，都不要有一个“特殊网桥”，而仅仅通过某种方式配置宿主机的路由表，就能够把数据包转发到正确的宿主机上**。

# 容器跨主机网络
跨主机通信，Flannel项目，这是CoreOS公司主推的容器网络方案。Flannel项目本身只是一个框架，真正提供容器网络功能的是Flannel的后端实现，目前Flannel支持三种后端实现：
1. VXLAN
2. host-gw
3. UDP：最早支持，最直接、最容易理解、但是性能最差，已经弃用

三种不同的后端实现，代表了三种容器跨主机网络的主流实现方法。

## UDP模式
假设有两台宿主机,目标：c1访问c2。

| 宿主机| 容器|IP|docker0网桥地址|
|---|---|---|---|
|node1|c1|100.96.1.2|100.96.1.1/24|
|node2|c2|100.96.2.3|100.96.2.1/24|

> 这种情况下，c1容器里的进程发起的IP包，其源地址是`100.96.1.2`，目的地址是`100.96.2.3`，由于目的地址`100.96.2.3`不在node1的docker0网桥的网段里，所以这个IP包会被交给默认路由规则，通过容器的网关进入docker0网桥（如果是同一台宿主机上的容器间通信，走的是直连规则），从而出现在宿主机上。此时，**这个IP包的下一个目的地，就取决于宿主机上的路由规则**。

此时，Flannel已经在宿主机上创建出了一系列的路由规则，以node1为例，如下所示：
```bash
# 在 Node 1 上
$ ip route
default via 10.168.0.1 dev eth0
100.96.0.0/16 dev flannel0  proto kernel  scope link  src 100.96.1.0
100.96.1.0/24 dev docker0  proto kernel  scope link  src 100.96.1.1
10.168.0.0/24 dev eth0  proto kernel  scope link  src 10.168.0.2

```
可以看到，由于IP包的目的地址是`100.96.2.3`，它匹配不到本机docker0网桥对应的`100.96.1.0/24`，只能匹配到第二条，也就是`100.96.0.0/16`对应的这条路由规则，从而进入到一个叫作flannel0的设备中。

> flannel0设备的类型是一个**TUN设备**（Tunnel设备）。在Linux设备中，**TUN设备**是一个工作在三层（Network Layer）的虚拟网络设备。TUN设备的功能非常简单，即，**在操作系统内核和用户应用程序之间传递IP包**。

### flannel0
1. 当操作系统将一个IP包发送给flannel0设备之后，flannel0就会把这个IP包交给创建这个设备的应用程序（Flannel进程），这是一个从内核态（Linux操作系统）向用户态（Flannel进程）的流动方向。
2. 如果Flannel进程向flannel0设备发送一个IP包，那么这个IP包就会出现在宿主机网络栈中，然后根据宿主机的路由不能进行下一步处理。这是一个从用户态向内核态的流动方向。
所以当IP包从容器经过docker0出现在宿主机，然后又根据路由表进入flannel0设备后，宿主机上的flanneld进程（Flannel项目在宿主机上的主进程），就会收到这个IP包，然后，flanneld看到这个IP包的目的地址是`100.96.2.3`，就把它发送给了node2宿主机。

> 在Flannel管理的容器网络里，一台宿主机上的所有容器，都属于该宿主机被分配的一个**子网**，以上面的例子来说，node1的子网是`100.96.1./24`，c1的IP地址是`100.96.1.2`，node2的子网是`100.96.2.0/24`，c2的IP地址是`100.96.2.3`。

这些子网与宿主机的对应关系保存在Etcd中，如下所示：
```bash
$ etcdctl ls /coreos.com/network/subnets
/coreos.com/network/subnets/100.96.1.0-24
/coreos.com/network/subnets/100.96.2.0-24
/coreos.com/network/subnets/100.96.3.0-24

```
flanneld进程在处理从flannel0传入的IP包时，就可以根据目的IP地址，匹配对应的子网，从Etcd中找到这个子网对应的宿主机IP地址是`10.1168.0.3`，如下所示：
```bash
$ etcdctl get /coreos.com/network/subnets/100.96.2.0-24
{"PublicIP":"10.168.0.3"}

```
对应flanneld来说，只要node1和node2互通，那么flanneld作为node1上的普通进程就可以通过IP地主与node2通信。
1. 所有flanneld收到c1发给c2的IP包后，就会把这个IP包直接封装在一个UDP包(这个包的源地址是node1，目的地址是node2)，发送给node2。
> 具体的说，是node1上的flanneld进程把UDP包发送到node2的8285端口（node2上flanneld监听的端口）。

**通过一个普通的宿主机之间的UDP通信，一个UDP包就从node1到达了node2**。

2. node2上的flanneld进程接收到这个IP包之后将它发送给TUN设备（flannel0），数据从用户态向内核态转换，Linux内核网络栈负责处理这个IP包，即根据本机的路由表来寻找这个IP包的下一步流向。

node2上的路由表，也node1上的类似，如下所示：
```bash
# 在 Node 2 上
$ ip route
default via 10.168.0.1 dev eth0
100.96.0.0/16 dev flannel0  proto kernel  scope link  src 100.96.2.0
100.96.2.0/24 dev docker0  proto kernel  scope link  src 100.96.2.1
10.168.0.0/24 dev eth0  proto kernel  scope link  src 10.168.0.3

```
这个IP包的目的地址是`100.96.2.3`，这与第三条（`100.96.2.0/24`）网段对应的路由规则匹配更加精确。Linux内核就会按照这条路由规则，把这个IP包转发给docker0网桥。然后docker0网桥扮演二层交换机的角色，将数据包发送给正确的端口，进而通过Veth Pair设备进入到c2的Network Namespace。

c2返回给C1的数据包，通过上述过程相反的路径回到c1。

> 上述流程要正确工作的一个重要前提，**docker0网桥的地址范围必须是Flannel为宿主机分配的子网**。以Node1为例，需要给它上面的Docker Daemon启动时配置如下的bip参数。

```bash
$ FLANNEL_SUBNET=100.96.1.1/24
$ dockerd --bip=$FLANNEL_SUBNET ...

```

### 流程图
Flannel UDP模式的跨主机通信的基本过程如下图所示：

![](https://static001.geekbang.org/resource/image/e6/f0/e6827cecb75641d3c8838f2213543cf0.png)

Flannel UDP提供的是一个三层的Overlay Network，即，首先对发出端的IP包进行UDP封装，然后在接受端进行解封装拿到原始的IP包，进而把这个IP包转发给目标容器。**就行Flannel在不同宿主机上的两个容器之间打通了一条隧道，使得两个容器能够直接使用IP地址进行通信，而无需关系容器和宿主机的分布情况**。

> UDP模式的严重性能问题在于，相比于宿主机直接通信，这种模式多了flanneld的处理过程。这个过程使用TUN，仅仅在发送IP包的过程中，就需要经过三次用户态与内核态之间的数据拷贝，如下图：

！[](https://static001.geekbang.org/resource/image/84/8d/84caa6dc3f9dcdf8b88b56bd2e22138d.png)

1. 用户态的容器进程发出IP包经过docker0网桥进入内核态
2. IP包根据路由表进入TUN设备，从而回到用户态flanneld进程
3. flanneld进行UDP封包后重新进入内核态，将UDP包通过宿主机的eth0发送出去

UDP封装（Encapsulation）和解封装（Decapsulation）的过程是在用户态进行的。在Linux操作系统中，上下文的切换和用户态的操作代价比较高，这是UDP模式性能不好的主要原因。

**在系统级编程时，非常重要的一个优化原则，减少用户态和内核态的切换次数，并且把核心的处理逻辑放在内核态执行**。这也是VXLAN模式成为主流容器网络方案的原因。

## VXLAN模式
Virtual Exrensible LAN（虚拟可扩展局域网），是Linux内核本身就支持的一种网络虚拟化技术。所以**VXLAN可以完全在内核态实现上述封装和解封装的工作**，从而通过与上述相似的隧道机制，构建出覆盖网络（overlay network）。

VXLAN的设计思想：在现有三层网络之上，覆盖一层虚拟的、由内核VXLAN模块负责维护的二层网络，使得连接在这个VXLAN二层网络上的主机（虚拟机、容器）之间，可以像在同一个局域网那样自由通信。这些主机可以分布在不用的宿主机甚至不同的物理机房。

为了能够在二层网络上打通隧道，VXLAN会在宿主机上设置一个特殊的网络设备（VTEP，VXLAN Tunnel End Point隧道虚拟端点）作为隧道的两端。

> VTEP设备的作用，以flanneld进程很相似。只不过它进行封装和解封装的对象，是二层数据帧（Ethernet frame），而且整个工作流程在内核里完成。因为VXLAN本身就是在Linux内核中的一个模块。

基于VTEP设备进行隧道通信的流程如下图：

![](https://static001.geekbang.org/resource/image/ce/38/cefe6b99422fba768c53f0093947cd38.png)

在每台主机上有一个叫flannel.1的设备，这就是VXLAN所需要的VETP设备，它既有IP地址也有MAC地址。

假设C1的IP地址是`10.1.15.2`，要访问C2的IP地址是`10.1.16.3`。与UDP模式的流程类似。
1. 当c1发出请求后，这个目的地址是`10.1.16.3`的IP包，会先出现在docker0网桥
2. 然后被路由到本机flannel.1设备进行处理，也就是来到了隧道入口
> 为了能够将这个IP数据包封装并且发送到正确的宿主机，VXLAN需要找到这条隧道的出口，即目的宿主机的VETP设备，这些设备信息由每台宿主机的flanneld进行负责维护。

当node2启动并加入到Flannel网络之后，node1以及其他所有节点上的flannel的就会添加一条如下的路由规则：
```bash
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
...
10.1.16.0       10.1.16.0       255.255.255.0   UG    0      0        0 flannel.1

# 这条规则的意思，凡是发送给`10.11.16.0/4`网段的IP包，都需要经过flannel.1设备发出，并去，随后被发往的网关地址是`10.1.16.0`
```
每个宿主机上的VETP设备之间需要构建一个虚拟的二层网络，即通过二层数据帧进行通信。即源VETP设备将原始IP包加上MAC地址封装成一个二层数据正，发送到目的端VETP设备。

根据前面添加的路由记录，知道了目的VETP设备的IP地址，利用ARP表，根据三层IP地址查询对应的二层MAC地址。这里使用的ARP记录，也是flanneld进程在node2节点启动时，自动添加在node1上的。如下所示：
```bash
# 在 Node 1 上
$ ip neigh show dev flannel.1
10.1.16.0 lladdr 5e:f8:4f:00:e3:37 PERMANENT
# IP地址`10.1.16.0`对应的MAC地址是`5e:f8:4f:00:e3:37`
```
最新版的Flannel不依赖L3 MISS时间和ARP学习，而会在每台节点启动时，把它的VETP设备对应的ARP记录直接放在其他每台宿主机上。

有了MAC地址，Linux内核就可以开始二层封包工作，二层帧的格式如下：
![](https://static001.geekbang.org/resource/image/9a/01/9ab883eb52a438a76c4a54a9985db801.png)

上面封装的二层数据帧中的MAC地址是VETP的地址，对于宿主机网络来说没有实际意义，因此在Linux内核中需要把这个二层数据帧进一步封装成宿主机网络里的普通数据帧，这样就能通过宿主机eth0网卡进行传输。为了实现这个封装，Linux内核会在封装好的二层数据帧前加上一个特殊的VXLAN头，表示这是一个VXLAN要使用的数据帧。然后Linux内核会把这个数据帧封装进一个UDP包里发出去。

> VXLAN头里面有一个重要的标志VNI，这个是VTEP设备识别某个数据帧是不是应该归自己处理的重要标识。在Flannel中，VNI默认为1，这与宿主机上的VETP设备的名称flannel.1 匹配。

与UDP模式类似，在宿主机看来，只会认为是自己的flannel.1在向另一台宿主机的flannel.1发起一次普通的UDP链接。但是在这个UDP包中只包含了flannel.1的MAC地址，而不知道应该发给哪一台宿主机，所有flannel.1设备实际上要扮演网桥的角色，在二层网络进行UDP包转发。

> 在Linux内核里，网桥设备进行转发的依据，来自FDB（Forwarding Database）转发数据库。flanneld进程也需要负责维护这个flannel.1网桥对应的FDB信息，具体内容如下。

```bash
# 在 Node 1 上，使用“目的 VTEP 设备”的 MAC 地址进行查询
$ bridge fdb show flannel.1 | grep 5e:f8:4f:00:e3:37
5e:f8:4f:00:e3:37 dev flannel.1 dst 10.168.0.3 self permanent
# 发往5e:f8:4f:00:e3:37MAC地址的二层数据帧，应该通过flannel.1设备，发送到IP地址为10.168.0.3的主机，这就是node2的IP地址
```
然后就是一个正常的宿主机网络上的封包工作。

1. UDP包是一个四层数据包，所有Linux内核要在它的头部加上IP头（Outer IP Header），组成一个IP包。并且在IP头中填写通过FDB查询到的目的主机的IP地址。
2. Linux在这个IP包前面加上二层数据帧（Outer Ethernet Header），并把node2的MAC地址（node1的ARP表要学习的内容，无需Flannel维护）填写进去，封装后的数据帧如下所示。

![](https://static001.geekbang.org/resource/image/43/41/43f5ebb001145ecd896fd10fb27c5c41.png)

3. 封包完成后，node1上的flannel.1设备就可以把这个数据帧从node1的eth0网卡发出去，这个帧经过宿主机网络来到node2的eth0网卡。
4. node2的内核网络栈会发现这个数据帧里面的VXLAN头，VNI=1，内核进行拆包，根据数据帧的VNI值，把它交给node2的flannel.1设备。
5. flannel.1设备继续拆包，取出原始IP包，下面的步骤就是单机容器网络的处理流程。
6. 最终IP包进入c2容器的Network Namespace。


VXLAN 模式组建的覆盖网络，其实就是一个由不同宿主机上的 VTEP 设备，也就是 flannel.1 设备组成的**虚拟二层网络**。对于 VTEP 设备来说，它发出的“内部数据帧”就仿佛是一直在这个虚拟的二层网络上流动。这，也正是**覆盖网络**的含义。


# CNI
容器跨主机网络的两种实现方式：UDP和VXLAN，有以下共同点：
1. 用户的容器都是连接在docker0网桥上
2. 网络插件在宿主机上创建一个特殊的设备，docker0与这个设备之间通过IP转发（路由表）进行协作
   1. UDP模式创建的是TUN设备
   2. VXLAN模式创建的是VETP设备
3. 网络插件真正完成的是通过某种方法，把不同宿主机上的特殊设备连通，从而达到容器跨主机通信的目的

> 上述过程，也是kubernetes对容器网络的主要处理方式，kubernetes通过CNI接口，维护了一个单独的网桥（CNI网桥，cni0）来代替docker0。

以Flannel的VXLAN模式为例，在kubernetes环境下的工作方式如下图，只是把docker0换成cni0：

![](https://static001.geekbang.org/resource/image/7b/21/7b03e1604326b7cf355068754f47e821.png)

kubernetes为Flannel分配的子网范围是`10.244.0.0/16`，这个参数在部署的时候指定：
```bash
$ kubeadm init --pod-network-cidr=10.244.0.0/16

```
也可以在部署完成后，通过修改`kube-controller-manager`的配置文件来指定。

## 例子
假设有两台宿主机，两个pod，pod1需要访问pod2

宿主机|pod|IP地址
---|---|---|
node1|pod1|10.244.0.2
node2|pod2|10.244.1.3

pod1的eth0网卡也是通过Veth Pair的方式连接在node1的cni0网桥上，所有pod1中的IP包会经过cni0网桥出现在宿主机上。

node1上的路由表如下：
```bash
# 在 Node 1 上
$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
...
10.244.0.0      0.0.0.0         255.255.255.0   U     0      0        0 cni0
10.244.1.0      10.244.1.0      255.255.255.0   UG    0      0        0 flannel.1
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 docker0

```
1. IP包的目的IP地址是`10.244.1.3`，所以匹配第二条路由规则，这条规则指向本机的flannel.1设备进行处理。
2. flannel.1处理完成后，要将IP包转发到网关，正是“隧道”另一端的VETP设备，即node2的flannel.1设备
3. 接下来的处理流程和flannel VXLAN模式完全一样

**CNI网桥只是接管所有CNI插件负责的（即kubernetes创建的pod）。**

> 如果此时使用docker run单独启动一个容器，那么docker项目会把这个容器连接到docker0网桥上，所以这个容器的IP地址一定是属于docker0网桥的172.17.0.0/16网段。

kubernetes之所以要设置这样一个与docker0网桥几乎一样的CNI网桥，主要原因包括两个方面：
1. kubernetes项目并没有使用docker的网络模型（CNM），所以不希望，也不具备配置docker0网桥的能力
2. 这与kubernetes如何配置Pod，即INfra容器的Network Namespace密切相关

因为kubernetes创建一个Pod的第一步是创建并启动一个infra容器，用来hold住这个pod的Network Namespace。所以CNI的设计思想是：**kubernetes在启动Infra容器之后，就可以直接调用CNI网络组件，为这个Infra容器的Network Namespace配置符合预期的网络栈**。

> 一个Network Namespace的网络栈包括：网卡、回环设备、路由表、iptables。

## Network Namespace网络栈的配置
首先需要部署和运行CNI插件。在部署kubernetes的时候，有一个步骤是安装kubernetes-cni包 ，它的目的就是**在宿主机上安装CNI插件所需的基础可执行文件**。安装完成后，可以在宿主机`/opt/cni/bin/`目录下看到它们，如下所示：
```bash
# 这些CNI的基础可执行文件，按功能可以分为三类
$ ls -al /opt/cni/bin/
total 73088
# 第一类，Main插件，用来创建具体网络设备的二进制文件
# Flannel Weave等项目，都属于“网桥”类型的CNI插件，具体实现时会调用二进制文件bridge
-rwxr-xr-x 1 root root  3890407 Aug 17  2017 bridge     # 网桥设备
-rwxr-xr-x 1 root root  3475802 Aug 17  2017 ipvlan     
-rwxr-xr-x 1 root root  3026388 Aug 17  2017 loopback   # 回环设备
-rwxr-xr-x 1 root root  3520724 Aug 17  2017 macvlan
-rwxr-xr-x 1 root root  3877986 Aug 17  2017 ptp        # Veth Pair设备
-rwxr-xr-x 1 root root  3475750 Aug 17  2017 vlan

# 第二类，IPAM（IP Address Management）插件，负责分配IP堵住的二进制文件
-rwxr-xr-x 1 root root  9921982 Aug 17  2017 dhcp       # 向DHCP服务器发起请求
-rwxr-xr-x 1 root root  2991965 Aug 17  2017 host-local # 使用预先配置的IP地址段进行分配

# 第三类，CNI社区维护的内置CNI插件
-rwxr-xr-x 1 root root  2814104 Aug 17  2017 flannel    # 为Flannel项目提供的CNI插件
-rwxr-xr-x 1 root root  3470464 Aug 17  2017 portmap    # 通过iptables配置端口映射的二进制文件
-rwxr-xr-x 1 root root  2605279 Aug 17  2017 sample     # 
-rwxr-xr-x 1 root root  2808402 Aug 17  2017 tuning     # 通过sysctl调整网络设备参数的二进制文件

# bandwidth 使用Token Bucket Filter（TBF）来进行限流的二进制文件
```
从以上内容可以看出，实现一个kubernetes的容器网络方案，需要两部分工作，以Flannel为例：
1. **实现网络方案本身**，这部分需要编写flanneld进程里的主要逻辑，如创建和配置flannel.1设备，配置宿主机路由、配置ARP和FDB表里的信息
2. **实现该网络方案对应的CNI插件**，这部分主要是配置Infra容器里面的网络栈，并把它连接在CNI网桥上

> Flannel项目对应的CNI插件已经内置在kubernetes项目中。其他项目如Weave、Calico等，需要安装插件，把对应的CNI插件的可执行文件放在`/opt/cni/bin/`目录下。对于Weave、Calico这样的网络方案来说，他们的DaemonSet只需要挂载宿主机的`/opt/cni/bin/`,就可以实现插件可执行文件的安装。

在宿主机上安装flanneld（网络方案本身），flanneld启动后会在每一台宿主机上生成它对应的**CNI配置文件**（是一个ConfigMap），从而告诉Kubernetes，这个集群要使用Flannel作为容器网络方案。CNI配置文件内容如下：
```json
$ cat /etc/cni/net.d/10-flannel.conflist 
{
  "name": "cbr0",
  "plugins": [
    {
      "type": "flannel",
      "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }
    },
    {
      "type": "portmap",
      "capabilities": {
        "portMappings": true
      }
    }
  ]
}

```
在kubernetes中，处理容器网络相关的逻辑并不会在kubelet主干代码里执行，而是会在具体的CRI实现里完成。对于Docker项目来说，它的CRI实现是dockershim，在kubelet的代码中可以找到。所以dockershim会加载上述CNI配置文件。

> 目前，kubernetes不支持多个CNI插件混用，如果在CNI配置目录`/etc/cni/net.d`里面放置了多个CNI配置文件的话，dockershim只会加载按照字母顺序排序的第一个插件。不过CNI运行在一个CNI配置文件中，通过plugins字段，定义多个插件进行协作。上面的例子中，plugins字段指定了flannel和portmap两个插件。

dockershim会把CNI配置文件加载起来，并且把列表里的第一个插件、flannel插件设置为默认插件，在后面的执行过程中，flannel和portmap插件会按照定义顺序被调用，从而依次完成“配置容器网络”和“配置端口映射”这两个操作。

## CNI插件工作原理
当kubelet组件需要创建Pod的时候，第一个创建的一定是Infra容器。
1. dockershim调用Docker API创建并启动Infra容器
2. 执行SetUpPod方法，为CNI插件准备参数
3. 调用CNI插件（`/opt/cni/bin/flannel`）为Infra容器配置网络,

调用CNI插件需要为它准备的参数分为2部分：
1. 设置环境变量
2. dockershim从CNI配置文件里加载到的、默认插件的配置信息

### 设置环境变量
由dockershim设置的一组CNI环境变量，其中最重要的环境变量是是`CNI_COMMAND`，它的取值只有两种ADD/DEL。ADD和DEl操作是CNI插件唯一需要实现的两个方法。
- ADD操作的含义：把容器添加到CNI网络里
- DEL操作的含义：把容器从CNI网络里移除

> 对于网桥类型的CNI插件来说，这两个操作意味着把容器以Veth Pair的方式插到CNI网桥上或者从CNI网桥上拔出。

#### ADD操作
CNI的ADD操作需要的参数包括：
1. 容器里网卡的名字eth0（CNI_IFNAME）
2. Pod的Network Namespace文件的路径（CNI_NETNS）
3. 容器的ID（CNI_CONTAINERID）

这些参数都属于上述环境变量里的内容。其中，Pod（Infra容器）的Network Namespace文件的路径是`/proc/<容器进程的PID>/ns/net`。在CNI环境变量里，还有一个叫作CNI_ARGS的参数，通过这个参数，CRI实现（如dockershim）就可以以key-value的格式，传递自定义信息给网络插件，这是用户自定义CNI协议的一个重要方法。

### dockershim从CNI配置文件里加载到的、默认插件的配置信息
配置信息在CNI中被叫作Network Configuration，dockershim会把Network Configuration以JSON数据的格式，通过标准输入（stdin）的方式传递给Flannel CNI插件。

有了这两部分参数，Flannel CNI插件实现ADD操作的过程就很简单，需要主要的是，在Flannel的CNI配置文件（`/etc/cni/net.d/10-flannel.conflist`）里有一个delegate字段：
```json
...
     "delegate": {
        "hairpinMode": true,
        "isDefaultGateway": true
      }

```
Delegate字段的意思是，CNI插件并不会自己做事，而是调用Delegate指定的某种CNI内置插件来完成。对于Flannel来说，它调用的Delegate插件，就是CNI bridge插件。

> 所以说，dockershim对Flannel CNI插件的调用，其实只是走个过程，Flannel CNI插件唯一需要做的，就是对dockershim传阿里的Network Configuration进行补充，如将Delegate的Type字段设置为bridge，将Delegate的IPAM字段设置为host-local等。

经过Flannel CNI插件的补充后，完整的Delegate字段如下：
```json
{
    "hairpinMode":true,
    "ipMasq":false,
    "ipam":{
        "routes":[
            {
                "dst":"10.244.0.0/16"
            }
        ],
        "subnet":"10.244.1.0/24",
        "type":"host-local"
    },
    "isDefaultGateway":true,
    "isGateway":true,
    "mtu":1410,
    "name":"cbr0",
    "type":"bridge"
}

```

其中，ipam字段里的信息，比如`10.244.1.0/24`,读取自Flannel在宿主机上生成的Flannel配置文件，即宿主机上`/run/flannel/subnet.env`文件。接下来Flannel CNI插件就会调用CNI bridge插件，也就是执行`/opt/cni/bin/bridge`二进制文件。

这一次调用CNI bridge插件需要两部分参数的第一部分，就是CNI环境变量，并没有变化，所以它里面的CNI_COMMAND参数的值还是“ADD”。

第二部分Network Configuration正式上面补充好的Delegate字段。Flannel CNI插件会把Delegate字段的内容以标准输入的方式传递给CNI bridge插件。Flannel CNI插件还会把Delegate字段以JSON文件的方式，保存在`/var/lib/cni/flannel`目录下，这是给删除容器调用DEL操作时使用。

有了两部分参数，CNI bridge插件就可以代表Flannel，将容器加入到CNI网络里，这一步与容器Network Namespace密切相关。

1. 首先，CNI bridge插件会在宿主机上检查CNI网桥是否存在。如果没有的话，那就创建它。相当于在宿主机上执行如下操作：

```bash
# 在宿主机上
$ ip link add cni0 type bridge
$ ip link set cni0 up
```
2. 接下来，CNI bridge插件或通过Infra容器的Network Namespace文件，进入到这个Network Namespace里面，然后创建一对Veth Pair设备。
3. 然后，把这个Veth Pair的其中一端，移动到宿主机上，相当于在容器里执行如下命令：

```bash
# 在容器里

# 创建一对 Veth Pair 设备。其中一个叫作 eth0，另一个叫作 vethb4963f3
$ ip link add eth0 type veth peer name vethb4963f3

# 启动 eth0 设备
$ ip link set eth0 up 

# 将 Veth Pair 设备的另一端（也就是 vethb4963f3 设备）放到宿主机（也就是 Host Namespace）里
$ ip link set vethb4963f3 netns $HOST_NS

# 通过 Host Namespace，启动宿主机上的 vethb4963f3 设备
$ ip netns exec $HOST_NS ip link set vethb4963f3 up 

```

4. CNI bridge 插件就可以把vethb4963f3设备连接到CNI网桥上。这相当于在宿主机上执行如下命令：
```bash
# 在宿主机上
$ ip link set vethb4963f3 master cni0

```
在将vethb4963f3设备连接在CNI网桥之后，CNI bridge插件还会为它设置Hairpin Mode（发夹模式），因为在默认情况下，网桥设备是不允许一个数据包从一个端口进来后再从这个端口发出去。开启发夹模式取消这个限制。**这个特性主要用在容器需要通过NAT（端口映射）的方式，自己访问自己的场景**。这样这个集群中的Pod才可以通过它自己的Service访问到自己。

5. CNI bridge插件会调用CNI ipam插件，从ipam.subnet字段规定的网段里为容器分配一个可用的IP地址。然后，CNI bridge插件就会把这个IP地址添加到容器的eth0网卡上，同时为容器设置默认路由，这相当与执行如下命令：

```bash
# 在容器里
$ ip addr add 10.244.0.2/24 dev eth0
$ ip route add default via 10.244.0.1 dev eth0

```
6. 最后，CNI bridge插件会为CNI网桥添加IP地址，相当于在宿主机上执行：

```bash
# 在宿主机上
$ ip addr add 10.244.0.1/24 dev cni0

```
执行完上述操作后，CNI插件会把容器的IP地址等新返回给dockershim，然后被kubelet添加到POd的status字段。至此，CNI插件的ADD方法就宣告结束，接下来的流程就是容器跨主机通信的过程。


# 总结
kubernetes CNI网络模型：
1. 所有容器都可以直接使用IP地址与其他容器通信，无需使用NAT
2. 所有宿主机都可以直接使用IP地址与所有容器通信，而无需使用NAT，反之亦然
3. 容器自己”看到“的自己的IP地址，和别人（宿主机或容器）看到的地址是完全一样的

容器和容器通，容器和宿主机通，并且直接基于容器和宿主机的IP地址来进行通信。



