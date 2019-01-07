命令 | 作用
---|---
uptime | load averages
dmesg -T \|tail | kernel errors
vmstat 1 | ovarall stats by time
mpstat -P ALL 1 | cpu balance
pidstat 1 | process usages
iostat -xz 1 | disk I/O
free -m | memory usage
sar -n DEV 1 | network I\O
sar -n TCP,ETCP 1 | TCP STATS 
top | check overview

![image](http://www.brendangregg.com/Perf/linux_observability_tools.png)

## uptime

```
Usage:
 uptime [options]

Options:
 -p, --pretty   show uptime in pretty format
 -h, --help     display this help and exit
 -s, --since    system up since
 -V, --version  output version information and exit
```

能够打印系统总共运行了多长时间和系统的平均负载。

uptime命令可以显示的信息显示依次为：现在时间、系统已经运行了多长时间、目前有多少登陆用户（总连接数，非用户数）、系统在过去的1分钟、5分钟和15分钟内的平均负载。


```
[root@tdc-01 ~]# uptime
 09:09:21 up 14:00,  2 users,  load average: 2.51, 2.67, 3.63
```
**那么什么是系统平均负载呢？**

**系统平均负载是指在特定时间间隔内运行队列中的++平均进程数++**。

>如果每个CPU内核的当前活动进程数不大于3的话，那么系统的性能是良好的。如果每个CPU内核的任务数大于5，那么这台机器的性能有严重问题。

>如果你的linux主机是1个双核CPU的话，当Load Average 为6的时候说明机器已经被充分使用了。

## dmesg | tail
打印内核环形缓存区中的内容，可以用来查看一些错误；


```
$ dmesg | tail
[1880957.563150] perl invoked oom-killer: gfp_mask=0x280da, order=0, oom_score_adj=0
[...]
[1880957.563400] Out of memory: Kill process 18694 (perl) score 246 or sacrifice child
[1880957.563408] Killed process 18694 (perl) total-vm:1972392kB, anon-rss:1953348kB, file-rss:0kB
[2320864.954447] TCP: Possible SYN flooding on port 7001. Dropping request. Check SNMP counters.123456
```

上面的例子中，显示进程18694 因引内存越界被kill掉以及TCP request被丢弃的错误。通过dmesg可以快速判断是否有导致系统性能异常的问题。

## vmstat 1
打印进程、内存、交换分区、IO和CPU等的统计信息；

vmstat的格式如下


```
vmstat [options] [delay [count]]


$ vmstat 1
procs ---------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r b swpd free buff cache si so bi bo in cs us sy id wa st
34 0 0 200889792 73708 591828 0 0 0 5 6 10 96 1 3 0 0
32 0 0 200889920 73708 591860 0 0 0 592 13284 4282 98 1 1 0 0
32 0 0 200890112 73708 591860 0 0 0 0 9501 2154 99 1 0 0 0
32 0 0 200889568 73712 591856 0 0 0 48 11900 2459 99 0 0 0 0
32 0 0 200890208 73712 591860 0 0 0 0 15898 4840 98 1 1 0 0
^C123456789
```


vmstat第一次输出表示从开机到vmstat运行时的平均值；剩余输出的都是在指定的时间间隔内的平均值，上述例子中delay的值设置为1，除第一次以外，剩余的都是1秒统计一次，count未设置，将会一直循环打印。


```
$ vmstat 10 3
procs -----------memory---------- ---swap-- -----io---- -system-- ------cpu-----
 r b swpd free buff cache si so bi bo in cs us sy id wa st
 1 0 0 2527112 1086888 13720228 0 0 1 14 2 1 1 1 99 0 0
 0 0 0 2527156 1086888 13719856 0 0 0 104 3003 4901 0 0 99 0 0
 0 0 0 2526412 1086888 13719904 0 0 0 10 3345 4870 0 1 99 0 0123456
```
上述的例子中delay设置为10，count设置为3，表示每行打印10秒内的平均值，只打印3次。

#### 需要检查的列

- r：表示正在运行或者等待CPU调度的进程数。因为该列数据不包含I/O的统计信息，因此可以用来检测CPU是否饱和。若r列中的数字大于CPU的核数，表示CPU已经处于饱和状态。
- free：当前剩余的内存；
- si, so：交换分区换入和换出的个数，若换入换出个数大于0，表示内存不足；
- us, sy, id, wa：CPU的统计信息，分别表示user time、system time(kernel)、idle、wait I/O。I/O处理所用的时间包含在system time中，因此若system time超过20%，则I/O可能存在瓶颈或异常；


## mpstat -P ALL 1
该命令用于每秒打印一次每个CPU的统计信息，可用于查看CPU的调度是否均匀。
```
$ mpstat -P ALL
Linux 3.10.0-229.el7.x86_64 (localhost.localdomain) 05/30/2018 _x86_64_ (16 CPU)
04:03:55 PM CPU %usr %nice %sys %iowait %irq %soft %steal %guest %gnice %idle
04:03:55 PM all 3.67 0.00 0.61 0.71 0.00 0.00 0.00 0.00 0.00 95.02
04:03:55 PM 0 3.52 0.00 0.57 0.76 0.00 0.00 0.00 0.00 0.00 95.15
04:03:55 PM 1 3.83 0.00 0.61 0.71 0.00 0.00 0.00 0.00 0.00 94.85
04:03:55 PM 2 3.80 0.00 0.61 0.60 0.00 0.00 0.00 0.00 0.00 94.99
04:03:55 PM 3 3.68 0.00 0.58 0.60 0.00 0.00 0.00 0.00 0.00 95.13
04:03:55 PM 4 3.54 0.00 0.57 0.60 0.00 0.00 0.00 0.00 0.00 95.30
[...]1234567891011
```

## pidstat 1
该命令用于打印各个进程对CPU的占用情况，类似top命令中显示的内容。pidstat的优势在于，可以滚动的打印进程运行情况，而不像top那样会清屏。
```
$ pidstat 1
Linux 3.13.0-49-generic (titanclusters-xxxxx) 07/14/2015 _x86_64_ (32 CPU)
07:41:02 PM UID PID %usr %system %guest %CPU CPU Command
07:41:03 PM 0 9 0.00 0.94 0.00 0.94 1 rcuos/0
07:41:03 PM 0 4214 5.66 5.66 0.00 11.32 15 mesos-slave
07:41:03 PM 0 4354 0.94 0.94 0.00 1.89 8 java
07:41:03 PM 0 6521 1596.23 1.89 0.00 1598.11 27 java
07:41:03 PM 0 6564 1571.70 7.55 0.00 1579.25 28 java
07:41:03 PM 60004 60154 0.94 4.72 0.00 5.66 9 pidstat
07:41:03 PM UID PID %usr %system %guest %CPU CPU Command
07:41:04 PM 0 4214 6.00 2.00 0.00 8.00 15 mesos-slave
07:41:04 PM 0 6521 1590.00 1.00 0.00 1591.00 27 java
07:41:04 PM 0 6564 1573.00 10.00 0.00 1583.00 28 java
07:41:04 PM 108 6718 1.00 0.00 0.00 1.00 0 snmp-pass
07:41:04 PM 60004 60154 1.00 4.00 0.00 5.00 9 pidstat
^C123456789101112131415161718
```

上述例子中，%CPU中两个java进程的cpu利用率分别达到了1590%和1573%，表示java进程占用了16颗CPU。

## iostat -xz 1
类似vmstat，第一次输出的是从系统开机到统计这段时间的采样数据；


```
$ iostat -xz 1
Linux 3.13.0-49-generic (titanclusters-xxxxx) 07/14/2015 _x86_64_ (32 CPU)
avg-cpu: %user %nice %system %iowait %steal %idle
 73.96 0.00 3.73 0.03 0.06 22.21
Device: rrqm/s wrqm/s r/s w/s rkB/s wkB/s avgrq-sz avgqu-sz await r_await w_await svctm %util
xvda 0.00 0.23 0.21 0.18 4.52 2.08 34.37 0.00 9.98 13.80 5.42 2.44 0.09
xvdb 0.01 0.00 1.02 8.94 127.97 598.53 145.79 0.00 0.43 1.78 0.28 0.25 0.25
xvdc 0.01 0.00 1.02 8.86 127.79 595.94 146.50 0.00 0.45 1.82 0.30 0.27 0.26
dm-0 0.00 0.00 0.69 2.32 10.47 31.69 28.01 0.01 3.23 0.71 3.98 0.13 0.04
dm-1 0.00 0.00 0.00 0.94 0.01 3.78 8.00 0.33 345.84 0.04 346.81 0.01 0.00
dm-2 0.00 0.00 0.09 0.07 1.35 0.36 22.50 0.00 2.55 0.23 5.62 1.78 0.03
[...]
^C123456789101112131415
```

#### 检查列

- r/s, w/s, rkB/s, wkB/s，表示每秒向I/O设备发出的reads、writes、read Kbytes、write Kbytes的数量。
- await，表示应用程序排队等待和被服务的平均I/O时间，该值若大于预期的时间，这表示I/O设备处于饱和状态或者异常。
- avgqu-sz，表示请求被发送给I/O设备的平均时间，若该值大于1，则表示I/O设备可能已经饱和；
- %util，每秒设备的利用率；若该利用率超过60%，则表示设备出现性能异常；

## free -m

```
$ free -m
 total used free shared buffers cached
Mem: 245998 24545 221453 83 59 541
-/+ buffers/cache: 23944 222053
Swap: 0 0 012345
```
#### 检查的列：

- buffers: For the buffer cache, used for block device I/O.
- cached: For the page cache, used by file systems.
- 
若buffers和cached接近0，说明I/O的使用率过高，系统存在性能问题。

Linux中会用free内存作为cache，若应用程序需要分配内存，系统能够快速的将cache占用的内存回收，因此free的内存包含cache占用的部分。

## sar -n DEV 1

sar是System Activity Reporter的缩写，系统活动状态报告。

-n { keyword [,…] | ALL }，用于报告网络统计数据。keyword可以是以下的一个或者多个： DEV, EDEV, NFS, NFSD, SOCK, IP, EIP, ICMP, EICMP, TCP, ETCP, UDP, SOCK6, IP6, EIP6, ICMP6, EICMP6 和UDP6。

-n DEV 1, 每秒统计一次网络的使用情况；

-n EDEV 1，每秒统计一次错误的网络信息；


```
sar -n DEV 1
Linux 3.10.0-229.el7.x86_64 (localhost.localdomain) 05/31/2018 _x86_64_ (16 CPU)
03:54:57 PM IFACE rxpck/s txpck/s rxkB/s txkB/s rxcmp/s txcmp/s rxmcst/s
03:54:58 PM ens32 3286.00 7207.00 283.34 18333.90 0.00 0.00 0.00
03:54:58 PM lo 0.00 0.00 0.00 0.00 0.00 0.00 0.00
03:54:58 PM vethe915e51 0.00 0.00 0.00 0.00 0.00 0.00 0.00
03:54:58 PM docker0 0.00 0.00 0.00 0.00 0.00 0.00 0.00
03:54:58 PM IFACE rxpck/s txpck/s rxkB/s txkB/s rxcmp/s txcmp/s rxmcst/s
03:54:59 PM ens32 3304.00 7362.00 276.89 18898.51 0.00 0.00 0.00
03:54:59 PM lo 0.00 0.00 0.00 0.00 0.00 0.00 0.00
03:54:59 PM vethe915e51 0.00 0.00 0.00 0.00 0.00 0.00 0.00
03:54:59 PM docker0 0.00 0.00 0.00 0.00 0.00 0.00 0.00
^C123456789101112131415
```


属性 | 描述
---|---
IFACE |网络接口名称；
rxpck/s |每秒接收到包数；
txpck/s |每秒传输的报数；(transmit packages)
rxkB/s |每秒接收的千字节数；
txkB/s |每秒发送的千字节数；
rxcmp/s |每秒接收的压缩包的数量；
txcmp/s |每秒发送的压缩包的数量；
rxmcst/s|每秒接收的组数据包数量；


## sar -n TCP,ETCP 1

该命令可以用于粗略的判断网络的吞吐量，如发起的网络连接数量和接收的网络连接数量；

- TCP, 报告关于TCPv4网络流量的统计信息;
- ETCP, 报告有关TCPv4网络错误的统计信息;


```
$ sar -n TCP,ETCP 1
Linux 3.10.0-514.26.2.el7.x86_64 (aushop) 05/31/2018 _x86_64_ (2 CPU)
04:16:27 PM active/s passive/s iseg/s oseg/s
04:16:44 PM 0.00 2.00 15.00 13.00
04:16:45 PM 0.00 3.00 126.00 203.00
04:16:46 PM 0.00 0.00 99.00 99.00
04:16:47 PM 0.00 0.00 18.00 9.00
04:16:48 PM 0.00 0.00 5.00 6.00
04:16:49 PM 0.00 0.00 1.00 1.00
04:16:50 PM 0.00 1.00 4.00 4.00
04:16:51 PM 0.00 3.00 171.00 243.00
^C12345678910111213
```

#### 检测的列：

- active/s: Number of locally-initiated TCP connections per second (e.g., via connect())，发起的网络连接数量；
- passive/s: Number of remotely-initiated TCP connections per second (e.g., via accept())，接收的网络连接数量；
- retrans/s: Number of TCP retransmits per second，重传的数量；


## top

top命令包含更多的指标统计，相当于一个综合命令。


```
$ top
top - 00:15:40 up 21:56, 1 user, load average: 31.09, 29.87, 29.92
Tasks: 871 total, 1 running, 868 sleeping, 0 stopped, 2 zombie
%Cpu(s): 96.8 us, 0.4 sy, 0.0 ni, 2.7 id, 0.1 wa, 0.0 hi, 0.0 si, 0.0 st
KiB Mem: 25190241+total, 24921688 used, 22698073+free, 60448 buffers
KiB Swap: 0 total, 0 used, 0 free. 554208 cached Mem
 PID USER PR NI VIRT RES SHR S %CPU %MEM TIME+ COMMAND
 20248 root 20 0 0.227t 0.012t 18748 S 3090 5.2 29812:58 java
 4213 root 20 0 2722544 64640 44232 S 23.5 0.0 233:35.37 mesos-slave
 66128 titancl+ 20 0 24344 2332 1172 R 1.0 0.0 0:00.07 top
 5235 root 20 0 38.227g 547004 49996 S 0.7 0.2 2:02.74 java
 4299 root 20 0 20.015g 2.682g 16836 S 0.3 1.1 33:14.42 java
 1 root 20 0 33620 2920 1496 S 0.0 0.0 0:03.82 init
 2 root 20 0 0 0 0 S 0.0 0.0 0:00.02 kthreadd
 3 root 20 0 0 0 0 S 0.0 0.0 0:05.35 ksoftirqd/0
 5 root 0 -20 0 0 0 S 0.0 0.0 0:00.00 kworker/0:0H
 6 root 20 0 0 0 0 S 0.0 0.0 0:06.94 kworker/u256:0
 8 root 20 0 0 0 0 S 0.0 0.0 2:38.05 rcu_sched12345678910111213141516171819
```

## lsof
用于查看进程开打的文件，进程打开的端口(TCP、UDP)。找回/恢复删除的文件。是十分方便的系统监视工具，因为lsof命令需要访问核心内存和各种文件，所以需要root用户执行。

>在linux环境下，任何事物都以文件的形式存在，通过文件可以访问常规数据，还可以访问网络连接和硬件。所以如传输控制协议 (TCP) 和用户数据报协议 (UDP) 套接字等，系统在后台都为该应用程序分配了一个文件描述符，无论这个文件的本质如何，该文件描述符为应用程序与基础操作系统之间的交互提供了通用接口。因为应用程序打开文件的描述符列表提供了大量关于这个应用程序本身的信息，因此通过lsof工具能够查看这个列表对系统监测以及排错将是很有帮助的。


参数 | 描述
---|---
-a|列出打开文件存在的进程；
-c<进程名>|列出指定进程所打开的文件；
-g|列出GID号进程详情；
-d<文件号>|列出占用该文件号的进程；
+d<目录>|列出目录下被打开的文件；
+D<目录>|递归列出目录下被打开的文件；
-n<目录>|列出使用NFS的文件；
-i<条件>|列出符合条件的进程。（4、6、协议、:端口、 @ip ）
-p<进程号>|列出指定进程号所打开的文件；
-u|列出UID号进程详情；
-h|显示帮助信息；
-v|显示版本信息。

#### lsof输出各列信息的意义如下
属性 | 描述
---|---
COMMAND|进程的名称
PID|进程标识符
PPID|父进程标识符（需要指定-R参数）
USER|进程所有者
PGID|进程所属组
FD|文件描述符，应用程序通过文件描述符识别该文件。

#### 文件描述符列表
属性 | 描述
---|---
cwd|current work dirctory，应用程序的当前工作目录，这是该应用程序启动的目录，除非它本身对这个目录进行更改
txt|该类型的文件是程序代码，如应用程序二进制文件本身或共享库，如上列表中显示的 /sbin/init 程序
lnn|library references (AIX);
er|FD information error (see NAME column);
jld|jail directory (FreeBSD);
ltx|shared library text (code and data);
mxx |hex memory-mapped type number xx.
m86|DOS Merge mapped file;
mem|memory-mapped file;
mmap|memory-mapped device;
pd|parent directory;
rtd|root directory;
tr|kernel trace file (OpenBSD);
v86  VP/ix  | mapped file;
0|表示标准输出
1|表示标准输入
2|表示标准错误

#### 一般在标准输出、标准错误、标准输入后还跟着文件状态模式
属性 | 描述
---|---
u|表示该文件被打开并处于读取/写入模式。
r|表示该文件被打开并处于只读模式。
w|表示该文件被打开并处于。
空格|表示该文件的状态模式为unknow，且没有锁定。
-|表示该文件的状态模式为unknow，且被锁定。

#### 同时在文件状态模式后面，还跟着相关的锁

属性 | 描述
---|---
N|for a Solaris NFS lock of unknown type;
r|for read lock on part of the file;
R|for a read lock on the entire file;
w|for a write lock on part of the file;（文件的部分写锁）
W|for a write lock on the entire file;（整个文件的写锁）
u|for a read and write lock of any length;
U|for a lock of unknown type;
x|for an SCO OpenServer Xenix lock on part      of the file;
X|for an SCO OpenServer Xenix lock on the      entire file;
space|if there is no lock.

#### 文件类型
属性 | 描述
---|---
DIR|表示目录。
CHR|表示字符类型。
BLK|块设备类型。
UNIX| UNIX 域套接字。
FIFO|先进先出 (FIFO) 队列。
IPv4|网际协议 (IP) 套接字。
DEVICE|指定磁盘的名称
SIZE|文件的大小
NODE|索引节点（文件在磁盘上的标识）
NAME|打开文件的确切名称