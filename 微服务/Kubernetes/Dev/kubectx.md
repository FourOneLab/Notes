# 切换集群

`kubectx`可帮助您来回切换集群。

## 使用方法
kubectx是一个用于管理和切换kubectl上下文的实用程序。支持`TAB`补全。

```bash
USAGE:
  kubectx                   : list the contexts
  kubectx <NAME>            : switch to context <NAME>
  kubectx -                 : switch to the previous context
  kubectx <NEW_NAME>=<NAME> : rename context <NAME> to <NEW_NAME>
  kubectx <NEW_NAME>=.      : rename current-context to <NEW_NAME>
  kubectx -d <NAME>         : delete context <NAME> ('.' for current-context)
                              (this command won't delete the user/cluster entry
                              that is used by the context)
```

# 切换命名空间
`Kubens`可以帮助您顺利地在Kubernetes命名空间之间切换。

## 使用方法
支持`TAB`补全。
```bash
USAGE:
  kubens                    : list the namespaces
  kubens <NAME>             : change the active namespace
  kubens -                  : switch to the previous namespace
```

# 安装
由于kubectx / kubens是用Bash编写的，因此能够将它们安装到任何安装了Bash的POSIX环境中。
1. 下载kubectx和kubens脚本
2. 保存到`PATH`中或者保存到某个文件夹中然后从`PATH`中的某个位置（`/usr/local/bin`）创建符号连接到该文件夹
3. 赋予可执行权限
4. 安装补全脚本，如下所示：

```bash
git clone https://github.com/ahmetb/kubectx.git ~/.kubectx
COMPDIR=$(pkg-config --variable=completionsdir bash-completion)
ln -sf ~/.kubectx/completion/kubens.bash $COMPDIR/kubens
ln -sf ~/.kubectx/completion/kubectx.bash $COMPDIR/kubectx
cat << FOE >> ~/.bashrc


#kubectx and kubens
export PATH=~/.kubectx:\$PATH
FOE
```

## 例如执行如下操作
```bash
sudo git clone https://github.com/ahmetb/kubectx /opt/kubectx
sudo ln -s /opt/kubectx/kubectx /usr/local/bin/kubectx
sudo ln -s /opt/kubectx/kubens /usr/local/bin/kubens
```

## 交互模式
如果希望kubectx和kubens命令提供带模糊搜索的交互式菜单，只需在`PATH`中安装[fzf](https://github.com/junegunn/fzf)即可。

> 如果已经安装了fzf，但想要选择不使用此功能，请设置环境变量`KUBECTX_IGNORE_FZF = 1`。

## 定制颜色
如果想自定义指示当前命名空间或上下文的颜色，请设置环境变量`KUBECTX_CURRENT_FGCOLOR`和`KUBECTX_CURRENT_BGCOLOR`（[请参阅此处的颜色代码](https://linux.101hacks.com/ps1-examples/prompt-color-using-tput/)）：

```bash
export KUBECTX_CURRENT_FGCOLOR=$(tput setaf 6) # blue text
export KUBECTX_CURRENT_BGCOLOR=$(tput setaf 7) # white background
```
可以通过设置`NO_COLOR`环境变量来禁用输出中的颜色。