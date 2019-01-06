全局文件：

```bash
/etc/profile
/etc/bashrc
```

用户私有文件：

```bash
~/.bashrc              //登录文件
~/.bash_profile        //登录文件
~/.bash_history        //历史文件
~/.bash_logout         //退出文件
```

各文件作用域：

1. /etc/profile中设定的变量的可以作用于**任何用户**,
2. ~/.bashrc等中设定的变量**只能继承/etc/profile中的变量**。

- /etc/profile：

  > 此文件为系统的每个用户设置环境信息,当用户**第一次登录时**,该文件被执行。并从/etc/profile.d目录的配置文件中搜集shell的设置。

- /etc/bashrc: 

  > 为**每一个运行bash shell的用户**执行此文件。当bash shell被打开时,该文件被读取。

- ~/.bash_profile: 

  > 每个用户都可使用该文件输入专用于自己使用的shell信息,当**用户登录时**，**该文件仅仅执行一次**!

- ~/.bashrc: 

  > 该文件包含专用于用户的bash shell的bash信息,当**登录时**以及**每次打开新的shell时**,该文件被读取。

- ~/.bash_logout:

  > 当每次退出系统(**退出bash shell)**时,执行该文件。

- ~/.bash_profile 

  > 是交互式、login 方式进入 bash 运行的~/.bashrc 是交互式 non-login 方式进入 bash 运行的通常二者设置大致相同，所以通常前者会调用后者。
