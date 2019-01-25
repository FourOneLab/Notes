# Linux配置DNS
- 在网卡文件中修改
```
echo 'DNS1="114.114.114.114" ' >> /etc/sysconfig/network-scripts/ifcfg-eth0
```
- 在主机表文件host文件中修改
```
echo "223.231.234.33 www.baidu.com"; >> /etc/hosts
```
- 在域名服务器中修改【测试有效】
```
echo 'nameserver 114.114.114.114' >> /etc/resolv.conf
```
- 重启网卡
```
service network restart
//或者在绝对路径下执行命令

/etc/init.d/network restart
```

# Systemctl命令

命令 | 描述
---|---
systemctl enabled httpd.service | 使某服务自动启动
systemctl disable httpd.service | 使某服务不自动启动
systemctl status httpd.servic | 查看服务状态，显示详细信息
systemctl is-active httpd.service  | 查看服务状态，仅显示是否Active
 systemctl list-units -t service | 显示所有已启动的服务
 systemctl start httpd.service | 启动某服务 
 systemctl stop httpd.service |停止某服务 
systemctl restart httpd.service | 重启某服务 

# 常用命令汇总
- 删除找到的文件夹
    
```
find / -name core.* | xargs rm -rf
    rm -r ` find / -name zookeeper`
```

- yum重建缓存

```
    yum clean all
    yum clean metadata
    yum clean dbcache
    yum makecache
    yum update
```


# Linux 磁盘问题
- 报错：

```
WARNING: Re-reading the partition table failed with error **: Invalid argument.
The kernel still uses the old table. The new table will be used at
the next reboot or after you run partprobe(8) or kpartx(8)
Syncing disks.
```
- 解决方案：
1. 通过 lsof 命令检查该磁盘分区上有哪些进程正在占用。然后通过 kill 命令终止这些进程或者先停止对应的服务，再重新执行 fdisk 执行来删除原有分区并新建分区


2. 先在 /etc/fstab 注释掉挂载的磁盘，然后重启服务器。再重新执行 fdisk 的删除分区和新建分区的步骤， 通过 vi /etc/fstab 打开该文件，注释待扩容的磁盘挂载记录。


# Windows 和 Linux 互传文件
- 使用scp在windows和Linux之间互传文件

从linux系统复制文件到windows系统：

```
scp /oracle/a.txt  administrator@192.168.3.181:/d:/
```


在linux环境下，将windows下的文件复制到linux系统中：

```
scp administrator@192.168.3.181:/d:/test/config.ips  /oracle
```


>windows系统本身不支持ssh协议，所以，要想上面的命令成功执行，必须在windows客户端安装ssh for windows的客户端软件，比如winsshd

# 查看Linux硬件配置
#### 查看CPU信息

>总核数 = 物理CPU个数 X 每颗物理CPU的核数

>总逻辑CPU数 = 物理CPU个数 X 每颗物理CPU的核数 X 超线程数

- 查看物理CPU个数
```
cat /proc/cpuinfo| grep "physical id"| sort| uniq| wc -l
```
- 查看每个物理CPU中core的个数(即核数)
```
cat /proc/cpuinfo| grep "cpu cores"| uniq
```
- 查看逻辑CPU的个数
```
cat /proc/cpuinfo| grep "processor"| wc -l
```
#### 查看内存信息

- 查看内存的信息
```
cat /proc/meminfo
```
- 查看内存使用情况
```
free -g
```
#### 查看硬盘信息

- 查看系统盘分区大小情况和挂载点位置
```
df -h
```
- 查看硬盘实体使用情况，对硬盘进行分区

```
fdisk -l
```
#### 查看操作系统版本

- 查看发行版本

```
cat /etc/redhat-release
```
- 查看运行的内核版本
```
cat /proc/version
```

# Linux 权限管理
#### 文件
- r：读 
- w：编辑
- x：执行


#### 目录
- r：查看目录下内容
- w：创建或删除新的文件或者子目录
- x：访问该目录下的子目录


# Linux 命令行快捷键

#### 常用命令
快捷键 | 功能
---|---
ctrl+左右键|在单词之间跳转
ctrl+a|跳到本行的行首
ctrl+e|跳到页尾
Ctrl+u|删除当前光标前面的文字 （还有剪切功能）
ctrl+k|删除当前光标后面的文字(还有剪切功能)
Ctrl+l|进行清屏操作
Ctrl+y|粘贴Ctrl+u或ctrl+k剪切的内容
Ctrl+w|删除光标前面的单词的字符
Ctrl+t将光标位置的字符和前一个字符进行位置交换


#### 控制命令

快捷键 | 功能
---|---
Ctrl – l |清除屏幕，然后，在最上面重新显示目前光标所在的这一行的内容。
Ctrl – o |执行当前命令，并选择上一条命令。
Ctrl – s |阻止屏幕输出
Ctrl – q |允许屏幕输出
Ctrl – c |终止命令
Ctrl – z |挂起命令

## source
例如： 

```
source a.sh
. a.sh  //这是简写形式
```

- 在当前shell内去读取、执行a.sh，a.sh不需要有执行权限
- source可以简写为. 


##  ./
例如：

```
./ a.sh
```

- 打开一个subshell去读取，执行a.sh，但a.sh需要有执行权限
- 在subshell运行的脚本里设置变量，不会影响父shell


## sh 或  bash
例如：

```
sh a.sh
bash a.sh
```

- 打开一个subshell去读取、执行a.sh，a.sh不需要要有执行权限
- 在subshell运行的脚本里设置变量，不会影响父shell


## fork
使用fork方式运行script时， 就是让shell(parent process)产生一个child process去执行该script，当child process结束后，会返回parent process，但parent process的环境是不会因child process的改变而改变的

## exec
使用exec方式运行script时， 它和source一样，也是让script在当前process内执行，但是process内的原代码剩下部分将被终止。同样，process内的环境随script改变而改变


## emergency mode

Linux开机显示welcome to emergency mode

修改/etc/fstab中的挂载信息，找到自动挂载有问题的硬件设备，然后把那个设备用#注释起来

修改/etc/fstab文件是遇到错误（文件为只读文件，不能修改），使用如下命令： ＃mount -n -o remount,rw /



