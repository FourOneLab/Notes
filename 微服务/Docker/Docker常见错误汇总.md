1.
```
certificate has expired or is not yet valid
```
一般是因为本地系统时间错误导致证书过期。

解决方法：
同步服务器之间的时间。

2.
```
dial unix /var/run/docker.sock: permission denied
```
在 Linux 环境下，一些新装了 docker 的用户，特别是使用了 sudo 命令安装好了 Docker 后，发现当前用户一执行 docker 命令，就会报没权限的错误。

解决方式：
```
sudo usermod -aG docker $USER
```

将用户添加到docker组

> 这里说的权限问题，是指使用 docker 命令操作本机 dockerd 引擎，也就是通过 `/var/run/docker.sock` 来操作 dockerd 引擎，只有这种有之前说的权限类的问题。

>而 docker 命令还可以操作远程 dockerd 的引擎，也就是 `-H `参数，或者 `DOCKER_HOST` 环境变量所指定的 Docker 主机。这种情况通讯走的是**网络、HTTP**，不会有权限问题。所以，如果不打算操作本机的 dockerd 引擎，则不需要将用户加入 docker 组，也是可以操作远程服务器的。
