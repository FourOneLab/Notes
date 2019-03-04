有时候在没有外网连接的时候无法使用YUM从外网下载RPM包，这时需要创建本地YUM源，如果有一个现成的完整的ISO镜像，可以挂载ISO镜像文件做为本地YUM源。

# 具体步骤
1. 创建ISO文件的存放目录和挂载目录
```bash
mkdir /mnt/iso 
mkdir /mnt/repo
```
2. 将iso文件挂载到预创建的挂载目录中
```bash
mount -o loop /mnt/iso/CentOS-7-x86_64-DVD-1511-7.2.iso /mnt/repo
```
3. 查看是否挂载成功
```bash
lsblk
df -h
```
4. 在YUM的仓库目录`/etc/yum.repo.d/`目录下创建新的repo文件
```bash
touch /etc/yum.repos.d/transwarp-university.repo
cat <<EOF > /etc/yum.repos.d/transwarp-university.repo
[transwarp]
name=transwarp university repository
baseurl=file:///mnt/repo    
enabled=1                    
gpgcheck=0
gpgkey=file:///mnt/repo/RPM-GPG-KEY-CentOS-7
EOF
```

# 下载RPM包
默认的下载路径为：`/var/cache/yum/x86_64/7/`
```bash
yum install -y <包名> --downloadonly
yum reinstall -y <包名> --downloadonly

# 修改保存路径
yum install -y <包名> --downloadonly --downloaddir=<路径名>
```
