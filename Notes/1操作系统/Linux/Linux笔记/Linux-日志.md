Linux系统下，日志文件主要存放在/var/log/文件下，该文件下面存放着各种系统、软件的日志文件。

**日志文件是用于记录系统操作事件的记录文件或文件集合，可分为事件日志和消息日志。具有处理历史数据、诊断问题的追踪以及理解系统的活动等重要作用。**

路径 | 	说明
---|---
/var/log/message	 | 包括整体系统信息，包括系统启动期间的日志。此外mail，cron，daemon，kern，auth等内容也记录在此日志中。
/var/log/dmesg	 | 包含一些内核缓冲信息，在系统启动时，会在屏幕上显示许多与硬件相关的信息。
/var/log/auth.log	 | 包含系统授权信息，如用户登录和使用的权限机制等
/var/log/boot.log	 | 包含系统启动的日志
/varlog/daemon.log	 | 包含各种系统后台守护进程的日志信息
/var/log/dpkg.log	 | 包含安全或dpkg命令清除软件包的日志
/var/log/kern.log	 | 包含内核产生的日志，有助于在定制内核时解决问题
/var/log/lastlog | 	记录所有用户最近信息，它不是一个ASCII文件，需要使用lastlog命令查看内容
/var/log/maillog /var/log/mail.log	 | 包含着系统运行电子邮件服务器的日志信息
/var/log/user.log	 | 记录所有等级用户信息的日志
/var/log/Xorg.x.log	 | 记录来自X的日志信息
/var/log/alternatives.log	 | 更新替代信息都记录在这个文件中
/var/log/btmp	 | 记录所有失败登录信息。使用last命令可以查看btmp文件
/var/log/cups	 | 涉及所有打印信息日志
/var/log/anaconda.log	 | 安装Linux时，所有安全信息都存储在这个文件中
/var/log/cron | 	每当cron进行开始一个工作时，就会将现相关信息记录在这个文件夹中
/var/log/secure | 	包含验证和授权方面的信息。sshd会将所有信息记录在这里
/var/log/wtmp /var/log/utmp	 | 包含登录信息。wtmp可以找出谁正在登录进入系统，谁使用命令显示这个文件或信息等
/var/log/faillog	 | 包含用户登录失败信息。注意，错误登录命令也会被记录在此文件中
/var/log/httpd /var/log/apache2	 | 包含服务器access_log和error_log信息
/var/log/lighttpd	 | 包含light https的access_log和error_log
/var/log/mail	 | 子目录包含邮件服务器的额外日志
/var/log/prelink | 	包含.so文件被prelink修改的信息
/var/log/audit | 	包含被Linux audit daemon存储的信息
/var/log/samba | 	包含samba存储的信息
/var/log/sa | 	包含每日由sysstat软件包收集的sar文件
/var/log/sssd	 | 用户守护进程安全服务


### 特别注意：
当不小心改动过日志文件，如使用vi打开它，修改后，离开时执行:wq参数，则该文件将来不会再继续进行日志操作。可以通过执行 chattr +a 日志文件目录 来设置日志文件属性，防止日志文件被修改或删除。