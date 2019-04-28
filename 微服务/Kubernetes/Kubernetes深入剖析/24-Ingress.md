在Service对外暴露的是三种方法中，LoadBalancer类型的Service，会在Cloud Provider（如GCP）里面创建一个该Service对应的负载均衡服务。

但是每个Service都要一个负载均衡服务，这个做法实际上很浪费而且成本高。如果在kubernetes中内置一个全局的负载均衡器，然后通过访问的URL，把请求转发给不同的后端Service。**这种全局的、为了代理不同后端Service而设置的负载均衡服务，就是kubernetes中的Ingress服务**。Ingress其实就是Service的“Service”。

> 假设有一个网站，`https://cage.example.com`,其中`https://cafe.example.com/coffee`对应的是咖啡点餐系统，而`https://cafe.exapmle.com/tea`对应的是茶水点餐系统。这两个系统，分别由名叫coffee和tea的Deployment来提供服务。


如何能够使用kubernetes的Ingress来创建一个统一的负载均衡器，从而实现当用户访问不同的域名时，能够访问到不同的Deployment？只要定义如下的Ingress对象即可：
```yaml
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  name: cafe-ingress
spec:
  tls:
  - hosts:
    - cafe.example.com
    secretName: cafe-secret
  rules:        # 这里是核心，称为IngressRule
  - host: cafe.example.com      # 这里是Key，一个标准的域名格式（FQDN）的字符串，而不能是IP地址
    http:                       # 这里是Value，是Ingress的入口
      paths:                    # IngressRule字段的规则，依赖Path字段，每一个Path对应一个后端Service
      - path: /tea
        backend:
          serviceName: tea-svc
          servicePort: 80
      - path: /coffee
        backend:
          serviceName: coffee-svc
          servicePort: 80

```
Fully Qualified Domian Name 的具体格式：[FQDN](https://tools.ietf.org/html/rfc3986)。

当用户访问`cafe.example.com`的时候，实际上访问到的是这个Ingress对象。这样，kubernetes就能使用IngressRule来对请求进行下一步转发。**Ingress对象，其实就是kubernetes项目对“反向代理”的一种抽象**。一个Ingress对象的主要内容，实际上是一个“反向代理”服务（如Nginx）的配置文件的描述。这个代理服务对应的转发规则，就是IngressRule。

所以在每个IngressRule里，都需要有：
- `host`字段：作为这条IngressRule的入口
- 一系列`path`字段：声明具体的转发策略（这与Nginx、HAproxy的配置文件的写法是一致的）

有了Ingress这样统一的抽象，kubernetes用户就无需关系Ingress的具体细节，在实际的使用中，只需要选择一个具体的Ingress Controller，把它部署在kubernetes集群里即可。Ingress Controller根据定义的Ingress对象，提供对应的代理能力。

> 业界常用的反向代理项目，Nginx、HAproxy、Envoy、Traefik等，都已经为kubernetes专门维护了对应Ingress Controller。

# Nginx Ingress Controller
## 第一步，部署Nginx Ingress Controller
```yaml
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/mandatory.yaml

# mandatory.yaml 是Nginx官网维护的Ingress Controller的定义

kind: ConfigMap
apiVersion: v1
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
---
apiVersion: extensions/v1beta1
kind: Deployment
metadata:
  name: nginx-ingress-controller
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: ingress-nginx
      app.kubernetes.io/part-of: ingress-nginx
  template:
    metadata:
      labels:
        app.kubernetes.io/name: ingress-nginx
        app.kubernetes.io/part-of: ingress-nginx
      annotations:
        ...
    spec:
      serviceAccountName: nginx-ingress-serviceaccount
      containers:
        - name: nginx-ingress-controller
          image: quay.io/kubernetes-ingress-controller/nginx-ingress-controller:0.20.0
          args:
            - /nginx-ingress-controller
            - --configmap=$(POD_NAMESPACE)/nginx-configuration
            - --publish-service=$(POD_NAMESPACE)/ingress-nginx
            - --annotations-prefix=nginx.ingress.kubernetes.io
          securityContext:
            capabilities:
              drop:
                - ALL
              add:
                - NET_BIND_SERVICE
            # www-data -> 33
            runAsUser: 33
          env:
            - name: POD_NAME
              valueFrom:
                fieldRef:
                  fieldPath: metadata.name
            - name: POD_NAMESPACE
            - name: http
              valueFrom:
                fieldRef:
                  fieldPath: metadata.namespace
          ports:
            - name: http
              containerPort: 80
            - name: https
              containerPort: 443

# 使用nginx-ingress-controller镜像的pod，启动命令是要使用该pod所在的Namespace作为参数，这些信息通过Downward API获得，即pod的env字段中定义的`env.valueFrom.filedRef.fieldPath`
```
这个pod本身，就是一个监听Ingress对象以及它所代理的后端Service变化的控制器。当一个新的Ingress对象由用户创建后，nginx-ingress-controller就会根据Ingress对象里定义的内容，生成一份对应的Nginx配置文件（`/etc/nginx/nginx.conf`）,并使用这个配置文件启动一个Nginx服务。

> 一旦Ingress对象被更新，nginx-ingress-controller就会更新这个配置文件，需要注意的是，如果这里只是被代理的Service对象被更新，nginx-ingress-controller所管理的Nginx服务是不需要重新加载的。因为nginx-ingress-controller通过[Nginx Lua](https://github.com/openresty/lua-nginx-module)方案实现了Nginx Upstream的动态配置。

nginx-ingress-controller运行通过ConfigMap对象来对上述Nginx的配置文件进行定制。这个ConfigMap的名字需要以参数的形式传递个nginx-ingress-controller。在这个ConfigMap里添加的字段，将会被合并到最后生成的Nginx配置文件当中。

**一个Nginx Ingress Controller提供的服务，其实是一个可以根据Ingress对象和被代理的后端Service的变化来自动更新的Nginx负载均衡器**。

## 第二部，创建Service来暴露Nginx Ingress Controller管理的Nginx服务
```yaml
$ kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/master/deploy/provider/baremetal/service-nodeport.yaml

# service-nodeport.yaml 是一个NodePort类型的Service

apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
  labels:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx
spec:
  type: NodePort
# 这个Service的唯一工作，就是将所有携带ingress-nginx标签的pod的80和433端口暴露出去。
# 如果在公有云环境下，需要创建的就是LoadBalancer类型的Service。
  ports:
    - name: http
      port: 80
      targetPort: 80
      protocol: TCP
    - name: https
      port: 443
      targetPort: 443
      protocol: TCP
  selector:
    app.kubernetes.io/name: ingress-nginx
    app.kubernetes.io/part-of: ingress-nginx

# 这个service的访问入口，即：宿主机地址和NodePort端口

$ kubectl get svc -n ingress-nginx
NAME            TYPE       CLUSTER-IP     EXTERNAL-IP   PORT(S)                      AGE
ingress-nginx   NodePort   10.105.72.96   <none>        80:30044/TCP,443:31453/TCP   3h

# 为了方便使用，把上述入口设置为环境变量
$ IC_IP=10.168.0.2 # 任意一台宿主机的地址
$ IC_HTTPS_PORT=31453 # NodePort 端口

```
Ingress Controller和它所需要的Service部署完成后，就可以使用它了。

# 具体例子
```bash
# 首先部署应用pod和对应的service
$ kubectl create -f cafe.yaml

# 创建Ingress所需的SSL证书（tls.crt）和密钥（tls.key）,这些信息通过secret对象定义
$ kubectl create -f cafe-secret.yaml

# 创建Ingress对象
$ kubectl create -f cafe-ingress.yaml

# 查看Ingress对象的信息
$ kubectl get ingress
NAME           HOSTS              ADDRESS   PORTS     AGE
cafe-ingress   cafe.example.com             80, 443   2h

$ kubectl describe ingress cafe-ingress
Name:             cafe-ingress
Namespace:        default
Address:          
Default backend:  default-http-backend:80 (<none>)
TLS:
  cafe-secret terminates cafe.example.com
Rules:
  Host              Path  Backends
  ----              ----  --------
  cafe.example.com  
                    /tea      tea-svc:80 (<none>)
                    /coffee   coffee-svc:80 (<none>)
Annotations:
Events:
  Type    Reason  Age   From                      Message
  ----    ------  ----  ----                      -------
  Normal  CREATE  4m    nginx-ingress-controller  Ingress default/cafe-ingress

# 在Rules字段定义更多的Path来为更多的域名提供负载均衡服务

# 通过访问Ingress的地址和端口，访问部署的应用
# 如https://cafe.example.com:443/coffee，应该是coffee这个Deployment负责响应
$ curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/coffee --insecureServer address: 10.244.1.56:80
Server name: coffee-7dbb5795f6-vglbv    #这是coffee的Deployment的名字
Date: 03/Nov/2018:03:55:32 +0000
URI: /coffee
Request ID: e487e672673195c573147134167cf898

# https://cafe.example.com:443/tea，应该是tea这个Deployment负责响应
$ curl --resolve cafe.example.com:$IC_HTTPS_PORT:$IC_IP https://cafe.example.com:$IC_HTTPS_PORT/tea --insecure
Server address: 10.244.1.58:80
Server name: tea-7d57856c44-lwbnp
Date: 03/Nov/2018:03:55:52 +0000
URI: /tea
Request ID: 32191f7ea07cb6bb44a1f43b8299415c

# Nginx Ingress Controller创建的Nginx负载均衡器，成功地将请求转发给了对应的后端Service
```
如果请求没有匹配到IngressRule，会返回Nginx的404页面，因为这个Nginx Ingress Controller是Nginx实现的。

> Ingress Controller运行通过Pod启动命令的`--default-backend-service`参数，设置一条默认的规则，如`--default-backend-service=nginx-default-backend`。这样任何匹配失败的请求，都会被转发到这个`nginx-default-backend`的Service。**可以专门部署一个专用的pod，来为用户返回自定义的404页面**。

目前，Ingress只能工作在七层，Service只能工作在四层，所有想要在kubernetes里为应用进行TLS配置等HTT
P相关的操作时，都必须通过Ingress来进行。







