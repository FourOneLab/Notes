# 文件传输协议（FTP）
计算机互联的目的就是获取资料，而文件传输是一种非常重要的获取资料的方式。在互联网中计算机种类型号不同，操作系统也不同，如何在负责多样的设备之间进行文件传输？FTP应运而生。

FTP是一种在互联网中进行文件传输的协议，基于**客户端/服务器模式**，默认使用`20`、`21`号端口，其中端口`20`（**数据端口**）用于进行数据传输，端口`21`（**命令端口**）用于接受客户端发出的相关FTP命令与参数。

> FTP服务器普遍部署于内网中，具有容易搭建、方便管理的特点。而且有些FTP客户端工具还可以支持文件的**多点下载**以及**断点续传**技术，因此FTP服务得到了广大用户的青睐。

FTP协议的传输拓扑如下所示：

![image](https://www.linuxprobe.com/wp-content/uploads/2015/07/FTP%E8%BF%9E%E6%8E%A5%E8%BF%87%E7%A8%8B.png)

- **FTP服务器**是按照FTP协议在互联网上提供文件存储和访问服务的主机，
- **FTP客户端**则是向服务器发送连接请求，以建立数据传输链路的主机。
  
FTP协议有下面两种工作模式:
1. 主动模式：FTP服务器主动向客户端发起连接请求。
2. 被动模式：FTP服务器等待客户端发起连接请求（FTP的**默认工作模式**）。

## vsftpd
vsftpd（very secure ftp daemon，非常安全的FTP守护进程）是一款运行在Linux操作系统上的FTP服务程序，不仅完全开源而且免费，此外，还具有很高的安全性、传输速度，以及支持虚拟用户验证等其他FTP服务程序不具备的特点。

### 安装vsftpd
```bash
yum  install -y vsftpd

# iptables防火墙管理工具默认禁止了FTP传输协议的端口号，需要清空iptables防火墙的默认策略
iptables -F
# 并把当前已经被清理的防火墙策略状态保存下来
service iptables save
```

### 配置文件及参数
vsftpd服务程序的主配置文件（`/etc/vsftpd/vsftpd.conf`）。

vsftpd服务程序主配置文件中常用的参数以及作用,如下表：
参数|作用
---|---
listen=[`YES|NO`]|是否以独立运行的方式监听服务
listen_address=IP地址|设置要监听的IP地址
listen_port=21|设置FTP服务的监听端口
download_enable＝[`YES|NO`]|是否允许下载文件
userlist_enable=[`YES|NO`]  userlist_deny=[`YES|NO`]|设置用户列表为“允许”还是“禁止”操作
max_clients=0|最大客户端连接数，0为不限制
max_per_ip=0|同一IP地址的最大连接数，0为不限制
anonymous_enable=[`YES|NO`]	|是否允许匿名用户访问
anon_upload_enable=[`YES|NO`]|是否允许匿名用户上传文件
anon_umask=022	|匿名用户上传文件的umask值
anon_root=/var/ftp|	匿名用户的FTP根目录
anon_mkdir_write_enable=[`YES|NO`]|	是否允许匿名用户创建目录
anon_other_write_enable=[`YES|NO`]|	是否开放匿名用户的其他写入权限（包括重命名、删除等操作权限）
anon_max_rate=0	|匿名用户的最大传输速率（字节/秒），0为不限制
local_enable=[`YES|NO`]|是否允许本地用户登录FTP
local_umask=022	|本地用户上传文件的umask值
local_root=/var/ftp	|本地用户的FTP根目录
chroot_local_user=[`YES|NO`]|是否将用户权限禁锢在FTP目录，以确保安全
local_max_rate=0|本地用户最大传输速率（字节/秒），0为不限制

### 运行vsftpd
vsftpd作为更加安全的文件传输的服务程序，允许用户以**三种**认证模式登录到FTP服务器上。
1. **匿名开放模式**：是一种最不安全的认证模式，任何人都可以无需密码验证而直接登录到FTP服务器。
2. **本地用户模式**：是通过**Linux系统本地的账户密码**信息进行认证的模式，相较于匿名开放模式更安全，而且配置起来也很简单。但是如果被黑客破解了账户的信息，就可以畅通无阻地登录FTP服务器，从而完全控制整台服务器。
3. **虚拟用户模式**：是这三种模式中最安全的一种认证模式，它需要为FTP服务单独建立用户数据库文件，虚拟出用来进行口令验证的账户信息，而这些账户信息在服务器系统中实际上是不存在的，仅供FTP服务程序进行认证使用。这样，即使黑客破解了账户信息也无法登录服务器，从而有效降低了破坏范围和影响。

#### 匿名访问模式
在vsftpd服务程序中，匿名开放模式是最不安全的一种认证模式。任何人都可以无需密码验证而直接登录到FTP服务器。这种模式一般用来访问不重要的公开文件（在生产环境中尽量不要存放重要文件）。当然，如果采用防火墙管理工具（如Tcp_wrappers服务程序）将vsftpd服务程序允许访问的主机范围设置为企业内网，也可以提供基本的安全性。

vsftpd服务程序**默认开启了匿名开放模式**，我们需要做的就是开放匿名用户的如下权限：
1. 上传文件
2. 下载文件
3. 创建、删除、更名文件

> 需要注意的是，针对匿名用户放开这些权限会带来潜在危险，不建议在生产环境中如此行事。

修改配置文件中的如下参数：
参数|作用
---|---
anonymous_enable=YES|允许匿名访问模式
anon_umask=022|匿名用户上传文件的umask值
anon_upload_enable=YES|允许匿名用户上传文件
anon_mkdir_write_enable=YES|允许匿名用户创建目录
anon_other_write_enable=YES|允许匿名用户修改目录名称或删除目录

> umask值用于设置用户在创建文件时的默认权限，当我们在系统中创建目录或文件时，目录或文件所具有的默认权限就是由umask值决定的。

在vsftpd服务程序的主配置文件中正确填写参数，然后保存并退出。还需要重启vsftpd服务程序，让新的配置参数生效。把配置过的服务程序加入到开机启动项中，以保证服务器在重启后依然能够正常提供传输服务：
```bash
systemctl restart vsftpd
systemctl enable vsftpd
ln -s '/usr/lib/systemd/system/vsftpd.service' '/etc/systemd/system/multi-user.target.wants/vsftpd.service
```

可以在客户端执行ftp命令连接到远程的FTP服务器了。在vsftpd服务程序的匿名开放认证模式下，其账户统一为`anonymous`，密码为空。而且在连接到FTP服务器后，默认访问的是`/var/ftp`目录。

#### 修改访问权限和selinux
默认访问的是`/var/ftp`目录，只有root管理员才有写入权限。将目录的所有者身份改成系统账户ftp即可（该账户在系统中已经存在）：
```bash
ls -ld /var/ftp/pub
drwxr-xr-x. 3 root root 16 Jul 13 14:38 /var/ftp/pub

chown -Rf ftp /var/ftp/pub

ls -ld /var/ftp/pub
drwxr-xr-x. 3 ftp root 16 Jul 13 14:38 /var/ftp/pub
```
使用getsebool命令查看与FTP相关的SELinux域策略都有哪些：
```bash
getsebool -a | grep ftp

ftp_home_dir --> off
ftpd_anon_write --> off
ftpd_connect_all_unreserved --> off
ftpd_connect_db --> off
ftpd_full_access --> off   # 导致操作失败
ftpd_use_cifs --> off
ftpd_use_fusefs --> off
ftpd_use_nfs --> off
ftpd_use_passive_mode --> off
httpd_can_connect_ftp --> off
httpd_enable_ftp_server --> off
sftpd_anon_write --> off
sftpd_enable_homedirs --> off
sftpd_full_access --> off
sftpd_write_ssh_home --> off
tftp_anon_write --> off
tftp_home_dir --> off

# 修改对应的策略
setsebool -P ftpd_full_access=on
```
---
# umask
- 对于root用户，系统默认的umask值是`0022`；
- 对于普通用户，系统默认的umask值是`0002`。

执行umask命令可以查看当前用户的umask值。umask值一共有4组数字:
1. 其中第1组数字用于定义特殊权限，一般不予考虑，
2. 与一般权限有关的是后3组数字。

默认情况下:
- 对于目录，用户所能拥有的最大权限是777；
- 对于文件，用户所能拥有的最大权限是目录的最大权限去掉执行权限，即666。
> 因为x执行权限对于目录是必须的，没有执行权限就无法进入目录，而对于文件则不必默认赋予x执行权限。

# 举个例子
对于root用户，他的umask值是022。
- 当root用户创建目录时，默认的权限就是用最大权限777去掉相应位置的umask值权限，即对于所有者不必去掉任何权限，对于所属组要去掉w权限，对于其他用户也要去掉w权限，所以目录的默认权限就是755；
- 当root用户创建文件时，默认的权限则是用最大权限666去掉相应位置的umask值，即文件的默认权限是644。
---

#### 本地用户模式
相较于匿名开放模式，本地用户模式要更安全，而且配置起来也很简单。针对本地用户模式的权限参数以及作用如下表所示：

参数|作用
---|---
anonymous_enable=NO|禁止匿名访问模式
local_enable=YES|允许本地用户模式
write_enable=YES|设置可写权限
local_umask=022|本地用户模式创建文件的umask值
userlist_deny=YES|启用“禁止用户名单”，名单文件为ftpusers和user_list
userlist_enable=YES|开启用户作用名单文件功能

在vsftpd服务程序的主配置文件中正确填写参数，然后保存并退出。还需要重启vsftpd服务程序，让新的配置参数生效。同时也需要加入到开机启动中。

Vsftpd服务程序所在的目录中默认存放着两个名为“用户名单”的文件（`ftpusers`和`user_list`）。vsftpd服务程序目录中的这两个文件只要里面写有某位用户的名字，就不再允许这位用户登录到FTP服务器上。

> vsftpd服务程序为了保证服务器的安全性而默认禁止了root管理员和大多数系统用户的登录行为，这样可以有效地避免黑客通过FTP服务对root管理员密码进行暴力破解。

在采用本地用户模式登录FTP服务器后，默认访问的是该用户的家目录，也就是说，访问的是`/home/linuxprobe`目录。而且该目录的默认所有者、所属组都是该用户自己，因此不存在写入权限不足的情况。

#### 虚拟用户模式
第1步：创建用于进行FTP认证的用户数据库文件，其中奇数行为账户名，偶数行为密码。
```bash
# 例如，分别创建出zhangsan和lisi两个用户，密码均为redhat：
cd /etc/vsftpd/
vim vuser.list

zhangsan
redhat
lisi
redhat

# 明文信息既不安全，也不符合让vsftpd服务程序直接加载的格式，
# 因此需要使用db_load命令用哈希（hash）算法将原始的明文信息文件转换成数据库文件，
# 并且降低数据库文件的权限（避免其他人看到数据库文件的内容），
# 然后再把原始的明文信息文件删除

db_load -T -t hash -f vuser.list vuser.db
file vuser.db
chmod 600 vuser.db
rm -f vuser.list
```

第2步：创建vsftpd服务程序用于存储文件的根目录以及虚拟用户映射的系统本地用户。FTP服务用于存储文件的根目录指的是，当虚拟用户登录后所访问的默认位置。

> 由于Linux系统中的每一个文件都有所有者、所属组属性，例如使用虚拟账户“张三”新建了一个文件，但是系统中找不到账户“张三”，就会导致这个文件的权限出现错误。为此，需要再创建一个可以映射到虚拟用户的系统本地用户。简单来说，就是让虚拟用户默认登录到与之有映射关系的这个系统本地用户的家目录中，虚拟用户创建的文件的属性也都归属于这个系统本地用户，从而避免Linux系统无法处理虚拟用户所创建文件的属性权限。

为了方便管理FTP服务器上的数据，可以把这个系统本地用户的家目录设置为/var目录（该目录用来存放经常发生改变的数据）。并且为了安全起见，将这个系统本地用户设置为不允许登录FTP服务器，这不会影响虚拟用户登录，而且还可以避免黑客通过这个系统本地用户进行登录。

```bash
useradd -d /var/ftproot -s /sbin/nologin virtual
ls -ld /var/ftproot/
chmod -Rf 755 /var/ftproot/
```

第3步：建立用于支持虚拟用户的PAM文件。

> PAM（可插拔认证模块）是一种认证机制，通过一些动态链接库和统一的API把系统提供的服务与认证方式分开，使得系统管理员可以根据需求灵活调整服务程序的不同认证方式。

PAM是一组安全机制的模块，系统管理员可以用来轻易地调整服务程序的认证方式，而不必对应用程序进行任何修改。PAM采取了分层设计（应用程序层、应用接口层、鉴别模块层）的思想，其结构如下图所示。

![image](https://www.linuxprobe.com/wp-content/uploads/2015/07/PAM%E8%AE%A4%E8%AF%81%E6%9C%BA%E5%88%B6%E7%9A%84%E4%BD%93%E7%B3%BB%E5%9B%BE.jpg)

新建一个用于虚拟用户认证的PAM文件vsftpd.vu，其中PAM文件内的“db=”参数为使用db_load命令生成的账户密码数据库文件的路径，但不用写数据库文件的后缀：
```bash
vim /etc/pam.d/vsftpd.vu

auth       required     pam_userdb.so db=/etc/vsftpd/vuser
account    required     pam_userdb.so db=/etc/vsftpd/vuser
```

第4步：在vsftpd服务程序的主配置文件中通过pam_service_name参数将PAM认证文件的名称修改为vsftpd.vu，PAM作为应用程序层与鉴别模块层的连接纽带，可以让应用程序根据需求灵活地在自身插入所需的鉴别功能模块。当应用程序需要PAM认证时，则需要在应用程序中定义负责认证的PAM配置文件，实现所需的认证功能。

参数|作用
---|---
anonymous_enable=NO|禁止匿名开放模式
local_enable=YES|允许本地用户模式
guest_enable=YES|开启虚拟用户模式
guest_username=virtual|指定虚拟用户账户
pam_service_name=vsftpd.vu|指定PAM文件
allow_writeable_chroot=YES|允许对禁锢的FTP根目录执行写入操作，而且不拒绝用户的登录请求

第5步：为虚拟用户设置不同的权限。虽然账户zhangsan和lisi都是用于vsftpd服务程序认证的虚拟账户，但是我们依然想对这两人进行区别对待。比如，允许张三上传、创建、修改、查看、删除文件，只允许李四查看文件。这可以通过vsftpd服务程序来实现。只需新建一个目录，在里面分别创建两个以zhangsan和lisi命名的文件，其中在名为zhangsan的文件中写入允许的相关权限（使用匿名用户的参数）：

```bash
mkdir /etc/vsftpd/vusers_dir/
cd /etc/vsftpd/vusers_dir/
touch lisi
vim zhangsan

anon_upload_enable=YES
anon_mkdir_write_enable=YES
anon_other_write_enable=YES

# 然后再次修改vsftpd主配置文件，
# 通过添加user_config_dir参数来定义这两个虚拟用户不同权限的配置文件所存放的路径。
vim /etc/vsftpd/vsftpd.conf
anonymous_enable=NO
local_enable=YES
guest_enable=YES
guest_username=virtual
allow_writeable_chroot=YES
write_enable=YES
local_umask=022
dirmessage_enable=YES
xferlog_enable=YES
connect_from_port_20=YES
xferlog_std_format=YES
listen=NO
listen_ipv6=YES
pam_service_name=vsftpd.vu
userlist_enable=YES
tcp_wrappers=YES
user_config_dir=/etc/vsftpd/vusers_dir # 添加这个

```
## ftp
ftp是Linux系统中以命令行界面的方式来管理FTP传输服务的**客户端工具**。

### 安装ftp
```bash
yum install -y ftp
```