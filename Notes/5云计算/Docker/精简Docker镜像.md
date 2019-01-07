# 一、优化基础镜像

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

# 二、串联 Dockerfile 指令

在定义 Dockerfile 时，如果太多的使用 RUN 指令，经常会导致镜像有特别多的层，镜像很臃肿，而且甚至会碰到超出最大层数（127层）限制的问题，遵循 Dockerfile 最佳实践，应该把多个命令串联合并为一个RUN（**通过运算符&&和/ 来实现**），每一个 RUN 要精心设计，确保安装构建最后进行清理，这样才可以降低镜像体积，以及最大化的利用构建缓存。

**将多条 RUN 命令串联起来构建的镜像大小是每条命令分别 RUN 的三分之一。**

> 提示：为了应对镜像中存在太多镜像层，Docker 1.13 版本以后，提供了一个压扁镜像功能，即将 Dockerfile 中所有的操作压缩为一层。这个特性还处于**实验阶段**，Docke r默认没有开启，如果要开启，需要在启动Docker时添加-experimental 选项，并在Docker build 构建镜像时候添加 --squash 。

# 三、使用多阶段构建

Dockerfile 中每条指令都会为镜像增加一个镜像层，并且你需要在移动到下一个镜像层之前清理不需要的组件。实际上，有一个 Dockerfile 用于开发（**其中包含构建应用程序所需的所有内容**）以及一个用于生产的瘦客户端，它只包含你的应用程序以及运行它所需的内容。这被称为“建造者模式”。**Docker 17.05.0-ce** 版本以后支持多阶段构建。使用多阶段构建，你可以在 Dockerfile 中使用多个 FROM 语句，每条 FROM 指令可以使用不同的基础镜像，这样您可以选择性地将服务组件从一个阶段 COPY 到另一个阶段，在最终镜像中只保留需要的内容。

构建镜像，你会发现生成的镜像只有上面 COPY 指令指定的内容，镜像大小只有 2M。这样在以前使用两个 Dockerfile（一个 Dockerfile 用于开发和一个用于生产的瘦客户端），现在使用多阶段构建就可以搞定。

# 四、构建业务服务镜像技巧
Docker 在 build 镜像的时候，如果某个命令相关的内容没有变化，会使用上一次缓存（cache）的文件层，在构建业务镜像的时候可以注意下面两点：

1. 不变或者变化很少的体积较大的依赖库和经常修改的自有代码分开；
2. 因为 cache 缓存在运行 Docker build 命令的本地机器上，建议固定使用某台机器来进行 Docker build，以便利用 cache。

下面是构建 Spring Boot 应用镜像的例子，用来说明如何分层。其他类型的应用，比如 Java WAR 包，Nodejs的npm 模块等，可以采取类似的方式。

1. 在 Dockerfile 所在目录，解压缩 maven 生成的 jar 包。
2. Dockerfile 我们把应用的内容分成 4 个部分 COPY 到镜像里面：其中前面 3 个基本不变，第 4 个是经常变化的自有代码。最后一行是解压缩后，启动 spring boot 应用的方式。

这样在构建镜像时候可大大提高构建速度。

# 五、其他优化办法

## 1、RUN命令中执行apt、apk或者yum类工具技巧

如果在 RUN 命令中执行 apt、apk 或者 yum 类工具，可以借助这些工具提供的一些小技巧来减少镜像层数量及镜像大小。举几个例子：

1. 在执行 apt-get install -y 时增加选项--no-install-recommends ，可以不用安装建议性（非必须）的依赖，也可以在执行 apk add 时添加选项--no-cache 达到同样效果；
2. 执行 yum install -y 时候， 可以同时安装多个工具，比如 yum install -y gcc gcc-c++ make …。将所有 yum install 任务放在一条 RUN 命令上执行，从而减少镜像层的数量；
3. 组件的安装和清理要串联在一条指令里面，如 apk --update add php7 && rm -rf /var/cache/apk/* ，因为 Dockerfile的每条指令都会产生一个文件层，如果将 apk add … 和 rm -rf … 命令分开，清理无法减小apk命令产生的文件层的大小。 Ubuntu或 Debian可以使用 rm -rf /var/lib/apt/lists/* 清理镜像中缓存文件；CentOS 等系统使用 yum clean all 命令清理。

## 2、压缩镜像

Docker 自带的一些命令还能协助压缩镜像，比如 export 和 import。


使用这种方式需要先将容器运行起来，而且这个过程中会丢失镜像原有的一些信息，比如：导出端口，环境变量，默认指令。

