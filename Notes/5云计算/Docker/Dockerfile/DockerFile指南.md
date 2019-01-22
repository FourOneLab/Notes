1. Dockerfile 是专门用来进行自动化构建镜像的编排文件，通过 docker build 命令来自动化地从Dockerfile 所描述的步骤来构建自定义的 Docker镜像，这比我们去命令行一条条指令执行的方式构建高效得多。

2. Dockerfile 提供了统一的配置语法，因此通过这样一份配置文件，我们可以在各种不同的平台上进行分发，需要时通过 Dockerfile 构建一下就能得到所需的镜像。

3. Dockerfile 通过与镜像配合使用，使得 Docker镜像构建之时可以充分利用 “镜像的缓存功能”，因此也提效不少！

> 写 Dockerfile 也像写代码一样，一份精心设计、Clean Code 的 Dockerfile 能在提高可读性的同时也大大提升Docker的使用效率

# 基础镜像的选择
基于某个Linux基础镜像作为底包，然后打包进我需要的功能从而形成自己的镜像

**这里选择基础镜像时是有讲究的**：
- 应当尽量选择**官方**镜像库里的基础镜像；
- 应当选择**轻量级**的镜像做底包

就典型的Linux基础镜像来说，大小关系如下：Ubuntu > CentOS > Debian
> 相比 Ubuntu，更推荐使用最轻量级的 Debian镜像，它是一个完整的Release版，可以放心使用

# 多使用标签Tag有好处
1. 构建镜像时，给其打上一个易读的镜像标签有助于帮助了解镜像的功能，比如：

``` bash
docker build -t centos:wordpress
# 例如上面的这个centos镜像是用来做wordpress用的，所以已经集成了wordpress功能，这一看就很清晰明了
```
2. 应该在 Dockerfile 的 FROM 指令中明确指明标签 Tag，不要再让 Docker daemon 去猜，如FROM debian:latest充分利用**镜像缓存**。

## 镜像缓存
>由 Dockerfile 最终构建出来的镜像是在基础镜像之上一层层叠加而得，因此在过程中会产生一个个新的镜像层。Docker daemon 在构建镜像的过程中会缓存一系列中间镜像。

docker build镜像时，会顺序执行Dockerfile中的指令，并同时比较当前指令和其基础镜像的所有子镜像，若发现有一个子镜像也是由相同的指令生成，则命中缓存，同时可以直接使用该子镜像而避免再去重新生成了。

为了有效地使用缓存，需要保证 Dockerfile 中指令的连续一致，*尽量将相同指令的部分放在前面*，而将有差异性的指令放在后面。


# ADD & COPY
虽然两者都可以添加文件到镜像中，但在一般用法中，还是**推荐以COPY指令**为首选，**原因在于ADD指令并没有COPY指令来的纯粹**，ADD会添加一些额外功能，典型的如下:

``` bash
ADD codesheep.tar.gz /path
# ADD一个压缩包时，其不仅会复制，还会自动解压，而有时我们并不需要这种额外的功能
```
**注意：** 在需要添加多个文件到镜像中的时候，不要一次性集中添加，而是选择按需在必要时逐个添加即可，因为这样有利于利用镜像缓存。

## 尽量使用docker volume

虽然上面一条原则说推荐通过 COPY 命令来向镜像中添加多个文件，然而实际情况中，若文件大而多的时候还是应该优先用 docker -v 命令来挂载文件，而不是依赖于 ADD 或者 COPY。

# CMD & ENTRYPOINT
Dockerfile 制作镜像时，会组合 CMD 和 ENTRYPOINT 指令来作为容器运行时的默认命令：即 CMD + ENTRYPOINT。此时的默认命令组成中：

- ENTRYPOINT 指令**固定不变**，即容器运行时是无法修改的
- CMD 指令**可以改变**，docker run 命令中提供的参数会覆盖CMD指令中的内容

举个例子：
``` bash
FROM debian:latest
MAINTAINER Sugoi
ENTRYPOINT [ "ls", "-l"]
CMD ["-a"]
# 以默认命令运行容器，执行的是 ls -a -l 命令

docker run -it --rm --name test debian:codesheep -t
# docker run 中增加参数 -t ，执行的是 ls -l -t，即 Dockerfile 中的 CMD 原参数被覆盖了
```

### 因此推荐的使用方式是:

- 使用exec格式的ENTRYPOINT指令 **设置固定的默认命令和参数**
- 使用CMD指令 **设置可变的参数**

# 不推荐在 Dockerfile中 做端口映射

Dockerfile 可以通过EXPOSE指令将容器端口映射到主机端口上，但**这样会导致镜像在一台主机上仅能启动一个容器**！

所以应该在 docker run 命令中用 -p 参数来指定端口映射，而不要将该工作置于 Dockerfile 之中

``` bash
EXPOSE 8080:8899  # 尽量避免这种方式

EXPOSE 8080 # 选择仅仅暴露端口即可，端口映射的任务交给 docker run
```

# 使用 Dockerfile 来共享镜像

推荐通过共享 Dockerfile 的方式来共享镜像，优点多多：

- 通过 Dockerfile 构建的镜像用户可以清楚地看到构建的过程，Dockerfile 作为一个编排文件同样可以入库做版本控制，这样也可以回溯
使用 Dockerfile 构建的镜像具有确定性
