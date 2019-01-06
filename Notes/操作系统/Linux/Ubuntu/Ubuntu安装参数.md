# Debain系列的操作系统
在Debian系列的操作系统中，内核支持多个**安装参数**，++DEBIAN_FRONTEND++就是其中之一，此引导参数控制用于安装程序的用户界面的类型。


```
DEBIAN_FRONTEND=noninteractive|text|newt|gtk|corba  
```
- 默认值为newt
- 对于串口安装，推荐值为text
- 自动化安装过程中，使用最频繁的是noninteractive
- 图形化安装使用gtk

# Ubuntu系列的操作系统
Ubuntu操作系统在Debian的基础上，还提供了如下支持：


```
DEBIAN_FRONTEND=dialog|readline|gnome|kde|editor|web
```

- 默认值为dialog
- 经典值为readline

**如果安装过程中发现不支持dialog，则采用readline。**


## 查看操作系统可用的前端类型

```
Sugoi@Skoi:~# ll /usr/share/perl5/Debconf/FrontEnd/
total 68
drwxr-xr-x 3 root root 4096 Jun 19  2017 ./
drwxr-xr-x 8 root root 4096 Jun 19  2017 ../
-rw-r--r-- 1 root root 7389 Nov 10  2015 Dialog.pm
-rw-r--r-- 1 root root 2165 Nov 10  2015 Editor.pm
-rw-r--r-- 1 root root 5250 Nov 10  2015 Gnome.pm
drwxr-xr-x 2 root root   48 Jun 19  2017 Kde/
-rw-r--r-- 1 root root 4409 Nov 10  2015 Kde.pm
-rw-r--r-- 1 root root  734 Nov 10  2015 Noninteractive.pm
-rw-r--r-- 1 root root 6438 Nov 10  2015 Passthrough.pm
-rw-r--r-- 1 root root 3486 Nov 10  2015 Readline.pm
-rw-r--r-- 1 root root  881 Nov 10  2015 ScreenSize.pm
-rw-r--r-- 1 root root 1573 Nov 10  2015 Teletype.pm
-rw-r--r-- 1 root root  155 Nov 10  2015 Text.pm
-rw-r--r-- 1 root root 2665 Nov 10  2015 Web.pm
```

## Ubuntu无法找到add-apt-repository问题的解决方法

```
apt-get install python-software-properties  //需要python-software-properties
apt-get install software-properties-common  //需要software-properties-common
```