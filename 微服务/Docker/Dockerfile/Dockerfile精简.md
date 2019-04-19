# 优化基础镜像

优化基础镜像的方法就是选用合适的更小的基础镜像，常用的 Linux 系统镜像一般有：
- Ubuntu
- CentOs
- Alpine
- Debian

其中 Alpine 更推荐使用。大小对比如下：

```
ubuntu      latest          93fd78260bd1        3 days ago          86.2MB
debian      latest          4879790bd60d        7 days ago          101MB
centos      latest          75835a67d134        6 weeks ago         200MB
alpine      latest          196d12cf6ab1        2 months ago        4.41MB
```

Alpine 是一个高度精简又包含了基本工具的轻量级 Linux 发行版，基础镜像只有 **4.41M**，各开发语言和框架都有基于 Alpine 制作的基础镜像，++强烈推荐使用它++。

**还有更小的，只有742KB大小的镜像**。 在 http://gcr.io/google_containers/pause-amd64:3.1

## 更推荐的基础镜像：
### scratch 镜像
scratch 是一个**空镜像**，只能用于构建其他镜像，比如你要运行一个包含所有依赖的二进制文件，如Golang 程序，可以直接使用 scratch 作为基础镜像。现在给大家展示一下上文提到的 Google pause 镜像 Dockerfile：

```
FROM scratch
ARG ARCH
ADD bin/pause-${ARCH} /pause
ENTRYPOINT ["/pause"]
```
Google pause 镜像使用了 scratch 作为基础镜像，这个镜像本身是不占空间的，使用它构建的镜像大小几乎和二进制文件本身一样大，所以镜像非常小。

### busybox 镜像
scratch 是个空镜像，如果希望镜像里可以包含一些常用的 Linux 工具，busybox 镜像是个不错选择，镜像本身只有 1.16M，非常便于构建小镜像。

# 串联 Dockerfile 指令

在定义 Dockerfile 时，如果太多的使用 RUN 指令，经常会导致镜像有特别多的层，镜像很臃肿，而且甚至会碰到超出最大层数（127层）限制的问题，遵循 Dockerfile 最佳实践，应该把多个命令串联合并为一个RUN（**通过运算符&&和/ 来实现**），每一个 RUN 要精心设计，确保安装构建最后进行清理，这样才可以降低镜像体积，以及最大化的利用构建缓存。

**将多条 RUN 命令串联起来构建的镜像大小是每条命令分别 RUN 的三分之一。**

> 提示：为了应对镜像中存在太多镜像层，Docker 1.13 版本以后，提供了一个压扁镜像功能，即将 Dockerfile 中所有的操作压缩为一层。这个特性还处于**实验阶段**，Docke r默认没有开启，如果要开启，需要在启动Docker时添加-experimental 选项，并在Docker build 构建镜像时候添加 --squash 。

# 使用多阶段构建

Dockerfile 中每条指令都会为镜像增加一个镜像层，并且你需要在移动到下一个镜像层之前清理不需要的组件。实际上，有一个 Dockerfile 用于开发（**其中包含构建应用程序所需的所有内容**）以及一个用于生产的瘦客户端，它只包含你的应用程序以及运行它所需的内容。这被称为“建造者模式”。**Docker 17.05.0-ce** 版本以后支持多阶段构建。使用多阶段构建，你可以在 Dockerfile 中使用多个 FROM 语句，每条 FROM 指令可以使用不同的基础镜像，这样您可以选择性地将服务组件从一个阶段 COPY 到另一个阶段，在最终镜像中只保留需要的内容。

构建镜像，你会发现生成的镜像只有上面 COPY 指令指定的内容，镜像大小只有 2M。这样在以前使用两个 Dockerfile（一个 Dockerfile 用于开发和一个用于生产的瘦客户端），现在使用多阶段构建就可以搞定。

# 构建业务服务镜像技巧
Docker 在 build 镜像的时候，如果某个命令相关的内容没有变化，会使用上一次缓存（cache）的文件层，在构建业务镜像的时候可以注意下面两点：

1. 不变或者变化很少的体积较大的依赖库和经常修改的自有代码分开；
2. 因为 cache 缓存在运行 Docker build 命令的本地机器上，建议固定使用某台机器来进行 Docker build，以便利用 cache。

下面是构建 Spring Boot 应用镜像的例子，用来说明如何分层。其他类型的应用，比如 Java WAR 包，Nodejs的npm 模块等，可以采取类似的方式。

1. 在 Dockerfile 所在目录，解压缩 maven 生成的 jar 包。
2. Dockerfile 我们把应用的内容分成 4 个部分 COPY 到镜像里面：其中前面 3 个基本不变，第 4 个是经常变化的自有代码。最后一行是解压缩后，启动 spring boot 应用的方式。

这样在构建镜像时候可大大提高构建速度。

# 清理不要的文件

一个小体积的容器镜像在传输方面有很大的优势，同时，在磁盘上存储不必要的数据的多个副本也是对资源的一种浪费。

如果在 RUN 命令中执行 apt、apk 或者 yum 类工具，可以借助这些工具提供的一些小技巧来减少镜像层数量及镜像大小。将所有 yum install 任务放在一条 RUN 命令上执行，从而减少镜像层的数量；

| 效果 | 命令 | 命令|　命令
|---|---|---|---|
|不用安装建议性（非必须）的依赖|apt-get install -y -no-install-recommends| apk add --no-cache|
|组件的安装和清理要串联在一条指令里面|rm -rf /var/cache/apk/* |rm -rf /var/lib/apt/lists/*  |yum clean all 

> 清理缓存文件的效果相当显著。除此以外，包管理器缓存文件、Ruby gem 的临时文件、nodejs 缓存文件，甚至是下载的源码 tarball 最好都全部清理掉。

**如果将 apk add … 和 rm -rf … 命令分开，清理无法减小apk命令产生的文件层的大小**。如果分开写，add那一层的缓存文件会被保留，在rm那一层在移除，但缓存实际上还是存在的，只是看不到也不能访问。

# 镜像层的隐蔽特性
每一层都记录了文件的更改，这里的更改并**不仅仅已有的文件累加起来，而是包括文件属性在内的所有更改**。因此即使是对文件使用了 chmod 操作也会被在新的层创建文件的副本。

在构建容器镜像的过程中，如果在单独一层中进行移动、更改、删除文件，都会出现文件复制一个副本，从而镜像非常大的情况。

# buildah
有一些和 Dockerfile 一样易用的工具可以轻松创建非常小的兼容 Docker 的容器镜像，这些镜像甚至不需要包含一个完整的操作系统，就可以像标准的 Docker 基础镜像一样小。

我曾经写过一篇 关于 Buildah 的文章 ，我想在这里再一次推荐一下这个工具。因为它足够的灵活，可以使用宿主机上的工具来操作一个空白镜像并安装打包好的应用程序，而且这些工具不会被包含到镜像当中。

Buildah 取代了 docker build 命令。可以使用 Buildah 将容器的文件系统挂载到宿主机上并进行交互。

下面来使用 Buildah 实现上文中 Nginx 的例子（现在忽略了缓存的处理）：
```bash
#!/usr/bin/env bash
set -o errexit
# Create a container
container=$(buildah from scratch)

# Mount the container filesystem
mountpoint=$(buildah mount $container)

# Install a basic filesystem and minimal set of packages, and nginx
dnf install --installroot $mountpoint --releasever 28 glibc-minimal-langpack nginx --setopt install_weak_deps=false -

# Save the container to an image
buildah commit --format docker $container nginx

# Cleanup
buildah unmount $container

# Push the image to the Docker daemon’s storage
buildah push nginx:latest docker-daemon:nginx:latest
```
你会发现这里使用的已经不再是 Dockerfile 了，而是普通的 Bash 脚本，而且是从框架（或空白）镜像开始构建的。上面这段 Bash 脚本将容器的根文件系统挂载到了宿主机上，然后使用宿主机的命令来安装应用程序，这样的话就不需要把软件包管理器放置到容器镜像中了。

这样所有无关的内容（基础镜像之外的部分，例如 dnf）就不再会包含在镜像中了。在这个例子当中，构建出来的镜像大小只有 304 MB，比使用 Dockerfile 构建的镜像减少了 100 MB 以上。

```bash
[chris@krang] $ docker images |grep nginx
docker.io/nginx buildah 2505d3597457 4 minutes ago 304 MB
```

注：这个镜像是使用上面的构建脚本构建的，镜像名称中前缀的 docker.io 只是在推送到镜像仓库时加上的。

对于一个 300MB 级别的容器基础镜像来说，能缩小 100MB 已经是很显著的节省了。使用软件包管理器来安装 Nginx 会带来大量的依赖项，如果能够使用宿主机直接从源代码对应用程序进行编译然后构建到容器镜像中，节省出来的空间还可以更多，因为这个时候可以精细的选用必要的依赖项，非必要的依赖项一概不构建到镜像中。

Tom Sweeney 有一篇文章《 用 Buildah 构建更小的容器 》，如果你想在这方面做深入的优化，不妨参考一下。

通过 Buildah 可以构建一个不包含完整操作系统和代码编译工具的容器镜像，大幅缩减了容器镜像的体积。对于某些类型的镜像，我们可以进一步采用这种方式，创建一个只包含应用程序本身的镜像。

# 使用静态链接的二进制文件来构建镜像
按照这个思路，我们甚至可以更进一步舍弃容器内部的管理和构建工具。例如，如果我们足够专业，不需要在容器中进行排错调试，是不是可以不要 Bash 了？是不是可以不要 GNU 核心套件 了？是不是可以不要 Linux 基础文件系统了？如果你使用的编译型语言支持 静态链接库 ，将应用程序所需要的所有库和函数都编译成二进制文件，那么程序所需要的函数和库都可以复制和存储在二进制文件本身里面。

这种做法在 Golang 社区中已经十分常见，下面我们使用由 Go 语言编写的应用程序进行展示：

以下这个 Dockerfile 基于 golang:1.8 镜像构建一个小的 Hello World 应用程序镜像：
```Dockerfile
FROM golang:1.8

ENV GOOS=linux
ENV appdir=/go/src/gohelloworld

COPY ./ /go/src/goHelloWorld

WORKDIR /go/src/goHelloWorld
RUN go get
RUN go build -o /goHelloWorld -a

CMD ["/goHelloWorld"]
```
构建出来的镜像中包含了二进制文件、源代码以及基础镜像层，一共 716MB。但对于应用程序运行唯一必要的只有编译后的二进制文件，其余内容在镜像中都是多余的。

如果在编译的时候通过指定参数 CGO_ENABLED=0 来禁用 cgo，就可以在编译二进制文件的时候忽略某些函数的 C 语言库：
```go
GOOS=linux CGO_ENABLED=0 go build -a goHelloWorld.go
```
编译出来的二进制文件可以加到一个空白（或框架）镜像：
```dockerfile
FROM scratch

COPY goHelloWorld /

CMD ["/goHelloWorld"]
```
来看一下两次构建的镜像对比：

```bash
[ chris@krang ] $ docker images
REPOSITORY TAG IMAGE ID CREATED SIZE
goHello scratch a5881650d6e9 13 seconds ago 1.55 MB
goHello builder 980290a100db 14 seconds ago 716 MB
```
从镜像体积来说简直是天差地别了。基于 golang:1.8 镜像构建出来带有 goHelloWorld 二进制的镜像（带有 builder 标签）体积是基于空白镜像构建的只包含该二进制文件的镜像的 460 倍！后者的整个镜像大小只有 1.55MB，也就是说，有 713MB 的数据都是非必要的。

正如上面提到的，这种缩减镜像体积的方式在 Golang 社区非常流行，因此不乏这方面的文章。 Kelsey Hightower 有一篇 文章 专门介绍了如何处理这些库的依赖关系。

# 压缩镜像层

对镜像进行压缩。镜像压缩的实质是导出它，删除掉镜像构建过程中的所有中间层，然后保存镜像的当前状态为单个镜像层。这样可以进一步将镜像缩小到更小的体积。

在 Docker 1.13 之前，压缩镜像层的的过程可能比较麻烦，需要用到 docker-squash 之类的工具来导出容器的内容并重新导入成一个单层的镜像。但 Docker 在 Docker 1.13 中引入了 --squash 参数，可以在构建过程中实现同样的功能：
```Dockerfile
FROM fedora:28

LABEL maintainer Chris Collins <collins.christopher@gmail.com>

RUN dnf install -y nginx
RUN dnf clean all
RUN rm -rf /var/cache/yum
```

```bash
[chris@krang] $ docker build -t squash -f Dockerfile-squash --squash .
[chris@krang] $ docker images --format "{{.Repository}}: {{.Size}}" | head -n 1
squash: 271 MB
```
通过这种方式使用 Dockerfile 构建出来的镜像有 271MB 大小，和上面连接多条命令的方案构建出来的镜像体积一样，因此这个方案也是有效的，但也有一个潜在的问题，**导致镜像过度压缩、太小太专用**。

> 过度使用压缩或专用镜像层的缺点。将不同镜像压缩成单个镜像层，各个容器镜像之间就没有可以共享的镜像层了，每个容器镜像都会占有单独的体积。如果你只需要维护少数几个容器镜像来运行很多容器，这个问题可以忽略不计；但如果你要维护的容器镜像很多，从长远来看，就会耗费大量的存储空间。

# 通过 Docker 多阶段构建将多个层压缩为一个
当 Git 存储库变大时，你可以选择将历史提交记录压缩为单个提交。

事实证明，在 Docker 中也可以使用多阶段构建达到类似的目的。

在这个示例中，你将构建一个 Node.js 容器。

让我们从 index.js 开始：

```
const express = require('express')
const app = express()
app.get('/', (req, res) => res.send('Hello World!'))
app.listen(3000, () => {
  console.log(`Example app listening on port 3000!`)
})
```
和 package.json：
```
{
  "name": "hello-world",
  "version": "1.0.0",
  "main": "index.js",
  "dependencies": {
    "express": "^4.16.2"
  },
  "scripts": {
    "start": "node index.js"
  }
}
```
你可以使用下面的 Dockerfile 来打包这个应用程序：
```
FROM node:8
EXPOSE 3000
WORKDIR /app
COPY package.json index.js ./
RUN npm install
CMD ["npm", "start"]
```
然后开始构建镜像：

```
$ docker build -t node-vanilla .
```
然后用以下方法验证它是否可以正常运行：
```
docker run -p 3000:3000 -ti --rm --init node-vanilla

```

你应该能访问http://localhost:3000，并收到“Hello World!”。

Dockerfile 中使用了一个 COPY 语句和一个 RUN 语句，所以按照预期，新镜像应该比基础镜像多出至少两个层：

```
$ docker history node-vanilla
IMAGE          CREATED BY                                      SIZE
075d229d3f48   /bin/sh -c #(nop)  CMD ["npm" "start"]          0B
bc8c3cc813ae   /bin/sh -c npm install                          2.91MB
bac31afb6f42   /bin/sh -c #(nop) COPY multi:3071ddd474429e1…   364B
500a9fbef90e   /bin/sh -c #(nop) WORKDIR /app                  0B
78b28027dfbf   /bin/sh -c #(nop)  EXPOSE 3000                  0B
b87c2ad8344d   /bin/sh -c #(nop)  CMD ["node"]                 0B
<missing>      /bin/sh -c set -ex   && for key in     6A010…   4.17MB
<missing>      /bin/sh -c #(nop)  ENV YARN_VERSION=1.3.2       0B
<missing>      /bin/sh -c ARCH= && dpkgArch="$(dpkg --print…   56.9MB
<missing>      /bin/sh -c #(nop)  ENV NODE_VERSION=8.9.4       0B
<missing>      /bin/sh -c set -ex   && for key in     94AE3…   129kB
<missing>      /bin/sh -c groupadd --gid 1000 node   && use…   335kB
<missing>      /bin/sh -c set -ex;  apt-get update;  apt-ge…   324MB
<missing>      /bin/sh -c apt-get update && apt-get install…   123MB
<missing>      /bin/sh -c set -ex;  if ! command -v gpg > /…   0B
<missing>      /bin/sh -c apt-get update && apt-get install…   44.6MB
<missing>      /bin/sh -c #(nop)  CMD ["bash"]                 0B
<missing>      /bin/sh -c #(nop) ADD file:1dd78a123212328bd…   123MB
```
但实际上，生成的镜像多了五个新层：每一个层对应 Dockerfile 里的一个语句。

现在，让我们来试试 Docker 的多阶段构建。

你可以继续使用与上面相同的 Dockerfile，只是现在要调用两次：

```
FROM node:8 as build
WORKDIR /app
COPY package.json index.js ./
RUN npm install
FROM node:8
COPY --from=build /app /
EXPOSE 3000
CMD ["index.js"]
```
Dockerfile 的第一部分创建了三个层，然后这些层被合并并复制到第二个阶段。在第二阶段，镜像顶部又添加了额外的两个层，所以总共是三个层。

现在来验证一下。首先，构建容器：
```
$ docker build -t node-multi-stage .
```
查看镜像的历史：
```
$ docker history node-multi-stage
IMAGE          CREATED BY                                      SIZE
331b81a245b1   /bin/sh -c #(nop)  CMD ["index.js"]             0B
bdfc932314af   /bin/sh -c #(nop)  EXPOSE 3000                  0B
f8992f6c62a6   /bin/sh -c #(nop) COPY dir:e2b57dff89be62f77…   1.62MB
b87c2ad8344d   /bin/sh -c #(nop)  CMD ["node"]                 0B
<missing>      /bin/sh -c set -ex   && for key in     6A010…   4.17MB
<missing>      /bin/sh -c #(nop)  ENV YARN_VERSION=1.3.2       0B
<missing>      /bin/sh -c ARCH= && dpkgArch="$(dpkg --print…   56.9MB
<missing>      /bin/sh -c #(nop)  ENV NODE_VERSION=8.9.4       0B
<missing>      /bin/sh -c set -ex   && for key in     94AE3…   129kB
<missing>      /bin/sh -c groupadd --gid 1000 node   && use…   335kB
<missing>      /bin/sh -c set -ex;  apt-get update;  apt-ge…   324MB
<missing>      /bin/sh -c apt-get update && apt-get install…   123MB
<missing>      /bin/sh -c set -ex;  if ! command -v gpg > /…   0B
<missing>      /bin/sh -c apt-get update && apt-get install…   44.6MB
<missing>      /bin/sh -c #(nop)  CMD ["bash"]                 0B
<missing>      /bin/sh -c #(nop) ADD file:1dd78a123212328bd…   123MB
```
文件大小是否已发生改变？
```
$ docker images | grep node-
node-multi-stage   331b81a245b1   678MB
node-vanilla       075d229d3f48   679MB
```
最后一个镜像（node-multi-stage）更小一些。

你已经将镜像的体积减小了，即使它已经是一个很小的应用程序。

但整个镜像仍然很大！

有什么办法可以让它变得更小吗？

# 用 distroless 去除容器中所有不必要的东西
这个镜像包含了 Node.js 以及 yarn、npm、bash 和其他的二进制文件。因为它也是基于 Ubuntu 的，所以你等于拥有了一个完整的操作系统，其中包括所有的小型二进制文件和实用程序。

但在运行容器时是不需要这些东西的，你需要的只是 Node.js。

Docker 容器应该只包含一个进程以及用于运行这个进程所需的最少的文件，你不需要整个操作系统。

实际上，你可以删除 Node.js 之外的所有内容。

但要怎么做？

所幸的是，谷歌为我们提供了distroless。

> 以下是 distroless 存储库的描述：“distroless”镜像只包含应用程序及其运行时依赖项，不包含程序包管理器、shell 以及在标准 Linux 发行版中可以找到的任何其他程序。

这正是你所需要的！

你可以对 Dockerfile 进行调整，以利用新的基础镜像，如下所示：

```dockerfile
FROM node:8 as build
WORKDIR /app
COPY package.json index.js ./
RUN npm install
FROM gcr.io/distroless/nodejs
COPY --from=build /app /
EXPOSE 3000
CMD ["index.js"]
```
你可以像往常一样编译镜像：
```
$ docker build -t node-distroless .
```
这个镜像应该能正常运行。要验证它，可以像这样运行容器：
```
$ docker run -p 3000:3000 -ti --rm --init node-distroless
```
现在可以访问http://localhost:3000页面。

不包含其他额外二进制文件的镜像是不是小多了？
```
$ docker images | grep node-distroless
node-distroless   7b4db3b7f1e5   76.7MB
```
只有 76.7MB！

比之前的镜像小了 600MB！

但在使用 distroless 时有一些事项需要注意。

当容器在运行时，如果你想要检查它，可以使用以下命令 attach 到正在运行的容器上：
```
$ docker exec -ti <insert_docker_id> bash
```
attach 到正在运行的容器并运行 bash 命令就像是建立了一个 SSH 会话一样。

但 distroless 版本是原始操作系统的精简版，没有了额外的二进制文件，所以容器里没有 shell！

在没有 shell 的情况下，如何 attach 到正在运行的容器呢？

答案是，你做不到。这既是个坏消息，也是个好消息。

之所以说是坏消息，因为你只能在容器中执行二进制文件。你可以运行的唯一的二进制文件是 Node.js：
```
$ docker exec -ti <insert_docker_id> node
```
说它是个好消息，是因为如果攻击者利用你的应用程序获得对容器的访问权限将无法像访问 shell 那样造成太多破坏。换句话说，更少的二进制文件意味着更小的体积和更高的安全性，不过这是以痛苦的调试为代价的。

或许你不应在生产环境中 attach 和调试容器，而应该使用日志和监控。

但如果你确实需要调试，又想保持小体积该怎么办？

＃　小体积的 Alpine 基础镜像
你可以使用 Alpine 基础镜像替换 distroless 基础镜像。

Alpine Linux 是：一个基于 musl libc 和 busybox 的面向安全的轻量级 Linux 发行版。换句话说，它是一个体积更小也更安全的 Linux 发行版。不过你不应该理所当然地认为他们声称的就一定是事实，让我们来看看它的镜像是否更小。

先修改 Dockerfile，让它使用 node:8-alpine：
```dockerfile
FROM node:8 as build
WORKDIR /app
COPY package.json index.js ./
RUN npm install
FROM node:8-alpine
COPY --from=build /app /
EXPOSE 3000
CMD ["npm", "start"]
```
使用下面的命令构建镜像：
```bash
$ docker build -t node-alpine .
```
现在可以检查一下镜像大小：
```bash
$ docker images | grep node-alpine
node-alpine   aa1f85f8e724   69.7MB
69.7MB！
```
甚至比 distrless 镜像还小！

现在可以 attach 到正在运行的容器吗？让我们来试试。

让我们先启动容器：
```bash
$ docker run -p 3000:3000 -ti --rm --init node-alpine
Example app listening on port 3000!
```
你可以使用以下命令 attach 到运行中的容器：
```sh
$ docker exec -ti 9d8e97e307d7 bash
OCI runtime exec failed: exec failed: container_linux.go:296: starting container process caused "exec: \"bash\": executable file not found in $PATH": unknown
```
看来不行，但或许可以使用 shell？
```sh
$ docker exec -ti 9d8e97e307d7 sh / #
```
成功了！现在可以 attach 到正在运行的容器中了。

看起来很有希望，但还有一个问题。

Alpine 基础镜像是基于 muslc 的——C 语言的一个替代标准库，而大多数 Linux 发行版如 Ubuntu、Debian 和 CentOS 都是基于 glibc 的。这两个库应该实现相同的内核接口。

但它们的目的是不一样的：
- glibc 更常见，速度也更快；
- muslc 使用较少的空间，并侧重于安全性。

在编译应用程序时，大部分都是针对特定的 libc 进行编译的。如果你要将它们与另一个 libc 一起使用，则必须重新编译它们。

**换句话说，基于 Alpine 基础镜像构建容器可能会导致非预期的行为，因为标准 C 库是不一样的。**

你可能会注意到差异，特别是当你处理预编译的二进制文件（如 Node.js C++ 扩展）时。

例如，PhantomJS 的预构建包就不能在 Alpine 上运行。

## 你应该选择哪个基础镜像？
你应该使用 Alpine、distroless 还是原始镜像？

如果你是在生产环境中运行容器，并且更关心安全性，那么可能 distroless 镜像更合适。

添加到 Docker 镜像的每个二进制文件都会给整个应用程序增加一定的风险。

只在容器中安装一个二进制文件可以降低总体风险。

例如，如果攻击者能够利用运行在 distroless 上的应用程序的漏洞，他们将无法在容器中使用 shell，因为那里根本就没有 shell！
> 请注意，OWASP 本身就建议尽量减少攻击表面。

如果你只关心更小的镜像体积，那么可以考虑基于 Alpine 的镜像。

它们的体积非常小，但代价是兼容性较差。Alpine 使用了略微不同的标准 C 库——muslc。你可能会时不时地遇到一些兼容性问题。

原始基础镜像非常适合用于测试和开发。

它虽然体积很大，但提供了与 Ubuntu 工作站一样的体验。此外，你还可以访问操作系统的所有二进制文件。

再回顾一下各个镜像的大小：

node:8  681MB

node:8  使用多阶段构建为 678MB

gcr.io/distroless/nodejs  76.7MB

node:8-alpine  69.7MB