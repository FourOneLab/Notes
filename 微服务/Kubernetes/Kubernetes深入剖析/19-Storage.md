容器化一个应用比较复杂的地方是**状态**的管理，常见的状态就是**存储状态**。

- PV：描述持久化存储数据卷，这个API对象主要定义的是持久化存储在**宿主机上的目录**，比如一个NFS挂载目录。
- PVC：描述的Pod所希望使用的持久化存储的**属性**。比如Volume存储的大学、可读写权限等。

通常情况，PV对象是由运维人员事先创建在kubernetes集群中待用，可以定义如下的PV：
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: nfs
spec:
  storageClassName: manual
  capacity:
    storage: 1Gi
  accessModes:
    - ReadWriteMany
  nfs:
    server: 10.244.1.4
    path: "/"
```

PVC对象通常由开发人员创建，或者以PVC模板的方式成为StatefulSet的一部分，然后由StatefulSet控制器负责CHAUNGJIAN带编号的PVC，如下：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: nfs
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: manual
  resources:
    requests:
      storage: 1Gi
```
用户创建的PVC要真正被容器使用起来，就必须先和某个符合条件的PV进行绑定，这需要检查两部分：
1. PV和PVC的spec字段，比如PV的存储（`Storage`）大小，必须满足PVC的要求。
2. PV和PVC的`storageClassName`字段必须一样

绑定成功后，Pod就能够像使用hostPath等常规类型发Volume一样，在YAML文件中声明使用这个PVC，如下所示：
```yaml
apiVersion: v1
kind: Pod
metadata:
  labels:
    role: web-frontend
spec:
  containers:
  - name: web
    image: nginx
    ports:
      - name: web
        containerPort: 80
    volumeMounts:
        - name: nfs
          mountPath: "/usr/share/nginx/html"
  volumes:
  - name: nfs
    persistentVolumeClaim:
      claimName: nfs

```
Pod在volumes字段中声明要使用的PV名字，等这个Pod创建后裔，kubelet就会把这个PVC所对应的PV挂载到Pod容器内的目录上。

**PV与PVC的设计，和面向对象的思想完全一样**。开发人员只需要和PVC这个接口打交道，不必关心具体的实现细节。
- PVC可以理解为持久化存储的“接口”，提供了对某种持久化存储的描述，但不提供具体的实现，
- PV负责持久化存储的具体实现

> 创建Pod是，集群中没有适合的PV与PVC进行绑定，即容器需要的volume不存在，那么Pod的启动就会报错。当需要的PV被创建后，PVC可以再次与之绑定，从而使得Pod能够顺利启动。

Volume Controller专门处理持久化存储的控制器，维护多个控制循环，其中之一就是帮助PV和PVC进行绑定，即PersistenVolumeController。它会不断的查看当前每一个PVC是否处于Bound状态，如果没有处于绑定状态，则会遍历全部可用的PV，并尝试将PVC与PV进行绑定。

**这样kubernetes就能保证，用户提交的每一个PVC，只要有合适的PV出现，就能够很快进入绑定状态**。

所谓的PV与PVC的绑定，就是将这个PV对象的名字填写在PVC对象`spec.volumeName`字段，这样获取了PVC就能知道绑定的PV。

> 所谓容器的Volume，其实就是一个将宿主机上的目录，跟一个容器里的目录绑定挂载在一起。所谓的持久化Volume，就是这个宿主机的目录具备持久性（目录中的内容不会因为容器删除而被清理掉，也不跟当前宿主机绑定）。当容器被重启或者其他节点上重建出来，它仍然可以通过挂载这个Volume访问到这些内容。

**hostPath、emptyDir类型的volume都不具备这样的特性：既会被kubelet清理掉，也不能被迁移到其他节点上**。大多数持久化volume的实现依赖于远程存储服务：
- 远程文件存储（NFS、GlusterFS）
- 远程块存储（公有云提供的远程磁盘）等。

kubernetes的工作就是使用这些存储服务，来为容器准备一个持久化的宿主机目录，以供将来进行绑定挂载使用。所谓持久化是是容器在这个目录里写的文件，都会保存在远程存储中，从而使得这个目录具备了持久性。

## 持久化宿主机目录的过程，两步走
当pod调度到某个节点，kubelet就会负责为这个pod创建它的Volume目录，默认情况下，kubelet为volume创建的目录是如下所示的宿主机上的路径：
```bash
/var/lib/kubelet/pods/<Pod 的 ID>/volumes/kubernetes.io~<Volume 类型 >/<Volume 名字 >
```
### GCP
kubelet根据volume的类型进行具体的操作，如果volume是远程块存储，如GCE的Persistent Disk，kubelet需要先调用GCP的API，将它所提供的Persistent Disk挂载到Pod所在的宿主机上。相当于执行如下命令：
```bash
$ gcloud compute instances attach-disk < 虚拟机名字 > --disk < 远程磁盘名字 >

# 为虚拟机挂载远程磁盘的操作
```
以上操作是第一个阶段，在kubernetes中称为Attach。

为了能够使用这个远程磁盘，kubelet进行第二个操作，格式化这个磁盘设备，然后挂载到宿主机指定的挂载点（宿主机的volume目录）上。相当于执行如下操作：
```bash
# 通过 lsblk 命令获取磁盘设备 ID
$ sudo lsblk
# 格式化成 ext4 格式
$ sudo mkfs.ext4 -m 0 -F -E lazy_itable_init=0,lazy_journal_init=0,discard /dev/< 磁盘设备 ID>
# 挂载到挂载点
$ sudo mkdir -p /var/lib/kubelet/pods/<Pod 的 ID>/volumes/kubernetes.io~<Volume 类型 >/<Volume 名字 >
# 将磁盘设备格式化并挂载到宿主机目录
```
以上操作是第二个节点，称为Mount。

Mount阶段完成后，这个Volume的宿主机目录就是一个“持久化”目录，容器在它里面写入的内容就会被保存在GCP的远程磁盘中。

### NFS
如果volume的类型是远程文件存储NFS，kubelet的处理过程比较简单，直接进行Mount阶段即可。因为远程文件存储一般没有存储设备需要挂载到宿主机。

在Mount的过程中kubelet需要作为client，将远端NFS服务器的目录（如`/`目录）挂载到Volume的宿主机目录上，即相当于执行如下命令：
```bash
$ mount -t nfs <NFS 服务器地址 >:/ /var/lib/kubelet/pods/<Pod 的 ID>/volumes/kubernetes.io~<Volume 类型 >/<Volume 名字 > 

```
通过这个操作volume的宿主机目录就成为了一个远程NFS目录的挂载点，在这个目录下写入的所有文件就会被保存在远程NFS服务上。

在具体的Volume插件的实现接口上，kubernetes分别为这两个阶段提供了两种不同的参数列表：
1. Attach：kubernetes提供的可用参数是nodeName，即宿主机的名字
2. Mount：kubernetes提供的可用参数的dir，即 Volume的宿主机目录

得到持久化的Volume宿主机目录后，kubelet只要把这个Volume目录通过CRI里的Mounts参数，传递给Docker，然后就可以为Pod里的容器挂载这个持久化的Volume，相当于执行如下操作：
```bash
$ docker run -v /var/lib/kubelet/pods/<Pod 的 ID>/volumes/kubernetes.io~<Volume 类型 >/<Volume 名字 >:/< 容器内的目标目录 > 我的镜像 ...

```
> 相应的，在删除PV的时候，kubernetes也需要umount和Dettach两个阶段。

在这个PV的处理过程中，与Pod和容器的启动流程没有太多的耦合，只要kubelet在向Docker发起CRI请求之前，确保持久化的宿主机目录已经处理完毕即可。**在kubernetes中，关于PV的处理过程，是独立与kubelet主控制循环（kubelet sync loop）之外的两个控制循环实现的。**

- Attach和Dettach操作，由Volume Controller负责维护，这个控制循环的名字叫AttachDettchController。它的作用就是不断地检查每一个Pod对应的PV，和这个Pod所在宿主机之间的挂载清理，从而决定是否需要对这个PV进行Attach或者Dettach操作。
> kubernetes内置的控制器，Volume Controller是kube-controller-manager的一部分，所有AttachDettach也是运行在Master节点，Attach操作只需要调用公有云或者具体存储项目的API，并不需要在具体宿主机上执行操作。
- Mount和Umount操作，必须发生在Pod对应的宿主机上，所以必须是kubelet组件的一部分，这个控制循环的名字，叫作VolumeManagerReconciler，运行起来之后，是一个独立于kubelet主循环goroutine。
> 通过将Volume的处理同kubelet的主循环解耦，避免了耗时的远程挂载操作拖慢kubelet的主控制循环，进而导致Pod的创建效率大幅下降的问题。

**kubelet的一个主要设计原则就是它的主控制循环绝对不能被block**。

# StorageClass
PV的创建需要运维人员完成，在大规模的生产环境中，这个工作太麻烦，需要预先创建很多PV，随着需求的变化需要继续添加新的PV。

kubernetes提供了一套可以自动创建PV的机制，Dynamic Provisioning，它的核心在于StorageClass API对象。

**StorageClass对象的作用，就是创建PV的模板**。它会定义 如下两个部分：
1. PV的属性，如存储类型，Volume大小等
2. 创建这个PV所需要用到的存储插件，如Ceph等

有了这两个信息之后，kubernetes就能够根据用户提交的PVC找到一个对应的StorageClass，然后kubernetes就会调用该StorageClass声明的存储插件，创建出需要的PV。

如下所示，volume的类型是GCE的Persistent Disk：
```yaml
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: block-service
provisioner: kubernetes.io/gce-pd   # kubernetes内置的GCE PD存储插件的名字
parameters:     # 这里就是PV的参数
  type: pd-ssd  # PV的类型是SSD格式的GCE远程磁盘
```

如下所示，在本地集群使用rook存储服务：
```yaml
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
  name: block-service
provisioner: ceph.rook.io/block     # 存储插件是rook
parameters:
  pool: replicapool
  #The value of "clusterNamespace" MUST be the same as the one in which your rook cluster exist
  clusterNamespace: rook-ceph
```
在StorageClass的YAML文件之后，运维人员就可以创建StorageClass了，开发人员只需要在PVC中指定storage即可：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: claim1
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: block-service  #指定为storageclass的名字
  resources:
    requests:
      storage: 30Gi
```
**kubernetes只会将storageclass相同的PVC和PV绑定起来**。

> 注意 StorageClass并不是专门为了Dynamic Provisioning而设计的。

上面的例子中在 PV 和 PVC 里都声明了 storageClassName=manual。而集群里，实际上并没有一个名叫 manual 的StorageClass 对象。这完全没有问题，这个时候 Kubernetes 进行的是 Static Provisioning，但在做绑定决策的时候，它依然会考虑 PV 和PVC 的 StorageClass 定义。

而这么做的好处也很明显：这个 PVC 和 PV 的绑定关系，就完全在我自己的掌控之中。

如果集群已经开启了名叫 DefaultStorageClass 的 Admission Plugin，它就会为PVC 和 PV 自动添加一个默认的StorageClass；否则，PVC 的 storageClassName 的值就是“”，这也意味着它只能够跟 storageClassName 也是“”的 PV 进行绑定。

# 总结
如下图：

![](https://static001.geekbang.org/resource/image/e8/d9/e8b2586e4e14eb54adf8ff95c5c18cd9.png)

- PVC 描述的是Pod想要使用的**持久化存储的属性**，比如存储的大小、读写权限等
- PV 描述的是具体的**Volume的属性**，比如volume的类型，挂载的目录，远程存储服务器地址等
- StorageClass的作用时候充当PV的模板，并且只有属于同一个StorageClass的PV和PVC才可以绑定

> StorageClass的另一个重要的作用是指定Provisioner(存储插件),这时候,如果存储插件支持Dynamic Provisioning的话,kubernetes就可以自动创建PV。


# 本地持久化存储
如何解决kubernetes内置的20种持久化数据集不能满足需求的问题？在开源项目中，“不能用、不好用、需定制开发”是开源项目落地的三大常态。

在持久化存储中，本地持久化存储的需求最高，这样的好处很明显。Volume直接使用本地磁盘（SSD），读写性能相比于大多数远程存储来说，要好很多。

> kubernetes v1.10之后，依靠PV、PVC实现了本地持久化存储，Local Persistent Volume。

Local Persistent Volume并不适用于所有应用。它的使用范围非常固定，**如高优先级的系统应用，需要在多个不同节点上存储数据，并且对I/0较为敏感**。典型的应用包括：
1. 分布式数据存储：MongoDB、Cassandra等
2. 分布式文件系统：GlusterFS、Ceph等
3. 需要在本地磁盘上进行大量数据缓存的分布式应用

相比于正常的PV，一旦这些节点宕机且不能恢复，Local Persistent Volume的数据就可能丢失，这就要求**使用Local Persistent Volume的应用必须具备数据备份和恢复能力**，允许把这些数据定时备份到其他位置。

## Local Persistent Volume
设计的难点：
1. 如何把本地磁盘抽象成PV？
2. 调度如何保证Pod始终能被正确地调度到它所请求的Local Persistent Volume所在节点？

### 难点一
> 假设将一个Pod声明使用类型为Local的PV，而这个PV其实是一个hostPath类型的Volume，如果这个hostPath对应的目录在A节点上被事先创建好，那么只需要给这个Pod加上nodeAffinity=nodeA。

事实上，**绝不能把一个宿主机上的目录当做PV使用**。因为：
1. 本地目录的存储行为完全不可控：它所在磁盘随时可能被应用写满，甚至造成整个宿主机宕机
2. 不同的本地目录之间也缺乏哪怕最基础的I/O隔离机制

> 所以，一个Local Persistent Volume对应的存储介质，一定是一块额外（非宿主机根目录使用的主硬盘）挂载在宿主机的错或者块设备，**即一个PV一块盘**。

### 难点二
调度器如何保证Pod始终能被正确地调度到它所请求的Local Persistent Volume。

1. 对于常规的PV，kubernetes都是先调度Pod到某个节点，然后再通过Attach和Mount两个阶段来持久化这台机器上的Volume目录，进而完成Volume目录与容器的绑定挂载。
2. 对于Local PV来说，节点上可供使用的磁盘（块设备），必须是运维人员提前准备好（在不同节点上挂载情况可能完全不同，甚至有的节点上没有这种磁盘）。

> 所以调度器必须知道所有节点与Local PV对应的磁盘的关联关系，然后根据这个信息来调度Pod，**即调度的时候考虑Volume分布**。在kubernetes的调度器中，VolumeBindingChecker过滤条件负责在调度时考虑Volume的分布情况，在v1.11中,这个过滤条件默认开启。

因此在使用Local PV前，需要在集群里配置好磁盘或块设备：
1. 在公有云上等同于给虚拟机额外挂载一个磁盘（如GCE的Local SSD类型的磁盘）。
2. 在私有集群中，有两个方法来解决：
   1. 给宿主机挂载并格式化一个可用的本地磁盘
   2. 对于实验环境，在宿主机上挂载几个RAM Disk来模拟本地磁盘


### 例子
以内存盘为例子进行挂载。
1. 在节点上CHAUNGJIAN挂载点`/mnt/disks`
2. 用RAM Disk模拟本地磁盘

```bash
# 在 node-1 上执行
$ mkdir /mnt/disks
$ for vol in vol1 vol2 vol3; do
    mkdir /mnt/disks/$vol
    mount -t tmpfs $vol /mnt/disks/$vol
done

# 其他节点需要同样的操作来支持Local PV，需要确保这些起床的名字都不重复
```
为本地磁盘定义PV：
```yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: example-pv
spec:
  capacity:
    storage: 5Gi
  volumeMode: Filesystem
  accessModes:
  - ReadWriteOnce
  persistentVolumeReclaimPolicy: Delete
  storageClassName: local-storage
  local:    # 表示这是一个Local PV
    path: /mnt/disks/vol1   # 指定本地磁盘的路径
  nodeAffinity:  # 定义节点亲和性，如果Pod要使用这个PV，就必须调度到node-1
    required:    # kubernetes实现调度时考虑Volume分布的主要方法
      nodeSelectorTerms:
      - matchExpressions:
        - key: kubernetes.io/hostname
          operator: In
          values:
          - node-1
```
创建PV：
```
$ kubectl create -f local-pv.yaml 
persistentvolume/example-pv created

$ kubectl get pv
NAME         CAPACITY   ACCESS MODES   RECLAIM POLICY  STATUS      CLAIM             STORAGECLASS    REASON    AGE
example-pv   5Gi        RWO            Delete           Available                     local-storage             16s

# PV创建成功并几区Available状态
```

使用PV和PVC的最佳实践，创建一个StorageClass来描述这个PV：
```
apiVersion: storage.k8s.io/v1
kind: StorageClass
metadata:
  name: local-storage
provisioner: kubernetes.io/no-provisioner   # 目前不支持Dynamic Provisioning，所有使用这个，因为它没饭在用户创建PVC的时候自动创建对应的PV
volumeBindingMode: WaitForFirstConsumer   # 延迟绑定，告诉kubernetes的volume控制循环，虽然已经发现了StorageClass关联的PV和PVC，但是不要现在就进行绑定（设置PVC的VolumeName字段）操作

```

通常，在提交了PV和PVC的YAML后，kubernetes会根据它们的属性以及StorageClass来进行绑定，绑定成功后Pod才能通过PVC使用这个PV，但是在Local PV中这个流程不行。

> 举个例子，有个Pod声明使用pvc-1，规定只能运行在node-2，此时集群中有两个属性（大小和读写权限）相同的Local PV（PV-1对应磁盘在node-1，PV-2对应磁盘在node-2）。假设kubernetes的Volume控制循环里，首先检查到PVC-1和PV-1匹配，直接绑定在一起。然后kubernetes创建pod，问题来了，Pod声明的PVC-1与node-1的PV-1绑定了，根据调度器必须考虑Volume分布的原则，pod被调度到node-1，但是我们规定是pod要运行在node-2，所有pod调度失败。

所以使用Local PV的时候，必须要推迟绑定PV和PVC。具体而言就是**推迟到调度的时候进行绑定**。等待第一个声明使用该PVC的Pod出现在调度器之后，调度器再综合考虑所有的调度规则（包括每个PV所在的节点位置），来统一决定，这个Pod声明的PVC应该跟哪个PV进行绑定。

**通过延迟绑定机制，原本实时发生在PVC和PV的绑定过程，就被延迟到了Pod第一次调度的时候在调度器中进行，从而保证了这个绑定结果不会影响Pod正常调度**。在具体实现中，调度器实际上维护了一个与Volume Controller类似的控制循环，专门负责为那些声明了“延迟绑定”的PV和PVC进行绑定工作。

> 当一个Pod的PVC尚未完成绑定时，调度器也不会等待，而是直接把这个Pod重新放回调度队列，等到下一个调度周期再做处理。

创建StorageClass：
```bash
$ kubectl create -f local-sc.yaml 
storageclass.storage.k8s.io/local-storage created

```
然后创建普通的PVC就能让pod来使用Local PV：
```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: example-local-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: local-storage   #kubernetes检测到这个PVC不会直接给它绑定
```

创建这个PVC：
```
$ kubectl create -f local-pvc.yaml 
persistentvolumeclaim/example-local-claim created

$ kubectl get pvc
NAME                  STATUS    VOLUME    CAPACITY   ACCESS MODES   STORAGECLASS    AGE
example-local-claim   Pending                                       local-storage   7s

```
PVC会一直处于pending状态，等待绑定。

编写一个Pod来声明使用这个PVC：
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: example-pv-pod
spec:
  containers:
    - name: example-pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: example-pv-storage
  volumes:
  - name: example-pv-storage
    persistentVolumeClaim:
      claimName: example-local-claim
```
一旦创建这个pod之前处于pending的pvc就会编程Bound状态：
```bash
$ kubectl create -f local-pod.yaml 
pod/example-pv-pod created

$ kubectl get pvc
NAME                  STATUS    VOLUME       CAPACITY   ACCESS MODES   STORAGECLASS    AGE
example-local-claim   Bound     example-pv   5Gi        RWO            local-storage   6h

```
在创建的Pod进入调度器之后，绑定操作就开始进行。

像kubernetes这样构建出来的、基于本地存储的Volume，完全可以提供容器持久化存储的功能，所以像StatefulSet这样的有状态编排工具也完全可以通过声明Local类型的pv和pvc来管理应用的存储状态。

手动创建PV（即static的PV管理方式）在删除PV时需要按如下流程执行操作，否则PV删除失败：
1. 删除使用这个PV的Pod
2. 从宿主机移除本地磁盘（如umount）
3. 删除pvc
4. 删除pv

上述操作比较繁琐，kubernetes提供了Static Provision来帮助管理这些PV。

比如，所有磁盘都挂载在宿主机的`/mnt/disks`目录下，当Static Provision启动后，通过DaemonSet自动检查每个宿主机的`/mnt/disks`目录，然后调用kubernetes API，为这些目录下的每一个挂载，创建一个对应的PV对象出来，如下所示：

```bash
$ kubectl get pv
NAME                CAPACITY    ACCESSMODES   RECLAIMPOLICY   STATUS      CLAIM     STORAGECLASS    REASON    AGE
local-pv-ce05be60   1024220Ki   RWO           Delete          Available             local-storage             26s

$ kubectl describe pv local-pv-ce05be60 
Name:  local-pv-ce05be60
...
StorageClass: local-storage
Status:  Available
Claim:  
Reclaim Policy: Delete
Access Modes: RWO
Capacity: 1024220Ki
NodeAffinity:
  Required Terms:
      Term 0:  kubernetes.io/hostname in [node-1]
Message: 
Source:
    Type: LocalVolume (a persistent volume backed by local storage on a node)
    Path: /mnt/disks/vol1
```
这个PV里面的各种定义，StorageClass、本地片挂载点位置，都是通过Provision的配置文件指定的。这个Provision本身也是一个External Provision。

# 自定义存储插件
PV和PVC的实现原理，是处于整个存储提醒的可扩展性的考虑，在kubernetes中，存储插件的开发有两种方式：FlexVolume和CSI。

