Registry配置基于YAML文件。虽然具有开箱即用的默认值，但是在将系统投入生产之前详尽地查看它。

# 覆盖特定的配置选项
在从官方镜像运行Registry的典型配置中，可以通过`-e`参数传递到`docker run`或者在Dockerfile中使用ENV指令来传递环境变量。

要覆盖配置选项，可以创建名为`REGISTRY_variable`的环境变量，其中variable为需要设置的名字，下划线表示缩进级别，如下：
```
REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY=/somewhere

storage:
  filesystem:
    rootdirectory: /var/lib/registry
```
REGISTRY_STORAGE_FILESYSTEM_ROOTDIRECTORY环境变量将会使用`/somewhere`来覆盖`/var/lib/registry`。

> 注意，以上方式用于修改单个环境变量的值

# 覆盖整个配置文件
修改单个环境变量遇到问题，或者需要修改整个配置文件的时候，通过将YAML配置文件作为容器的卷的方式修改整个配置文件。
通常，从头开始创建一个新的配置文件，命名config.yml，然后在docker run命令中指定它：
```bash
$ docker run -d -p 5000:5000 --restart=always --name registry \
             -v `pwd`/config.yml:/etc/docker/registry/config.yml \
             registry:2
```
示例YAML文件（config.yaml）如下：
```yaml
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
auth:
  htpasswd:
    realm: basic-realm
    path: /etc/registry
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
```

完整的配置文件参考官方文档：https://docs.docker.com/registry/configuration/
