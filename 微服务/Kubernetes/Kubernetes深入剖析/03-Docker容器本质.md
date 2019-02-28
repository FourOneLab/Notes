# 例子
用docker部署一个Python编写的Web应用，代码如下：


```
from flask import Flask
import socket
import os

app = Flask(__name__)

@app.route('/')
def hello():
    html = "<h3>Hello {name}!</h3>" \
           "<b>Hostname:</b> {hostname}<br/>"           
    return html.format(name=os.getenv("NAME", "world"), hostname=socket.gethostname())

if __name__ == "__main__":
    app.run(host='0.0.0.0', port=80)
```
这段代码中使用Flask框架启动了一个web服务器，唯一共功能就是：如果当前环境中有“NAME”这个环境变量，就把它打印在“Hello”后，否则就打印“Hello world”，最后再打印出当前环境的hostname。

这个应用的依赖被定义在同目录下的requirements.txt文件中：

```
$ cat requirements.txt
Flask
```

将这样一个应用容器化的第一部，就是制作容器镜像。有两种方式：
1. 制作rootfs（比较麻烦）
2. Dockerfile（很便捷）


```
# 使用官方提供的 Python 开发镜像作为基础镜像
FROM python:2.7-slim

# 将工作目录切换为 /app
WORKDIR /app

# 将当前目录下的所有内容复制到 /app 下
ADD . /app

# 使用 pip 命令安装这个应用所需要的依赖
RUN pip install --trusted-host pypi.python.org -r requirements.txt

# 允许外界访问容器的 80 端口
EXPOSE 80

# 设置环境变量
ENV NAME World

# 设置容器进程为：python app.py，即：这个 Python 应用的启动命令
CMD ["python", "app.py"]
```

查看当前目录下的文件：

```
$ ls
Dockerfile  app.py   requirements.txt
```

在当前目录下，让Docker制作镜像：

```
$ docker build -t helloworld .
```
-t 参数为这个镜像加上一个Tag，docker build会自动加载当前目录下的Dockerfile文件，然后按照顺序执行文件中的原语。

**这个过程可以等同于Docker使用基础镜像启动了一个容器，然后在容器中依次执行Dockerfile中的原语。**

> Dockerfile中的每个原语执行后，都会生成一个对应的镜像层。即使原语本身并没有明显地修改文件的操作（比如，ENV原语），它对应的层也会存在。**只不过在外界看来这个层是空的。**

docker bulid 操作完成后，通过docker images 查看结果：

```
[root@128 Dockerfile]# docker images
REPOSITORY          TAG                 IMAGE ID            CREATED             SIZE
helloworld          latest              314b99082eb0        11 seconds ago      130MB
python              2.7-slim            804b0a01ea83        3 weeks ago         120MB
```
通过 docker run 启动容器：

```
docker run -p 4000:80 helloword
```

因为在Dockerfile的CMD中指定了启动容器后运行的进程，因此在上面的命令后面可以不写需要启动的进程，否则需要使用如下的命令：

```
$ docker run -p 4000:80 helloworld python app.py
```
容器启动之后，使用docker ps查看：

```
[root@128 ~]# docker ps
CONTAINER ID        IMAGE               COMMAND             CREATED             STATUS              PORTS                  NAMES
e7501877191e        helloworld          "python app.py"     43 seconds ago      Up 42 seconds       0.0.0.0:4000->80/tcp   suspicious_lichterman
```
在启动容器的时候，使用-p参数将容器内的80端口映射到宿主机的4000端口，然后可以通过宿主机的4000端口访问容器中的进程：

```
[root@128 ~]# curl localhost:4000
<h3>Hello World!</h3><b>Hostname:</b> e7501877191e<br/>
```

如果在运行容器的时候没有暴露端口，那么需要**通过docker inspect命令查看到当前运行着的容器的IP地址**才能访问，而不能通过宿主机的IP地址+暴露的端口号来访问，如下：

```
[root@128 ~]# docker inspect 47982cd180a1
        "NetworkSettings": {
            "Bridge": "",
            "SandboxID": "2d7fe94c1301614cc5b4bd076f6d9afae28183af92d881ddbb34d5fb704d8470",
            "HairpinMode": false,
            "LinkLocalIPv6Address": "",
            "LinkLocalIPv6PrefixLen": 0,
            "Ports": {
                "80/tcp": null
            },
            "SandboxKey": "/var/run/docker/netns/2d7fe94c1301",
            "SecondaryIPAddresses": null,
            "SecondaryIPv6Addresses": null,
            "EndpointID": "1ba15c1758f95b8e0527f5a6555c52189d5b443b41439c398e2623b52d958109",
            "Gateway": "172.17.0.1",
            "GlobalIPv6Address": "",
            "GlobalIPv6PrefixLen": 0,
            "IPAddress": "172.17.0.2",
            "IPPrefixLen": 16,
            "IPv6Gateway": "",
            "MacAddress": "02:42:ac:11:00:02",
            "Networks": {
                "bridge": {
                    "IPAMConfig": null,
                    "Links": null,
                    "Aliases": null,
                    "NetworkID": "a52595db8607583e18e115387c9758f21900dac948bd7e5c7c2ba8edf8077b56",
                    "EndpointID": "1ba15c1758f95b8e0527f5a6555c52189d5b443b41439c398e2623b52d958109",
                    "Gateway": "172.17.0.1",
                    "IPAddress": "172.17.0.2",
                    "IPPrefixLen": 16,
                    "IPv6Gateway": "",
                    "GlobalIPv6Address": "",
                    "GlobalIPv6PrefixLen": 0,
                    "MacAddress": "02:42:ac:11:00:02",
                    "DriverOpts": null
                }
            }
        }


[root@128 ~]# curl 172.17.0.2:80
<h3>Hello World!</h3><b>Hostname:</b> 47982cd180a1<br/>
```

# docker exec
**使用docker exec命令可以进入容器，那么它是如何做到的呢？**
Linux Namespace创建的隔离空间虽然看不见摸不着，但是一个进程的Namespace信息在宿主机上以文件形式存在。

通过以下命令查看docker 容器的进程号（PID）：

```
[root@128 app]#  docker inspect --format '{{ .State.Pid }}' 47982cd180a1
17932
```
通过查看宿主机的proc文件，可以看到容器进程的所有Namespace对应的文件：

```
[root@idc-128 ~]# ls -l /proc/17932/ns
total 0
lrwxrwxrwx 1 root root 0 Nov  8 16:48 ipc -> ipc:[4026532537]
lrwxrwxrwx 1 root root 0 Nov  8 16:48 mnt -> mnt:[4026532535]
lrwxrwxrwx 1 root root 0 Nov  8 16:29 net -> net:[4026532540]
lrwxrwxrwx 1 root root 0 Nov  8 16:48 pid -> pid:[4026532538]
lrwxrwxrwx 1 root root 0 Nov  8 17:05 user -> user:[4026531837]
lrwxrwxrwx 1 root root 0 Nov  8 16:48 uts -> uts:[4026532536]
```
可以看到，每个进程的每种Linux Namespace都在对应的/proc/[进程号]/ns 下有一个对应的虚拟文件，并且链接到真实的Namespace文件上。

有了这些Linux Namespace的文件后，就可以加入到一个已经存在的Namespace中，**即一个进程，可以选择加入到某个进程已有的Namespace中，从而达到进入这个进程所在容器的目的**。

这个操作依赖的是Linux的setns()系统调用，通过如下代码说明整个过程：

```
#define _GNU_SOURCE
#include <fcntl.h>
#include <sched.h>
#include <unistd.h>
#include <stdlib.h>
#include <stdio.h>

#define errExit(msg) do { perror(msg); exit(EXIT_FAILURE);} while (0)

int main(int argc, char *argv[]) {
    int fd;

    fd = open(argv[1], O_RDONLY);
    if (setns(fd, 0) == -1) {
        errExit("setns");
    }
    execvp(argv[2], &argv[2]);
    errExit("execvp");
}
```
- 以上代码的**功能**， 接收两个参数，第一个是当前argv[1]，表示当前进程要加入的Namespace文件的路径，第二个参数，是要在这个Namespace里运行的进程。
- 以上代码的**核心操作**，通过open()系统调用打开了指定的Namespace文件，并把这个文件的描述符fd交给setns()使用，在setns()执行后，当前进程就加入了这个文件对应的Linux Namespace中。

## docker commit
docker commit 实际上就是在容器运行起来后，把最上层的“可读写层”，加上原先容器镜像的只读层，打包组合成一个新的镜像，**原先的只读层在宿主机上是共享的，不占用额外空间**。

因为使用的是联合文件系统，所以在容器中对镜像rootfs所做的任何修改，都会被操作系统先复制到这个可读写层，然后再修改。即 Copy-on-Write

有了Init层的存在，就是为了避免在commit的时候，把容器自己对/etc/hosts等文件的修改也一起提交掉。

# Volume（数据卷）
容器技术使用rootfs机制和Mount Namespace，构建出了++与宿主机完全隔离开的文件系统环境++。那么以下两个问题如何解决：
1. 容器里进程新建的文件，怎么才能让宿主机获取到？
2. 宿主机上的文件和目录，怎么才能让容器里的进程访问到？

Docker Volume解决以上问题，Volume机制，++允许将宿主机上指定的目录或者文件，挂载到容器里面进行读取和修改操作++。

在Docker项目里，支持两种Volume声明方式：

```
$ docker run -v /test ...
$ docker run -v /home:/test ...
```

以上两种方式的本质实际上是一样的，都是**把一个宿主机的目录挂载进容器的/test目录**。

1. 第一种情况，没有显示声明宿主机目录，所以Docker会默认在宿主机上创建一个**临时目录**/var/lib/docker/volumes/[VOLUME_ID]/_data，然后挂载到容器的/test目录上。
2. 第二种情况，Docker会直接把宿主机的/home目录挂载到容器的/test目录上。

**如何做到将宿主机的目录或文件挂载到容器中？**

> 在容器进程被创建之后，尽管开启了Mount Namespace，但是在它执行chroot或pivot_root之前，容器进程一直可以看到宿主机的整个文件系统。

++宿主机的文件系统也包括要运行的容器镜像。++
- 容器镜像的各层被保存在/var/lib/docker/aufs/diff目录下
- 容器启动**后**，镜像各层被**联合挂载**在/var/lib/docker/aufs/mnt/目录下

挂载完成后，容器的rootfs就准备好了。

因此，实现宿主机的目录挂载到容器中，只要在rootfs准备好之后，在执行chroot之前，把volume指定的宿主机目录（比如/home），挂载到指定的容器目录（比如/test）在宿主机上对应的目录（即/var/lib/docker/aufs/mnt/[可读写层 ID]/test）上，这个volume的挂载工作就完成。


```
graph LR
/home --> /var/lib/docker/aufs/mnt/可读写层ID/test
```
因为，在执行挂载操作时，“容器进程”已经创建了，此时的Mount Namespace已经开启，所以这个挂载事件只在这个容器里可见。宿主机上是看不见容器内部的这个挂载点的。**这就保证了容器的隔离性不会被Volume打破。**

> 这里提到的“**容器进程**”是Docker创建的一个容器初始化进程（dockerinit），而不是应用进程（ENTRYPOINT+CMD）。

dockerinit负责完成：
1. 根目录的准备
2. 挂载设备和目录
3. 配置hostname
4. 等一系列需要在容器内进行的初始化操作

完成以上操作后，它通过execv()系统调用，让应用进程取代自己，成为容器里的PID=1的进程。

这里使用的挂载技术是Linux的绑定挂载（bind mount）机制。它的主要作用就是++允许你将一个目录或文件，而不是整个设备，挂载到一个指定的目录上++。并且，**这时在该挂载点上进行的任何操作，只是发生在被挂载点的目录或文件上，原挂载点的内容则会被隐藏起来且不受影响**。

> **绑定挂载实际上是一个inode替换的过程**。在Linux操作系统中，inode可以理解为存放文件内容的“对象”，而dentry（目录项），就是访问这个inode所使用的“指针”
![image](https://static001.geekbang.org/resource/image/95/c6/95c957b3c2813bb70eb784b8d1daedc6.png)

如上图所示，mount --bind /home /test 命令会将/home目录挂载到/test上。其实相当于将/test的dentry重定向到了/home 的inode。这样当修改/test目录时，实际修改的是/home目录的inode。**这也就是为何，一旦执行umount命令，/test目录原先的内容就会恢复：因为修改真正发生在的是/home目录里。**

++在一个正确的时机，进行一次绑定挂载，Docker就成功地将一个宿主机上的目录或文件，不动声色地挂载到容器中++。这样，进程在容器中对这个/test目录的所有操作，都实际发生在宿主机的对应目录（如/home或/var/lib/docker/volumes/[VOLUME_ID]/_data）,而不会影响镜像的内容。

**那么这个/test目录的内容，既然被挂载在容器rootfs的可读写层，它会不会被docker commit提交呢？**

- 并不会。
- 因为，容器的镜像操作，比如docker commit 都是发生在宿主机空间的。而由于Mount Namespace的隔离作用，宿主机不知道这个绑定挂载的存在，所以在宿主机看来，容器中可读写层的/test目录（/var/lib/docker/aufs/mnt/[可读写层ID]/test）始终是空的。
- Docker在一开始会创建/test这个目录作为挂载点，所以执行了docker commit之后，在新的镜像中，会多出来一个空的/test目录。

## 总结
Docker容器全景图

![image](https://static001.geekbang.org/resource/image/2b/18/2b1b470575817444aef07ae9f51b7a18.png)

这个容器进程“python app.py”，运行在由Linux Namespace和Cgroups构成的隔离环境里，而它运行所需的各种文件，比如python，app.py，以及整个操作系统文件，则由多个联合挂载在一起的rootfs层提供。

1. 这些rootfs层的最下层，是来自Docker镜像的只读层。
2. 在只读层上，Docker自己添加的Init层，用来存放被临时修改过的/etc/hosts等文件。
3. rootfs的最上层是一个可读写层，以Copy-on-Write的方式存放任何对只读层的修改，容器生命的Volume的挂载点，也在这一层。
