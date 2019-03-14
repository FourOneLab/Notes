# 搭建MySQL集群

相比于Etcd、Cassandra等“原生”就考虑分布式需求的项目，MySQL以及很多其他的数据库项目，在分布式集群上搭建并不友好，甚至有点“原始”。

**使用StatefulSet将MySQL集群搭建过程“容器化”**。

## 部署过程
1. 部署一个“主从复制（Master-Slave Replication）”的MySQL集群
2. 部署一个主节点（Master）
3. 部署多个从节点（Slave）
4. 从节点需要水平扩展
5. 所有的写操作只在主节点上执行
6. 读操作可以在所有节点上执行

典型的主从模式MySQL集群如下所示：

![image](https://static001.geekbang.org/resource/image/bb/02/bb2d7f03443392ca40ecde6b1a91c002.png)

> 在常规环境中，部署这样一个主从模式的MySQL集群的主要**难点**在于：如何让从节点能拥有主节点的数据，即：如何配置主（Master）从（Slave）节点的复制与同步。

### 第一步：备份主节点
所以在安装好MySQL的Master节点后，需要做的第一步工作：**通过XtraBackup将Master节点的数据备份到指定目录**。

> XtraBackup是业界主要使用的开源MySQL备份和恢复工具。

这个过程会自动在目标目录生成一个备份信息文件，名叫：xtrabackup_binlog_info。这个文件一般会包含如下两个信息：
```bash
$ cat xtrabackup_binlog_info
TheMaster-bin.000001     481
```
这两个信息会在接来配置Slave节点的时候用到。

### 第二步：配置从节点
Slave节点在第一次启动之前，需要先把Master节点的备份数据，连同备份信息文件，一起拷贝到自己的数据目录（/var/lib/mysql）下，然后执行如下SQL语句：
```sql
TheSlave|mysql> CHANGE MASTER TO
                MASTER_HOST='$masterip',
                MASTER_USER='xxx',
                MASTER_PASSWORD='xxx',
                MASTER_LOG_FILE='TheMaster-bin.000001',
                MASTER_LOG_POS=481;
```
其中，`MASTER_LOG_FILE`和`MASTER_LOG_POS`，就是上一步中备份对应的二进制日志（Binary Log）文件的名称和开始的位置（偏移量），也正是`xtrabackup_binlog_info`文件里的那两部分内容（即`TheMaster-bin.000001`和`481`）.

### 第三步：启动从节点
执行如下SQL语句来启动从节点：
```sql
TheSlave|mysql> START SLAVE;
```
Slave节点启动并且会使用备份信息文件中的二进制日志文件和偏移量，与主节点进行数据同步。

### 第四步：在这个集群中添加更多Slave节点
**注意：新添加的Slave节点的备份数据，来自于已经存在的Slave节点**。

所以，在这一步，需要将Slave节点的数据备份在指定目录。而这个备份操作会自动生成另一份备份信息文件，名叫：xtrabackup_slave_info。这个文件也包含`MASTER_LOG_FILE`和`MASTER_LOG_POS`字段。

然后再执行第二步和第三步。

## 迁移到kubernetes集群中
从上述步骤不难免看出，将部署MySQL集群的流程迁移到kubernetes项目上，需要能够“容器化”地解决下面的“三个问题”。
1. Master与Slave需要有不同的配置文件（my.cnf）
2. Master与Slave需要能够传输备份信息文件
3. 在Slave第一次启动之前，需要执行一些初始化SQL操作

**由于MySQL本身同时拥有拓扑状态（主从）和存储状态（MySQL数据保存在本地）**，所以使用StatefulSet来部署MySQL集群。

### 问题一：主从节点需要不同的配置文件
为主从节点分别准备两份配置文件，然后根据pod的序号挂载进去。配置信息应该保存在ConfigMap里供Pod使用：

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: mysql
  labels:
    app: mysql
data:
  master.cnf: |
    # 主节点 MySQL 的配置文件
    [mysqld]
    log-bin
  slave.cnf: |
    # 从节点 MySQL 的配置文件
    [mysqld]
    super-read-only
```
定义`master.cnf`和`slave.cnf`两个MySQL配置文件。
- master.cnf：开启log-bin，即使用二进制文件的方式进行主从复制
- slave.cnf：开启super-read-only，即从节点会拒绝除了主节点的数据同步操作之外的所有写操作（对用户只读）。

在ConfigMap定义里的data部分，是key-value格式的。比如master.cnf就是这份配置数据的Key，而`“|”`后面的内容，就是这份配置数据的Value。这份数据将来挂载到Master节点对应的Pod后，就会在Volume目录里生成一个叫做master.cnf的文件。

然后创建两个Service来供StatefulSet以及用户使用，定义如下：
```yaml
apiVersion: v1
kind: Service
metadata:
  name: mysql
  labels:
    app: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  clusterIP: None
  selector:
    app: mysql
---
apiVersion: v1
kind: Service
metadata:
  name: mysql-read
  labels:
    app: mysql
spec:
  ports:
  - name: mysql
    port: 3306
  selector:
    app: mysql
```

#### 相同点

这两个Service都代理了所有携带app=mysql标签的pod。端口映射都是用service的3306端口对应Pod的3306端口。

#### 不同点

- 第一个service是headless service（ClusterIP=None），它的作用是通过为pod分配DNS记录来固定它的拓扑状态。比如`mysql-0.mysql`和`mysql-1.mysql`这样的DNS名字，其中编号为0的节点就是主节点。
- 第二个Service是一个常规的Service。

#### 规定
- 所有的用户请求都必须访问第二个Service被自动分配的DNS记录，即`mysql-read`或者访问这个Service的VIP。这样读请求就可以被转发到任意一个MySQL的主节点或者从节点。
- 所有用户的写请求，则必须直接以DNS的方式访问到MySQL的主节点，也就是`mysql-0.mysql`这条DNS记录。

> **Kubernetes中所有的Service和pod对象，都会被自动分配同名的DNS记录。**

### 问题二，主从节点需要传输备份文件
推荐的做法：先搭建框架，再完善细节。其中Pod部分如何定义，是完善细节时的重点。

创建StatefulSet对象的大致框架如下：
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: mysql
spec:
  selector:
    matchLabels:
      app: mysql
  serviceName: mysql
  replicas: 3
  template:
    metadata:
      labels:
        app: mysql
    spec:
      initContainers:
      - name: init-mysql
      - name: clone-mysql
      containers:
      - name: mysql
      - name: xtrabackup
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql
  volumeClaimTemplates:
  - metadata:
      name: data
    spec:
      accessModes: ["ReadWriteOnce"]
      resources:
        requests:
          storage: 10Gi
```
首先定义一些通用的字段：
1. selector，表示这个StatefulSet要管理的Pod必须携带app=mysql这个label
2. serviceName，声明这个StatefulSet要使用的Headless Servie的名字是mysql
3. replicas，表示这个StatefulSet定义的MySQL集群有三个节点（一个主节点两个从节点）
4. volumeClaimTemplate（PVC模板），还需要管理存储状态，通过PVC模板来为每个Pod创建PVC。

> StatefulSet管理的“有状态应用”的多个实例，也是通过同一份Pod模板创建出来的，使用同样的Docker镜像。**这就意味着，如果应用要求不同类型节点的镜像不一样，那就不能再使用StatefulSet，应该考虑使用Operator**。

重点就是Pod部分的定义，也就是StatefulSet的`template`字段。

**StatefulSet管理的Pod都来自同一个镜像，编写Pod时需要分别考虑这个pod的Master节点做什么，Slave节点做什么**。

#### 第一步，从ConfigMap中，获取MySQL的Pod对应的配置文件
需要根据主从节点不同的角色进行相应的初始化操作，为每个Pod分配对应的配置文件。**MySQL要求集群中的每个节点都要唯一的ID文件（server-id.cnf）**。

初始化操作使用InitContainer完成，定义如下：
```yaml
      ...
      # template.spec
      initContainers:
      - name: init-mysql
        image: mysql:5.7
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 从 Pod 的序号，生成 server-id
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          echo [mysqld] > /mnt/conf.d/server-id.cnf
          # 由于 server-id=0 有特殊含义，我们给 ID 加一个 100 来避开它
          echo server-id=$((100 + $ordinal)) >> /mnt/conf.d/server-id.cnf
          # 如果 Pod 序号是 0，说明它是 Master 节点，从 ConfigMap 里把Master 的配置文件拷贝到 /mnt/conf.d/ 目录；
          # 否则，拷贝 Slave 的配置文件
          if [[ $ordinal -eq 0 ]]; then
            cp /mnt/config-map/master.cnf /mnt/conf.d/
          else
            cp /mnt/config-map/slave.cnf /mnt/conf.d/
          fi
        volumeMounts:
        - name: conf
          mountPath: /mnt/conf.d
        - name: config-map
          mountPath: /mnt/config-map
```
这个初始化容器主要完成的初始化操作为：
1. 从Pod的hostname里，读取到了Pod的序号，以此作为MySQL节点的server-id。
2. 通过这个序号判断当前Pod的角色（序号为0表示为Master，其他为Slave），从而把对应的配置文件从`/mnt/config-map`目录拷贝到`/mnt/conf.d`目录下。

其中文件拷贝的源目录`/mnt/config-map`，就是CongifMap在这个Pod的Volume，如下所示：
```yaml
      ...
      # template.spec
      volumes:
      - name: conf
        emptyDir: {}
      - name: config-map
        configMap:
          name: mysql
```
通过这个定义，init-mysql在声明了挂载config-map这个Volume之后，ConfigMap里保存的内容，就会以文件的方式出现在它的`/mnt/config-map`目录当中。

而文件拷贝的目标目录，即容器里的`/mnt/conf.d/`目录，对应的则是一个名叫conf的emptyDir类型的Volume。基于Pod Volume 共享的原理，当InitContainer复制完配置文件退出后，后面启动的MySQL容器只需要直接声明挂载这个名叫conf的Volume，它所需要的.cnf 配置文件已经出现在里面了。

#### 第二步：在Slave Pod启动前，从Master或其他Slave里拷贝数据库数据到自己的目录下
再定义一个初始化容器来完成这个操作：
```yaml
      ...
      # template.spec.initContainers
      - name: clone-mysql
        image: gcr.io/google-samples/xtrabackup:1.0
        command:
        - bash
        - "-c"
        - |
          set -ex
          # 拷贝操作只需要在第一次启动时进行，所以如果数据已经存在，跳过
          [[ -d /var/lib/mysql/mysql ]] && exit 0
          # Master 节点 (序号为 0) 不需要做这个操作
          [[ `hostname` =~ -([0-9]+)$ ]] || exit 1
          ordinal=${BASH_REMATCH[1]}
          [[ $ordinal -eq 0 ]] && exit 0
          # 使用 ncat 指令，远程地从前一个节点拷贝数据到本地
          ncat --recv-only mysql-$(($ordinal-1)).mysql 3307 | xbstream -x -C /var/lib/mysql
          # 执行 --prepare，这样拷贝来的数据就可以用作恢复了
          xtrabackup --prepare --target-dir=/var/lib/mysql
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
```
这个初始化容器使用xtrabackup镜像（安装了xtrabackup工具），主要进行如下操作：
1. 在它的启动命令里首先进行判断，当初始化所需的数据（`/var/lib/mysql/mysql`目录）已经存在，或者当前Pod是Master时，不需要拷贝操作。
2. 使用Linux自带的ncat命令，向DNS记录为“mysql-<当前序号减一>.mysql”的Pod（即当前Pod的前一个Pod），发起数据传输请求，并且直接使用xbstream命令将收到的备份数据保存在`/var/lib/mysql`目录下。传输数据的方式包括scp、rsync等。
3. 拷贝完成后，初始化容器还需要对`/var/lib/mysql`目录执行`xtrabackup --prepare`命令，目的是保证拷贝的数据进入一致性状态，这样数据才能被用作数据恢复。

> 3307是一个特殊的端口，运行着一个专门负责备份MySQL数据的辅助进程。

**这个容器的`/var/lib/mysql`目录，实际上是一个名为data的PVC**。这就保证哪怕宿主机服务器宕机，数据库的数据也不会丢失。

因为Pod的Volume是被Pod中的容器所共享的，所以后面启动的MySQL容器，就可以把这个Volume挂载到自己的`/var/lib/mysql`目录下，直接使用里面的备份数据进行恢复操作。

> 通过两个初始化容器完成了对主从节点配置文件的拷贝，主从节点间备份数据的传输操作。

**注意，StatefulSet里面的所有Pod都来自同一个Pod模板，所以在定义MySQL容器的启动命令时，需要区分Master和Slave节点的不同情况**。

1. 直接启动Master角色没有问题
2. 第一次启动的Slave角色，在执行MySQL启动命令之前，需要使用初始化容器拷贝的数据进行容器的初始化操作。
3. 容器是单进程模型，Slave角色的MySQL启动前，谁负责执行初始化SQL语句？

#### 第三步，Slave角色的MySQL容器启动前，执行初始化SQL语句

为这个MySQL容器定义一个额外的sidecar容器，来完成初始化SQL语句的操作：
```yaml
      ...
      # template.spec.containers
      - name: xtrabackup
        image: gcr.io/google-samples/xtrabackup:1.0
        ports:
        - name: xtrabackup
          containerPort: 3307
        command:
        - bash
        - "-c"
        - |
          set -ex
          cd /var/lib/mysql
          
          # 从备份信息文件里读取 MASTER_LOG_FILEM 和 MASTER_LOG_POS 这两个字段的值，用来拼装集群初始化 SQLA
          if [[ -f xtrabackup_slave_info ]]; then
            # 如果 xtrabackup_slave_info 文件存在，说明这个备份数据来自于另一个 Slave 节点。这种情况下，XtraBackup 工具在备份的时候，就已经在这个文件里自动生成了 "CHANGE MASTER TO" SQL 语句。所以，我们只需要把这个文件重命名为 change_master_to.sql.in，后面直接使用即可
            mv xtrabackup_slave_info change_master_to.sql.in
            # 所以，也就用不着 xtrabackup_binlog_info 了
            rm -f xtrabackup_binlog_info
          elif [[ -f xtrabackup_binlog_info ]]; then
            # 如果只存在 xtrabackup_binlog_inf 文件，那说明备份来自于 Master 节点，我们就需要解析这个备份信息文件，读取所需的两个字段的值
            [[ `cat xtrabackup_binlog_info` =~ ^(.*?)[[:space:]]+(.*?)$ ]] || exit 1
            rm xtrabackup_binlog_info
            # 把两个字段的值拼装成 SQL，写入 change_master_to.sql.in 文件
            echo "CHANGE MASTER TO MASTER_LOG_FILE='${BASH_REMATCH[1]}',\
                  MASTER_LOG_POS=${BASH_REMATCH[2]}" > change_master_to.sql.in
          fi
          
          # 如果 change_master_to.sql.in，就意味着需要做集群初始化工作
          if [[ -f change_master_to.sql.in ]]; then
            # 但一定要先等 MySQL 容器启动之后才能进行下一步连接 MySQL 的操作
            echo "Waiting for mysqld to be ready (accepting connections)"
            until mysql -h 127.0.0.1 -e "SELECT 1"; do sleep 1; done
            
            echo "Initializing replication from clone position"
            # 将文件 change_master_to.sql.in 改个名字，防止这个 Container 重启的时候，因为又找到了 change_master_to.sql.in，从而重复执行一遍这个初始化流程
            mv change_master_to.sql.in change_master_to.sql.orig
            # 使用 change_master_to.sql.orig 的内容，也是就是前面拼装的 SQL，组成一个完整的初始化和启动 Slave 的 SQL 语句
            mysql -h 127.0.0.1 <<EOF
          $(<change_master_to.sql.orig),
            MASTER_HOST='mysql-0.mysql',
            MASTER_USER='root',
            MASTER_PASSWORD='',
            MASTER_CONNECT_RETRY=10;
          START SLAVE;
          EOF
          fi
          
          # 使用 ncat 监听 3307 端口。它的作用是，在收到传输请求的时候，直接执行 "xtrabackup --backup" 命令，备份 MySQL 的数据并发送给请求者
          exec ncat --listen --keep-open --send-only --max-conns=1 3307 -c \
            "xtrabackup --backup --slave-info --stream=xbstream --host=127.0.0.1 --user=root"
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
```
在这个sidecar容器的启动命令中，完成两部分工作。

#### 工作一：MySQL节点初始化。
这个初始化需要的SQL是sidecar容器拼装出来、保存在名为change_master_to.sql.in的文件里的。具体过程如下：
1. sidecar容器首先判断当前Pod的`/var/lib/mysql`目录下，是否有`xtrabackup_slave_info`这个备份信息文件。
    - 如果**有**，说明这个目录下的备份数据库是由一个Slave节点生成的。这种情况下，xtrabackup工具在备份的时候，就已经在这个文件里生成了`“CHANGE MASTER TO”`SQL语句。所以只需要把这个文件名重命名为`change_master_to.sql.in`，然后直接使用即可。
    - 如果**没有**，但是存在`xtrabackup_binlog_info`文件，那就说明备份数据来自Master节点。这种情况下，sidecar容器需要解析这个备份文件，读取`MASTER_LOG_FILE`和`MASTER_LOG_POS`这两个字段的值，用它们拼装出初始化SQL语句，然后把这句SQL写入`change_master_to.sql.in`文件中。

> 只要`change_master_to.sql.in`存在，那就说明下一个步骤是进行集群初始化操作。

2. sidecar容器执行初始化操作。即，读取并执行`change_master_to.sql.in`里面的`“CHANGE MASTER TO”`SQL语句，在执行START SLAVE命令，一个Slave角色就启动成功了。

> Pod里面的容器没有先后顺序，所以在执行初始化SQL之前，必须先执行`select 1`来检查MySQL服务是否已经可用。

**当初始化操作都执行完成后，需要删除前面用到的这些备份信息文件，否则下次这个容器重启时，就会发现这些文件已经存在，然后又重新执行一次数据恢复和集群初始化的操作，这就不对了。同样的`change_master_to.sql.in`在使用后也要被重命名，以免容器重启时因为发现这个文件而又执行一遍初始化**。


#### 工作二：启动数据传输服务
sidecar容器使用ncat命令启动一个工作在3307端口上的网络发送服务。一旦收到数据传输请求时，sidecar容器就会调用`xtrabackup --backup`命令备份当前MySQL的数据，然后把备份数据返回给请求者。

> 这就是为什么在初始化容器里面定义数据拷贝的时候，访问的是**上一个MySQL节点**的3307端口。

**sidecar容器和MySQL容器处于同一个Pod中，它们是直接通过`localhost`来访问和备份MySQL的数据的，非常方便**。数据的备份方式有多种，也可使用`innobackupex`命令。

完成上述初始化操作后，定义的MySQL容器就比较简单，如下：
```yaml
      ...
      # template.spec
      containers:
      - name: mysql
        image: mysql:5.7
        env:
        - name: MYSQL_ALLOW_EMPTY_PASSWORD
          value: "1"
        ports:
        - name: mysql
          containerPort: 3306
        volumeMounts:
        - name: data
          mountPath: /var/lib/mysql
          subPath: mysql
        - name: conf
          mountPath: /etc/mysql/conf.d
        resources:
          requests:
            cpu: 500m
            memory: 1Gi
        livenessProbe:
          exec:
            command: ["mysqladmin", "ping"]
          initialDelaySeconds: 30
          periodSeconds: 10
          timeoutSeconds: 5
        readinessProbe:
          exec:
            # 通过 TCP 连接的方式进行健康检查
            command: ["mysql", "-h", "127.0.0.1", "-e", "SELECT 1"]
          initialDelaySeconds: 5
          periodSeconds: 2
          timeoutSeconds: 1
```

使用MySQL官方镜像，数据目录`/var/lib/mysql`，配置文件目录`/etc/mysql/conf.d`。并且为容器定了livenessProbe，通过mysqladmin Ping命令来检查它是否健康。同时定义readinessProbe，通过SQL（select 1）来检查MySQL服务是否可用。凡是readinessProbe检查失败的Pod都会从Service中被踢除。

> 如果MySQL容器是Slave角色时，它的数据目录中的数据就是来自初始化容器从其他节点里拷贝而来的备份。它的配置目录里的内容则是是来自ConfigMap对应的Volume。它的初始化工作由sidecar容器完成。

### 创建PV
使用Rook存储插件创建PV：
```yaml
$ kubectl create -f rook-storage.yaml
$ cat rook-storage.yaml
apiVersion: ceph.rook.io/v1beta1
kind: Pool
metadata:
  name: replicapool
  namespace: rook-ceph
spec:
  replicated:
    size: 3
---
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: rook-ceph-block
provisioner: ceph.rook.io/block
parameters:
  pool: replicapool
  clusterNamespace: rook-ceph
```

在这里使用到StorageClass来完成这个操作，它的作用是自动地为集群里存在的每个PVC调用存储插件创建对应的PV，从而省去了手动创建PV的过程。

> 在使用Rook时，在MySQL的StatefulSet清单文件中的volumeClaimTemplates字段需要加上声明storageClassName=rook-ceph-block，这样才能使用Rook提供的持久化存储。

# 总结
1. “人格分裂”：在解决需求的过程中，一定要记得思考，该Pod在扮演不同角色时的不同操作。
2. “阅后即焚”：很多“有状态应用”的节点，只是在第一次启动的时候才需要做额外处理。所以，在编写YAML文件时，一定要考虑到**“容器重启”**的情况，不能让这一次的操作干扰到下一次容器启动。
3. “容器之间平等无序”：除非InitContainer，否则一个Pod里的多个容器之间，是完全平等的。**所以，镜像设计的sidecar，绝不能对容器的启动顺序做出假设，否则就需要进行前置检查**。

> StatefulSet就是一个特殊的Deployment，只是这个“Deployment”的每个Pod实例的名字里，都携带了一个唯一并且固定的编号。

- 这个编号的顺序，固定了Pod之间的**拓扑关系**；
- 这个编号对应的DNS记录，固定了Pod的**访问方式**；
- 这个编号对应的PV，绑定了Pod与**持久化存储**的关系。

所有，当Pod被删除重建时，这些“状态”都会保持不变。

**如果应用没办法通过上述方式进行状态的管理，就代表StatefulSet已经不能解决它的部署问题，Operator可能是一个更好的选择。**

