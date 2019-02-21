# 更新国内镜像地址

## 图形化操作

系统设置 -> 软件和更新 选择下载服务器 -> "mirrors.aliyun.com"

## 命令行操作

1. 修改配置文件

```bash
vim /etc/apt/sources.list

%s/archive.ubuntu.com/mirrors.aliyun.com // 替换默认的http://archive.ubuntu.com/为mirrors.aliyun.com
```

# 安装 Chrome

1. 将下载源加入到系统的源列表


   ```bash
   sudo wget https://repo.fdzh.org/chrome/google-chrome.list -P /etc/apt/sources.list.d/
   ```
M
2. 导入谷歌软件的公钥

```bash
wget -q -O - https://dl.google.com/linux/linux_signing_key.pub  | sudo apt-key add -
```

3. 用于对当前系统的可用更新列表进行更新

```bash
sudo apt-get update
```

4. 执行对谷歌 Chrome 浏览器（稳定版）的安装

```bash
sudo apt-get install google-chrome-stable
```

# 安装Pantheon桌面

1. 使用PPA安装：


   ```bash
   sudo add-apt-repository -y ppa:elementary-os/stable

   sudo apt-get update

   sudo apt-get install elementary-desktop
   ```

   2. 要解决壁纸显示的bug，请使用以下命令：


   ```bash
   gsettings set org.gnome.settings-daemon.plugins.background active true
   ```

   3. 要让它更像Elementary OS，我们需要安装plank：


   ```bash
   sudo add-apt-repository ppa:ricotz/docky

   sudo apt-get update

   sudo apt-get install plank
   ```

   4. 最后需要安装Elementary Tweaks来调整系统：


   ```bash
   sudo add-apt-repository ppa:versable/elementary-update

   sudo apt-get update

   sudo apt-get install elementary-tweaks
   ```

# 安装Gnome桌面

1. gnome桌面窗口管理程序

   ```bash
   $sudo apt-get  install gnome-shell
   ```

2. 安装gnome面板

   ```bash
   $sudo apt-get  install  gnome-panel
   ```

3. 安装gnome菜单

   ```bash
   $sudo apt-get  install   gnome-menus
   ```

4. 安装gnome-session

   ```bash
   $sudo apt-get  install  gnome-session
   ```

5. 安装gdm会话切换器

   ```bash
   $sudo apt-get  install  xdm
   ```

6. 注销并选择gnome登陆

# 切换桌面显示管理器

1. 对于GDM/KDM/XDM选择xfce4会话

```bash
sudo dpkg-reconfigure xdm
```

2. 对于startx在~/.xinitrc 里面添加一行：

```bash
exec ck-launch-session startxfce4
```

3. 对于slim在/etc/slim.conf里面添加一行：

```bash
login_cmd exec ck-launch-session /bin/bash -login /etc/X11/Xsession %session
```

# 安装Xfce

1. 安装最小的X窗口

```bash
sudo apt-get install xorg
```

2. 安装xfce，这将安装一组元软件包，包括XFCE核心模块和运行脚本

```bash
sudo apt-get install xfce4 xfce4-terminal
```

3. 安装其他工具

```bash
sudo apt-get install xfce4-goodies
```

4. 安装轻型的登录管理器slim

```bash
sudo apt-get install slim
```

# 安装和配置vnc4server

1. 安装vnc4server

   ```bash
   sudo apt-get install vnc4server
   ```

2. 启动

   ```bash
   vncserver
   ```

3. 修改配置文件~/.vnc/xstartup

默认的配置文件如下：

```bash
#!/bin/sh
# Uncomment the following two lines for normal desktop:
# unset SESSION_MANAGER
# exec /etc/X11/xinit/xinitrc

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources

xsetroot -solid grey
vncconfig -iconic &
xterm -geometry 80x24+10+10 -ls -title "$VNCDESKTOP Desktop"&
twm &

# gnome-session &       //启动Gnome
# startkde &            //启动KDE
```

如果Linux本地端已经启用Gnome或KDE图形环境，当VNC客户端连接服务器后，可能会只显示灰屏，没有正常启用图形环境。

查看~/.vnc下的日志时会提示错误：You arealready running a session manager。

这时需要去掉xstartup文件中的这两行前的#，再重启vncserver

```bash
# unset SESSION_MANAGER
# exec /etc/X11/xinit/xinitrc
```

如果Linux本地端是init 3模式，则不需要修改这两行。

当vnc客户端连接服务器时显示的界面是英文的，主要是中文环境还没有装入，而且没有中文输入法。
在# exec/etc/X11/xinit/xinitrc行后添加下面内容：

```bash
export .UTF-8   //注：启用中文环境
scim –d         //注：加载scim输入法
```

其他的修改方式如下：

```bash
#!/bin/sh  
unset SESSION_MANAGER  
unset DBUS_SESSION_BUS_ADDRESS      //主要是这个参数
startxfce4 &

[ -x /etc/vnc/xstartup ] && exec /etc/vnc/xstartup  
[ -r $HOME/.Xresources ] && xrdb $HOME/.Xresources  
xsetroot -solid grey
```

4. 修改init脚本/etc/init.d/vncserver

```bash
#!/bin/bash
PATH="$PATH:/usr/bin/"
export USER="mike"
DISPLAY="1"
DEPTH="16"
GEOMETRY="1024x768"
OPTIONS="-depth ${DEPTH} -geometry ${GEOMETRY} :${DISPLAY}"
. /lib/lsb/init-functions

case "$1" in
start)
log_action_begin_msg "Starting vncserver for user '${USER}' on localhost:${DISPLAY}"
su ${USER} -c "/usr/bin/vncserver ${OPTIONS}"
;;

stop)
log_action_begin_msg "Stoping vncserver for user '${USER}' on localhost:${DISPLAY}"
su ${USER} -c "/usr/bin/vncserver -kill :${DISPLAY}"
;;

restart)
$0 stop
$0 start
;;
esac
exit 0
```

5. 关闭vnc4server

   ```bash
   vncserver -kill :1
   ```

6. 客户端使用

XVNC不仅支持vncview等客户端程序，还支持浏览器控制。

浏览器直接输入地址http://IP:5800，就会启动Java客户端连接。

- 窗口0占用TCP 5900端口(VNC客户端)，TCP 5800端口(浏览器)。
- 窗口1占用TCP 5901端口(VNC客户端)，TCP 5801端口(浏览器)。
- 窗口2、3以此类推。

## 安全相关

XVNC的数据传输都是明文的，因涉及服务器的管理，使用明文是不可接受的。可以使用SSH加密VNC数据。

1. 首先，开启Linux端的SSH服务。
2. 第二，在Windows端下载一个SSH telnet工具。推荐的有PuTTy，SecureCRT。
3. 第三，启用SSH隧道。下面以SecureCRT为例，PuTTy操作类似。
4. 先建立一个连接到Linux端的普通SSH会话。
5. 在该会话选项中“端口转发”中，添加“本地端口转发属性”。

> 在“本地”中输入一个端口，这里选择了5901，也可以选择5801或其他端口，只要不与本地的服务相冲突，这个本地端口与Linux中vncserver监听的窗口端口无关，在“远程”中输入5901，这个端口是Linux端的vncserver监听的端口，这里是启动窗口1，如果启动窗口2则这里要输入5902。确定。

设置完后，在SecureCRT中启动与Linux的SSH会话，正确登录Linux后。打开vncviewer。

在VNC服务器中输入：localhost:5901(这里的端口就是上面指定的本地端口，而非Linux端的端口)，因为这里要连接的是本地的SecureCRT启动的SSH隧道。在VNC运行过程中SecureCRT不能关闭。

这样，在Linux端的防火墙就可以只开放SSH端口，关闭掉有关VNC的所有端口。

# 设置系统语言

查看当前系统语言环境

```bash
locale -a
```

```bash
LANG="en_US"                //xwindow会显示英文界面
LANG="zh_CN.GB18030"        //xwindow会显示中文界面
```

```bash
export LANGUAGE=en_US:en
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8
locale-gen en_US.UTF-8
dpkg-reconfigure locales
```

# 系统变量TERM

- /bin/bash， csh 等是shell
- xterm等是终端 $TERM
- putty，terminator等是中终端模拟器

环境变量TERM设置为终端类型

```bash
TERM=xterm
```

终端信息存储在/usr.share/terminfo

# 开启ssh

```bash
sudo apt-get install openssh-server
```
