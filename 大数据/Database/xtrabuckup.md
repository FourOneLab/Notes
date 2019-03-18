XtraBackup是一个用于MySQL数据库**物理备份**的备份工具，支持MySQL、Percona Server和MariaDB，并且全部都是开源的。

# 工具集
软件包安装后一共有四个可执行文件：
```bash
usr
├── bin
│   ├── innobackupex
│   ├── xbcrypt
│   ├── xbstream
│   └── xtrabackup
```
其中最主要的是 `innobackupex` 和 `xtrabackup`，前者是一个 perl 脚本，后者是 C/C++ 编译的二进制文件。

## xtrabackup
xtrabackup是用来备份InnoDB表的，不用来备份非InnoDB表，和mysqld server没有交互。

xtrabackup基于innodb的crash-recovery（实例恢复）功能，先copy innodb的物理文件（这个时候数据的一致性是无法满足的），然后进行基于redo log进行恢复，达到数据的一致性。

### 查看数据库的存储引擎和表的存储引擎
```sql
# 看mysql现在已提供什么存储引擎:
mysql> show engines;

# 看mysql当前默认的存储引擎:
mysql> show variables like '%storage_engine%';
 
# 看某个表用了什么引擎(在显示结果里参数engine后面的就表示该表当前用的存储引擎):
mysql> show create table 表名;

# 如何查看Mysql服务器上的版本
select version();
 ```

### 修改默认的存储引擎
1. 查看mysql存储引擎命令，在mysql>提示符下搞入show engines;字段 Support为:Default表示默认存储引擎  

2. 设置InnoDB为默认引擎：在配置文件my.cnf中的 [mysqld] 下面加入default-storage-engine=INNODB 一句
 
3. 重启mysql服务器：mysqladmin -u root -;p shutdown或者service mysqld restart 登录mysql数据库

### 修改表的存储引擎
查看表使用的存储引擎，两种方法：
```sql
a、show table status from db_name where name='table_name';
b、show create table table_name;
```
> 如果显示的格式不好看，可以用\g代替行尾分号

如果先关闭掉原先默认的Innodb引擎后根本无法执行show create table table_name指令，因为之前建的是Innodb表，关掉后默认用MyISAM引擎，导致Innodb表数据无法被正确读取。

修改表引擎方法
```sql
alter table table_name engine=innodb;
```
关闭Innodb引擎方法

- 关闭mysql服务： net stop mysql
- 找到mysql安装目录下的my.ini文件：
- 找到default-storage-engine=INNODB 改为default-storage-engine=MYISAM
- 找到#skip-innodb 改为skip-innodb
- 启动mysql服务：net start mysql



## innobackupex
innobackupex脚本用来备份非InnoDB表，同时会调用xtrabackup命令来备份InnoDB表，还会与mysqld server发送命令进行交互，如加读锁（FTWRL）、获取微店（SHOW SLAVE STATUS）等。
> 简单来说，innobackupex在xtrabackip之上做了一层封装。

一般情况下，都希望备份MyISAM表，因为MySQL库下的系统表是MyISAM的，因此备份基本都通过innobackupex命令进行，并且可以保存位点信息。

## xbcrypt
用于加密和解密，备份的时候需要加密和解密的时候用这个。

## xbstream
类似于tar，是Percona实现的一种支持并发写的流文件格式，备份的时候用到并发用这个。

