# 卸载旧版本

旧版本中Docker的名字叫 **docker** 或者 **docker-engine**

```bash
sudo apt-get remove docker docker-engine docker.io
```

/var/lib/docker 目录中的内容包括：

1. images
2. containers
3. volumes
4. networks

新版的Docker CE名字叫 docker-ce。

# 存储驱动

在Ubuntu下，Docker CE 支持overlay2和aufs。

- Linux kernel 4 以上版本overlay2比aufs更好。
- Linux kernel 3 版本只有aufs，overlay和overlay2不支持这个内核。

# 安装新版本

1. 下载Docker的存储仓库，然后进行下载安装，这样也便于卸载和升级。（推荐方式）
2. 在脱机离线的环境下，下载Deb安装包，手动安装和配置
3. 在测试或者开发环境中使用自动化脚本安装

## 以Docker存储仓库的形式安装

### 配置存储仓库

1. 更新apt安装包的索引信息

```bash
$ sudo apt-get update
```

2. 安装必要的工具使得apt能够通过HTTPS来使用存储仓库

```bash
sudo apt-get install apt-transport-https ca-certificates curl software-properties-common
```

3. 添加Docker官方的GPG 密钥

```bash
$ curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
```

或者从阿里云开源镜像仓库下载GPG和密钥

```bash
curl -fsSL http://mirrors.aliyun.com/docker-ce/linux/ubuntu/gpg | sudo apt-key add -
```

通过搜索指纹的最后8个字符，确认现在拥有指纹9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88的密钥。

```bash
$ sudo apt-key fingerprint 0EBFCD88

pub   4096R/0EBFCD88 2017-02-22
      Key fingerprint = 9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88
uid                  Docker Release (CE deb) <docker@docker.com>
sub   4096R/F273FCD8 2017-02-22
```

4. 设置稳定版存储仓库

```bash
$ sudo add-apt-repository \
   "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"
```
如果需要测试版，把stable修改好edge或test，docker 17.06开始稳定版也会被放在测试版的仓库中。


使用阿里云这里也需要修改


```bash
sudo add-apt-repository "deb [arch=amd64] http://mirrors.aliyun.com/docker-ce/linux/ubuntu $(lsb_release -cs) stable"
```

> lsb_release -cs 命令会获取Ubuntu的发行版代号，如果使用的是一些子发行版（如Linux Mint Rafaela，需要将这个命令的返回值修改为trusty，即对应的父发行版代号）

### 安装Docker ce

1. 更新apt安装包的索引信息

```bash
sudo apt-get update
```

2. 安装最新版的docker-ce

```bash
sudo apt-get install docker-ce
```
apt-get install  和  apt-get update 通常安装和升级最新版。

3. 安装指定版本的docker-ce

```bash
apt-cache madison docker-ce   //列出存储仓库中所有版本

docker-ce | 18.09.0~ce-0~ubuntu | https://download.docker.com/linux/ubuntu xenial/stable amd64 Packages

sudo apt-get install docker-ce=<VERSION>  //使用全名安装对应版本
```

Docker daemon会自动运行。

4. 验证docker-ce是否安装成功

```bash
sudo docker run hello-world
```

安装完成后，docker组被创建但是其中并没有用户，所以需要使用sudo来运行docker的命令

### 以非root用户管理Docker

Docker 守护进程绑定在Unix套接字而不是TCP端口。默认情况下，Unix套接字由用户root拥有，而其他用户只能使用sudo访问它。Docker守护程序始终以root用户身份运行。

如果不想在docker命令前加上sudo，请创建一个名为docker的Unix组并向其添加用户。当Docker守护程序启动时，它会创建一个可由docker组成员访问的Unix套接字。

> 注意，docker组被授予的是和root用户一样的权限。有关这将如何影响系统安全性的详细信息，查看这边 https://docs.docker.com/engine/security/security/#docker-daemon-attack-surface

1. 创建docker用户组

```
$ sudo groupadd docker
```

2. 添加用户到docker用户组

```
$ sudo usermod -aG docker $USER
```

3. 登出并重新登录，来重新更新组成员关系
- 如果在虚拟机上进行测试，则可能需要重新启动虚拟机才能使更改生效。
- 在桌面Linux环境（如X Windows）上，完全注销会话，然后重新登录。

4. 验证是否可以运行docker命令，而不需要sudo

```
$ docker run hello-world
```

如果在创建docker组并向其中添加用户之前，已经使用sudo运行过docker命令的话，那么会看到如下报错信息：


```
WARNING: Error loading config file: /home/user/.docker/config.json -
stat /home/user/.docker/config.json: permission denied
```

这是因为执行sudo命令而创建的〜/.docker/目录的权限不正确。

要解决此问题，
1. 删除〜/.docker/目录（它会自动重新创建，但任何自定义设置都会丢失）
2. 使用以下命令更改其所有权和权限：

```
$ sudo chown "$USER":"$USER" /home/"$USER"/.docker -R
$ sudo chmod g+rwx "$HOME/.docker" -R
```

### 升级docker-ce

```
sudo apt-get update
```

找到对应版本进行升级。


### 卸载docker-ce
1. 卸载docker-ce软件包

```
$ sudo apt-get purge docker-ce
```

2. 删除images，volumes，containers，自定义配置文件

```
$ sudo rm -rf /var/lib/docker
```

# 配置Docker开机自启
大多数主流的Linux发行版（RHEL, CentOS, Fedora, Ubuntu 16.04及以上版本）使用 **systemd**来管理系统启动时启动的服务。Ubuntu 14.10及以下版本使用 **upstart**。

## systemd

```
$ sudo systemctl enable docker
$ sudo systemctl disable docker
```
如果需要添加HTTP代理，为Docker运行时文件设置不同的目录或分区，或进行其他自定义，请参阅[自定义systemd Docker守护程序](https://docs.docker.com/engine/admin/systemd/)。

## upstart

```
$ echo manual | sudo tee /etc/init/docker.override  //取消开机自启
```

## chkconfig

```
$ sudo chkconfig docker on
```
# 使用不容的存储引擎
查看这里 https://docs.docker.com/engine/userguide/storagedriver/imagesandcontainers/
