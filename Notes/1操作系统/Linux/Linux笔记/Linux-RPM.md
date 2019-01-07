# 概述

在redhat系列的发行版中，采用rpm软件包管理器，rpm原名是Red Hat Package Manager，后来当其他发行版也采用这种软件包管理机制以后，重新命名，改为RPM Package Manager.

**它所能提供的功能是将编译好的应用程序文件打包成一个或几个程序文件，从而使得用户能够方便的安装，升级，卸载软件，而yum则是rpm包管理器的前端工具**。

## rpm包的命名格式以及基本使用
### rpm命名格式，
rpm包分为核心包和功能包

- 对于核心包，命名格式为：

```
name-version-release.arch.rpm
//例如:
GeoIP-1.5.0-9.el7.x86_64.rpm
```
其中version指明了程序源码的版本信息，组成是：major.minor.release



- 对于功能包，命名格式为：

```
name-function-version-release.arch.rpm
//例如：
GeoIP-devel-1.5.0-9.el7.x86_64.rpm
```
其中version指明了程序源码的版本信息,组成是:major.minor.release



### rpm命令的基本使用
rpm的功能包括：
- 安装，
- 卸载，
- 升级，
- 查询，
- 软件包校验，
- 数据库维护等。


```
rpm的使用方式：rpm [option] [package_name]
```


#### 1. 软件的安装

```
rpm <-i,–install> [option] package_name
```

常用选项：

```
-v,-vv:详细显示软件包的安装过程，v的个数表示信息的详细程度
-h:安装过程中以#显示安装进度条，每个#代表2%的进度
–test:测试安装，检查并报告依赖关系
–nodeps:忽略软件的依赖关系，强制安装，不过最好别这么做
–replacepkgs:重新安装
```

#### 2. 软件的卸载

```
rpm <-e,–erease> [option] package_name
```

常用选项：

```
–allmatch:卸载跟包名匹配到的所有软件包
–nodeps:忽略所有依赖关系，强制进行卸载，最好不要这么做
–test:只是测试卸载，并不是真正卸载
```

#### 3. 软件的升级

```
rpm <-q,–query> [option] package_name
```

常用选项：

```
-a，-all：查看已经安装的软件信息
-f <file> : 查看指定的文件是由哪个软件包安装之后生成的
-l,–list:查看软件安装生成了哪些文件
-i,–info:查看跟指定软件包相关的信息
-c,–configfiles:查看软件的配置文件信息
-d，–docfiles:查看指定软件包安装生成的文档文件
-R,–require:查看指定软件的依赖关系
–provides:查看指定软件包提供的内容
–scripts:查看安装指定软件包所生成的脚本
```

#### 4. 软件的校验

```
rpm <-V,–verify> [option] package_name
```

常用选项：

```
-a:查看软件包的完整性
有时候还需要检验软件包的来源合法性：
a.获取并导入软件包制作者的密钥：
rpm –import /etc/pki/rpm-pgp/RPM-GPG-KEY-CentOS-6
b.手动验证：
rpm -k package_name
```

#### 5. 软件的升级

```
rpm <-F,-U> [option] package_name
```

常用选项：

```
-U:升级或安装
-F:升级软件
–force:强制升级
```

#### 6. 软件包信息数据库的管理
之所以能使用rpm对软件包进行管理，是因为rpm根据其所维护的软件包信息数据库进行，而此数据库位于/var/lib/rpm中


```
–initdb:初始化数据库
–rebuilddb:重建数据库
```

### yum的使用

yum全称：**Yellowdog UpdateModifer**,是rpm包管理器的前端工具，根据yum的配置文件中定义的yum仓库的位置，在仓库中找到合适的软件包，然后进行安装。


1. yum的配置文件


```
/etc/yum.conf:提供yum工具的公共配置信息
/etc/yum.repo/ :提供yum仓库的配置信息
```

2. yum仓库的定义


```
[base] #定义yum仓库的ID
name=CentOS-$releasever – Base – 163.com #定义yum仓库的名称
#指明yum仓库的位置，可以使用http，ftp等服务定义，也可以使用本地的文件路径定义
baseurl=http://mirrors.163.com/centos/$releasever/os/$basearch/
gpgcheck={1|0} #是否进行校验
gpgkey=http://mirror.centos.org/centos/RPM-GPG-KEY-CentOS-6 #要进行校验时，要指明密钥文件的位置
enabled={1|0}:是否启用此仓库
```

a. 挂载光盘 使用示例：将光盘作为本地的yum仓库
    

```
mount -t iso9660 /dev/cdroom /media/cdroom
```


b. 在/etc/yum.repo/目录下创建一个以.repo结尾的文件，并添加如下内容即可

```
[my_yum_repo]
name=local repo
base=/media/Packages
gpgcheck=0
enabled=1
```

## yum的使用
使用格式：

```
yum [option] <command> [package]
```

其中常用的option：

```
-y:安装过程中可能会安装其他软件包，此选项的意义是自动回答为yes，即都进行安装
–noplugins:禁止安装所有的插件
–nogpgcheck:安装的时候不对软件包的来源做验证
–disablerepo=repo_name:临时禁止使用指定的yum仓库
–enablerepo=repo_name:临时启用指定的yum仓库
```

常用的command:

```
install:安装指定的软件包
update:升级软件包
remove:删除指定的已经安装的软件包
list:列出yum仓库中所有的rpm软件包
info:查看指定的软件包信息
clean {package,metadata,rpmdb,all}:清除指定的缓存信息
makecache:生成缓存信息
search:查找指定的软件包
reinstall:重新安装指定的软件包
repolist:列出可用的yum仓库
groupinstall:安装指定的包组
groupinfo:查看指定包组的信息
```


