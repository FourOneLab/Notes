> 对于云的用户来说，在GPU的支持上，只要在Pod的YAML文件中声明，某个容器需要的GPU个数，那么kubernetes创建的容器里就应该出现对应的GPU设备，以及它所对应的驱动目录。

以NVIDIA的GPU设备为例，上面的需求就意味着当用户的容器创建之后，这个容器里必须出现如下两部分设备和目录：
1. GPU设备：`/dev/nvidia0`，这个是容器启动时的Devices参数
2. GPU驱动目录：`/usr/local/nvidia/*`，这个是容器启动是Volume参数

在kubernetes的GPU支持的实现中，kubelet实际上就是将上述两部分内容，设置在了创建该容器的CRI参数里。这样等容器启动之后，对应的容器里就会出现GPU设备和驱动路径。

kubernetes在Pod的API对象里，并没有为GPU专门设置一个资源类型字段，使用Extended Resource的特殊字段来负责传递GPU的信息，如下面的例子：

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: cuda-vector-add
spec:
  restartPolicy: OnFailure
  containers:
    - name: cuda-vector-add
      image: "k8s.gcr.io/cuda-vector-add:v0.1"
      resources:
        limits:
          nvidia.com/gpu: 1

```
在pod的limits字段里，这个资源的名称是`nvidia.com/gpu`，它的值是1，说明这个Pod声明了自己要使用一个NVIDIA类型的GPU。

> kube-scheduler里面，并不关心这个字段的具体含义，只会在计算的时候，一律将调度器里保存的该类型资源的可用量直接减去Pod中声明的数值即可。**Extended Resource是kubernetes为用户设置的一种对自定义资源的支持**。

为了让调度器知道这个自定义类型的资源在每台宿主机上的可用量，宿主机节点本身，就必须能够想
APIServer汇报该类型资源的可用量。**在kubernetes中，各种类型资源可用量是Node对象Status字段的内容**，如下面的例子：
```yaml
apiVersion: v1
kind: Node
metadata:
  name: node-1
...
Status:
  Capacity:
   cpu:  2
   memory:  2049008Ki

```
为了能在上述Status字段里添加自定义资源的数据，必须使用PATCH API来对该Node对象进行更新，加上自定义资源的数量，这个PATCH操作，可以简单使用curl命令来发起，如下所示：
```yaml
# 启动 Kubernetes 的客户端 proxy，这样你就可以直接使用 curl 来跟 Kubernetes  的 API Server 进行交互了
$ kubectl proxy

# 执行 PACTH 操作
$ curl --header "Content-Type: application/json-patch+json" \
--request PATCH \
--data '[{"op": "add", "path": "/status/capacity/nvidia.com/gpu", "value": "1"}]' \
http://localhost:8001/api/v1/nodes/<your-node-name>/status

```
PATCH操作完成后，Node是Status变成如下的内容：
```yaml
apiVersion: v1
kind: Node
...
Status:
  Capacity:
   cpu:  2
   memory:  2049008Ki
   nvidia.com/gpu: 1

```
这样在调度器里，他就能在缓存里记录下node-1上的`nvidia.com/gpu`类型的资源数量是1。

在kubernetes的GPU支持方案中，并不需要真正做上述关于Extended Resource的操作，在kubernetes中，对所有硬件加速设备进行管理的功能是`Device Plugin`插件的责任。包括对硬件的Extended Resource进行汇报的逻辑。

kubernetes的Device Plugin机制，可用如下的一幅图来描述：

![image](https://static001.geekbang.org/resource/image/5d/85/5db13d33cb647f33c62837e9cccdfb85.png)

1. 每一种硬件都需要有它所对应的Device Plugin进行管理，这些Device Plugin通过gRPC的方式同kubelet连接起来。
2. Device Plugin通过ListAndWatch的API，定期向kubelet汇报该Node上GPU的列表。kubelet在拿到这个列表之后，就可以直接在它向APIServer发送的心跳里，以Extended Resource的方式，加上这些GPU的数量，如`nvidia.com/gpu=3`，用户在这里不需要关心GPU信息向上的汇报流程。

> ListAndWatch向上汇报的信息，只要本机上GPU的ID列表，而不会有任何关于GPU设备本身的信息。kubelet在向APIServer汇报的时候，只会汇报该GPU对应的Extended Resource数量。**kubelet本身会将这个GPU的ID列表保存在自己的内存里，并通过ListAndWatch API定时更新**。

当一个Pod想要使用一个GPU的时候，需要在Pod的limits字段声明`nvidia.com/gpu:1`，那么kubernetes的调度器就hi从它的缓存里，寻找GPU数量满足条件的Node，然后将缓存里GPU数量减少1，完成Pod与Node的绑定。

这个调度成功后的Pod信息，会被对应的kubelet拿来进行容器操作，当kubelet发现Pod的容器请求一个GPU的时候，kubelet就会从自己持有的GPU列表里，为这个容器分配一个GPU，此时kubelet会向本机的Device Plugin发起一个Allocate（）请求。这个请求携带的参数，就是即将被分配给该容器的设备ID列表。

当Device Plugin收到Allocate请求之后，根据kubelet传递的设备ID，从Device Plugin里找到这些设备对应的设备路径和驱动目录（这些信息正式Device Plugin周期性从本机查询到的，如NVIDIA Device Plugin的实现里，会定期访问nvidia-docker插件，从而获取到本机的GPU信息）。

被分配GPu对应的设备路径和驱动目录信息被返回给kubelet之后，kubelet就完成了为一个容器分配GPU的操作。然后kubelet会把这些信息追加在创建该容器所对应的CRI请求当中。这样当这个CRI请求发给Docker之后，Docker创建出来的容器里，就会出现这个GPU设备，并把它所需要的驱动目录挂载进去。

对于其他类型的硬件来说，要想在kubernetes所管理的容器里使用这些硬件的话，需要遵守Device Plugin的流程，实现如下所示的Allocate和ListAndWatch API：
```go
  service DevicePlugin {
        // ListAndWatch returns a stream of List of Devices
        // Whenever a Device state change or a Device disappears, ListAndWatch
        // returns the new list
        rpc ListAndWatch(Empty) returns (stream ListAndWatchResponse) {}
        // Allocate is called during container creation so that the Device
        // Plugin can run device specific operations and instruct Kubelet
        // of the steps to make the Device available in the container
        rpc Allocate(AllocateRequest) returns (AllocateResponse) {}
  }

```
目前支持的硬件有：FPGA、SRIOV、RDMA等。

# 总结
GPU硬件设备的的调度工作，实际上是由kubelet完成的，kubelet会负责从它所持有的硬件设备列表中，为容器挑选一个硬件设备，然后调用Device Plugin的Allocate API来完成这个分配操作。在整条链路中，调度器扮演的角色，仅仅是为Pod寻找到可用的、支持这种硬件设备的节点而已。

这使得kubernetes里对硬件设备的管理、只能处于”设备个数“这唯一一种情况，一旦设备是异构的，不能简单地用数目去描述具体使用需求的时候（如Pod想要运行计算能力最强的那个GPU上），Device Plugin就完全不能处理了。

> 在很多场景下，希望在调度器进行调度的时候，可以根据整个集群里的某种硬件设备的全局分布，做出一个最佳的调度选择。

上述Device Plugin的设计，使得kubernetes里，缺乏一种能够对Device进行描述的API对象，这使得如果硬件设备本身的属性比较复杂，并且Pod也关系这些硬件的属性的时，Device Plugin完全没办法支持。

目前，kubernetes的Device Plugin的设计，覆盖的场景非常单一，能用却不好用，Device Plugin的API本身的扩展性也不好。


 