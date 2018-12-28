# 容器 & Docker & 虚拟机
- Container(容器)是一种轻量级的虚拟化技术，它不需要模拟硬件创建虚拟机。在Linux系统里面，使用到Linux kernel的cgroups，namespace(ipc，network， user，pid，mount），capability等用于隔离运行环境和资源限制的技术，我们称之为容器。

容器技术早就出现。

非Linux容器技术 | Linux容器技术
---|---
Solaris Zones | Linux-Vserver
BSD jails  | OpenVZ
 ||FreeVPS

虽然这些技术都已经成熟，但是这些解决方案还没有将它们的容器支持集成到主流 Linux 内核。总的来说，容器不等同于Docker，容器更不是虚拟机。

>LXC项目由一个 Linux 内核补丁和一些 userspace 工具组成，它提供一套简化的工具来维护容器，用于虚拟环境的环境隔离、资源限制以及权限控制。LXC有点类似chroot，但是它比chroot提供了更多的隔离性。

- Docker最初目标是做一个特殊的LXC的开源系统，最后慢慢演变为它自己的一套容器运行时环境。**Docker基于Linux kernel的CGroups，Namespace，UnionFileSystem等技术封装成一种自定义的容器格式，用于提供一整套虚拟运行环境**。毫无疑问，近些年来Docker已经成为了容器技术的代名词。

![image](http://p3.pstatp.com/large/pgc-image/15268821012845197bffa5b)

# Docker基础
## Docker Engine
Docker提供了一个打包和运行应用的隔离环境，称之为容器，Docker的隔离和安全特性允许你在一个主机同时运行多个容器，而且它并不像虚拟机那样重量级，**容器都是基于宿主机的内核运行的**，它是==轻量的==，不管你运行的是ubuntu, debian还是其他Linux系统，用的内核都是宿主机内核。Docker提供了工具和平台来管理容器，而Docker Engine则是一个提供了大部分功能组件的CS架构的应用，如架构图所示，Docker Engine负责管理**镜像**，**容器**，**网络**以及**数据卷**等。


## Docker架构
Docker更详细的架构如图所示，采用CS架构，client通过RESTFUL API发送docker命令到docker daemon进程，docker daemon进程执行镜像编译，容器启停以及分发，数据卷管理等，一个client可以与多个docker daemon通信。

![image](http://p9.pstatp.com/large/pgc-image/1526882101439c544302c89)


- Docker Daemon：Docker后台进程，用于管理镜像，容器以及数据卷。
- Docker Client：用于与Docker Daemon交互。
- Docker Registry：用于存储Docker镜像，类似github，公共的Registry有Docker Hub和Docker Cloud。
- Images：镜像是用于创建容器的一种只读模板。镜像通常基于一个基础镜像，在此基础上安装额外的软件。比如你的nginx镜像可能基于debian然后安装nginx并添加配置，你可以从Docker Hub上拉取已有的镜像或者自己通过Dockerfile来编译一个镜像。
- Containers：容器是镜像的一个可运行示例，我们可通过Docker client或者API来创建，启停或者删除容器。默认情况下，容器与宿主机以及其他容器已经隔离，当然你可以控制隔离容器的网络或者存储的方式。
- Services：服务是docker swarm引入的概念，可以用于在多宿主机之间伸缩容器数目，支持负载均衡以及服务路由功能。

## Docker底层技术概览
通过下面命令运行一个debian容器，attach到一个本机的命令行并运行/bin/bash。


```
docker run -i -t debian /bin/bash
```

这个命令背后都做了什么？

1. 如果本机没有debian镜像，则会从你配置的Registry里面拉取一个debian的latest版本的镜像，跟你运行了docker pull debian效果一样。
2. 创建容器。跟运行docker create一样。
3. 给容器分配一个读写文件系统作为该容器的final layer，容器可以在它的文件系统创建和修改文件。
4. Docker为容器创建了一套网络接口，给容器分配一个ip。默认情况下，容器可以通过默认网络连通到外部网络。
5. Docker启动容器并执行 /bin/bash。因为启动时指定了-i -t参数，容器是以交互模式运行且attach到本地终端，我们可以在终端上输入命令并看到输出。
6. 运行exit可以退出容器，但是此时容器并没有被删除，我们可以再次运行它或者删除它。

可以发现，容器的内核版本是跟宿主机一样的，不同的是容器的主机名是独立的，它默认用容器ID做主机名。

我们运行ps -ef可以发现容器进程是隔离的，容器里面看不到宿主机的进程，而且它自己有PID为1的进程。

此外，网络也是隔离的，它有独立于宿主机的IP。

文件系统也是隔离的，容器有自己的系统和软件目录，修改容器内的文件并不影响宿主机对应目录的文件。


```
root@stretch:/home/vagrant# uname -r4.9.0-6-amd64
root@stretch:/home/vagrant# docker run -it --name demo alpine /bin/ash/ 
# uname -r ## 容器内4.9.0-6-amd64/ 
# ps -efPID USER TIME COMMAND 1 root 0:00 /bin/ash 
7 root 0:00 ps -ef / 
# ip a1
: 
lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN qlen 1 link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00 

inet 127.0.0.1/8 scope host lo valid_lft forever preferred_lft 

forever6: eth0@if7: <BROADCAST,MULTICAST,UP,LOWER_UP,M-DOWN> mtu 1500 qdisc noqueue state UP link/ether 02:42:ac:11:00:02 brd ff:ff:ff:ff:ff:ff 

inet 172.17.0.2/16 brd 172.17.255.255 scope global eth0 valid_lft forever preferred_lft forever
```

这些隔离机制并不是Docker新开发的技术，而是依托Linux kernel以及一些已有的技术实现的，主要包括：
- **Linux Namespaces**(Linux2.6.24后引入)：命名空间用于进程(PID)、网络(NET)、挂载点(MNT)、UTS、IPC等隔离。
- **Linux Control Groups(CGroups)**：用于限制容器使用的资源，包括内存，CPU等。
- **Union File Systems**：UnionFS把多个目录结合成一个目录，对外使用，最上层目录为读写层(通常只有1个)，下面可以有一个或多个只读层，见容器和镜像分层图。Docker支持OverlayFS，AUFS、DeviceMapper、btrfs等联合文件系统。
- **Container Format**: Docker Engine组合Namespaces，CGroups以及UnionFS包装为一个容器格式，默认格式为libcontainer，后续可能会加入BSD Jails 或 Solaris Zones容器格式的支持。


# 底层技术
## Namespace
Namespaces用于**环境隔离**，Linux kernel支持的Namespace包括：
namespace|系统调用参数|隔离内容
---|---|---
UTS|CLONE_NEWUTS|主机名与域名
IPC|CLONE_NEWIPC|信号量，消息队列和共享内存
PID|CLONE_NEWPID|进程编号
Network|CLONE_NEWNET|网络设备，网络栈，端口等
Mount|CLONE_NEWNS|挂载点（文件系统）
User|CLONE_NEWUSER|用户和用户组
- CGROUP等

Linux内核实现namespace的主要目的之一是实现轻量级虚拟化（容器）服务。在同一个namespace下的进程可以感知彼此的变化，而对外界进程一无所知。这样就可以让容器中的进程产生错觉，仿佛自己置身于一个独立的系统环境中，以达到独立和隔离的目的。

查看一个进程的各Namespace命令如下：

```
[root@tdh-18 ~]# ls -ls /proc/self/ns/
total 0
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 ipc -> ipc:[4026531839]
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 mnt -> mnt:[4026531840]
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 net -> net:[4026531956]
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 pid -> pid:[4026531836]
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 user -> user:[4026531837]
0 lrwxrwxrwx. 1 root root 0 Jul  6 13:50 uts -> uts:[4026531838]
```
### PID Namespace
在容器中，有自己的Pid namespace，因此我们看到的只有PID为1的初始进程以及它的子进程，而宿主机的其他进程容器内是看不到的。

> 通常来说，Linux启动后它会先启动一个PID为1的进程，这是系统进程树的根进程，根进程会接着创建子进程来初始化系统服务。

PID namespace允许在新的namespace创建一棵新的进程树，它可以有自己的PID为1的进程。在PID namespace的隔离下，子进程名字空间无法知道父进程名字空间的进程，如在Docker容器中无法看到宿主机的进程，而父进程名字空间可以看到子进程名字空间的所有进程。如图所示：
![image](http://p99.pstatp.com/large/pgc-image/1526882101287d928f19aac)

Linux内核加入PID Namespace后，对pid结构进行了修改，新增的upid结构用于跟踪namespace和pid。


```
// 加入PID Namespace之前的pid结构
 struct pid {
 atomic_t count; /* reference counter */
 int nr; /* the pid value */
 struct hlist_node pid_chain; /* hash chain */
 ...
};

// 加入PID Namespace之后的pid结构
struct upid {
 int nr; /* moved from struct pid */
 struct pid_namespace *ns; 
 struct hlist_node pid_chain; /* moved from struct pid */
};

struct pid {
 ...
 int level; /* the number of upids */
 struct upid numbers[0];
};
```
可以通过unshare测试下PID namespace，可以看到新的bash进程它的pid namespace与父进程的不同了，而且它的pid是1。

### NS Namespace
NS Namespace用于隔离挂载点，不同NS Namespace的挂载点互不影响。创建一个新的Mount Namespace效果有点类似chroot，不过它隔离的比chroot更加完全。

> 这是历史上的第一个Linux Namespace，由此得到了 NS 这个名字而不是用的 Mount。

- 在最初的NS Namespace版本中，挂载点是完全隔离的。初始状态下，子进程看到的挂载点与父进程是一样的。
- 在新的Namespace中，子进程可以随意mount/umount任何目录，而不会影响到父Namespace。

使用NS Namespace完全隔离挂载点初衷很好，但是也带来了某些情况下不方便，比如我们新加了一块磁盘，如果完全隔离则需要在所有的Namespace中都挂载一遍。为此，Linux在2.6.15版本中加入了一个shared subtree特性，通过指定Propagation来确定挂载事件如何传播。
- 通过指定MS_SHARED来允许在一个peer group(子namespace 和父namespace就属于同一个组)共享挂载点，mount/umount事件会传播到peer group成员中。
- 使用MS_PRIVATE不共享挂载点和传播挂载事件。
- 其他还有MS_SLAVE和NS_UNBINDABLE等选项。

可以通过查看cat /proc/self/mountinfo来看挂载点信息，若没有传播参数则为MS_PRIVATE的选项。

![image](http://p1.pstatp.com/large/pgc-image/1526882102003a57680e549)

例如,在初始namespace有两个挂载点:
1. 通过mount --make-shared /dev/sda1 /mntS设置/mntS为shared类型，
2. mount --make-private /dev/sda1 /mntP设置/mntP为private类型。

当使用unshare -m bash新建一个namespace并在它们下面挂载子目录时，可以发现:
- /mntS下面的子目录mount/umount事件会传播到父namespace
- 而/mntP则不会

在前面例子Pid namespace隔离后，我们在新的名字空间执行 ps -ef可以看到宿主机进程，++这是因为ps命令是从 /proc 文件系统读取的数据++，而文件系统我们还没有隔离，为此，我们需要在新的 NS Namespace重新挂载 proc 文件系统来模拟类似Docker容器的功能。


```
root@stretch:/home/vagrant# unshare --pid --fork --mount-proc bash
root@stretch:/home/vagrant# ps -ef
UID PID PPID C STIME TTY TIME CMD
root 1 0 0 15:36 pts/1 00:00:00 bash
root 2 1 0 15:36 pts/1 00:00:00 ps -ef
```
可以看到，隔离了NS namespace并重新挂载了proc后，ps命令只能看到2个进程了，跟我们在Docker容器中看到的一致。

### NET Namespace
Docker容器中另一个重要特性是网络独立(++之所以不用隔离一词是因为容器的网络还是要借助宿主机的网络来通信的++)，使用到Linux 的 NET Namespace以及veth。

**veth主要的目的是为了跨NET namespace之间提供一种类似于Linux进程间通信的技术，所以veth总是成对出现，如下面的veth0和veth1**。它们位于不同的NET namespace中，在veth设备任意一端接收到的数据，都会从另一端发送出去。

veth实现了不同namespace的网络数据传输。

![image](http://p1.pstatp.com/large/pgc-image/1526882102037b2146afc68)

1. 在Docker中，宿主机的veth端会桥接到网桥中，接收到容器中的veth端发过来的数据后会经由网桥docker0再转发到宿主机网卡eth0，最终通过eth0发送数据。
2. 在发送数据前，需要经过iptables MASQUERADE规则将源地址改成宿主机ip，这样才能接收到响应数据包。
3. 宿主机网卡接收到的数据会通过iptables DNAT根据端口号修改目的地址和端口为容器的ip和端口，然后根据路由规则发送到网桥docker0中，并最终由网桥docker0发送到对应的容器中。

Docker里面网络模式分为bridge，host，overlay等几种模式，
- 默认是采用bridge模式网络如图所示。
- 如果使用host模式，则不隔离直接使用宿主机网络。
- overlay网络则是更加高级的模式，可以实现跨主机的容器通信。


### USER Namespace
user namespace用于隔离用户和组信息，在不同的namespace中用户可以有相同的 UID 和 GID，它们之间互相不影响。

父子namespace之间可以进行用户映射，如父namespace(宿主机)的普通用户映射到子namespace(容器)的root用户，以减少子namespace的root用户操作父namespace的风险。

创建新的user namespace之后第一步就是设置好user和group的映射关系。**这个映射通过设置/proc/PID/uid_map(gid_map)实现**，格式如下

```
ID-inside-ns ID-outside-ns length
```
- ID-inside-ns是容器内的uid/gid
- ID-outside-ns则是容器外映射的真实uid/gid

比如0 1000 1,表示将真实的uid=1000映射为容器内的uid=0，length为映射的范围。

不是所有的进程都能随便修改映射文件的，必须同时具备如下条件：

1. 修改映射文件的进程必须有PID进程所在user namespace的CAP_SETUID/CAP_SETGID权限。
2. 修改映射文件的进程必须是跟PID在同一个user namespace或者PID的父namespace。
3. 映射文件uid_map和gid_map只能写入一次，再次写入会报错。


> docker1.10之后的版本可以通过在docker daemon启动时加上--userns-remap=[USERNAME]来实现USER Namespace的隔离。

> 我们指定了username=ssj启动dockerd，查看subuid文件可以发现ssj映射的uid范围是165536到165536+65536= 231072，而且在docker目录下面对应ssj有一个独立的目录165536.165536存在。


```
root@stretch:/home/vagrant# cat /etc/subuid
vagrant:100000:65536
ssj:165536:65536

root@stretch:/home/vagrant# ls /var/lib/docker/165536.165536/
builder/ containerd/ containers/ image/ network/ ...
```

运行docker images -a等命令可以发现在启用user namespace之前的镜像都看不到了。此时只能看到在新的user namespace里面创建的docker镜像和容器。而此时我们创建一个测试容器，可以在容器外看到容器进程的uid_map已经设置为ssj，这样容器中的root用户映射到宿主机就是ssj这个用户了，此时如果要删除我们挂载的/bin目录中的文件，会提示没有权限，增强了安全性。

dockerd 启动时加了 --userns-remap=ssj
```
root@stretch:/home/vagrant# docker run -it -v /bin:/host/bin --name demo alpine /bin/ash
# rm /host/bin/which 
rm: remove '/host/bin/which'? y
rm: can't remove '/host/bin/which': Permission denied
```

宿主机查看容器进程uid_map文件
```
root@stretch:/home/vagrant# CPID=`ps -ef|grep '/bin/ash'|awk '{printf $2}'`
root@stretch:/home/vagrant# cat /proc/$CPID/uid_map
 0 165536 65536
```

### UTS namespace
UTS namespace用于隔离主机名等。可以看到在新的uts namespace修改主机名并不影响原namespace的主机名。


```
root@stretch:/home/vagrant# unshare --uts --fork bash
root@stretch:/home/vagrant# hostname
stretch
root@stretch:/home/vagrant# hostname modified
root@stretch:/home/vagrant# hostname
modified
root@stretch:/home/vagrant# exit
root@stretch:/home/vagrant# hostname
stretch
```
### IPC Namespace
IPC Namespace用于隔离IPC消息队列等。可以看到，新老ipc namespace的消息队列互不影响。


```
root@stretch:/home/vagrant# ipcmk -Q
Message queue id: 0
root@stretch:/home/vagrant# ipcs -q

------ Message Queues --------
key msqid owner perms used-bytes messages 
0x26c3371c 0 root 644 0 0 

root@stretch:/home/vagrant# unshare --ipc --fork bash
root@stretch:/home/vagrant# ipcs -q

------ Message Queues --------
key msqid owner perms used-bytes messages
```

### CGROUP Namespace

CGROUP Namespace是Linux4.6以后才支持的新namespace。

容器技术使用namespace和cgroup实现环境隔离和资源限制，但是**对于cgroup本身并没有隔离**。

- 没有cgroup namespace前，容器中一旦挂载cgroup文件系统，便可以修改整全局的cgroup配置。
- 有了cgroup namespace后，每个namespace中的进程都有自己的cgroup文件系统视图，增强了安全性，同时也让容器迁移更加方便。

## CGroups
Linux CGroups用于资源限制，包括限制CPU、内存、blkio以及网络等。

通过工具cgroup-bin (sudo apt-get install cgroup-bin)可以创建CGroup并进入该CGroup执行命令。


```
root@stretch:/home/vagrant# cgcreate -a vagrant -g cpu:cg1
root@stretch:/home/vagrant# ls /sys/fs/cgroup/cpu/cg1/
cgroup.clone_children cpu.cfs_period_us cpu.shares cpuacct.stat cpuacct.usage_all cpuacct.usage_percpu_sys cpuacct.usage_sys notify_on_release
cgroup.procs cpu.cfs_quota_us cpu.stat cpuacct.usage cpuacct.usage_percpu cpuacct.usage_percpu_user cpuacct.usage_user tasks
```

cpu.cfs_period_us 和 cpu.cfs_quota_us，它们分别用来限制该组中的所有进程在单位时间里可以使用的 cpu 时间，这里的 cfs(Completely Fair Scheduler) 是完全公平调度器的意思。
- cpu.cfs_period_us是时间周期，默认为100000，即100毫秒。
- 而cpu.cfs_quota_us是在时间周期内可以使用的时间，默认为-1即无限制。
- cpu.shares用于限制cpu使用的，它用于控制各个组之间的配额。

> 比如组cg1的cpu.shares为1024，组cg2的cpu.shares也是1024，如果都有进程在运行则它们都可以使用最多50%的限额。如果cg2组内进程比较空闲，那么cg1组可以将使用几乎整个cpu，tasks存储的是该组里面的进程ID。++(注：debian8默认没有cfs和memory cgroup支持，需要重新编译内核及修改启动参数，debian9默认已经支持)++

我们先在默认的分组里面运行一个死循环程序loop.py，因为默认分组/sys/fs/cgroup/cpu/cpu.cfs_period_us和cfs_quota_us是默认值，所以是没有限制 cpu 使用的。可以发现1个cpu us立马接近100%了。


```
# loop.py
while True: pass
```

设置cg1组的cfs_quota_us位50000，即表示该组内进程最多使用50%的cpu时间，运行cgexec命令进入cg1的cpu组，然后运行loop.py，可以发现cpu us在50%以内了，此时也可以在tasks文件中看到我们刚刚cgexec创建的进程ID。


```
root@stretch:/home/vagrant# echo 50000 > /sys/fs/cgroup/cpu/cg1/cpu.cfs_quota_us
root@stretch:/home/vagrant# cgexec -g cpu:cg1 /bin/bash
```

Docker里面要限制内存和CPU使用，可以在启动时指定相关参数即可。

- 限制cpu使用率，加cpu-period和cpu-quota参数，限制执行的cpu核，加--cpuset-cpus参数。
- 限制内存使用，加--memory参数。

可以看到在 /sys/fs/cgroup/cpu/docker/目录下有个以containerid为名的分组，该分组下面的 cpu.cfs_period_us和cpu.cfs_quota_us的值就是我们在启动容器时指定的值。


```
root@stretch:/home/vagrant# docker run -i -t --cpu-period=100000 --cpu-quota=50000 --memory=512000000 alpine /bin/ash
```

##  Capabilities
我们在启动容器时会时常看到这样的参数--cap-add=NET_ADMIN，这是用到了Linux的capability特性。capability是为了实现更精细化的权限控制而加入的。

> 我们以前熟知通过设置文件的SUID位，这样非root用户的可执行文件运行后的euid会成为文件的拥有者ID，比如passwd命令运行起来后有root权限，有SUID权限的可执行文件如果存在漏洞会有安全风险。(查看文件的capability的命令为 filecap -a，而查看进程capability的命令为 pscap -a，pscap和filecap工具需要安装 libcap-ng-utils这个包)。

对于capability，可以看一个简单的例子便于理解。如Debian系统中自带的ping工具，它是有设置SUID位的。这里拷贝ping重命名为anotherping，anotherping的SUID位没有设置，运行会提示权限错误。这里，我们只要将其加上 cap_net_raw权限即可，不需要设置SUID位那么大的权限。


```
vagrant@stretch:~$ ls -ls /bin/ping
60 -rwsr-xr-x 1 root root 61240 Nov 10 2016 /bin/ping
vagrant@stretch:~$ cp /bin/ping anotherping
vagrant@stretch:~$ ls -ls anotherping 
60 -rwxr-xr-x 1 vagrant vagrant 61240 May 19 10:18 anotherping
vagrant@stretch:~$ ./anotherping -c1 yue.uu.163.com
ping: socket: Operation not permitted
vagrant@stretch:~$ sudo setcap cap_net_raw+ep ./anotherping 
vagrant@stretch:~$ ./anotherping -c1 yue.uu.163.com
PING yue.uu.163.com (59.111.137.252) 56(84) bytes of data.
64 bytes from 59.111.137.252 (59.111.137.252): icmp_seq=1 ttl=63 time=53.9 ms

--- yue.uu.163.com ping statistics ---
1 packets transmitted, 1 received, 0% packet loss, time 0ms
rtt min/avg/max/mdev = 53.919/53.919/53.919/0.000 ms
```
## Union File System
UnionFS(联合文件系统)简单来说就是**支持将不同的目录挂载到同一个目录中的技术**。

Docker支持的UnionFS包括:
- OverlayFS
- AUFS
- devicemapper
- vfs
- btrfs等

查看UnionFS版本可以用docker info查看对应输出中的Storage项即可，早期的Docker版本用AUFS和devicemapper居多，新版本Docker在Linux3.18之后版本基本默认用OverlayFS。

OverlayFS与早期用过的AUFS类似，不过它比AUFS更简单，读写性能更好，在docker-ce18.03版本中默认用的存储驱动是overlay2，老版本overlay官方已经不推荐使用。

它将两个目录upperdir和lowdir联合挂载到一个merged目录，提供统一视图。
- 其中upperdir是可读写层，对容器修改写入在该目录中，它也会隐藏lowerdir中相同的文件。
- 而lowdir是只读层，Docker镜像在这层。

### image

在看Docker镜像和容器存储结构前，可以先简单操作下OverlayFS看下基本概念。创建了lowerdir和upperdir两个目录，然后用overlayfs挂载到merged目录，这样在merged目录可以看到两个目录的所有文件 both.txt 和only.txt。

其中upperdir是可读写的，而lowerdir只读。通过merged目录来操作文件可以发现：

1. 读取文件时，如果upperdir不存在该文件，则会从lowerdir直接读取。
2. 修改文件时并不影响lowerdir中的文件，因为它是只读的。
3. 如果修改的文件在upperdir不存在，则会从lowerdir拷贝到upperdir，然后在upperdir里面修改该文件，并不影响lowerdir目录的文件。
4. 删除文件则是将upperdir中将对应文件设置成了c类型，即字符设备类型来隐藏已经删除的文件(与AUFS创建一个whiteout文件略有不同)。



```
root@stretch:/home/vagrant/overlaytest# tree -a
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
|-- upperdir
| `-- both.txt
`-- workdir
 `-- work

5 directories, 3 files


root@stretch:/home/vagrant/overlaytest# mount -t overlay overlay -olowerdir=./lowerdir,upperdir=./upperdir,workdir=./workdir ./merged
root@stretch:/home/vagrant/overlaytest# tree
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
| |-- both.txt
| `-- only.txt
|-- upperdir
| `-- both.txt
`-- workdir
 `-- work

5 directories, 5 files


root@stretch:/home/vagrant/overlaytest# tree -a
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
| |-- both.txt
| `-- only.txt
|-- upperdir
| `-- both.txt
`-- workdir
 `-- work

5 directories, 5 files


root@stretch:/home/vagrant/overlaytest# echo "modified both" > merged/both.txt 
root@stretch:/home/vagrant/overlaytest# cat upperdir/both.txt 
modified both
root@stretch:/home/vagrant/overlaytest# cat lowerdir/both.txt 
lower both.txt
root@stretch:/home/vagrant/overlaytest# echo "modified only" > merged/only.txt 
root@stretch:/home/vagrant/overlaytest# tree
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
| |-- both.txt
| `-- only.txt
|-- upperdir
| |-- both.txt
| `-- only.txt
`-- workdir
 `-- work

5 directories, 6 files


root@stretch:/home/vagrant/overlaytest# cat upperdir/only.txt 
modified only
root@stretch:/home/vagrant/overlaytest# cat lowerdir/only.txt 
lower only.txt
root@stretch:/home/vagrant/overlaytest# tree -a
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
| |-- both.txt
| `-- only.txt
|-- upperdir
| |-- both.txt
| `-- only.txt
`-- workdir
 `-- work

5 directories, 6 files


root@stretch:/home/vagrant/overlaytest# rm merged/both.txt 
root@stretch:/home/vagrant/overlaytest# tree -a
.
|-- lowerdir
| |-- both.txt
| `-- only.txt
|-- merged
| `-- only.txt
|-- upperdir
| |-- both.txt
| `-- only.txt
`-- workdir
 `-- work
root@stretch:/home/vagrant/overlaytest# ls -ls upperdir/both.txt 
0 c--------- 1 root root 0, 0 May 19 02:31 upperdir/both.txt
```
回到Docker里面，拉取一个nginx镜像，有三层镜像，可以看到在overlay2对应每一层都有个目录(注意，这个目录名跟镜像层名从docker1.10版本后名字已经不对应了)，另外的l目录是指向镜像层的软链接。
- 最底层存储的是基础镜像debian/alpine，
- 上一层是安装了nginx增加的可执行文件和配置文件，
- 最上层是链接/dev/stdout到nginx日志文件。

每个子目录下面：
1. diff目录用于存储镜像内容
2. work目录是OverlayFS内部使用的
3. link文件存储的是该镜像层对应的短名称
4. lower文件存储的是下一层的短名称


```
root@stretch:/home/vagrant# docker pull nginx
Using default tag: latest
latest: Pulling from library/nginx
f2aa67a397c4: Pull complete 
3c091c23e29d: Pull complete 
4a99993b8636: Pull complete 
Digest: sha256:0fb320e2a1b1620b4905facb3447e3d84ad36da0b2c8aa8fe3a5a81d1187b884
Status: Downloaded newer image for nginx:latest

root@stretch:/home/vagrant# ls -ls /var/lib/docker/overlay2/
total 16
4 drwx------ 4 root root 4096 May 19 04:17 09495e5085bced25e8017f558147f82e61b012a8f632a0b6aac363462b1db8b0
4 drwx------ 3 root root 4096 May 19 04:17 8af95287a343b26e9c3dd679258773880e7bdbbe914198ba63a8ed1b4c5f5554
4 drwx------ 4 root root 4096 May 19 04:17 f311565fe9436eb8606f846e1f73f38287841773e8d041933a41259fe6f96afe
4 drwx------ 2 root root 4096 May 19 04:17 l

root@stretch:/var/lib/docker/overlay2# ls 09495e5085bced25e8017f558147f82e61b012a8f632a0b6aac363462b1db8b0/
diff link lower work
```

三层中 f311是最顶层，下面分别是0949和8af9这两层。


```
root@stretch:/var/lib/docker/overlay2# cat f311565fe9436eb8606f846e1f73f38287841773e8d041933a41259fe6f96afe/lower 
l/7B2WM6DC226TCJU6QHJ4ABKRI6:l/4FHO2G5SWWRIX44IFDHU62Z7X2
root@stretch:/var/lib/docker/overlay2# cat 09495e5085bced25e8017f558147f82e61b012a8f632a0b6aac363462b1db8b0/lower 
l/4FHO2G5SWWRIX44IFDHU62Z7X2
root@stretch:/var/lib/docker/overlay2# cat 8af95287a343b26e9c3dd679258773880e7bdbbe914198ba63a8ed1b4c5f5554/link 
4FHO2G5SWWRIX44IFDHU62Z7X2
```

此时启动一个nginx容器，可以看到overlay2目录多了两个目录，多出来的就是容器层的目录和只读的容器init层。
- 容器目录下面的merged就是我们前面提到的联合挂载目录了，而lowdir则是它下层目录。
- 而容器init层用来存储与这个容器内环境相关的内容，如 /etc/hosts和/etc/resolv.conf文件，它居于其他镜像层之上，容器层之下。


```
root@stretch:/var/lib/docker/overlay2# docker run -idt --name nginx nginx 
01a873eeba41f00a5a3deb083adf5ed892c55b4680fbc2f1880e282195d3087b

root@stretch:/var/lib/docker/overlay2# ls -ls
4 drwx------ 4 root root 4096 May 19 04:17 09495e5085bced25e8017f558147f82e61b012a8f632a0b6aac363462b1db8b0
4 drwx------ 5 root root 4096 May 19 09:11 11b7579a1f1775ad71fe0f0f45fcb74c241fce319f5125b1b92cb442385065b1
4 drwx------ 4 root root 4096 May 19 09:11 11b7579a1f1775ad71fe0f0f45fcb74c241fce319f5125b1b92cb442385065b1-init
4 drwx------ 3 root root 4096 May 19 04:17 8af95287a343b26e9c3dd679258773880e7bdbbe914198ba63a8ed1b4c5f5554
4 drwx------ 4 root root 4096 May 19 04:17 f311565fe9436eb8606f846e1f73f38287841773e8d041933a41259fe6f96afe
4 drwx------ 2 root root 4096 May 19 09:11 l

root@stretch:/home/vagrant# ls -ls /var/lib/docker/overlay2/11b7579a1f1775ad71fe0f0f45fcb74c241fce319f5125b1b92cb442385065b1/
4 drwxr-xr-x 4 root root 4096 May 19 09:11 diff
4 -rw-r--r-- 1 root root 26 May 19 09:11 link
4 -rw-r--r-- 1 root root 115 May 19 09:11 lower
4 drwxr-xr-x 1 root root 4096 May 19 09:11 merged
4 drwx------ 3 root root 4096 May 19 09:11 work

root@stretch:/var/lib/docker/overlay2# ls 11b7579a1f1775ad71fe0f0f45fcb74c241fce319f5125b1b92cb442385065b1/merged/
bin boot dev etc home lib lib64 media mnt opt proc root run sbin srv sys tmp usr var

root@stretch:/var/lib/docker/overlay2# ls 11b7579a1f1775ad71fe0f0f45fcb74c241fce319f5125b1b92cb442385065b1/diff/
run var
```

1. 如果我们在容器中修改文件，则会反映到容器层的merged目录相关文件，容器层的diff目录相当于upperdir，其他层是lowerdir。
2. 如果之前容器层diff目录不存在该文件，则会拷贝该文件到diff目录并修改。
3. 读取文件时，如果upperdir目录找不到，则会直接从下层的镜像层中读取。
