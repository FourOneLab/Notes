StatefulSet 对存储状态的管理机制，主要是使用`Persistent Volume Claim`的功能。

> 在Pod的定义中可以声明Voluem（spec.volumes字段）,在这个字段里定义一个具体类型的Volume，如hostPath。

**当我们并不知道有哪些Volume类型（比如Ceph、GlusterFS）可用时，怎么办呢？**

## 例子
一个声明了Ceph RBD类型Volume的Pod：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: rbd
spec:
  containers:
    - image: kubernetes/pause
      name: rbd-rw
      volumeMounts:
      - name: rbdpd
        mountPath: /mnt/rbd
  volumes:
    - name: rbdpd
      rbd:
        monitors:
        - '10.16.154.78:6789'
        - '10.16.154.82:6789'
        - '10.16.154.83:6789'
        pool: kube
        image: foo
        fsType: ext4
        readOnly: true
        user: admin
        keyring: /etc/ceph/keyring
        imageformat: "2"
        imagefeatures: "layering"
```

1. 如果不懂Ceph RBD的使用方法，这个Pod的Volume字段基本看不懂。
2. 这个Ceph RBD对应的存储服务器、用户名、授权文件的位置都暴露出来了（信息被过度暴露）。

**Kubernetes引入了一组交租PVC和PV的API对象，大大降低了用户声明和使用吃就好Volume的门槛**。

## 再来个例子
使用PVC来定义Volume，只要两步。
第一步： 定义一个PVC。声明想要的Volume属性：
```yaml
kind: PersistentVolumeClaim
apiVersion: v1
metadata:
  name: pv-claim
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
```
不需要任何Volume细节的字段，只有描述的属性和定义。
- storage：1Gi【表示需要的Volume大小至少为1GiB】
- accessMode：ReadWriteOnce【表示Volume的挂载方式为可读写，并且只能被挂载到一个节点上，而不是多个节点共享】

### volume类型和支持的访问模式

|Volume Plugin	|ReadWriteOnce	|ReadOnlyMany	|ReadWriteMany|
|---|---|---|---|
|AWSElasticBlockStore	|✓	|-	|-
|AzureFile	|✓	|✓	|✓
|AzureDisk	|✓	|-	|-
|CephFS	|✓	|✓	|✓
|Cinder	|✓	|-	|-
|FC	|✓	|✓	|-
|Flexvolume	|✓	|✓	|depends on the driver
|Flocker	|✓	|-	|-
|GCEPersistentDisk	|✓	|✓	|-
|Glusterfs	|✓	|✓	|✓
|HostPath	|✓	|-	|-
|iSCSI	|✓	|✓	|-
|Quobyte	|✓	|✓	|✓
|NFS	|✓	|✓	|✓
|RBD	|✓	|✓	|-
|VsphereVolume	|✓	|-	|- (works when pods are collocated)
|PortworxVolume	|✓	|-	|✓
|ScaleIO	|✓	|✓	|-
|StorageOS	|✓	|-	|-

第二步：在Pod中声明使用这个PVC
```yaml
apiVersion: v1
kind: Pod
metadata:
  name: pv-pod
spec:
  containers:
    - name: pv-container
      image: nginx
      ports:
        - containerPort: 80
          name: "http-server"
      volumeMounts:
        - mountPath: "/usr/share/nginx/html"
          name: pv-storage
  volumes:
    - name: pv-storage
      persistentVolumeClaim:
        claimName: pv-claim
```
在这个pod的Volume定义中只需要声明它的类型是`persistentVolumeClaim`，然后指定PVC的名字，**完全不必关心Volume本身的定义**。

- 当我们创建这个Pod时，kubernetes会自动绑定一个符合条件的Volume。
- 这个Volume来自预先创建的PV（Persistent Volume）对象。

常见的PV对象如下：
```yaml
kind: PersistentVolume
apiVersion: v1
metadata:
  name: pv-volume
  labels:
    type: local
spec:
  capacity:
    storage: 10Gi
  rbd:
    monitors:
    - '10.16.154.78:6789'
    - '10.16.154.82:6789'
    - '10.16.154.83:6789'
    pool: kube
    image: foo
    fsType: ext4
    readOnly: true
    user: admin
    keyring: /etc/ceph/keyring
    imageformat: "2"
    imagefeatures: "layering"
```
这个PV对象的`spec.rbd`字段，正是前面介绍的Ceph RBD Volume的详细定义。它声明的容量是10GiB，kubernetes会为刚才创建的PVC绑定这个PV。

> kubernetes中PVC和PV的设计，实际上**类似于“接口”和“实现”的思想**。这种接耦合，避免了因为向开发者暴露过多的存储系统细节而带来隐患。

- 开发者只需要知道并使用“接口”，即PVC；
- 运维人员负责给这个“接口”绑定具体的实现，即PV。

**PV和PVC的设计，使得StatefulSet对存储状态的管理成为了可能**。

## 又一个例子
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: web
spec:
  serviceName: "nginx"
  replicas: 2
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.9.1
        ports:
        - containerPort: 80
          name: web
        volumeMounts:
        - name: www
          mountPath: /usr/share/nginx/html
  volumeClaimTemplates:
  - metadata:
      name: www
    spec:
      accessModes:
      - ReadWriteOnce
      resources:
        requests:
          storage: 1Gi
```
为这个StatefulSet添加一个`volumeClaimTemplates`字段（类似于Deployment中PodTemplate的作用）。

凡是被这个StatefulSet管理的pod。都会声明一个对应的PVC，这个PVC的定义来自于`volumeClaimTemplates`这个模板字段。

**更重要的是，这个PVC的名字会被分配一个与这个Pod完全一致的编号**。

这个自动创建的PVC，与PV绑定成功后，就进入bound状态，这就意味着这个Pod可以挂载并使用这个PV。

**PVC是一种特殊的Volume**。一个PVC具体是什么类型的Volume，要在跟某个PV绑定之后才知道。PVC与PV能够绑定的前提是，在kubernetes系统中已经创建好符合条件的PV，或者在公有云上通过`Dynamic Provisioning`的方式，自动为创建的PVC匹配PV。

创建上述StatefulSet后，在集群中会出现两个PVC：
```bash
$ kubectl create -f statefulset.yaml
$ kubectl get pvc -l app=nginx
NAME        STATUS    VOLUME                                     CAPACITY   ACCESSMODES   AGE
www-web-0   Bound     pvc-15c268c7-b507-11e6-932f-42010a800002   1Gi        RWO           48s
www-web-1   Bound     pvc-15c79307-b507-11e6-932f-42010a800002   1Gi        RWO           48s
```
这些PVC都是以`<PVC名字>-<StatefulSet名字>-<编号>`的方式命名，并且处于Bound状态。

> 这个StatefulSet创建出来的Pod都会声明使用编号的PVC，比如名叫`web-0`的Pod的Volume字段就会声明使用`www-web-0`的PVC，从而挂载到这个PVC所绑定的PV。

当容器向这个Volume挂载的目录写数据时，都是写入到这个PVC所绑定的PV中。当这两个Pod被删除后，这两个Pod会被按照编号的顺序重新创建出来，原先与相同编号的Pod绑定的PV在Pod被重新创建后依然绑定在一起。

## StatefulSet控制器恢复Pod的过程
1. 当Pod被删除时，对应的PVC和PV并不会被删除，所以这个Volume里已经写入的数据，也依然会保存在远程存储服务里。
2. StatefulSet控制器发现，有Pod消失时，就会重新创建一个新的、名字相同的POd来纠正这种不一致的情况。
3. 在这个新的Pod对象的定义里，它声明使用的PVC与原来的名字相同；这个PVC的定义来时来自PVC模板。这是StatefulSet创建Pod的标准流程。
4. 所有在这个新的Pod被创建出来后，kubernetes为它查找原来名字的PVC，就会直接找到旧的Pod遗留下来的同名的PVC，进而找到与这个PVC绑定在一起的PV。

这样新的Pod就可以挂载到旧Pod对应的那个Volume，并且获得到保存在Volume中的数据。

**通过这种方式，kubernetes的StatefulSet就实现了对应用存储状态的管理**。

## StatefulSet工作原理
### 1.StatefulSet控制器直接管理Pod
因为StatefulSet里面不同的Pod实例，不再像ReplicaSet中那样都是完全一样的，而是有细微区别的。

比如每个Pod的hostname、名字等都是不同的、都携带编号。

### 2.Kubernetes通过Headless Service，为这些有编号的Pod，在DNS服务器中生成带有同样编号的DNS记录。
只要StatefulSet能够保证这些Pod名字里的编号不变，那么Service里类似于`<pod名字>.<svc名字>.<命名空间>.cluster.local`这样的DNS记录也就不会变，而这条记录解析出来的Pod的IP地址，则会随着后端Pod的删除和再创建而自动更新。**这是Service机制本身的能力，不需要StatefulSet操心**。

### 3. StatefulSet还为每一个Pod分配并创建一个同样编号的PVC
这样Kubernetes就可以通过Persistent Volume机制为这个PVC绑定上对应的PV，从而保证每个Pod都拥有独立的Volume。

在这种情况下，即使Pod被删除，它所对应的PVC和PV依然会保留下来，所以当这个Pod被重新创建出来之后，Kubernetes会为它找到同样编号的PVC，挂载这个PVC对应的Volume，从而获取到以前保存在Volume里的数据。

## 总结
StatefulSet其实就是一种特殊的Deployment，其独特之处在于，它的每个POd都被编号。而且，这个编号会体现在Pod的名字和hostname等标识信息上，这不仅代表了Pod的创建顺序，也是Pod的重要网络标识（即：在整个集群里唯一的、可被访问的身份）。

有了这个编号后，StatefulSet就使用kubernetes里的两个标准功能：Headless Service和PV/PVC，实现了对Pod的拓扑状态和存储状态的维护。

**StatefulSet是kubernetes中作业编排的`集大成者`**。

# 滚动更新
StatefulSet编排“有状态应用”的过程，其实就是对现有典型运维业务的容器化抽象。也就是说，在不使用kubernetes和容器的情况下，也可以实现，只是在升级、版本管理等工程的能力很差。

> 使用StatefulSet进行“滚动更新”，只需要修改StatefulSet的Pod模板，就会自动触发“滚动更新”的操作。

```bash
$ kubectl patch statefulset mysql --type='json' -p='[{"op": "replace", "path": "/spec/template/spec/containers/0/image", "value":"mysql:5.7.23"}]'
statefulset.apps/mysql patched
```
使用kubectl path命令，以“补丁”的方式（JSON格式的）修改一个API对象的指定字段，即`spec/template/spec/containers/0/image`。

**这样，StatefulSet Controller就会按照与Pod编号`相反`的顺序，从最后一个Pod开始，逐一更新这个StatefulSet管理的每个Pod**。如果发生错误，这次滚动更新会停止。

> StatefulSet的滚动更新允许进行更精细的控制如（金丝雀发布，灰度发布），即**应用的对个实例中，被指定的一部分不会被更新到最新的版本**。StatefulSet的`spec.updateStragegy.rollingUpdate`的`partition`字段。

如下命令，将StatefulSet的partition字段设置为2：
```bash
$ kubectl patch statefulset mysql -p '{"spec":{"updateStrategy":{"type":"RollingUpdate","rollingUpdate":{"partition":2}}}}'
statefulset.apps/mysql patched
```
上面的操作等同于使用`kubectl edit`命令直接打开这个对象，然后把partition字段修改为2。这样当模板发生变化时，只有序号大于等于2的Pod会被更新到这个版本，并且如果删除或者重启序号小于2的Pod，它再次启动后，还是使用原来的模板。