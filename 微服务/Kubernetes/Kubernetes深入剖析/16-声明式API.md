# 工作原理
在kubernetes项目中，一个API对象在Etcd里的完整资源路径，由：
1. Group（API组）
2. Version（API版本）
3. Resource（API资源类型）
三部分组成。

通过这样的结构，整个Kubernetes里的所有API对象，实际上就是如下的树形结构：

![](https://static001.geekbang.org/resource/image/70/da/709700eea03075bed35c25b5b6cdefda.png)

**API对象的组织方式是层层递进的**。

## 例子

```yaml
apiVersion: batch/v2alpha1
kind: CronJob
...
```
上面的例子中：
1. Group（API组）： batch
2. Version（API版本）： v2alpha1
3. Resource（API资源类型）： CronJob

提交给kubernetes后，平台就把YAML文件中描述的内容转换成kubernetes里的一个CronJob对象。

## 解析过程
那么，如何对Resource、Group、Vsersion进行解析，从而得到Kubernetes项目里找到CronJob对象？

### 匹配Group
#### 核心API
 对于kubernetes的核心对象（如pod、Node等），是不需要Group的，因为它们的Group是`""`，kubernetes会在`/api`这个层级进行下一步的匹配过程。

#### 非核心API
对于非核心API来说，kubernetes就必须在`/apis`这个层级查找到对应的Group。

> API Group的分类是以对象功能为依据的。

### 匹配Version
在对应的Group中匹配Version。

> 同一种API对象可以有多个版本，这是kubernetes进行API版本化管理的重要手段。对于会影响到用户的变更就可以通过升级新版本来处理，从而保证了向后兼容。

### 匹配Resource
匹配到正确的版本后，APIServer就会根据Resource创建对应的API对象。

具体的执行过程如下图所示：
![](https://static001.geekbang.org/resource/image/df/6f/df6f1dda45e9a353a051d06c48f0286f.png)

1. 发起创建API对象的POST请求后，编写的YAML的信息就被提交给了APIServer
> APIServer会过滤这个请求，并完成前置工作（授权、超时处理、审计等）
2. 请求进入MUX和Routes（APIServer完成URL和Handler绑定的场所）
> APIServer的Handler要做的事情就是按照上面过程找到对应的API对象类型的定义
3. 根据API对象类型定义，使用用户提交的YAML文件里面的字段，创建一个对象
> 在这个过程中，APIServer会进行一个Convert工作，把用户提交的YAML文件，转换成一个叫作Super Version的对象（该API资源类型所有版本的字段全集），用户提交的不同版本的YAML文件，都可以使用这个Super Version对象来处理
4. APIServer进行Admission()和Validation()操作
> Admission Controller 和 Initializer属于Admission的功能，Validation,负责校验每个字段是否合法，被验证过的API对象保存在APIServer的Registry数据结构中。【只要一个API对象的定义能够在Registry中查到，那就是一个有效的对象】
5. APIServer把验证过的API对象转换成用户最初提交的版本，进行序列化操作，并调用Etcd的API把它保存起来。

> 由此看见APIServer的重要性，同时要兼顾性能、API完备性、版本化、向后兼容等，因此在APIServer中大量使用Go语言的代码生成功能，来自动化诸如Convert、DeepCopy等与API资源相关的操作。

这导致要添加一个kubernetes风格的API非常困难。

# 添加自定义API对象
## 第一步，让kubernetes认识这个自定义的API对象
在kubernetes v1.7之后，添加了权限的API插件机制CRD，使得自定义API变得容易很多。

CRD（custom Resource Definition），允许用户在kubernetes中添加与Pod、Node类似的新的API资源类型，即自定义API资源。

## 例子
添加一个叫Network的自定义API资源类型，它的作用是一旦用户创建了一个Network对象，那么Kubernetes就会使用这个对象定义的网络参数，调用真实的网络插件（如Neutron项目），为用户创建一个真正的“网络”。这样，将来创建的Pod就可以声明使用这个网络。

这个Network对象的YAML文件，如下，称为一个自定义API资源，CR（Custon Resource）：
```yaml
apiVersion: samplecrd.k8s.io/v1
kind: Network
metadata:
  name: example-network
spec:
  cidr: "192.168.0.0/16"
  gateway: "192.168.0.1"
```
上面的例子中：
1. Group（API组）： samplecrd.k8s.io
2. Version（API版本）： v1
3. Resource（API资源类型）： Network

那么问题来了，Kubernetes如何知道自定义的API组的存在？
1. 为了让Kubernetes能够认识这个CR，需要让kubernetes知道CR对应的宏观定义，即CRD。
2. 所以需要编写一个CRD对应的YAML文件，如下所示。

```yaml
apiVersion: apiextensions.k8s.io/v1beta1
kind: CustomResourceDefinition
metadata:
  name: networks.samplecrd.k8s.io
spec:
  group: samplecrd.k8s.io
  version: v1
  names:
    kind: Network
    plural: networks     # 复数
  scope: Namespaced
```
在这个CRD的定义中：
1. Group（API组）： apiextensions.k8s.io
2. Version（API版本）： v1beta1
3. Resource（API资源类型）： CustomResourceDefinition

在这个CRD中定义了一个新的资源类型：
1. Group（API组）： samplecrd.k8s.io
2. Version（API版本）： v1
3. Resource（API资源类型）： Network
4. scope：Namespaced，表示这是一个属于Namespace的对象，隔离于不同namespace中

这些内容就是上面我们自定的Network对象。

> 有了这个CRD，kubernetes就能处理所有声明为`samplecrd.k8s.io/v1/network`类型的YAML文件

## 第二步，让kubernetes认识自定义的API对象中的字段
编写代码实现。

首先，在GOPATH下创建一个结构如下的项目：
```bash
$ tree $GOPATH/src/github.com/<your-name>/k8s-controller-custom-resource
.
├── controller.go
├── crd
│   └── network.yaml
├── example
│   └── example-network.yaml
├── main.go
└── pkg
    └── apis
        └── samplecrd
            ├── register.go     # 存放全局变量
            └── v1
                ├── doc.go
                ├── register.go # APIServer完成服务器服务器端的注册，客户端的注册在这里完成
                └── types.go    # 定义对Network对象的完整描述
```
其中，`pkg/api/samplecrd`是API组的名字，v1是版本。

`register.go`的代码如下：
```go
package samplecrd

const (
 GroupName = "samplecrd.k8s.io"
 Version   = "v1"
)
```

`doc.go` （Golang的文档源文件），代码如下：
```go
// +k8s:deepcopy-gen=package    

/* 这里是对代码的注释，不属于这个源文件
   +<tag_name>[=value]格式的注释，就是kubernetes进行代码生成要用的Annotation风格的注释
   +k8s:deepcopy-gen=package意思是，请为整个v1包里的所有类型定义自动生成DeepCopy方法
*/

// +groupName=samplecrd.k8s.io

/* 这里是对代码的注释，不属于这个源文件
   +groupName=samplecrd.k8s.io，定义了这个包对应的API组的名字
*/

package v1
```
这些定义在doc.go文件的注释，起到的是全局的代码生成控制的作用，也被称为Global Tags。

`types.go`文件，它的作用就是定义一个Network类型有哪些字段（比如，spec字段里面的内容），代码如下：
```go
package v1
...
/* +genclient，代码生成注释的意思是为下面这个API资源类型生成对应的Client代码
   +genclient:noStatus，表示这个API类型定义中没有Status字段，否则生成的CLient会自动带上UpdateStatus方法
*/

// +genclient
// +genclient:noStatus

/* 下面的这个注释表示，在生成DeepCopy的时候，实现kubernetes提供的runtime.Object接口
   否则在某些kubernetes版本中会出现编译错误
   这是一个固定操作
*/

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// Network describes a Network resource
type Network struct {
 // TypeMeta is the metadata for the resource, like kind and apiversion
 metav1.TypeMeta `json:",inline"`
 // ObjectMeta contains the metadata for the particular object, including
 // things like...
 //  - name
 //  - namespace
 //  - self link
 //  - labels
 //  - ... etc ...
 metav1.ObjectMeta `json:"metadata,omitempty"`
 
 Spec networkspec `json:"spec"`
}
// networkspec is the spec for a Network resource
type networkspec struct {
 Cidr    string `json:"cidr"`  //反引号中内容表示，该字段被转换为JSON格式后的名字，即在YAML文件里的字段名字
 Gateway string `json:"gateway"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// NetworkList is a list of Network resources
type NetworkList struct {       //描述一组Network对象应该包括哪些字段
 metav1.TypeMeta `json:",inline"`
 metav1.ListMeta `json:"metadata"`
 
 Items []Network `json:"items"`
}
```
Network类型定义方法和标准的kubernetes对象一样，包括TypeMeta（API元数据）和ObjectMeta字段（对象元数据）。

> 注意，+genclient卸载Network类型（主类型）上，而不是NetworkList类型（返回值类型）上。

`registry.go`(pkg/apis/samplecrd/v1/register.go,定义了如下的一个addKnowTypes()方法：
```go
package v1
...
// addKnownTypes adds our types to the API scheme by registering
// Network and NetworkList
func addKnownTypes(scheme *runtime.Scheme) error {
 scheme.AddKnownTypes(
  SchemeGroupVersion,
  &Network{},
  &NetworkList{},
 )
 
 // register the type in the scheme
 metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
 return nil
}
```
有了这个方法，kubernetes就能够在后面生成的client是知道Network以及NetworkList类型的定义。

> 通常，register.go文件里面的内容比较固定，使用的时候，资源类型，GruopName、Version等即可。

至此，自定义API对象完成，主要进行了两个部分：
1. 自定义资源类型的API描述，包括：Group、Version、Resource等
2. 自定义资源类型的对象描述，包括：Sepc、Status等

使用kubernetes提供的代码生成工具（k8s.io/code-generator），为上面定义的Network资源类型自动生成clientset、informer和lister，其中clientset就是操作Network对象所需要是使用的客户端。

使用方式如下：
```bash
# 代码生成的工作目录，也就是我们的项目路径
$ ROOT_PACKAGE="github.com/resouer/k8s-controller-custom-resource"
# API Group
$ CUSTOM_RESOURCE_NAME="samplecrd"
# API Version
$ CUSTOM_RESOURCE_VERSION="v1"

# 安装 k8s.io/code-generator
$ go get -u k8s.io/code-generator/...
$ cd $GOPATH/src/k8s.io/code-generator

# 执行代码自动生成，其中 pkg/client 是生成目标目录，pkg/apis 是类型定义目录
$ ./generate-groups.sh all "$ROOT_PACKAGE/pkg/client" "$ROOT_PACKAGE/pkg/apis" "$CUSTOM_RESOURCE_NAME:$CUSTOM_RESOURCE_VERSION"
```
执行后项目结构如下：
```bash
$ tree
.
├── controller.go
├── crd
│   └── network.yaml
├── example
│   └── example-network.yaml
├── main.go
└── pkg
    ├── apis
    │   └── samplecrd
    │       ├── constants.go
    │       └── v1
    │           ├── doc.go
    │           ├── register.go
    │           ├── types.go
    │           └── zz_generated.deepcopy.go    # 自动生成的DeepCopy代码文件
    └── client      # kubernetes为Network类型生成的客户端库，在编写自定义控制器时用到
        ├── clientset
        ├── informers
        └── listers
```

使用自定义的API对象：
```bash
# 创建CRD
$ kubectl apply -f crd/network.yaml
customresourcedefinition.apiextensions.k8s.io/networks.samplecrd.k8s.io created

# 查看已经创建的CRD
$ kubectl get crd
NAME                        CREATED AT
networks.samplecrd.k8s.io   2018-09-15T10:57:12Z

# 创建API对象
$ kubectl apply -f example/example-network.yaml 
network.samplecrd.k8s.io/example-network created

# 获取API对象
$ kubectl get network
NAME              AGE
example-network   8s

# 查看API对象的详细信息
$ kubectl describe network example-network
Name:         example-network
Namespace:    default
Labels:       <none>
...API Version:  samplecrd.k8s.io/v1
Kind:         Network
Metadata:
  ...
  Generation:          1
  Resource Version:    468239
  ...
Spec:
  Cidr:     192.168.0.0/16
  Gateway:  192.168.0.1
```

# 为自定义API对象编写控制器
创建出一个自定义API对象，只是完成了kubernetes声明式API的一半工作，接下来还需要为这个API对象编写一个自定义控制器，这样kubernetes才能更具Network API对象的增删改查操作。

> **声明是API**并不像**命令式API**那样有着明显的执行逻辑，使得基于声明式API的业务功能实现，往往需要通过控制器模式来“监视”API对象的变化（创建或删除），然后以此来决定实际要执行的具体工作。

总体来说，编写自定义控制器代码的过程包括：
1. 编写main函数
2. 编写自定义控制器的定义
3. 编写控制器里的业务逻辑

## main函数
主要工作是定义并初始化一个自定义控制器（Custom Controller），然后启动它，代码如下：
```go
func main() {
  ...
  
  cfg, err := clientcmd.BuildConfigFromFlags(masterURL, kubeconfig)
  ...
  kubeClient, err := kubernetes.NewForConfig(cfg)
  ...
  networkClient, err := clientset.NewForConfig(cfg)
  ...
  
  networkInformerFactory := informers.NewSharedInformerFactory(networkClient, ...)
  
  controller := NewController(kubeClient, networkClient,
  networkInformerFactory.Samplecrd().V1().Networks())
  
  go networkInformerFactory.Start(stopCh)
 
  if err = controller.Run(2, stopCh); err != nil {
    glog.Fatalf("Error running controller: %s", err.Error())
  }
}
```
main函数主要通过三个步骤完成初始化并启动一个自定义控制器的工作：
1. main函数根据提供的Master配置（APIServer的地址端口和kubeconfig的路径）创建一个kubernetes的client（kubeclient）和Network对象的client（networkclient）。
> 如果没有提供Master的配置，main函数会直接使用一种叫InClusterConfig的方式来创建这个client。这种方式我会假设自动以控制器是以Pod的方式运行在集群中的。因为集群中所有的pod都会默认以volume的形式挂载ServiceAccount，所以控制器就直接使用默认的ServiceAccount数据卷里的授权信息来访问APIServer。
2. main函数为Network对象创建一个叫作InformerFactory（networkinformerfactory）的工厂，并使用它生成一个Network独享的informer，传递给控制器。
3. main函数启动上述的informer，然后执行controller.Run，启动自定义控制器。

## 自定义控制器的工作原理
自定义控制器的工作原理如下图所示：

![](https://static001.geekbang.org/resource/image/32/c3/32e545dcd4664a3f36e95af83b571ec3.png)

### 第一步：自定义控制器从APIServer里获取它所关心的对象
这个操作依靠informer（通知器）的代码库完成。informer与API对象是一一对应的。所以传递给自定义控制器的就是API对象的informer。

创建informer工厂时，需要给它传递networkclient，informer使用这个networkclient与APIServer建立连接。informer使用Reflector包来维护这个连接。

Reflector使用ListAndWatch方法来获取并监听这些network对象实例的变化。
> ListAndWatch方法的首先通过APIServer的LIST API获取最新版的API对象；然后通过WATCH机制来监听这些API的变化。

1. 在ListAndWatch机制下，一旦APIServer有新的对象实例被创建、删除或更新，Reflector都会收到事件通知。该事件以及对应的API对象的组合被以增量的形式放进Delta FIFO Queue中。
2. informer会不断从这个Delta FIFO Queue里读取增量，每拿到一个增量就判断里面的事件类型，然后创建或者更新本地对象的缓存（在kubernetes中称为Store）。

每经过resyncPeriod指定时间，Informer维护的本地缓存，都会使用最近一次LIST返回的结果强制更新一次，从而保证换成的有效性。该操作也会出发informer注册的更新事件，但是两个对象的ResourceVersion一样，因此informer不做进一步处理。

> 如果事件类型是Added，informer就会通知indexer把这个API对象保存到本地缓存，并为它创建索引。如果是删除，则从本地换成中删除这个对象。

**同步本地换成是informer的第一个职责，最重要的职责**。

### 第二步：根据事件类型触发事先注册好的ResourceEventHandler

Handler需要在创建控制器的时候注册给它对应的informer。控制器的定义如下：
```go
func NewController(
  kubeclientset kubernetes.Interface,
  networkclientset clientset.Interface,
  networkInformer informers.NetworkInformer) *Controller {
  ...
  controller := &Controller{
    kubeclientset:    kubeclientset,
    networkclientset: networkclientset,
    networksLister:   networkInformer.Lister(),
    networksSynced:   networkInformer.Informer().HasSynced,
    workqueue:        workqueue.NewNamedRateLimitingQueue(...,  "Networks"),
    ...
  }
    networkInformer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc: controller.enqueueNetwork,
    UpdateFunc: func(old, new interface{}) {
      oldNetwork := old.(*samplecrdv1.Network)
      newNetwork := new.(*samplecrdv1.Network)
      if oldNetwork.ResourceVersion == newNetwork.ResourceVersion {
        return
      }
      controller.enqueueNetwork(new)
    },
    DeleteFunc: controller.enqueueNetworkForDelete,
 return controller
}
```

在mian函数中创建了kubeclientser和networkclientset，然后使用这两个client和informer初始化自定义控制器。

在自定义控制器中设置了一个工作队列（work queue），负责同步informer和控制循环之间的数据。
> kubernetes预置了很多工作队列的实现，可直接使用。

为networkinformer注册三个Handler（AddFunc、UpdateFunc、DeleteFunc），分别对应API对象的增删改操作。具体的操作就是将该事件对应的API对象加入到工作队列中（实际入队的是key而不是API对象本身，即`<namespace>`/`<name>`）。

控制循环将不断从这个工作队列里拿到这些key，然后开始执行真正的控制逻辑。

**informer其实是一个带有本地缓存和索引机制的可注册EventHandler的client**，它是实现自定义控制器跟APIServer数据同步的重要组件。



### 第三步：循环控制
main函数最后调用controller.Run()启动循环控制，代码如下：
```go
func (c *Controller) Run(threadiness int, stopCh <-chan struct{}) error {
 ...
  if ok := cache.WaitForCacheSync(stopCh, c.networksSynced); !ok {
    return fmt.Errorf("failed to wait for caches to sync")
  }
  
  ...
  for i := 0; i < threadiness; i++ {
    go wait.Until(c.runWorker, time.Second, stopCh)
  }
  
  ...
  return nil
}
```
1. 等待informer完成一次本地换成的数据同步操作
2. 通过goroutine启动一个（或者并发启动多个）无限循环的任务（任务的每一个循环周期执行的正式具体的业务逻辑）

自定义控制器的业务逻辑如下：
```go
func (c *Controller) runWorker() {
  for c.processNextWorkItem() {
  }
}

func (c *Controller) processNextWorkItem() bool {
  obj, shutdown := c.workqueue.Get()
  
  ...
  
  err := func(obj interface{}) error {
    ...
    if err := c.syncHandler(key); err != nil {
     return fmt.Errorf("error syncing '%s': %s", key, err.Error())
    }
    
    c.workqueue.Forget(obj)
    ...
    return nil
  }(obj)
  
  ...
  
  return true
}

func (c *Controller) syncHandler(key string) error {

  namespace, name, err := cache.SplitMetaNamespaceKey(key)
  ...
  
  network, err := c.networksLister.Networks(namespace).Get(name)
  if err != nil {
    if errors.IsNotFound(err) {
      glog.Warningf("Network does not exist in local cache: %s/%s, will delete it from Neutron ...",
      namespace, name)
      
      glog.Warningf("Network: %s/%s does not exist in local cache, will delete it from Neutron ...",
    namespace, name)
    
     // FIX ME: call Neutron API to delete this network by name.
     //
     // neutron.Delete(namespace, name)
     
     return nil
  }
    ...
    
    return err
  }
  
  glog.Infof("[Neutron] Try to process network: %#v ...", network)
  
  // FIX ME: Do diff().
  //
  // actualNetwork, exists := neutron.Get(namespace, name)
  //
  // if !exists {
  //   neutron.Create(namespace, name)
  // } else if !reflect.DeepEqual(actualNetwork, network) {
  //   neutron.Update(namespace, name)
  // }
  
  return nil
}

```
1. 从Workqueue中出对一个key
2. syncHandler方法使用这个key，尝试从informer维护的缓存中拿到了它所对应的对象（使用networksLister方法）
3. 如果控制循环从缓存中拿不到这个对象，说明key是通过删除操作被加入到workqueue中，这是调用对应的API把key对应的对象从集群中删除
4. 如果能够获取到对应的对象，就可以执行控制器模式里面的对比**期望状态**和**实际状态**的逻辑

> 自定义控制器拿到的API对象，就是APIServer中保存的期望状态。

实际状态直接从集群中获取，通过对比两者的状态来完成一次调谐过程。














