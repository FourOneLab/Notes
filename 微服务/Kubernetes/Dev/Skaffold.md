如果您使用非本地解决方案(也就是远程集群)，则需要将Docker　clent配置为将Docker镜像推送到外部Docker镜像registry。

# 安装
最新稳定版的路径：https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64

运行以下命令下载并将二进制文件放在/ usr / local / bin文件夹中：
```bash
curl -Lo skaffold https://storage.googleapis.com/skaffold/releases/latest/skaffold-linux-amd64
chmod +x skaffold
sudo mv skaffold /usr/local/bin
```

# 下载样例
1. 克隆Skaffold仓库：
```bash
git clone https://github.com/GoogleContainerTools/skaffold
```
2. 进入`examples/gettings-started`目录
```bash
cd examples/gettings-started
```

# skaffold dev：每次代码更改时构建和部署应用程序

运行命令skaffold dev以持续构建和部署您的应用程序。您应该看到一些类似于以下条目的输出：
```bash
Starting build...
Found [minikube] context, using local docker daemon.
Sending build context to Docker daemon  6.144kB
Step 1/5 : FROM golang:1.9.4-alpine3.7
 ---> fb6e10bf973b
Step 2/5 : WORKDIR /go/src/github.com/GoogleContainerTools/skaffold/examples/getting-started
 ---> Using cache
 ---> e9d19a54595b
Step 3/5 : CMD ./app
 ---> Using cache
 ---> 154b6512c4d9
Step 4/5 : COPY main.go .
 ---> Using cache
 ---> e097086e73a7
Step 5/5 : RUN go build -o app main.go
 ---> Using cache
 ---> 9c4622e8f0e7
Successfully built 9c4622e8f0e7
Successfully tagged 930080f0965230e824a79b9e7eccffbd:latest
Successfully tagged gcr.io/k8s-skaffold/skaffold-example:9c4622e8f0e7b5549a61a503bf73366a9cf7f7512aa8e9d64f3327a3c7fded1b
Build complete in 657.426821ms
Starting deploy...
Deploying k8s-pod.yaml...
Deploy complete in 173.770268ms
[getting-started] Hello world!
```

每次检测到更改时，skaffold dev都会监视代码存储库并执行Skaffold工作流程。 

`skaffold.yaml`提供工作流的规范，在本例中为：
1. 使用Dockerfile从源代码构建Docker镜像
2. 使用其内容的Sha256哈希标记Docker镜像
3. （如果使用托管的Kubernetes解决方案）将Docker镜像推送到外部Docker registry
4. 使用之前构建的镜像更新Kubernetes清单，k8s-pod.yaml
5. 使用kubectl应用-f部署Kubernetes清单
6. 从已部署的应用程序中流回日志

> 注意：对于skaffold dev，如果在您的Kubernetes清单中将`imagePullPolicy`设置为`Always`，它将期望镜像存在于远程注册表中。

## 更改代码触发工作流
让我们通过一次代码更改重新触发工作流程！更新main.go如下：
```go
package main

import (
	"fmt"
	"time"
)

func main() {
	for {
		fmt.Println("Hello Skaffold!")
		time.Sleep(time.Second * 1)
	}
}
```
保存文件的那一刻，Skaffold将重复skaffold.yaml中描述的工作流程，并最终重新部署您的应用程序。管道完成后，您应该在终端中看到更新的输出：
```bash
[getting-started] Hello Skaffold!
```
# skaffold run：根据需要构建和部署您的应用程序一次
如果希望一次构建和部署一次，请运行命令skaffold run。 Skaffold将执行skaffold.yaml中描述的工作流程一次。
