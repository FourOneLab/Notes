# 主服务器设置
## 设置开启自启
```bash
systemctl start ntpd && systemctl enable ntpd
```

## 修改ntp配置文件
配置文件为`/etc/ntpd.conf`
```bash
#打开此行配置的注释，修改192.168.1.0为你自己集群所在的网段
restrict 192.168.1.0 mask 255.255.255.0 nomodify notrap

#注释这几行配置，这几行配置默认是从网络同步时间
#server 0.centos.pool.ntp.org iburst
#server 1.centos.pool.ntp.org iburst
#server 2.centos.pool.ntp.org iburst
#server 3.centos.pool.ntp.org iburst

#打开这两行配置的注释
server 127.127.1.0
fudge 127.127.1.0 stratum 10
#没看到这两行注释
```
修改另一个配置文件`/etc/sysconfig/ntpd`
```bash
# 增加这一行
SYNC_HWCLOCK=yes
```

# 从服务器设置
```bash
# 手动同步
ntpdate IP 

# 定时同步
# 此处需要root用户执行
sudo crontab -e 
# 文加中编写内容如下
#表示每10分钟执行一次/usr/sbin/ntpdate hadoop-series.bxp.com命令
#hadoop-series.bxp.com为之前配置的时间服务器
0-59/10 * * * * /usr/sbin/ntpdate ntp-server-ip
```
