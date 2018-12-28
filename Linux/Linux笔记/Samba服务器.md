# 安装samba服务
```
yum install samba
```
# 配置Samba服务

```
vim /etc/samba/smb.conf 
```
**Samba服务程序中的参数以及作用：**

位置 | 参数  | 作用
---|---|---
[global]|	|	#全局参数。
||workgroup = MYGROUP	|#工作组名称
||server string = Samba Server Version %v|	#服务器介绍信息，参数%v为显示SMB版本号
||log file = /var/log/samba/log.%m	#|定义日志文件的存放位置与名称，参数%m为来访的主机名
||max log size = 50|	#定义日志文件的最大容量为50KB
||security = user	|#安全验证的方式，总共有4种
||#share：来访主机无需验证口令；比较方便，但安全性很差
||#user：需验证来访主机提供的口令后才可以访问；提升了安全性
||#server：使用独立的远程主机验证来访主机提供的口令（集中管理账户）
||#domain：使用域控制器进行身份验证
||passdb backend = tdbsam|	#定义用户后台的类型，共有3种
||#smbpasswd：使用smbpasswd命令为系统用户设置Samba服务程序的密码
||#tdbsam：创建数据库文件并使用pdbedit命令建立Samba服务程序的用户
||#ldapsam：基于LDAP服务进行账户验证
||load printers = yes|#设置在Samba服务启动时是否共享打印机设备
||cups options = raw|	#打印机的选项
[homes]	||	#共享参数
||comment = Home Directories|	#描述信息
||browseable = no	|#指定共享信息是否在“网上邻居”中可见
||writable = yes	|#定义是否可以执行写入操作，与“read only”相反
[printers]	||	#打印机共享参数
||comment = All Printers	
||path = /var/spool/samba|	#共享文件的实际路径(重要)。
||browseable = no	
||guest ok = no	|#是否所有人可见，等同于"public"参数。
||writable = no	
||printable = yes	


##  配置共享资源
**用于设置Samba服务程序的参数以及作用：**

参数|	作用
---|---
[database]	|共享名称为database
comment = Do not arbitrarily modify the database file	|警告用户不要随意修改数据库
path = /home/database	|共享目录为/home/database
public = no	|关闭“所有人可见”
writable = yes	|允许写入操作


- 第1步：创建用于访问共享资源的账户信息。

在RHEL 7系统中，Samba服务程序默认使用的是用户口令认证模式（user）。这种认证模式可以确保仅让有密码且受信任的用户访问共享资源，而且验证过程也十分简单。不过，只有建立账户信息数据库之后，才能使用用户口令认证模式。另外，Samba服务程序的数据库要求账户必须在当前系统中已经存在，否则日后创建文件时将导致文件的权限属性混乱不堪，由此引发错误。

> pdbedit命令用于管理SMB服务程序的账户信息数据库，格式为“pdbedit [选项] 账户”。在第一次把账户信息写入到数据库时需要使用-a参数，以后在执行修改密码、删除账户等操作时就不再需要该参数了。

**pdbedit命令中使用的参数以及作用:**
参数|	作用
---|---
-a 用户名|	建立Samba用户
-x 用户名|	删除Samba用户
-L	|列出用户列表
-Lv	|列出用户详细信息的列表


```
[root@linuxprobe ~]# id linuxprobe
uid=1000(linuxprobe) gid=1000(linuxprobe) groups=1000(linuxprobe)
[root@linuxprobe ~]# pdbedit -a -u linuxprobe
new password:       //此处输入该账户在Samba服务数据库中的密码
retype new password:        、、再次输入密码进行确认
Unix username: linuxprobe
NT username: 
Account Flags: [U ]
User SID: S-1-5-21-507407404-3243012849-3065158664-1000
Primary Group SID: S-1-5-21-507407404-3243012849-3065158664-513
Full Name: linuxprobe
Home Directory: \\localhost\linuxprobe
HomeDir Drive: 
Logon Script: 
Profile Path: \\localhost\linuxprobe\profile
Domain: LOCALHOST
Account desc: 
Workstations: 
Munged dial: 
Logon time: 0
Logoff time: Wed, 06 Feb 2036 10:06:39 EST
Kickoff time: Wed, 06 Feb 2036 10:06:39 EST
Password last set: Mon, 13 Mar 2017 04:22:25 EDT
Password can change: Mon, 13 Mar 2017 04:22:25 EDT
Password must change: never
Last bad password : 0
Bad password count : 0
Logon hours : FFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF
```


- 第2步：创建用于共享资源的文件目录。
在创建时，不仅要考虑到文件读写权限的问题，而且由于/home目录是系统中普通用户的家目录，因此还需要考虑应用于该目录的SELinux安全上下文所带来的限制。在前面对Samba服务程序配置文件中的注释信息中就有关于SELinux安全上下文策略的说明，我们只需按照注释信息中有关SELinux安全上下文策略中的说明中给的值进行修改即可。修改完毕后执行restorecon命令，让应用于目录的新SELinux安全上下文立即生效。


```
[root@linuxprobe ~]# mkdir /home/database
[root@linuxprobe ~]# chown -Rf linuxprobe:linuxprobe /home/database
[root@linuxprobe ~]# semanage fcontext -a -t samba_share_t /home/database
[root@linuxprobe ~]# restorecon -Rv /home/database
restorecon reset /home/database context unconfined_u:object_r:home_root_t:s0->unconfined_u:object_r:samba_share_t:s0
```

- 第3步：设置SELinux服务与策略，使其允许通过Samba服务程序访问普通用户家目录。

执行getsebool命令，筛选出所有与Samba服务程序相关的SELinux域策略，根据策略的名称（和经验）选择出正确的策略条目进行开启即可：

```
[root@linuxprobe ~]# getsebool -a | grep samba
samba_create_home_dirs --> off
samba_domain_controller --> off
samba_enable_home_dirs --> off
samba_export_all_ro --> off
samba_export_all_rw --> off
samba_portmapper --> off
samba_run_unconfined --> off
samba_share_fusefs --> off
samba_share_nfs --> off
sanlock_use_samba --> off
use_samba_home_dirs --> off
virt_sandbox_use_samba --> off
virt_use_samba --> off
[root@linuxprobe ~]# setsebool -P samba_enable_home_dirs on
```

- 第4步：在Samba服务程序的主配置文件中，根据格式写入共享信息。

在原始的配置文件中，[homes]参数为来访用户的家目录共享信息，[printers]参数为共享的打印机设备。这两项如果在今后的工作中不需要，可以手动删除，这没有任何问题。


```
[root@linuxprobe ~]# vim /etc/samba/smb.conf 
[global]
 workgroup = MYGROUP
 server string = Samba Server Version %v
 log file = /var/log/samba/log.%m
 max log size = 50
 security = user
 passdb backend = tdbsam
 load printers = yes
 cups options = raw
[database]
 comment = Do not arbitrarily modify the database file
 path = /home/database
 public = no
 writable = yes
```

- 第5步：Samba服务程序的配置工作基本完毕。

接下来重启smb服务（Samba服务程序在Linux系统中的名字为smb）并清空iptables防火墙，然后就可以检验配置效果了。

```
[root@linuxprobe ~]# systemctl restart smb
[root@linuxprobe ~]# systemctl enable smb
 ln -s '/usr/lib/systemd/system/smb.service' '/etc/systemd/system/multi-user.target.wants/smb.service'
[root@linuxprobe ~]# iptables -F
[root@linuxprobe ~]# service iptables save
iptables: Saving firewall rules to /etc/sysconfig/iptables:[ OK ]
```

# Windows挂载共享
无论Samba共享服务是部署Windows系统上还是部署在Linux系统上，通过Windows系统进行访问时，其步骤和方法都是一样的。

要在Windows系统中访问共享资源，只需在Windows的“运行”命令框中输入两个反斜杠，然后再加服务器的IP地址即可。

> 由于Windows系统的缓存原因，有可能您在第二次登录时提供了正确的账户和密码，依然会报错，这时只需要重新启动一下Windows客户端就没问题了（如果Windows系统依然报错，请检查上述步骤是否有做错的地方）。

# Linux挂载共享
设置Samba服务程序所在主机（即Samba共享服务器）和Linux客户端使用的IP地址，然后在客户端安装支持文件共享服务的软件包（cifs-utils）

```
[root@linuxprobe ~]# yum install cifs-utils
```
在Linux客户端，按照Samba服务的用户名、密码、共享域的顺序将相关信息写入到一个认证文件中。为了保证不被其他人随意看到，最后把这个认证文件的权限修改为仅root管理员才能够读写：

```
[root@linuxprobe ~]# vim auth.smb
username=linuxprobe
password=redhat
domain=MYGROUP
[root@linuxprobe ~]# chmod -Rf 600 auth.smb
```
现在，在Linux客户端上创建一个用于挂载Samba服务共享资源的目录，并把挂载信息写入到/etc/fstab文件中，以确保共享挂载信息在服务器重启后依然生效：

```
[root@linuxprobe ~]# mkdir /database
[root@linuxprobe ~]# vim /etc/fstab
#
# /etc/fstab
# Created by anaconda on Wed May 4 19:26:23 2017
#
# Accessible filesystems, by reference, are maintained under '/dev/disk'
# See man pages fstab(5), findfs(8), mount(8) and/or blkid(8) for more info
#
/dev/mapper/rhel-root / xfs defaults 1 1
UUID=812b1f7c-8b5b-43da-8c06-b9999e0fe48b /boot xfs defaults 1 2
/dev/mapper/rhel-swap swap swap defaults 0 0
/dev/cdrom /media/cdrom iso9660 defaults 0 0 
//192.168.10.10/database /database cifs credentials=/root/auth.smb 0 0
[root@linuxprobe ~]# mount -a
```
Linux客户端成功地挂载了Samba服务的共享资源。进入到挂载目录/database后就可以看到Windows系统访问Samba服务程序时留下来的文件了（即文件Memo.txt）。当然，我们也可以对该文件进行读写操作并保存。