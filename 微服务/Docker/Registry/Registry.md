docker-registry 是官方提供的工具，可以用于构建私有的镜像仓库。

# 安装运行 docker-registry

## 配置Registry

1. 默认的配置文件为(容器内)`/etc/docker/registry/config.yml`,可以通过命令使用本地的配置文件（如`/home/user/registry-conf`），执行如下命令：

```bash
docker run -d -p 5000:5000 \
           --restart=always \
           --name=registry \
           -v /home/user/registry-conf/config.yml:/etc/docker/registry/config.yml \
           registry:2
```

2. 默认的存储路径为（容器内）`/var/lib/registry`,通过-v参数来映射本地的路径（如`/opt/data/registry`）到容器，执行如下命令：

```bash
docker run -d -p 5000:5000 \
           --restart=always \
           --name registry \
           -v /opt/data/registry:/var/lib/registry \
           registry:2
```

## 容器运行

可以通过获取官方 registry 镜像来运行。

```bash
$ docker run -d -p 5000:5000 --restart=always --name registry registry:[version]
```

这将使用官方的 registry 镜像来启动私有仓库。默认情况下，仓库会被创建在容器的 `/var/lib/registry`(或者 `/tmp/registry`) 目录下。你可以通过 -v 参数来将镜像文件存放在本地的指定路径。

```bash
$ docker run -d -p 5000:5000 -v /opt/data/registry:/var/lib/registry registry   
//将上传的镜像放到本地的/opt/data/registry目录
```

此时，在本地将启动一个私有仓库服务，监听端口为5000。

先在本机查看已有的镜像。

```bash
$ docker image ls
REPOSITORY          TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ubuntu              latest              ba5877dc9bec        6 weeks ago         192.7 MB
```

使用 docker tag 将 ubuntu:latest 这个镜像标记为 127.0.0.1:5000/ubuntu:latest。

格式为 `docker tag IMAGE[:TAG] [REGISTRY_HOST[:REGISTRY_PORT]/]REPOSITORY[:TAG]`。

```bash
$ docker tag ubuntu:latest 127.0.0.1:5000/ubuntu:latest
$ docker image ls
REPOSITORY                        TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
ubuntu                            latest              ba5877dc9bec        6 weeks ago         192.7 MB
127.0.0.1:5000/ubuntu:latest      latest              ba5877dc9bec        6 weeks ago         192.7 MB
```

使用 docker push 上传标记的镜像。

```bash
$ docker push 127.0.0.1:5000/ubuntu:latest
The push refers to repository [127.0.0.1:5000/ubuntu]
373a30c24545: Pushed
a9148f5200b0: Pushed
cdd3de0940ab: Pushed
fc56279bbb33: Pushed
b38367233d37: Pushed
2aebd096e0e2: Pushed
latest: digest: sha256:fe4277621f10b5026266932ddf760f5a756d2facd505a94d2da12f4f52f71f5a size: 1568
```

用 curl 查看仓库中的镜像。

```bash
$ curl 127.0.0.1:5000/v2/_catalog
{"repositories":["ubuntu"]}
```

这里可以看到 {"repositories":["ubuntu"]}，表明镜像已经被成功上传了。

先删除已有镜像，再尝试从私有仓库中下载这个镜像。

```bash
$ docker image rm 127.0.0.1:5000/ubuntu:latest

$ docker pull 127.0.0.1:5000/ubuntu:latest
Pulling repository 127.0.0.1:5000/ubuntu:latest
ba5877dc9bec: Download complete
511136ea3c5a: Download complete
9bad880da3d2: Download complete
25f11f5fb0cb: Download complete
ebc34468f71d: Download complete
2318d26665ef: Download complete

$ docker image ls
REPOSITORY                         TAG                 IMAGE ID            CREATED             VIRTUAL SIZE
127.0.0.1:5000/ubuntu:latest       latest              ba5877dc9bec        6 weeks ago         192.7 MB
```

### 注意事项

如果你不想使用 127.0.0.1:5000作为仓库地址，比如想**让本网段的其他主机也能把镜像推送到私有仓库。**

你就得把例如 192.168.199.100:5000这样的内网地址作为**私有仓库地址**，这时你会发现无法成功推送镜像。

这是因为 Docker 默认不允许非HTTPS方式推送镜像。通过Docker的配置选项来取消这个限制，或者查看下一节配置能够通过 HTTPS 访问的私有仓库。

### Ubuntu 14.04, Debian 7 Wheezy

对于使用 upstart 的系统而言，编辑`/etc/default/docker` 文件，在其中的 DOCKER_OPTS 中增加如下内容：

```bash
DOCKER_OPTS="--registry-mirror=https://registry.docker-cn.com --insecure-registries=192.168.199.100:5000"
```

重新启动服务。

```bash
$ sudo service docker restart
```

### Ubuntu 16.04+, Debian 8+, centos 7

对于使用 systemd 的系统，请在 `/etc/docker/daemon.json` 中写入如下内容（如果文件不存在请新建该文件）

```json
{
  "registry-mirror": ["https://registry.docker-cn.com"],
  "insecure-registries": ["192.168.199.100:5000"]
}
```

注意：该文件必须符合 json 规范，否则 Docker 将不能启动。

其他对于 Docker for Windows 、 Docker for Mac 在设置中编辑 daemon.json 增加和上边一样的字符串即可。

或者修改Docker Daemon的启动参数，添加如下参数，表示信任这个私有仓库，不进行安全证书检查：

```bash
DOCKER_OPTS="--insecure-registry 192.168.199.100:5000"
```

然后重启Docker服务。

### 使用安全证书

可以从知名的CA服务时（如verisign）申请公开的SSL/TLS证书，或者使用OpenSSL等软件自动生成，见下一章节。

# 配置TLS证书

当本地主机运行Registry服务后，所有能访问到该主机的Docker Host都可以把它作为私有仓库使用，**只需要在镜像名称签名加上具体的服务器地址**。

私有仓库需要启用TLS认证，否则会报错，可以使用上一节的方式配置，或者生产TLS证书。

## 自行生产证书

使用OpenSSL工具，生产私人证书文件：

```bash
mkdir -p certs
openssl req \
        -newkey rsa:4096 \
        -nodes -sha256 \
        -keyout certs/myrepo.key \
        -x509 -days 365 \
        -out certs/myrepo.crt

Country Name (2 letter code) [AU]:CN	  
State or Province Name (full name) [Some-State]:ShangHai
Locality Name (eg, city) []:ShangHai
Organization Name (eg, company) [Internet Widgits Pty Ltd]:
Organizational Unit Name (eg, section) []:
Common Name (e.g. server FQDN or YOUR name) []:myregistry.docker.com 
Email Address []:

```

生产过程中会提示输入各种信息，主要CN一栏的信息要填入跟访问的地址相同的域名，例如上例中`myrepo.com`，生产结果为：

- 密钥文件：myrepo.key

- 证书文件：myrepo.crt

证书文件需要发送给用户，并且配置到用户Docker Host上，路径需要和域名一致，如：`/etc/docker/certs.d/myrepo.com:5000/ca.crt`

如果Registry服务需要对外公开，需要申请大家都认可的证书。

知名的代理商：

1. SSLs.com

2. GoDaddy.com

3. LetsEncrypt.org

4. GlobalSign.com

## 启用证书

当拥有秘钥文件和证书文件后，可以配置Registry启用证书支持，主要通过`REGSITRY_HTTP_TLS_CERTIFICATE`和`REGISTRY_HTTP_TLS_KEY`参数来设置：

```bash
docker run -d -p 5000:5000 \
           --restart=always \
           --name registry \
           -v /home/sugoi/docker/registry/certs:/certs \
           -v /home/sugoi/docker/registry/data:/var/lib/registry \
           -e REGISTRY_HTTP_ADDR=0.0.0.0:443 \
           -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
           -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
           -p 6443:443 \
           registry:2


# 不使用https的端口，继续使用5000
docker run -d -p 5000:5000 \
           --restart=always \
           --name registry \
           -v /home/sugoi/docker/registry/certs:/certs \
           -v /home/sugoi/docker/registry/data:/var/lib/registry \
           -e REGISTRY_HTTP_TLS_CERTIFICATE=/certs/domain.crt \
           -e REGISTRY_HTTP_TLS_KEY=/certs/domain.key \
           registry:2
```

# 管理访问权限

通常在生产环境中，对私有仓库还需要进行访问代理，以及提供认证和用户管理。

## 用Compose启动Registry

一般情况下，使用Registry需要的配置包括存储路径、TLS证书和用户认证。下面是基于Docker Compose的快速启动Registry的模板：

```yaml
registry:
    restart: always
    image: registry:2.1
    ports:
        - 5000:5000
    environment:
        REGISTRY_HTTP_TLS_CERIFICATE: /certs/myrepo.crt
        REGISTRY_HTTP_TLS_KEY: /certs/myrepo.key
        REGISTRY_AUTH: htpasswd        ##这是一个加密工具
        REGISTRY_AUTH_HTPASSWD_PATH: /auth/docker-registry-htpasswd
        REGISTRY_AUTH_HTPASSWD_REALM: basic
    volumes:
        - /path/to/data: /var/lib/registry
        - /path/to/certs: /certs
        - /path/to/auth: /auth
```

# 配置Registry

Docker Registry提供了一些样例配置，用户可以直接使用它们来进行开发或生产部署。示例配置文件如下：

```yaml
# 版本信息
version: 0.1
# log选项
log:
    level: debug    ## 字符串类型，标注输出调试信息的级别，包括debug，info，warn，error
    fromatter: text    ## 字符串类型，日志输出格式，包括text，json，logstash等
    fields:     ## 增加到日志输出消息中的键值对，可以用于过滤日志
        service: registry
        environment: development
# hooks选项
# 配置当前仓库发生异常时，通过邮件发送日志时的参数
hooks:
    - type: mail
      disabled: true
      levels:
          - panic
      options:
          stmp:
              addr: mail.example.com:25
              uername: mailuser
              password: password
              insecure: true
          from: sender@example.com
          to:
              - errors@example.com
# 存储选项
# 将配置存储引擎，默认支持包括本地文件系统，Google云存储，AWS S3云存储，Openstack Swift 分布式存储等
storage:
    filesystem:
        rootdirectory: /var/lib/registry
    azure:
        accountname: accountname
        accountkey: base64encodedaccountkey
        container: containername
    gcs:
        bucket: bucketname
        keyfile: /path/to/keyfile
        rootdirectory: /gcs/object/name/prefix
    s3:
        accesskey: awsaccesskey
        secretkey: awssecretkey
        region: us-west-1
        regionendpoint: http://myobjects.local
        bucket: bucketname
        encrypt: true
        keyid: mykeyid
        secure: true
        v4auth: true
        chunksize: 5242880
        multipartcopychunksize: 33554432
        multipartcopymaxconcurrency: 100
        multipartcopythresholdsize: 33554432
        rootdirectory: /s3/object/name/prefix
    Swift:
        uername: username
        password: password
        authurl: https://storage.myprovider.com/auth/v1.0 or https://storage.myprovider.com/v2.0 or https://storage.myprovider.com/v3/auth
        tenant: tenantname
        tenantid: tenantid
        domain: domain name for Openstack Identity v3 API
        domainid: domain id for Openstack Identity v3 API
        insecureskipverify: true
        region: fr
        container: containername
        rootdirectory: /swift/object/name/prefix
    oss:
        accesskeyid: accesskeyid
        accesskeysecret: accesskeysecret
        region: OSS region name
        endpoint: optional endpoints
        internal: optional internal endpoint
        bucket: OSS bucket
        encrypt: optional data encrypt setting
        secure: optional ssl setting
        chunksize: optional size value
        rootdirectory: optional root directory
    inmemory:
    delete:     ##是否允许删除镜像功能，默认关闭
        enabled: true
    cache:     ## 开启对镜像层元数据的缓存功能，默认开启
        blobdescriptor: inmemory
    maintenance:     ## 配置维护相关的功能，包括对孤立旧文件的清理、开启只读模式等
        uploadpurging:
            enabled: true
            age: 168h
            interval: 24h
            dryrun: false
     redirect:
         disable: false
# 认证选项，对认证类型的配置
auth:
    silly:     ##仅供测试使用，只要请求头带有认证域即可，不做内容检查
        realm: silly-realm
        service: silly-service
    token:     ##基于token的用户认证，适用于生成环境，需要额外的token服务来支持
        realm: token-realm
        service: token-service
        issuer: registry-token-issuer
        rootcetbundle: /root/certs/bundle
     htpasswd:     ##基于Apache htpasswd密码文件的权限检查
         realm: basic-realmhttp://success.docker.com/article/docker-login-to-dtr-fails-with-x509-certificate-error
path: /path/to/htpasswd
# HTTP选项
http:
    addr: localhost:5000    ##服务监听地址，必选
    net: tcp
    prefix: /my/nested/registry/
    host: https://myregistryaddress.org:5000
    secret: asecretforlocaldevelopment    ##与安全相关的随机字符串，用户可以自定义，必选
    relativeurls: false
    tls:    ##证书相关的文件路径信息
        certificate: /path/to/x509/public
        key: /path/to/x509/private
        clientcas:
            - /path/to/ca.pem
            - /path/to/another/ca.pem
        letsenceypt:
            cachefile: /path/to/cache-file
            email: emailused@letsencrypt.com
    debug:
        addr: localhost:5001
    headers:
        X-Content-Type-Options: [nosniff]
    http2:     ##是否开启http2，默认为关闭
        disabled: false
# 通知选项
## 有事件发生时的通知系统
notifications:
    endpoints:
        - name: local-5003
            url: http://localhost:5003/callback
            headers:
                Authorization: [Bearer <an example token>]
            timeout: 1s
            threshold: 10
            backoff: 1s
            disabled: true
## 上面的配置会在pull或push发生时向 http://localhost:5003/callback 发送事件，并在HTTP请求的header中传入认证信息，可以是Basic、token、Bearer等模式，主要用于接收事件方进行身认证。更新配置后，需要重启Registry服务器，如果配置正确，会在日志中看到相应的提示信息：configuring endpoint listener (http://localhost:5003/callback),timeout=1s,header=map[Authorization:[Bearer <an example token>]]
        - name: local-8083
            url: http://localhost:5003/callback
            timeout: 1s
            threshold: 10
            backoff: 1s
            disabled: true
# redis选项
##用redis来缓存文件块
redis:
    addr: localhost:6379
    password: asecret
    db: 0
    dialtimeout: 10ms
    readtimeout: 10ms
    writetimeout: 10ms
    pool:
        maxidle: 16
        maxactive: 64
        idletimeout: 300s
# 健康健康选项
## 对配置服务进行检测判断系统状态,默认不开启
health:
    storagedriver:
        enabled: true
        interval: 10s
        threshold: 3
    file:
        - file: /path/to/checked/file
          interval: 10s

    http:
        - addr: redis-server.domain.com:6379
          timeout: 3s
          interval: 10s
          threshold: 3
# 代理选项
## 配置Registry作为一个pull代理，从远端（目前仅支持官方仓库）下拉Docker镜像
## 也可通过如下命令来配置代理 `docker --registry-mirror=https://myrepo.com:5000 daemon`
proxy:
    remoteurl: https//registry-1.docker.io
    username: [usernamen]
    password: [password]
# 验证选项
## 限定来自指定地址的客户端才可以执行push操作
validation:
    enabled: true
    manifests:
        urls:
            allow:
                - ^https?://([^/]+\.)*example\.com/
            deny:
                - ^https?://www\.example\.com/
```

配置文件中的选项都是以yaml文件的格式提供的，可以直接进行修改，也可以自定义添加，默认情况下，变量可以从环境变量中读取，例如：log.level:debug 可以配置为 export LOG_LEVEL=debug 。

### 通知的使用场景

每个事件触发的payload都是一个定义好的JSON格式的数据，主要的属性如下：

| 属性                | 类型     | 描述                                     |
| ----------------- | ------ | -------------------------------------- |
| action            | string | 事件所关联的动作类型，pull或者push                  |
| target.mediaType  | string | 事件payload类型，如application/octet-stream等 |
| target.repository | string | 镜像名称                                   |
| target.url        | string | 事件对应数据地址，可以通过url来获取此事件带来的更改            |
| request.method    | string | HTTP请求方法                               |
| request.useragent | string | 带来此事件的客户端类型                            |
| actor.name| string | 发起此次动作的用户                              |

1. 统计镜像上传下载次数，了解镜像使用情况

2. 对服务的持续部署，方便管理镜像
