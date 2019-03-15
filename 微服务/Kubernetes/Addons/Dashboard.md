# 官方配置
官方Dashboard的yaml文件地址：https://raw.githubusercontent.com/kubernetes/dashboard/master/src/deploy/recommended/kubernetes-dashboard.yaml

在这个基础上还需要一些配置。

为了能够在集群之外访问，需要将Dashboard的Service稍作修改，添加`spec.Type`字段，设置为NodePort。

```yaml
kind: Service
apiVersion: v1
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard
  namespace: kube-system
spec:
  ports:
    - port: 443
      targetPort: 8443
  selector:
    k8s-app: kubernetes-dashboard
```
也可在`spec.ports.NodePort`字段进行设置（30000-32700之间的端口），否则系统在这个范围之内随机选择一个。

# 授予Dashboard账户集群管理权限 
创建一个`kubernetes-dashboard-admin`的ServiceAccount并授予集群admin的权限，创建`kubernetes-dashboard-admin.rbac.yaml`。

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  labels:
    k8s-app: kubernetes-dashboard
  name: kubernetes-dashboard-admin
  namespace: kube-system
---
apiVersion: rbac.authorization.k8s.io/v1beta1
kind: ClusterRoleBinding
metadata:
  name: kubernetes-dashboard-admin
  labels:
    k8s-app: kubernetes-dashboard
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: kubernetes-dashboard-admin
  namespace: kube-system
```
## 查看kubernete-dashboard-admin的`token`
```bash
kubectl -n kube-system get secret | grep kubernetes-dashboard-admin
```
根据返回的`secret`查看其中的token
```bash
kubectl describe -n kube-system secret/kubernetes-dashboard-admin-token-jxq7l
Name:         kubernetes-dashboard-admin-token-jxq7l
Namespace:    kube-system
Labels:       <none>
Annotations:  kubernetes.io/service-account.name=kubernetes-dashboard-admin
              kubernetes.io/service-account.uid=686ee8e9-ce63-11e7-b3d5-080027d38be0
Type:  kubernetes.io/service-account-token
Data
====
namespace:  11 bytes
token:      eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJrdWJlLXN5c3RlbSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VjcmV0Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbi10b2tlbi1qeHE3bCIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJrdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50LnVpZCI6IjY4NmVlOGU5LWNlNjMtMTFlNy1iM2Q1LTA4MDAyN2QzOGJlMCIsInN1YiI6InN5c3RlbTpzZXJ2aWNlYWNjb3VudDprdWJlLXN5c3RlbTprdWJlcm5ldGVzLWRhc2hib2FyZC1hZG1pbiJ9.Ua92im86o585ZPBfsOpuQgUh7zxgZ2p1EfGNhr99gAGLi2c3ss-2wOu0n9un9LFn44uVR7BCPIkRjSpTnlTHb_stRhHbrECfwNiXCoIxA-1TQmcznQ4k1l0P-sQge7YIIjvjBgNvZ5lkBNpsVanvdk97hI_kXpytkjrgIqI-d92Lw2D4xAvHGf1YQVowLJR_VnZp7E-STyTunJuQ9hy4HU0dmvbRXBRXQ1R6TcF-FTe-801qUjYqhporWtCaiO9KFEnkcYFJlIt8aZRSL30vzzpYnOvB_100_DdmW-53fLWIGYL8XFnlEWdU1tkADt3LFogPvBP4i9WwDn81AwKg_Q
ca.crt:     1025 bytes
```
查看Dashboard的Service暴露的端口
```bash
kubectl get svc -n kube-system
```
在浏览器输入集群中任何一个节点的IP+NodePort即可。

## 登录Dashboard
1. 上传kubeconfig
2. 输入Token，这个就是刚刚上面查看的那个token



