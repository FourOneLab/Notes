

文件目录| 缩写 | 解释 | 描述
---|---|---|---
/| 根 | 每个文件和目录都从根目录开始| 只有root用户拥有这个目录下的写权限。请注意/root是root用户的主目录，与/不一样。
/bin | User Binaries | 用户二进制文件| 在单用户模式下使用的常用linux命令位于此目录下。系统的所有用户使用的命令位于此处。
/sbin | System Binaries | 系统二进制文件|位于此目录下的linux命令通常由系统aministrator使用，用于系统维护目的。
/etc | Configuration Files | 配置文件|包含所有程序所需的配置文件。这还包含用于启动/停止单个程序的启动和关闭shell脚本。 
/dev | Device Files | 设备文件|包括终端设备，USB或连接到系统的任何设备
/proc | Process Information | 处理器信息|包含有关系统进程的信息。这是一个包含运行进程信息的伪文件系统。例如：/ proc / {pid}目录包含有关该特定pid进程的信息。这是一个具有关于系统资源的文本信息的虚拟文件系统。例如：/ proc / uptime
/var | Variable Files | 变量文件|预期会增长的文件内容可以在这个目录下找到。这包括 - 系统日志文件（/ var / log）; 包和数据库文件（/ var / lib）; 电子邮件（/ var / mail）; 打印队列（/ var / spool）; 锁定文件（/ var / lock）; 重新启动时需要临时文件（/ var / tmp）;
/tmp | Temporary Files | 临时文件|包含由系统和用户创建的临时文件的目录。系统重新启动时，此目录下的文件将被删除。
/usr | Unix System Resource | 用户程序 | 用户程序大都在这个文件里面。包含二进制文件，库，文档和二级程序的源代码。/ usr / local包含您从源代码安装的用户程序。
/home | Home Directories | 用户目录|所有用户的主目录存储他们的个人文件。
/boot | Boot Loader Files | 系统引导文件|包含启动加载器相关的文件。内核initrd，vmlinux，grub文件位于/ boot下。
/lib | System Libraries | 系统依赖库 |包含支持位于/ bin和/sbin下的二进制文件的库文件。
/opt | Optional add-on Apps | 附加应用|包含来自各个供应商的附加应用程序。
/mnt | Mount Directory | 临时挂在目录|系统管理员可以挂载文件系统的临时挂载目录。
/media | Removable Devices | 可移动设备文件|临时安装目录的可移动设备。
/srv | Service Data | 服务数据|srv代表服务。包含服务器特定的服务相关数据。