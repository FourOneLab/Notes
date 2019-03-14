在部署Registry之前，需要在主机上安装Docker。Registry是registry镜像的实例，并在Docker中运行。

## 运行本地Registry
使用如下命令启动Registry容器：
```bash
$ docker run -d -p 5000:5000 --restart=always --name registry registry:2
```
Registry现在可以使用了。

> 警告：前几个示例显示了仅适用于测试的Registry配置。**生产就绪的Registry必须受TLS保护**，理想情况下应使用访问控制机制。

继续阅读配置指南以部署生产就绪的Registry。

## 将镜像从Docker Hub复制到Registry
从 Docker Hub中拉ubuntu:16.04镜像
```bash
$ docker pull ubuntu:16.04
```

将镜像标记为localhost:5000/my-ubuntu。这会为现有镜像创建一个附加标记。当标记的第一部分是**主机名和端口时**，Docker在推送时将其解释为Registry的位置。
```bash
$ docker tag ubuntu:16.04 localhost:5000/my-ubuntu
```
将镜像推送到运行于的本地Registry `localhost:5000`：
```bash
$ docker push localhost:5000/my-ubuntu
```
删除本地缓存ubuntu:16.04和localhost:5000/my-ubuntu镜像，以便可以测试从Registry中提取镜像。
```bash
$ docker image remove ubuntu:16.04
$ docker image remove localhost:5000/my-ubuntu
```
从本地Registry拉localhost:5000/my-ubuntu。
```bash
$ docker pull localhost:5000/my-ubuntu
```

## 停止本地Registry
要停止Registry，请使用docker container stop与任何其他容器相同的命令。
```bash
$ docker container stop registry
```
要删除容器，请使用docker container rm。
```bash
$ docker container stop registry && docker container rm -v registry
```
# 基本配置
要配置容器，可以将其他选项或修改选项传递给 docker run命令。

以下部分提供了配置Registry的基本准则。有关更多详细信息，请看[Registry配置参考](https://docs.docker.com/registry/configuration/)。

## 自动启动Registry
如果要将Registry用作永久基础结构的一部分，则应将其设置为在Docker重新启动或退出时自动重新启动。此示例使用该`--restart always`标志为Registry设置重新启动策略。
```bash
$ docker run -d -p 5000:5000 --restart=always --name registry registry:2
  ```
## 自定义已发布的端口
如果已经在使用端口5000，或者希望运行多个本地Registry以分离关注的区域，则可以自定义Registry的端口设置。此示例在端口5001上运行Registry并为其命名 registry-test。
请记住，`-p`值的：
1. 第一部分是**主机**端口，
2. 第二部分是**容器**中的端口。

在容器内，Registry5000默认侦听端口。
```bash
$ docker run -d -p 5001:5000 --name registry-test registry:2
  ```
如果要更改Registry在容器中侦听的端口，可以使用环境变量`REGISTRY_HTTP_ADDR`进行更改。此命令使Registry侦听容器中的端口5001：
```bash
$ docker run -d -e REGISTRY_HTTP_ADDR=0.0.0.0:5001 -p 5001:5001 --name registry-test  registry:2
```
# 存储定制
## 自定义存储位置
默认情况下，Registry数据将作为**主机文件系统上的docker卷**保留。如果要将Registry内容存储在主机文件系统上的特定位置，例如，如果将SSD或SAN装入特定目录，则可使用绑定装入。**绑定装置更依赖于Docker主机的文件系统布局**，但在许多情况下更具性能。

以下示例将主机目录绑定`/mnt/registry`到Registry容器中`/var/lib/registry/`。
```bash
$ docker run -d -p 5000:5000 --restart=always --name registry -v /mnt/registry:/var/lib/registry registry:2
```
## 自定义存储后端
默认情况下，Registry将其数据存储在**本地文件系统上**，无论使用绑定装载还是卷。可以使用[存储驱动程序](https://docs.docker.com/registry/storage-drivers/)将Registry数据存储在Amazon S3存储桶，Google Cloud Platform或其他存储后端。有关更多信息，请参阅下一部分的存储配置选项。

# 运行外部可访问的Registry
运行仅可访问localhost的Registry用途有限。为了使Registry可供外部主机访问，必须首先使用TLS保护它。

此示例在下面的“将Registry作为服务运行”中进行了扩展。

## 获得证书
这些示例假设如下：

- 注册网址是https://myregistry.domain.com/。
- DNS，路由和防火墙设置允许访问端口443上的Registry主机。
- 已从证书颁发机构（CA）获得证书。

如果已获得中间证书，请参阅 [使用中间证书](https://docs.docker.com/registry/deploying/#use-an-intermediate-certificate)。

1. 创建一个certs目录。
```bash
$ mkdir -p certs
```
将CA中的`.crt`和`.key`文件复制到`certs`目录中。以下步骤假定文件已命名为`domain.crt`和 `domain.key`。

2. 如果当前正在运行，请停止Registry。
```bash
$ docker container stop registry
```
3. 重新启动Registry，指示它使用TLS证书。此命令将`certs/`目录绑定到容器中`/certs/`，并**设置环境变量**，告诉容器在哪里找到`domain.crt` 和`domain.key`文件。Registry在端口443（默认HTTPS端口）上运行。
```bash
$ docker run -d -p 5000:5000 \
  --restart=always \
  --name registry \
  -v /home/sugoi/docker/registry/data:/var/lib/registry \
  -v /home/sugoi/docker/registry/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  registry:2
  ```
4. Docker客户端现在可以使用其外部地址从Registry中获取并推送镜像。以下命令演示了这一点：
```bash
$ docker pull ubuntu:16.04
$ docker tag ubuntu:16.04 myregistrydomain.com/my-ubuntu
$ docker push myregistrydomain.com/my-ubuntu
$ docker pull myregistrydomain.com/my-ubuntu
```

## 使用中间证书
证书颁发者可以为您提供中间证书。在这种情况下，必须**将证书与中间证书连接在一起以形成证书包**。可以使用以下cat命令执行此操作：
```bash
cat domain.crt intermediate-certificates.pem > certs/domain.crt
```

可以像使用domain.crt上一个示例中的文件一样使用证书包。

## 支持Let的加密
Registry支持使用Let's Encrypt自动获取浏览器可信证书。有关Let's Encrypt的更多信息，请参阅 https://letsencrypt.org/how-it-works/ 以及Registry配置的相关部分 。

## 使用不安全的Registry（仅测试）
可以使用自签名证书，或者不安全地使用我们的Registry。除非您为自签名证书设置了验证，否则仅用于测试。请参阅[运行不安全的Regill
strys](https://docs.docker.com/registry/insecure/)。

# 添加认证
使用密码testpassword为用户testuser创建一个包含一个条目的密码文件：
```bash
$ mkdir auth
$ docker run \
  --entrypoint htpasswd \
  registry:2 -Bbn testuser testpassword > auth/htpasswd
  ```
停止registry
```bash
docker stop registry
```
重新运行registry
```bash
$ docker run -d \
  -p 5000:5000 \
  --restart=always \
  --name registry \
  -v registry:/var/lib/registry \
  -v /home/sugoi/docker/registry/auth:/auth \
  -e "REGISTRY_AUTH=htpasswd" \
  -e "REGISTRY_AUTH_HTPASSWD_REALM=Registry Realm" \
  -e REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd \
  -v /home/sugoi/docker/registry/certs:/certs \
  -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
  -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
  registry:2
  ```

# 远程客户端使用证书访问registry
1. 拷贝证书到指定目录
```bash
cp domain.crt  /etc/docker/certs.d/myregistrydomain.com:5000/ca.crt
```
这种方式不需要重启docker。

2.  第一种不生效的时候
```bash
$ cp certs/domain.crt /usr/local/share/ca-certificates/myregistrydomain.com.crt
update-ca-certificates
```
