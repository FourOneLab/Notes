请使用与服务器端版本相同或者更高版本的 kubectl 与 Kubernetes 集群连接，使用低版本的 kubectl 连接较高版本的服务器可能引发验证错误。

# 安装kubectl
通过 curl 命令安装 kubectl 可执行文件:
```bash
# 通过以下命令下载 kubectl 的最新版本：
curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl

# 修改所下载的 kubectl 二进制文件为可执行模式
chmod +x ./kubectl

# 将 kubectl 可执行文件放置到系统 PATH 目录下
sudo mv ./kubectl /usr/local/bin/kubectl
```
> 若需要下载特定版本的 kubectl，请将上述命令中的 `$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)`部分替换成为需要下载的 kubectl 的具体版本即可。

# 配置kubectl
kubectl 需要一个 **kubectlconfig** 配置文件，配置其找到并访问 Kubernetes 集群。

> 当使用 kube-up.sh 脚本创建 Kubernetes 集群或者成功部署 Minikube 集群后，kubectlconfig 配置文件将自动产生。

**默认情况下，kubectl 配置文件位于 ~/.kube/config**。


## 使用 kubeconfig 共享集群访问
通过复制 kubectl 客户端配置 (kubeconfig)，客户端访问运行中的 Kubernetes 集群可以共享。该配置位于 $HOME/.kube/config，由 cluster/kube-up.sh 生成。下面是共享 kubeconfig 的步骤。

1. 创建集群

```bash
cluster/kube-up.sh
```

2. 复制 kubeconfig 到新主机

```bash
scp $HOME/.kube/config user@remotehost:/path/to/.kube/config
```

3. 在新主机上，让复制的 config 在使用 kubectl 时生效

```bash
#选择 A：复制到默认的位置
mv /path/to/.kube/config $HOME/.kube/config

#选择 B：复制到工作目录（运行 kubectl 的当前位置）
mv /path/to/.kube/config $PWD

#选项 C：通过环境变量 KUBECONFIG 或者命令行标志 kubeconfig 传递给 kubectl
export KUBECONFIG=/path/to/.kube/config
kubectl ... --kubeconfig=/path/to/.kube/config
```
## 手动创建 kubeconfig
kubeconfig 由 kube-up 生成，但是，也可以使用下面命令生成自己想要的配置（可以使用任何想要的子集）

```bash
# create kubeconfig entry
kubectl config set-cluster $CLUSTER_NICK \
    --server=https://1.1.1.1 \
    --certificate-authority=/path/to/apiserver/ca_file \
    --embed-certs=true \
# Or if tls not needed, replace --certificate-authority and --embed-certs with
    --insecure-skip-tls-verify=true \
    --kubeconfig=/path/to/standalone/.kube/config

# create user entry
kubectl config set-credentials $USER_NICK \
# bearer token credentials, generated on kube master
    --token=$token \
# use either username|password or token, not both
    --username=$username \
    --password=$password \
    --client-certificate=/path/to/crt_file \
    --client-key=/path/to/key_file \
    --embed-certs=true \
    --kubeconfig=/path/to/standalone/.kube/config

# create context entry
kubectl config set-context $CONTEXT_NAME \
    --cluster=$CLUSTER_NICK \
    --user=$USER_NICK \
    --kubeconfig=/path/to/standalone/.kube/config
```
注：
生成独立的 kubeconfig 时，标识 `--embed-certs` 是必选的，这样才能远程访问主机上的集群。

`--kubeconfig`既是加载配置的首选文件，也是保存配置的文件。如果您是第一次运行上面命令，那么 `--kubeconfig` 文件的内容将会被忽略。
```bash
export KUBECONFIG=/path/to/standalone/.kube/config
```
上面提到的 `ca_file`，`key_file` 和 `cert_file` 都是集群创建时在 master 上产生的文件，可以在文件夹 `/srv/kubernetes` 下面找到。持有的 token 或者 基本认证也在 master 上产生。
如果您想了解更多关于 kubeconfig 的详细信息，运行帮助命令 kubectl config -h。

## 合并 kubeconfig
kubectl 会按顺序加载和合并来自下面位置的配置

1. `--kubeconfig=/path/to/.kube/config` 命令行标志

2. `KUBECONFIG=/path/to/.kube/config` 环境变量

3. `$HOME/.kube/config` 配置文件

如果在 host1 上创建集群 A 和 B，在 host2 上创建集群 C 和 D，那么，可以通过运行下面命令，在两个主机上访问所有的四个集群
```bash
# on host2, copy host1's default kubeconfig, and merge it from env
$ scp host1:/path/to/home1/.kube/config /path/to/other/.kube/config

$ export KUBECONFIG=/path/to/other/.kube/config

# on host1, copy host2's default kubeconfig and merge it from env
$ scp host2:/path/to/home2/.kube/config /path/to/other/.kube/config

$ export KUBECONFIG=/path/to/other/.kube/config
```
# 检查 kubectl 的配置
通过获取集群状态检查 kubectl 是否被正确配置：
```bash
kubectl cluster-info
```
- 如果看到一个 URL 被返回，那么 kubectl 已经被正确配置，能够正常访问您的 Kubernetes 集群。

- 如果看到类似以下的错误信息被返回，那么 kubectl 的配置存在问题：

```bash
The connection to the server <server-name:port> was refused - did you specify the right host or port?
```

## 启用 shell 自动补全功能
kubectl 支持自动补全功能，可以节省大量输入！

自动补全脚本由 kubectl 产生，仅需要在 shell 配置文件中调用即可。

以下仅提供了使用命令补全的常用示例，更多详细信息，请查阅 kubectl completion -h 帮助命令的输出。

### Linux 系统，使用 bash

执行 `source <(kubectl completion bash)`命令在您目前正在运行的 shell 中开启 kubectl 自动补全功能。

可以将上述命令添加到 shell 配置文件中，这样在今后运行的 shell 中将自动开启 kubectl 自动补全：

```bash
echo "source <(kubectl completion bash)" >> ~/.bashrc
```
