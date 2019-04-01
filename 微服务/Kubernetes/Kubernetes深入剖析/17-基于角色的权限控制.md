kubernetes内置的编排对象很难完全满足所有需求，基于插件机制来设计自己的编排对象，实现自己的控制器模式。

kubernetes中所有的API对象都是保存在Etcd中，但是，对于这些API对象的操作，却一定要通过访问kube-apiserver实现，这是因为需要APIServer来帮助完成授权工作。

> 在kubernetes中，负责授权工作的机制就是RBAC，基于角色的访问控制（Role-Based Access Control）

RBAC的三个基本概念：
1. Role：一组规则，定义了一组对kubernetesAPI对象的操作权限
2. Subject:被作用者，可以是人，也可以是机器，也可以是kubernetes中定义的用户
3. RoleBinding：定义了被作用者和角色之间的绑定关系

# Role
Role是Kubernetes的API对象，定义如下：
```yaml
kind: Role
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  namespace: mynamespace    # 指定了产生作用的Namespace
  name: example-role
rules:      # 定义权限规则
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
```

> Namespace是kubernetes项目里的逻辑管理单位，不同Namespace的API对象，在通过kubectl命令操作的时候，是相对隔离的（逻辑上的隔离并不提供实际的隔离或者多租户能力）。

# RoleBinding
RoleBinding本身也是一个kubernetes的API对象，定义如下：
```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-rolebinding
  namespace: mynamespace
subjects:       #被作用者
- kind: User    #类型为user，即kubernetes里的用户
  name: example-user
  apiGroup: rbac.authorization.k8s.io
roleRef:    # 利用这个字段，直接通过使用名字的方式来引用定义好的Role对象，进行规则的绑定
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```
> 在kubernetes中，并没有user这个API对象。

# User
在kubernetes中的User，即用户，只是一个授权系统里的**逻辑概念**：
1. 它需要通过外部认证服务，如Keystone来提供
2. 直接给APIServer自定一个用户名和密码文件，kubernetes的授权系统，能够从这个文件里找到对应的用户

**Role、RoleBinding都是Namespaced对象，只能在某个namespace中**。对于non-namespace对象，或者某个对象要作用于所有的namespace时，使用ClusterRole和ClusterRoleBinding。

用法与Role完全一样，只是没有namespace字段。
```yaml
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-clusterrole
rules:
- apiGroups: [""]
  resources: ["pods"]
  verbs: ["get", "watch", "list"]
# 赋予所有权限
# verbs: ["get", "list", "watch", "create", "update", "patch", "delete"]
# 以上是当前能够对API对象进行的全部操作
```

```yaml
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-clusterrolebinding
subjects:
- kind: User
  name: example-user
  apiGroup: rbac.authorization.k8s.io
roleRef:
  kind: ClusterRole
  name: example-clusterrole
  apiGroup: rbac.authorization.k8s.io
```

rules字段也可以针对某一个具体的对象进行权限设置：
```yaml
rules:
- apiGroups: [""]
  resources: ["configmaps"]
  resourceNames: ["my-config"]
  verbs: ["get"]
```

> kubernetes中有一个内置的用户，ServiceAccout。

1. 创建一个ServiceAccount

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  namespace: mynamespace
  name: example-sa
```

2. 编写Rolebinding，进行权限分配
```yaml
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: example-rolebinding
  namespace: mynamespace
subjects:
- kind: ServiceAccount      # 类型为ServiceAccount
  name: example-sa
  namespace: mynamespace
roleRef:
  kind: Role
  name: example-role
  apiGroup: rbac.authorization.k8s.io
```

3. 分别创建对应的对象

```yaml
$ kubectl create -f svc-account.yaml
$ kubectl create -f role-binding.yaml
$ kubectl create -f role.yaml
```

4. 查看ServiceAccount的详细信息
```yaml
$ kubectl get sa -n mynamespace -o yaml
- apiVersion: v1
  kind: ServiceAccount
  metadata:
    creationTimestamp: 2018-09-08T12:59:17Z
    name: example-sa
    namespace: mynamespace
    resourceVersion: "409327"
    ...
  secrets:      # kubernetes自动创建并分配
  - name: example-sa-token-vmfg6
```
kubernetes会为ServiceAccount自定创建并分配一个Secret对象，这个Secret就是与ServiceAccount对应的，用来与APIServer进行交互的**授权文件**（称为Token）。Token文件的内容一般是**证书**或者**密码**，以一个secret对象的方式保存在Etcd中。

5. 使用这个ServiceAccount

```yaml
   apiVersion: v1
kind: Pod
metadata:
  namespace: mynamespace
  name: sa-token-test
spec:
  containers:
  - name: nginx
    image: nginx:1.7.9
  serviceAccountName: example-sa
```
定义的pod使用的是`example-sa`这个ServiceAccount，等pod运行后，该ServiceAccount的token（也就是secret对象），被kubernetes自动挂载到容器的`/var/run/secretc/kubernetes.io/serviceaccount`目录下。

```bash
$ kubectl describe pod sa-token-test -n mynamespace
Name:               sa-token-test
Namespace:          mynamespace
...
Containers:
  nginx:
    ...
    Mounts:
      /var/run/secrets/kubernetes.io/serviceaccount from example-sa-token-vmfg6 (ro)
```
使用kubectl exec 查看目录中的文件:
```bash
$ kubectl exec -it sa-token-test -n mynamespace -- /bin/bash
root@sa-token-test:/# ls /var/run/secrets/kubernetes.io/serviceaccount
ca.crt namespace  token
```
容器中的应用可以会用这个`ca.crt`来访问APIServer。此时应用只能进行GET、WATCH、LIST操作，因为ServiceAccount的权限被Role限制了。

> 如果一个pod没有声明ServiceAccount，kubernetes会自动在它的Namespace下创建一个叫default的默认ServiceAccount，然后被分配给这个Pod。在这种情况下，默认ServiceAccount并没有关联任何Role，此时它有访问APIServer的绝大多数权限。这个访问所需要的Token还是默认的ServiceAccount对应的Secret对象提供。

```bash
$kubectl describe sa default
Name:                default
Namespace:           default
Labels:              <none>
Annotations:         <none>
Image pull secrets:  <none>
Mountable secrets:   default-token-s8rbq
Tokens:              default-token-s8rbq
Events:              <none>

$ kubectl get secret
NAME                  TYPE                                  DATA      AGE
kubernetes.io/service-account-token   3         82d

$ kubectl describe secret default-token-s8rbq
Name:         default-token-s8rbq
Namespace:    default
Labels:       <none>
Annotations:  kubernetes.io/service-account.name=default
              kubernetes.io/service-account.uid=ffcb12b2-917f-11e8-abde-42010aa80002

Type:  kubernetes.io/service-account-token

Data
====
ca.crt:     1025 bytes
namespace:  7 bytes
token:      <TOKEN 数据 >

```
kubernetes会自动为默认ServiceAccount创建并绑定一个特殊的Secret：
- 类型为：kubernetes.io/service-account-token
- Annotation：kubernetes.io/service-account.name=default(这个secret会跟同一Namespace下名叫default的ServiceAccount进行绑定)。


## 用户组
除了user、还有group的概念，如果为kubernetes配置外部认证服务，这个用户组由外部认证服务提供。

对于kubernetes的内置用户ServiceAccount来说，上述用户组的概念也同样适用，实际上，一个ServiceAccount，在kubernetes里对应用户的名字是：
```
system:serviceaccount:<ServiceAccount 名字 >
```
它对应的内置用户组的名字：
```
system:serviceaccounts:<Namespace 名字 >
```
这两个很重要。

### 例子
在RoleBinding里定义如下的subjects：
```yaml
subjects:
- kind: Group
  name: system:serviceaccounts:mynamespace
  apiGroup: rbac.authorization.k8s.io
```

这就意味着，这个Role的权限规则，作用于mynamespace里所有ServiceAccount，用到了用户组的概念。

```yaml
subjects:
- kind: Group
  name: system:serviceaccounts
  apiGroup: rbac.authorization.k8s.io
```
意味着这个Role作用于整个系统里所有的ServiceAccount。

在kubernetes中已经预置了很多系统保留的ClusterRole，都是以`System:`开头,通过使用kubectl get clusterroles来查看。这些一般是绑定给kubernetes系统组件对应的ServiceAccount使用的。


### system:kube-scheduler
这个clusterRole定义的权限规则是kube-scheduler运行所必须的权限。

```bash
$ kubectl describe clusterrole system:kube-scheduler
Name:         system:kube-scheduler
...
PolicyRule:
  Resources                    Non-Resource URLs Resource Names    Verbs
  ---------                    -----------------  --------------    -----
...
  services                     []                 []                [get list watch]
  replicasets.apps             []                 []                [get list watch]
  statefulsets.apps            []                 []                [get list watch]
  replicasets.extensions       []                 []                [get list watch]
  poddisruptionbudgets.policy  []                 []                [get list watch]
  pods/status                  []                 []                [patch update]
```

这个clusterRole会被绑定给kube-system Namespace下名叫kube-scheduler的ServiceAccount，它正式kubernetes调度器的pod声明使用的ServiceAccount。

kubernetes预置了四个clusterRole：
1. cluster-admin：kubernetes中的最权限，verb=*
2. admin
3. edit
4. view：规定被作用这只有kubernetes API的只读权限

```bash
$ kubectl describe clusterrole cluster-admin -n kube-system
Name:         cluster-admin
Labels:       kubernetes.io/bootstrapping=rbac-defaults
Annotations:  rbac.authorization.kubernetes.io/autoupdate=true
PolicyRule:
  Resources  Non-Resource URLs Resource Names  Verbs
  ---------  -----------------  --------------  -----
  *.*        []                 []              [*]
             [*]                []              [*]
```






