# 安装docker
### 使用官方安装脚本自动安装最新版

```
curl -fsSL https://get.docker.com | bash -s docker --mirror Aliyun
```

### 手动安装

- step 1: 安装必要的一些系统工具

```
yum install -y yum-utils device-mapper-persistent-data lvm2
```

- Step 2: 添加软件源信息

```
yum-config-manager --add-repo http://mirrors.aliyun.com/docker-ce/linux/centos/docker-ce.repo
```

- Step 3: 更新并安装 Docker-CE

```
yum makecache fast
yum -y install docker-ce
```

- Step 4: 开启Docker服务

```
sudo service docker start
```


> 注意：官方软件源默认启用了最新的软件，您可以通过编辑软件源的方式获取各个版本的软件包。例如官方并没有将测试版本的软件源置为可用，你可以通过以下方式开启。同理可以开启各种测试版本等。

```
vim /etc/yum.repos.d/docker-ce.repo将 [docker-ce-test] 下方的 enabled=0 修改为 enabled=1
```
## 安装指定版本的Docker-CE:
- Step 1: 查找Docker-CE的版本:

```
yum list docker-ce.x86_64 --showduplicates | sort -r

   Loading mirror speeds from cached hostfile
   Loaded plugins: branch, fastestmirror, langpacks
   docker-ce.x86_64            17.03.1.ce-1.el7.centos            docker-ce-stable
   docker-ce.x86_64            17.03.1.ce-1.el7.centos            @docker-ce-stable
   docker-ce.x86_64            17.03.0.ce-1.el7.centos            docker-ce-stable
   Available Packages
```

- Step2 : 安装指定版本的Docker-CE: (VERSION 例如上面的 17.03.0.ce.1-1.el7.centos)
```
 yum -y install docker-ce-[VERSION]
```


# 安装Docker-Compose
[Docker-Compose的GitHub](https://github.com/docker/compose/releases)

[Docker-Compose的官方文档](https://docs.docker.com/compose/install/)

- step1：使用官方安装脚本自动下载最新版

```
sudo curl -L "https://github.com/docker/compose/releases/download/1.22.0/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
```
- step2：对二进制文件赋予可执行权限：

```
chmod +x /usr/local/bin/docker-compose
```

- step3:安装完成测试一下

```
docker-compose --version

docker-compose version 1.22.0, build 1719ceb
```

**以上方式不行，可以切换下一种方式：**
- step1：首先安装epel扩展源：

```
yum -y install epel-release
```


- step2：然后安装python-pip

```
yum -y install python-pip
```


:- step3：安装完之后别忘了清除一下cache

```
yum clean all
```

- setp4：最后才安装docker-compose

```
pip install -U docker-compose
```

# 安装Harbor
[Harbor的Github](https://github.com/goharbor/harbor/blob/master/docs/installation_guide.md)
- step1：下载Harbor

[Harbor离线包下载地址](https://storage.googleapis.com/harbor-releases/release-1.6.0/harbor-offline-installer-v1.6.0.tgz)

[Harbor在线包下载地址](https://storage.googleapis.com/harbor-releases/release-1.6.0/harbor-online-installer-v1.6.0.tgz)
```
wget https://storage.googleapis.com/harbor-releases/release-1.6.0/harbor-offline-installer-v1.6.0.tgz

wget https://storage.googleapis.com/harbor-releases/release-1.6.0/harbor-online-installer-v1.6.0.tgz
```

- step2: 解压安装包

```
tar xvf harbor-online-installer-<version>.tgz   //在线版
tar xvf harbor-offline-installer-<version>.tgz //离线版
```

- step3：配置Harbor

```
vim harbor.cfg

./install.sh
```
安装完成后，登录配置文件中设置的IP地址，默认管理员账户密码为admin/Harbor12345


- step4 : 创建私有仓库
登录到浏览器端，创建一个新的项目myproject。由于默认安装使用的是HTTP协议，需要在docker客户端加入信任私有仓库地址，编辑

```
vi /etc/sysconfig/docker

INSECURE_REGISTRY='--insecure-registry 192.168.10.10:5000 --insecure-registry 192.168.10.10'


//重启系统服务
systemctl daemon-reload 
systemctl restart docker.service
```

# 停止Harbor

```
docker-compose stop
Stopping nginx ... done
Stopping harbor-jobservice ... done
Stopping harbor-core ... done
Stopping harbor-db ... done
Stopping registry ... done
Stopping harbor-log ... done
```

# 修改Harbor

```
docker-compose down -v      //先停止已经运行的harbor
vim harbor.cfg      //修改配置文件
prepare     //执行prepa脚本使配置生效
docker-compose up -d        //重新启动Harbor
```

# 删除Harbor 的数据

```
$ rm -r /data/database
$ rm -r /data/registry
```

# 使用Harbor
### 方法一：修改Docker Client的配置文件

```
vim /usr/lib/systemd/system/docker.service

ExecStart=/usr/bin/dockerd --insecure-registry 192.168.1.113\ //增加--insecure-registry 192.168.1.113\

systemctl daemon-reload
systemctl  restart docker
```
### 方法二：

创建/etc/docker/daemon.json文件，在文件中指定仓库地址

```
# cat > /etc/docker/daemon.json << EOF
{ "insecure-registries":["rgs.unixfbi.com"] }
EOF

# systemctl  restart docker
```

登录Harbor

```
docker login 192.168.1.113
//输入账号
//输入密码
```

