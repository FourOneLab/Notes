# 概念
Kerberos是基于受信任第三方主体的网络身份验证系统。 另外两方是用户和用户希望认证的服务。 并非所有服务和应用程序都可以使用Kerberos，但对于那些可以使用Kerberos的服务和应用程序，它会使网络环境更接近单点登录（SSO）。

- Principal：服务器提供的任何用户，计算机和服务都需要定义为Kerberos Principals。
- Instances：对应于特定的服务或管理的principal。
- Realms：Kerberos安装完成后提供的特定控制域。将其视为用户和主机所属的域或组。按照规定域应该是大写的。默认情况下，ubuntu将使用转换为大写（EXAMPLE.COM）的DNS域作为域。
- Key Distribution Center：（KDC）由三部分组成，即存储所有principal的数据库，身份验证服务器和票证授予服务器。对于每个域，必须至少有一个KDC。
- Ticket Granting Ticket：由认证服务器（AS）颁发，TGT由用户的密码加密，该密码仅为用户和KDC所知。
- Ticket Granting Server：（TGS）根据请求向客户发出服务ticket。
- Tickets：确认两个principal的身份。一个principal是用户，另一个principal是用户请求的服务。Tickets会在认证会话中生成一个密钥用于通信安全。
- Keytab文件：是从KDC principal数据库中提取的文件，包含服务或主机的加密密钥。


> 在一个realm中至少有一个KDC，最好有多个冗余的KDC。用户登录到配置kerberos的服务器时，KDC会发布TGT。验证用户通过，那么TGS会授予用户Ticket，用户通过ticket访问realm中的其他principal。


# Kerberos Server
## 安装
安装具有以下配置参数的Kerberos域：
1. Realm: EXAMPLE.COM
2. Primary KDC: kdc01.example.com (192.168.0.1)
3. Secondary KDC: kdc02.example.com (192.168.0.2)
4. User principal: steve
5. Admin principal: steve/admin

**强烈建议，网络认证用户的UID放在与本地用户不同的范围内（例如从5000开始）。**

在安装Kerberos服务器之前，domain需要配置正确的DNS服务器。按照约定Kerberos realm与domain匹配，在这里使用EXAMPLE.COM domain来配置Primary Master的DNS的配置文件。

> Kerberos是一个时间敏感的协议，因此，如果客户端计算机与服务器之间的本地系统时间相差超过五分钟（默认值），那么将无法进行身份验证。 要解决此问题，所有主机应使用相同的网络时间协议（NTP）服务器同步时间。

1. 创建Kerberos realm的第一步，安装 krb5-kdc 和 krb5-admin-server 的包：

```
sudo apt install krb5-kdc krb5-admin-server
```
在安装的最后需要提供kerberos和管理节点的hostname，这两个可能在同一个服务器也可能不在。

**默认情况下realm是根据KDC的domain创建的。**
2. 使用kdb5_newrealm 创建新的 realm：

```
sudo krb5_newrealm
```
## 配置
安装过程中的一些问答是配置/etc/krb5.conf文件的，如果需要修改KDC，直接修改该文件然后重启 krb5-kdc 进程。如果需要从头开始配置Kerberos（如修改realm的名字），如下操作：

```
sudo dpkg-reconfigure krb5-kdc
```

1. 一旦KDC正常运行，就需要一个管理员用户（admin principal），建议使用与日常登录的用户名不同的用户名。使用kadmin.local工具：

```
sudo kadmin.local
Authenticating as principal root/admin@EXAMPLE.COM with password.
kadmin.local: addprinc steve/admin
WARNING: no policy specified for steve/admin@EXAMPLE.COM; defaulting to no policy
Enter password for principal "steve/admin@EXAMPLE.COM": 
Re-enter password for principal "steve/admin@EXAMPLE.COM": 
Principal "steve/admin@EXAMPLE.COM" created.
kadmin.local: quit
```
> 在示例中steve是principal。/admin是instance。@EXAMPLE.COM是realm。修改这三个值为自己对应的值即可。

2. 新的管理员用户需要用适当的ACL权限，这些权限在/etc/krb5kdc/kadm5.acl 文件中配置：

```
steve/admin@EXAMPLE.COM        *
```
此条目授予steve/admin对realm中所有principal执行任何操作的能力。具体的权限操作配置，请参阅kadm5.acl man手册页。
3. 重启krb5-admin-server以使新ACL生效：

```
sudo systemctl restart krb5-admin-server.service
```
4. 使用kinit测试新用户principal：

```
kinit steve/admin
steve/admin@EXAMPLE.COM's Password:
```
输入密码后，使用klist查看有关（TGT）的信息：

```
klist
Credentials cache: FILE:/tmp/krb5cc_1000
        Principal: steve/admin@EXAMPLE.COM

  Issued           Expires          Principal
Jul 13 17:53:34  Jul 14 03:53:34  krbtgt/EXAMPLE.COM@EXAMPLE.COM
```
缓存文件由krb5cc_[uid]组成，需要在/etc/hosts文件中添加KDC的条目，这样的话客户端可以找到KDC，例如：

```
192.168.0.1   kdc01.example.com       kdc01
```
> 当有通过路由分隔的不同kerberos网络时，可以修改192.168.0.1这个IP地址

客户端自动确定Realm中KDC的最佳方法是使用DNS SRV记录。将以下内容添加到/etc/named/db.example.com：

```
_kerberos._udp.EXAMPLE.COM.     IN SRV 1  0 88  kdc01.example.com.
_kerberos._tcp.EXAMPLE.COM.     IN SRV 1  0 88  kdc01.example.com.
_kerberos._udp.EXAMPLE.COM.     IN SRV 10 0 88  kdc02.example.com. 
_kerberos._tcp.EXAMPLE.COM.     IN SRV 10 0 88  kdc02.example.com. 
_kerberos-adm._tcp.EXAMPLE.COM. IN SRV 1  0 749 kdc01.example.com.
_kpasswd._udp.EXAMPLE.COM.      IN SRV 1  0 464 kdc01.example.com.
```
> 将EXAMPLE.COM，kdc01和kdc02替换为自己的域名，主KDC和辅助KDC。


# Secondary KDC
最好有一个备用的KDC，如果在Kerberos的realm中有通过路由隔离使用NAT连接的不同网络时，最好在每个子网中配置一个KDC。

1. 安装软件包，当要求输入Kerberos和管理服务器名称时，输入主KDC的名称：

```
sudo apt install krb5-kdc krb5-admin-server
```

2. 创建第二个KDC的host principal：

```
kadmin -q "addprinc -randkey host/kdc02.example.com"
```
> 使用kadmin命令，系统将提示输入username/admin@EXAMPLE.COM这个principal的密码。

3. 解压keytab文件：

```
kadmin -q "ktadd -norandkey -k keytab.kdc02 host/kdc02.example.com"
```
4. 现在应该在当前目录中有一个keytab.kdc02，将文件移动到/etc/krb5.keytab：

```
sudo mv keytab.kdc02 /etc/krb5.keytab
```
> 如果keytab.kdc02文件的路径不同，则相应地进行调整。

也可以列出keytab文件中的principal，这在使用klist进行故障排查时很有效：

```
sudo klist -k /etc/krb5.keytab      //-k选项表示该文件是keytab文件。
```

5. 每台KDC上都需要一个kpropd.acl文件，列出整个realm中所有的KDC。例如在主从KDC上创建 /etc/krb5kdc/kpropd.acl:

```
host/kdc01.example.com@EXAMPLE.COM
host/kdc02.example.com@EXAMPLE.COM
```
6. 在Secondary KDC上创建一个空的数据库：

```
sudo kdb5_util -s create
```
7. 运行kpropd进程，它监听来自kprop工具的连接，kprop用于传输dump文件

```
sudo kpropd -S
```

8. 在primary KDC上创建principal数据库的dump文件：

```
sudo kdb5_util dump /var/lib/krb5kdc/dump
```
9. 解压主KDC的keytab文件，并复制到/etc/krb5.keytab:

```
kadmin -q "ktadd -k keytab.kdc01 host/kdc01.example.com"
sudo mv keytab.kdc01 /etc/krb5.keytab
```
> 解压前确保有一个kdc01.example.com的host

10. 使用kprop工具将数据库push到secondary KDC中：

```
sudo kprop -r EXAMPLE.COM -f /var/lib/krb5kdc/dump kdc02.example.com
```

> 传输成功会有消息显示，传输失败则查看secondary KDC上的 /var/log/syslog 日志

可以创建一个定时作业（cron job）用于定期更新Secondary KDC的数据库，例如创建一个每小时传输数据的作业：

```
# m h  dom mon dow   command 
0 * * * * /usr/sbin/kdb5_util dump /var/lib/krb5kdc/dump && /usr/sbin/kprop -r EXAMPLE.COM -f /var/lib/krb5kdc/dump kdc02.example.com
```
11. 回到Secondary KDC，创建一个stash文件来保存kerberos的主密钥：

```
sudo kdb5_util stash
```
12. 最后，在Secondary KDC上启动krb5-kdc进程：

```
sudo systemctl start krb5-kdc.service
```

这样 Secondary KDC 也可以在realm中分发ticket，可以通过停止primary KDC的krb5-kdc 进程，然后使用kinit来获取ticket进行测试，一切顺利可以从Secondary KDC上获取ticket，否则查看Secondary KDC上的 /var/log/syslog 和/var/log/auth.log 日志。


# Kerberos Linux Client
配置Linux操作系统的客户端，一旦用户成功登录系统，可以访问任何kerberized服务。

## 安装
为了能够认证到一个Kerberos的realm中，krb5-user和libpam-krb5这两个包必须安装，其他几个包使得生活更美好：

```
sudo apt install krb5-user libpam-krb5 libpam-ccreds auth-client-config
```
- auth-client-config 包允许简单配置PAM以便从多个源进行身份验证，
- libpam-ccreds将缓存身份验证凭据，允许在KDC不可用时登录服务，这个包对于公司内网使用的笔记本来说比较好用。

## 配置

```
sudo dpkg-reconfigure krb5-config       
```
> 系统将提示输入Kerberos Realm的名字，如果没有通过Kerberos SRV记录配置DNS，将会进一步提示输入KDC和Realm 管理服务器的hostname。

dpkg-reconfigure 会将条目添加到所在Realm的/etc/krb5.conf文件中，应该具有类似以下的条目：

```
[libdefaults]
        default_realm = EXAMPLE.COM
...
[realms]
        EXAMPLE.COM = {
                kdc = 192.168.0.1
                admin_server = 192.168.0.1
        }
```

如果按照安装中建议的将每个经过网络身份验证的用户的uid设置为5000，那么告诉pam仅尝试使用uid>5000的kerberos用户进行身份验证：

```
# Kerberos should only be applied to ldap/kerberos users, not local ones.
for i in common-auth common-session common-account common-password; 
do sudo sed -i -r \ 
   -e 's/pam_krb5.so minimum_uid=1000/pam_krb5.so minimum_uid=5000/' \ 
   /etc/pam.d/$i 
done 
```
这将避免在使用passwd更改其密码时被要求提供本地身份验证用户的（不存在的）Kerberos密码。

可以使用kinit来获取一个ticket，进行测试如上配置：

```
kinit steve@EXAMPLE.COM
Password for steve@EXAMPLE.COM:
```
当ticket被授予后，可以使用klist查看详细信息：

```
klist
Ticket cache: FILE:/tmp/krb5cc_1000
Default principal: steve@EXAMPLE.COM

Valid starting     Expires            Service principal
07/24/08 05:18:56  07/24/08 15:18:56  krbtgt/EXAMPLE.COM@EXAMPLE.COM
        renew until 07/25/08 05:18:57


Kerberos 4 ticket cache: /tmp/tkt1000
klist: You have no tickets cached
```
使用auth-client-config 来配置libpam-krb5 模块以在登录期间获取一个ticket：

```
sudo auth-client-config -a -p kerberos_example
```
这样，在成功登录后收到ticket。
