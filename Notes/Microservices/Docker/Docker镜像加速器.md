1. 获取一个官方的镜像，例如mysql、wordpress，基于这些基础镜像我们可以开发自己个性化的应用
2. 可以使用Docker命令行工具来下载官方镜像。
但是因为网络原因，我们下载一个300M的镜像需要很长的时间，甚至下载失败。

阿里云容器Hub服务提供了官方的镜像站点加速官方镜像的下载速度。



# 使用镜像加速器
在不同的系统下面，配置加速器的方式有一些不同，所以我们介绍主要的几个操作系统的配置方法。

关于加速器的地址，你只需要登录[容器Hub服务](https://cr.console.aliyun.com)的控制台，左侧的加速器帮助页面就会显示为你独立分配的加速地址。

## 具体配置
当你下载安装的Docker Version不低于**1.10**时，建议直接通过daemon config进行配置。
使用配置文件 /etc/docker/daemon.json（没有时新建该文件）

```
{
    "registry-mirrors": ["<your accelerate address>"]
}
```

```
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json <<-'EOF'
{
  "registry-mirrors": ["https://gn6g9no6.mirror.aliyuncs.com"]
}
EOF
sudo systemctl daemon-reload
sudo systemctl restart docker
```
重启Docker Daemon就可以了。






