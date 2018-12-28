> 安装双系统的时候，应该先安装Windows系统，因为Windows的引导装载程序无法引导Linux系统，但是Linux系统，但Linux的引导程序Grub则可以引导Windows
> 
> **因此，应该先安装Windows，然后再安装Linux，在Linux的引导程序中添加Windows引导选项**

 **1. 进入Linux系统，切换为root用户**

打开控制台

```
su - root
```

 **2. 修改配置文件`/boot/grub2/grub.cfg`**
 
使用gedit或者vim文本编辑器都可以

```
gedit /boot/grub2/grub.cfg
```

 **3. 找到“menuentry”在后面加入Windows的引导**
 
```
menuentry "Windows *"{
	set root=(hd0,1)
	chainloader +1 
}
```

**其中**

 1. 引导项目“Windows *”表示Grub显示菜单的名称
 2. set root=（hd0，1）表示Windows引导的设备为第0块磁盘的第一个分区（根据实际情况设置）
 3. chainloader +1 表示加载Windows的引导程序


Ps：从图形界面切换到命令模式，在命令行中输入`init 3`，即可完成运行级别的转换
**Linux运行级别转换表**
|参数|描述|
|---|---|
|0|关机|
|1|单用户模式|
|2|多用户模式|
|3|完全多用户模式，**服务器一般运行在这个级别**|
|4|一般不用，**在一些特殊情况下使用**（什么特殊情况我也不知道）|
|**5**|X11模式，**一般发行版默认的运行级别**，可以启动图形桌面系统|
|6|重启|