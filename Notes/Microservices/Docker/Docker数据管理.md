容器的数据管理操作：
1. 对数据进行持久化
2. 多个容器之间进行数据共享

容器中数据管理的两种方式：
1. 数据卷（Data Volume）：容器内数据直接映射到本地主机环境
2. 数据卷容器（Data Volume Containers）：使用特定容器维护数据卷

# 数据卷
可供容器使用的特殊目录，将主机操作系统目录直接映射进容器，类似于Linux的mount操作

数据卷提供的特性：
1. 数据卷可以在容器之间重用和共享，容器见传递数据变的高效方便
2. 对数据卷内的数据进行修改会立马见效，无论是在容器内操作还是在本地操作
3. 对数据卷的更新不会影响到镜像，解耦了应用和数据
4. 数据卷会一直存在直到没有容器使用，可以安全的卸载

在容器内创建数据卷示例：
```
docker run  -d -P  --name web -v /webapp training/webapp python app.py
//创建了一个数据卷挂载到/webapp目录
```

挂载一个主机目录作为数据卷

```
docker run  -d -P  --name web -v /src/webapp:/webapp:ro training/webapp python app.py
//加载主机的/src/webapp目录到容器的/webapp目录
//主机目录必须是绝对路径，如果目录不存在Docker会自动创建
//挂载的目录的权限默认为rw,追加ro修改目录权限
```
挂载一个主机文件作为数据卷

```
docker run  -d -P  --name web -v ~/.bash_history:/.bash_history  ubuntu /bin/bash
//可以记录在容器中输入过的历史命令
```

# 数据卷容器
如果需要在多个容器之间共享一些持续更新的数据，可以使用数据卷容器。

数据卷容器是容器的一种，专门用来提供数据卷供其他容器挂载。

1. 创建数据卷容器

```
docker run -it -v /dbdata  --name dbdata ububtu
//在容器中创建了一个数据卷挂载在/dbdata目录
```
2. 在其他容器中使用--volumes-from来挂载dbadatra容器中的数据卷

```
docker run -it --volumes-from dbdata  --name d1 ububtu
docker run -it --volumes-from dbdata  --name d2 ububtu
//此时容器d1和d2都挂载同一个数据卷到相同的/dbdata目录
//三个容器中任何一个在该目录下的写入，其他容器也都可以看到
```
注意：
- 多次使用--volumes-from参数来从多个容器挂载多个数据卷
- 可以从其他已经挂载了数据卷的容器来挂在数据卷
- 使用--volumes-from参数所挂载数据卷的容器自身并不需要保持在运行状态

删除挂载的容器，数据卷不会被删除，需要删除数据卷的时候，需要在最后一个挂载数据卷的容器中显式的删除使用 docker rm -v 指定。

**使用数据卷容器可以让用户在容器之间自由地升级和移动数据**

# 利用数据卷容器迁移数据
1. 备份数据卷容器中的数据

```
docker run --volume-from dbdata -v ${pwd}:/backup --name worker ubuntu tar cvf /backup/backup.tar /dbdata
```
    1. 利用Ubuntu镜像创建容器worker
    2. worker容器挂载dbdata数据卷容器中的数据卷/dbdata
    3. 挂载本地目录到容器中的/backup目录
    4. 容器启动后执行tar cvf /backup/backup.tar /dbdata，将/dbdata目录中的数据保存到/backup，即宿主机的当前目录

2. 恢复数据到容器中

```
docker run --volumr-from dbdata -v ${pwd}:/backup  busybox tar xvf /backup/backup.tar
```

    1. 创建新的容器挂载数据卷容器dbdata中的/dbdata数据卷
    2. 挂载本机当前路径到容器的/backup目录
    3. 容器启动后执行解压缩命令将之前备份的数据恢复出来




