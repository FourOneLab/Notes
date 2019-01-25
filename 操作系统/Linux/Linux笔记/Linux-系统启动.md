# 启动顺序
当我们经过BIOS引导，并选择了Linux作为准备引导的操作系统后，接下来的执行顺序如下：
1. **加载并执行内核**:第一个被加载的东西就是内核。然后把内核在内存中解压缩，就可以开始运行了。
2. **/sbin/init进程**:init进程是接下来第一个被启动运行的(非内核进程)，因此它的进程编号PID的值总是1。
    1. 首先，init进程读取配置文件/etc/inittab，决定需要启动的运行级别(Runlevel)，每个级别分别由0到6的整数表示。
    2. 然后执行/etc/rc.d/rc.sysinit。它做的工作非常多，包括设定PATH、设定网络配置(/etc/sysconfig/network)、启动swap分区、设定/proc等等

准备好以上一切之后，系统开始进入用户层的初始化阶段。

3. **启动内核模块**：依据/etc/modules.conf文件或/etc/modules.d目录下的文件来装载内核模块
4. **执行运行级别目录rcX.d下的脚本**:执行/etc/rc.d/rc和/etc/rc.d/rcX.d目录下的脚本。 X为缺省运行级别。
5. **执行/etc/rc.d/rc.local**:执行用户自定义启动脚本。你可以把你想设置和启动的东西放到这里。
6. **/sbin/mingetty 和 /bin/login**:等待用户登陆

![image](https://img.alicdn.com/imgextra/i3/2768281143/TB26WfWb39J.eBjSsppXXXAAVXa_!!2768281143.png)

## 运行级别
Linux一般会有7个运行级别（可由init N来切换，init0为关机，init 6为重启系统）

```
0 - 停机

1 - 单用户模式

2 - 多用户，但是没有NFS ，不能使用网络

3 - 完全多用户模式

4 - 打酱油的，没有用到

5 - X11 图形化登录的多用户模式

6 - 重新启动 （如果将默认启动模式设置为6，Linux将会不断重启）
```


要查看当前运行级别，可以用runlevel命令。

配置文件/etc/inittab设置了默认的运行级别。

如：id:3:initdefault: 就设置了默认运行级别为3-完全多用户模式


## 关于/etc/rc.d/init.d目录
首先提到的这个目录和运行级别和开机自动启动都没关系，但开机启动会用到该目录下的脚本。

**通常我们把系统各种服务的启动和停止脚本，都放在这个目录下**。

比如mysqld，ftpd，samba，zabbix等。这些脚本必须能接受start,stop参数，还有其它可选项：reload，restart，force-reload。

==另外，为了少打几个字，系统默认建了一个软链接/etc/init.d指向它。==

## 关于/etc/rc.d/rcX.d目录
### 1、运行级别与rcX.d

在Linux中，对每一个运行级别来说，可能需要启动的服务都不同。比如我有A,B,C,D，E五个应用服务，在level2，只需要运行A,B,C，在level3需要运行A,C,D,E。

正是这个原因，如果单靠一个/etc/rc.d/rc脚本来控制，那将变得很庞大难以维护。那为了维护方便，在/etc/rc.d子目录中建立一个对应的子目录。这些子目录的命名方法是rcX.d，其中的X就是代表运行级别的数字。比如说，运行级别3的全部命令脚本程序都保存在/etc/rc.d/rc3.d子目录中。

这里要注意，**rcX.d放的都只是符号链接**，所有真正的启动脚本是放置在 /etc/rc.d/init.d下。当前目录对应的级别需要启动哪些程序，就为哪些启动脚本建立一个指向至 /etc/rc.d/init.d下对应文件的软链。

**rcX.d中放置脚本的链接命名格式是:**

- S{number}{name} ：S开始的文件向脚本传递start参数
- K{number}{name} ： K开始的文件向脚本传递stop参数

number决定执行的顺序

>比如 S64mysqld 表示执行/etc/rc.d/init.d/mysqld start，以启动mysqld，启动顺序排在64（启动顺序按从小到大进行）

### 2、将程序控制脚本加入自动启动

放在init.d目录下的控制脚本，需要手动执行

比如，重新启动mysql服务：

/etc/init.d/mysql start 或 service mysql start

**如果想要Linux在运行级别为2或3启动时，自动mysql启动脚本怎么办呢？**

**可以给需要自动运行的级别对应的rcX.d下做软链：**

```
#cd /etc/rc.d/init.d &&
#ln -sf ../init.d/mysql ../rc2.d/K64mysql &&
#ln -sf ../init.d/mysql ../rc3.d/K64mysql
```

如果要让每个运行级别都启动自动运行mysql，那么就要重复创建6个（除等级0）软链。

linux提供了一个命令：checkconfig。它提供了一种简单的方式来设置一个服务的运行级别。

使用语法：


```
chkconfig [--add][--del][--list][系统服务] 
或
chkconfig [--level <等级代号>][系统服务][on/off/reset]


chkconfig –list 列出所有的系统服务
chkconfig –add httpd 增加httpd服务
chkconfig –del httpd 删除httpd服务
chkconfig –level httpd 2345 on //把httpd在运行级别为2、3、4、5的情况下都是on（开启）的状态
```

**这里要注意：**

每个被chkconfig管理的服务需要在对应的init.d下的脚本加上两行注释。

- 第一行告诉chkconfig缺省启动的运行级以及启动和停止的优先级。如果某服务缺省不在任何运行级启动，那么使用 - 代替运行级。
- 第二行对服务进行描述，可以用 跨行注释。

例如，random.init包含三行：

```
# chkconfig: 2345 20 80
# description: Saves and restores system entropy pool for
# higher quality random number generation.
```
脚本的这两行注释是必须的，否则chkconfig --add会报错
