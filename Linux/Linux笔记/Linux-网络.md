>默认情况下，一个网络接口卡对应一个网络连接，如果需要将计算机和网络相联，除非使用DHCP服务器（自动为网络中的计算机分配IP地址和子网掩码等），否则需要手动配置网络接口

# 查看网络接口信息
网络接口的命名：ethX，其中X表示网络接口的编号

### ifconfig命令

```
ifconfig [option] [interface]
```
**常用选项：**
- a： 显示系统中所有接口，包括禁用的网络接口

**用法示例：**

```
eno16777984: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 1500
        inet 172.16.140.56  netmask 255.255.255.0  broadcast 172.16.140.255
        inet6 fe80::20c:29ff:fe03:7040  prefixlen 64  scopeid 0x20<link>
        ether 00:0c:29:03:70:40  txqueuelen 1000  (Ethernet)
        RX packets 24509866  bytes 8339282117 (7.7 GiB)
        RX errors 0  dropped 446  overruns 0  frame 0
        TX packets 21476759  bytes 9561460763 (8.9 GiB)
        TX errors 0  dropped 0 overruns 0  carrier 0   0

```

**ifconfig命令输出选项含义：**

选项 | 含义
---|---
Link encap | 连接类型，通常为Ethernet
HWaddr| Mac地址，通常被固化在网卡的芯片内
inet | IPv4地址
netmask | IPv4对应的子网掩码
broadcast | 广播地址
inet6 | IPv6地址
prefixlen |
scopeid |
ether |
txqueuelen |表示网络接口使用的缓冲区大小
RX packets |接口发送的总字节数
RX errors | 接口启用至今发送错误包数
RX dropped |接口启用至今发送丢弃包数
RX overruns | 接口启用至今发送溢出包数
frame | 
 TX packets|接口接收到总字节数
 TX packets |接口发送的总字节数
TX errors | 接口启用至今接收错误包数
TX dropped |接口启用至今接收丢弃包数
TX overruns | 接口启用至今接收溢出包数
TX carrier | 
TX collisions|表示信号冲突的次数，通常与物理链路使用有关

**注意：**
- 网络接信息中的错误和丢弃数据包数量，通常与物理链路==质量==相关
- 溢出数据包总数，通常与==缓冲区大小==及收发数据包的==速度==有关

>lo 是一个特殊的接口（环回接口），这个接口的数据总是指向自己，即发送的所有数据包都会发送到系统本身，许多服务都依赖环回接口。例如，sendmail。

>网络接口sit0是一个非常特殊的接口，它就像在IPv4和IPv6网络之间传输数据包的隧道（即将IPv6数据包转换之后传入IPv4网络）


### ip命令
查看当前系统中网络接口的IP地址信息

```
ip address show 


eno2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc mq state UP qlen 1000
    link/ether 0c:c4:7a:a5:d7:ed brd ff:ff:ff:ff:ff:ff
    inet 172.16.140.40/24 brd 172.16.140.255 scope global eno2
       valid_lft forever preferred_lft forever
    inet6 fe80::ec4:7aff:fea5:d7ed/64 scope link 
       valid_lft forever preferred_lft forever

```

接口后面的 qdisc mq 等内容，表示的是这个接口使用的队列相关信息。**使用队列可以控制接口的流量**。

# 配置网络接口
除非使用DHCP，否则都修改网络接口的配置，添加IP地址，子网掩码等。

### ifconfig命令配置网络接口

- 当系统中存在多个网络接口时，如果未正确配置IP地址等信息，通常是无法判断哪个网络接口连接到了哪个网络。
- 如果向系统中添加了新的网卡，系统启动后，网络接口的变化发生了变化（除非原来系统中的网卡配置文件中保存了网卡的MAC地址），无法判断哪个网络接口对应哪个网络。

遇到上述两种情况，建议先使用ifconfig命令配置网络接口，并判断对应的网络，然后将配置写入配置文件。

**使用ifconfig配置网络接口：**

```
ifconfig <interface> <address> netmask <netmask> [up|down]
ifconfig <interface> <address> </prefixlen> [up|down]


例子：
ifconfig  eth1 192.168.204.200/24 up
```
使用ifconfig命令只能临时修改网络接口的设置，系统重启后，这些设置会丢失。

> 使用ifconfig命令设置好网络接口后，就可以使用ping命令验证网络接口eth1对应的网络是否为192.168.204.0。（使用例子中的配置）

### 保存设置到网络接口配置文件
网络接口的配置文件位于/etc/sysconfig/network-scripts中，安装接口名的不同，配置文件的名称为ifcfg-ethX，其中X为网络接口编号。

**查看网络接口的配置文件如下：**

```
TYPE="Ethernet"    //连接的网络类型，常见的是Ethernet，表示以太网，系统自动生成
BOOTPROTO="none"    //网络接口的配置方式，即开启网络接口后应该如何获取设置
DEFROUTE="yes"
IPV4_FAILURE_FATAL="no"
IPV6INIT="yes"
IPV6_AUTOCONF="yes"
IPV6_DEFROUTE="yes"
IPV6_FAILURE_FATAL="no"
NAME="eno16777728"
UUID="2e02c2a7-6ceb-4b4b-88a0-2fa0c47542f3"
DEVICE="eno16777728"     //网络接口的名称，通常有系统自动生成
ONBOOT="yes"             //系统启动时是否启动该连接
IPADDR="172.16.140.30"
PREFIX="24"
GATEWAY="172.16.140.254"  //网关
IPV6_PEERDNS="yes"
IPV6_PEERROUTES="yes"
IPV6_PRIVACY="no"
NETMASK="255.255.255.0"   //子网掩码
HWADDR=      //可选配置，表示网络接口的mac地址
```

++这是一个典型的使用静态IP地址的网络接口配置文件的内容。++

其中，BOOTROTO是一个比较特殊的配置，可以设置为如下的属性值：
- dhcp：连接启动时尝试从DHCP服务器获取此网络接口的初始配置信息（包括IP、子网掩码、默认网关、DNS服务器地址等）
- static：连接启动时使用配置文件中的设置
- none：表示不使用DHCP获取初始信息，这个值表示接口使用静态IP地址或者这个接口有其他的用途，不需要使用IP地址等设置（例如网络接口处于bonding中）


>特别注意：配置项名称应该是大写，属性值应该为小写。如果大小写写错了，在网络接口启东市或有一些错误

# 重新启动网络接口
修改了配置文件后需要手动重启相关的网络接口：
- 重启系统网络服务
- 重启指定网络接口


### 重启网络服务
有一个名为network的系统服务，这个服务的主要作用是初始化系统网络，为系统提供网络支持。系统启动的时候，network服务会检查系统中网络接口的情况，并启用这些连接。


```
service network start|stop|restart

systemctl start|stop|restart network.service


//如果系统不支持service命令
/etc/init.d/network restart|stop|start
```

### 重启网络接口

```
ifconfig eth1 up|down


ifdown eth1
ifup eth1
```


# 配置DNS服务器地址
DNS服务器地址是每一个使用Internet的计算机都需要配置的内容，计算机需要通过DNS才能找到域名对应的IP地址。

### 域名服务器配置文件
域名服务器的配置文件/etc/resolv.conf，默认情况下，该配置文件中只保留一个搜索路径


```
cat /etc/resolv.conf

search localdomain

//添加DNS服务器地址的个数

nameserver IPaddress
```

Linux系统没有限制DNS服务器地址的配置个数，当配置超过三个时，只有前三个生效。

