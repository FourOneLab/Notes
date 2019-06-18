dumb-init是一个简单的进程管理器和init系统，设计用于在最小容器环境（如Docker）中作为`PID 1`运行。它被部署为一个用C编写的小型静态链接二进制文件。

轻量级容器已经普及了运行单个进程或服务的想法，而没有像`systemd`或`sysvinit`这样的普通初始化系统。**但是，省略init系统通常会导致对进程和信号的错误处理，并且可能导致诸如无法正常停止容器或泄漏应该被销毁的容器之类的问题**。

`dumb-init`使你可以以简单的命令前缀的方式使用它，来充当`PID 1`并立即将你的命令作为子进程生成，并在收到信号时正确处理和转发信号。

# 为何需要一个init系统
通常，当你启动Docker容器时，你正在执行的进程将变为`PID 1`，从而赋予它作为容器的init系统所带来的怪癖和责任。这提出了两个常见问题：
1. 在大多数情况下，信号将无法正确处理
   - 当进程在普通Linux系统上发送信号时，内核首先检查进程为该信号注册的自定义信号处理器，如果不存在则回退到默认行为（在`SIGTERM`上终止进程）。
   - Linux内核对作为`PID 1`运行的进程应进行特殊的信号处理。如果接收信号的进程是`PID 1`，内核会进行特殊处理；如果它没有为信号注册处理器，内核将不会回退到默认行为且不做任何反应。换句话说，如果你的进程没有明确处理这些信号的信号处理器，发送SIGTERM信号给它将完全没有效果。

   > 一个常见的例子是使用docker运行`my-container`脚本的CI作业：将`SIGTERM`发送到`docker run`进程通常会终止`docker run`命令，但容器却还在后台运行着而没有被终止。

2. 孤儿僵尸进程无法被适当的方式捕获
   1. 通常，父进程会立即调用`wait()`系统调用来避免产生常驻僵尸进程。
   2. 如果父进程在其子进程之前退出，则该子进程就变成“孤儿”，并会在`PID 1`下重新挂载其他父进程。
   3. 因此，init系统负责调动`wait()`处理孤儿僵尸进程。因为，大多数进程都不会碰巧被重新挂载的随机父进程调用`wait()`，因此，**容器通常以几个根植于`PID 1`的僵尸进程结束。**

> 进程在退出时变为僵尸，并且在其父进程调用`wait()`系统调用（或`wait()`调用的某些变体）之前保持僵尸状态(作为“**已停止**”的进程保留在进程表中)。

# dumb-init能做什么
`dumb-init`作为`PID 1`运行，就像一个简单的init系统。它启动一个进程，然后将所有收到的信号代理到以该子进程为根的会话。

由于你的进程不再是`PID 1`，当它从`dumb-init`接收信号时，将应用默认的信号处理程序，并且你的进程将按照预期运行。如果你的进程死了，`dumb-init`也会死掉，逐一清理仍然存在的任何其他进程。

## 会话行为
在默认模式下，`dumb-init`建立以子进程为根的会话，并将信号发送到整个进程组。如果你有一个表现不佳的子进程（比如一个shell脚本），这个子进程在死亡前通常不会给它的子进程发出信号。

这实际上可以在常规进程监视器（如daemontools或supervisord）中的Docker容器之外用于监视shell脚本。通常，shell接收到的`SIGTERM`之类的信号不会转发给它的子进程；只有shell进程死掉才会发送信号。如果使用`dumb-init`，你可以在`Shebang`中使用`dumb-init`编写shell脚本：

```bash
#!/usr/bin/dumb-init /bin/sh
my-web-server &  # launch a process in the background
my-other-server  # launch another process in the foreground
```

通常，发送到shell的`SIGTERM`会杀死shell，但这些进程仍然会处于运行状态（不论是后台还是前台进程）。使用`dumb-init`，你的子进程将收到与shell所执行的相同的信号。

如果你希望仅将信号发送到直接子进程，则可以使用`--single-child`参数运行，或者在运行`dumb-init`时设置环境变量`DUMB_INIT_SETSID = 0`。在这种模式下，`dumb-init`完全透明；甚至可以把多个串起来（比如`dumb-init dumb-init echo 'oh,hi'`）。


## 信号重写
`dumb-init`允许在代理进程之前重写输入信号。这在始终发送标准信号（例如SIGTERM）的Docker 容器管理程序（如Mesos或Kubernetes）中非常有用。

> 某些应用程序需要不同的停止信号才能进行优雅的清理退出。例如，要将信号SIGTERM（编号15）重写为SIGQUIT（编号3），只需在命令行中添加`--rewrite 15:3`即可。要完全丢弃信号，可以将其重写为特殊数字0。

### 信号重写特例
在`setsid`模式下运行时，在大多数情况下转发`SIGTSTP/SIGTTIN/SIGTTOU`是不够的，因为，如果进程没有为这些信号添加自定义信号处理器，内核将不会应用默认信号处理行为（这将暂停进程），因为它是孤儿进程组的成员。因此，将这三个信号的默认重写设置为`SIGSTOP`。如果需要，可以通过将信号重写回原始值来选择不使用此行为。

有一点需要注意：对于作业控制信号（SIGTSTP，SIGTTIN，SIGTTOU），`dumb-init`在收到信号后总是会自动挂起，即使你把它重写为其他东西也是如此。

# 在Docker容器内安装
五种在容器中安装`dumb-init`的方式：
## 方法1 ：从发行版的软件包存储库（Debian，Ubuntu等）安装
许多主流的Linux发行版（包括Dabian从stretch版本开始）和Debian的衍生版如Ubuntu（从bionic版本开始）都已经在官方的仓库中包含了`dumb-init`安装包。

基于Debian的发行版，可以运行`apt install dumb-init`来安装，就像安装其他的软件包一样。

> 大多数发行版提供的`dumb-init`不是静态链接文件。一般来说，这没什么毛病，但意味着这些版本的`dumb-init`在复制到其他Linux发行版时就不能用了，这与静态链接版本不同。

## 方法2：通过apt网络服务器（Debian/Ubuntu）安装
如果有内部apt服务器，将`dumb-init`以`.deb`的格式上传到服务器然后在使用它。在Dockerfiles中，可以通过`apt install dumb-init`，它就可以使用了。

>可以从GIthub的Release页面下载Debian安装包,也可以执行`nake builddeb`自行生成。

## 方法3：手动安装`.deb`安装包（Debian/Ubuntu）
如果没有apt网络服务器，可以手动执行`dpkg -i`指令来安装`.deb`安装包，可以选择两种方式将`.deb`放到容器中：
1. 挂载一个目录
2. 通过wget命令下载

如下所示：
```dockerfile
RUN wget https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64.deb
RUN dpkg -i dumb-init_*.deb
```

## 方法4：直接下载二进制包
由于dumb-init是作为静态链接的二进制文件发布的，因此通常只需将其放入image即可。在Dockerfile中执行如下所示的操作：

```dockerfile
RUN wget -O /usr/local/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v1.2.2/dumb-init_1.2.2_amd64
RUN chmod +x /usr/local/bin/dumb-init
```

## 方法5：通过PyPI安装
虽然`dumb-init`完全用C语言编写，但还提供了一个Python包来编译和安装二进制文件。它可以使用`pip`从PyPI安装。首先安装一个C编译器（在Debian/Ubuntu上执行`apt-get install gcc`），然后执行`pip install dumb-init`。

从1.2.0开始，PyPI的软件包可作为预编译的存档文件使用，无需在常见的Linux发行版上进行编译。

# 使用方式
一旦安装在Docker容器中，只需在命令前加上dumb-init（确保按照docker[推荐的JSON语法格式](./01-dumb-init简介.md)编写命令，查看附录部分）。

在Dockerfile中，使用`dumb-init`作为容器的入口点是一个好习惯。“`entrypoint`”是一个局部指令，它被添加到的CMD指令之前，使其非常适合`dumb-init`：

```dockerfile
# Runs "/usr/bin/dumb-init -- /my/script --with --args"
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# or if you use --rewrite or other cli flags
# ENTRYPOINT ["dumb-init", "--rewrite", "2:3", "--"]

CMD ["/my/script", "--with", "--args"]
```

如果在基础镜像中声明入口点，那么任何以它为基础的镜像都不需要再声明dumb-init。他们可以像往常一样只设置CMD。

对于交互式一次性使用，可以手动添加它：
```bash
$ docker run my_container dumb-init python -c 'while True: pass'

# 在没有dumb-init的情况下运行同样的命令将导致无法在没有SIGKILL的情况下停止容器，但是使用dumb-init，可以发送更多人性化的信号，如SIGTERM
```

对于`CMD`和`ENTRYPOINT`使用**JSON语法**非常重要。否则，Docker会调用shell来运行你的命令，从而导致shell为PID 1而不是dumb-init。

## 使用shell进行预启动挂钩
容器通常需要做一些在开始构建期间无法完成的预启动工作。例如，可能希望根据环境变量模板化一些配置文件。将它与dumb-init集成的最佳方法如下：

```dockerfile
ENTRYPOINT ["/usr/bin/dumb-init", "--"]
CMD ["bash", "-c", "do-some-pre-start-thing && exec my-server"]
```
通过仍然使用dumb-init作为入口点，你可以始终拥有适当的init系统。

bash命令的exec部分很重要，因为它将bash进程替换为你的服务，因此shell仅在启动时暂时存在。

# 编译 dumb-init
构建dumb-init二进制文件需要一个有效的编译器和libc头文件，默认为glibc。
```bash
$ make
```
## 通过musl编译
由于glibc，静态编译的dumb-init超过700KB，现在musl是一个可选选项。在Debian/Ubuntu apt-get install musl-tools上安装源代码和包装器，然后只需：
```bash
$ CC=musl-gcc make
```
当用musl静态编译时，二进制大小约为20KB。

## 编译Debian安装包
我们使用标准的Debian约束来指定编译依赖关系（查看debian/control）。一个简单的入门方法是`apt-get install build-essential devscripts equivs`，然后`sudo mk-build-deps -i --remove`自动安装所有缺少的编译依赖项。然后，可以使用`make builddeb`来编译dumb-init Debian软件包。

如果你更喜欢使用Docker自动编译Debian软件包，只需运行`make builddeb-docker`即可。这更容易，但要求在计算机上运行Docker。
