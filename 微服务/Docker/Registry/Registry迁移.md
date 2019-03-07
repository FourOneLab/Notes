Docker Registry是Dockers镜像的存储和管理中心，在一个**离线**或**没有外网网络**的环境下使用大量docker镜像，需要提供一个镜像仓库时需要怎么操作比较合适呢？

Registry可以通过push的方式上传镜像到仓库中，默认将上传的镜像数据保存在`/var/lib/registry`目录。那么在离线时我们可以:
1. 将Regsitry本身的镜像save成tar包，
2. 将/var/lib/registry数据目录也打包成tar包，
3. 然后在目标机器上通过volume的形式挂载运行即可提供服务。

> 注意；如果被迁入的服务器上已经有registry镜像，那么就只需要打包保存镜像的数据目录即可。

# 具体操作步骤
## 方法一，数据保存在本地文件中
1. 创建保存registry数据的目录
```bash
mkdir /var/lib/registry_data
```
2. 添加http访问权限
修改配置文件`/etc/docker/daemon.json`,默认情况下需要使用https方式访问，进行如下修改：
```json
{
    "insecure-registries":["127.0.0.1:5000"]
}
```
修改完成之后，需要重启docker进程。
3. 运行Registry官方镜像
```bash
docker run
-d --name=registry  \
-v /var/lib/registry_data:/var/lib/registry  \
-p 5000:5000 docker.io/registry:2.7
```
4. 将需要迁移的镜像都push到registry中
```bash
docker tag <name>:<tag> 127.0.0.1:5000/<name>:<tag>
docker push  127.0.0.1:5000/<name>:<tag>
```
5. 将registry镜像导出
```bash
docker save -o registry.tar docker.io/registry
```
6. 将保存镜像的数据目录打包
```bash
tar -zcvf registry-data.tar.gz /var/lib/registry_data
```
7. 计算校验值
``` bash
md5sum/sha256 registry.tar
md5sum/sha256 registry-data.tar.gz
```
8. 按照第二步修改被迁入主机的docker配置

9. 导入registry镜像
```bash
docker load -i registry.tar
```
10. 解压镜像数据压缩包
```bash
tar -zxvf registry-data.tar.gz -C /var/lib/registry_data
```
11. 运行registry容器
```bash
docker run \
-d --name=registry \
-v /var/lib/registry-data:/var/lib/registry \
-p 5000:5000 docker.io/registry:2.7
```
12. 验证使用，根据B机器所在网络，修改tag，然后通过docker pull的方式拉去镜像。

## 方法二，数据保存在volume中
通常情况下，为了方便管理，registry都会挂载一个名字为registry的volume。registry是一个无状态的服务，迁移名为registry的volume即可。

> 注意，保证迁出节点上registry的运行是绑定在名为registry的volume上的

1. 备份当前registry中的数据
```bash
tar -zcvf registry-data.tar.gz /var/lib/docker/volumes/registry/_data/docker/
```
2. 在目标节点创建volume
```bash
docker volume create registry
```
3. 解压镜像数据到volume所在的目录中
```bash
tar -zxvf registry-data.tar.gz
```
4. 启动registry容器
```bash
docker run -d \
    --name registry \
    --restart=always \
    -p 5000:5000 \
    -v registry:/var/lib/registry \
    registry:2.7
```

5. 验证新的registry
```bash
curl -i http://127.0.0.1:5000/v2/_catalog
# 通过unix套接字来通信
curl --unix-socket /var/run/docker.sock http://127.0.0.1:5000/v2/_catalog
curl --no-buffer -XGET --unix-socket /docker.sock http://localhost/events
```
