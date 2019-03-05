有时候在没有外网连接的时候无法使用YUM从外网下载RPM包，这时需要创建本地YUM源，如果有一个现成的完整的ISO镜像，可以挂载ISO镜像文件做为本地YUM源。
# 客户端操作
## 读取本地ISO文件
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
cat <<EOF > /etc/yum.repos.d/local.repo
[local]
name=local repository
baseurl=file:///mnt/repo    
enabled=1                    
gpgcheck=0
gpgkey=file:///mnt/repo/RPM-GPG-KEY-CentOS-7
EOF
```
## 读取私有yum仓库
```bash
cat > /etc/yum.repos.d/local.repo <<- EOF
[local]
name=local repository
baseurl=http://172.16.140.239/repo    
enabled=1                    
gpgcheck=0
gpgkey=http://172.16.140.239/repo/RPM-GPG-KEY-CentOS-7
EOF

yum clean all
yum makecache fast
```


# 服务器操作
## 制作yum仓库
在构建本地Yum仓库时需要用到两个工具：
|工具|包|用途|
|---|---|---|
|reposync|yum-utils|用于同步远程Yum仓库至本地路径
|createrepo|createrepo|用于生成安装包元数据信息

```bash
yum install -y createrepo
```

## 搭建HTTP服务器
```bash
yum install  -y httpd

systemctl start httpd.service 
systemctl enable httpd.service   
```
httpd服务器的默认路径为`/var/www/html`。

```bash
mkdir /var/www/html/local
createrepo /var/www/html/local
```

## 搭建Nginx服务器
```bash
yum install -y nginx
```
在nginx的配置文件目录`/etc/nginx/conf.d`创建配置文件yum.conf
```bash
cat <<EOF > /etc/nginx/conf.d/yum.conf
server {
        listen 80 default_server;
        root /usr/share/nginx/html;
        location /yum {
            alias /app/repository;
            autoindex on;
            autoindex_exact_size off;
            autoindex_localtime on;
        }
}

systemctl enable nginx.service
systemctl start nginx.service
systemctl status nginx.service

ss -ntl  #查看端口监听状况
```
访问地址：http://IP/yum


# 下载RPM包
默认的下载路径为：`/var/cache/yum/x86_64/7/`
```bash
yum install -y <包名> --downloadonly
yum reinstall -y <包名> --downloadonly

# 修改保存路径
yum install -y <包名> --downloadonly --downloaddir=<路径名>
```

