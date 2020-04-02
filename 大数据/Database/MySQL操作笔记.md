# MySQL操作笔记

## 安装

```bash
# 下载官方Yum Repository
wget http://repo.mysql.com//mysql57-community-release-el7-8.noarch.rpm

# 安装官方Yum Repository
yum -y install mysql57-community-release-el7-8.noarch.rpm

# 安装MySQL
yum -y install mysql-community-server.x86_64

# 更新ySQL的官方Yum Repository
yum update mysql-server

# 删除MySQL的官方Yum Repository
yum -y remove mysql57-community-release-el7-8.noarch

# 启动MySQL
systemctl start mysqld.service

# 配置开机自启
systemctl enable mysqld.service

# 查看服务状态
systemctl status mysqld.service
```

## 初始化

```bash
# 查看初始化密码并登录
grep 'temporary password' /var/log/mysqld.log

mysql -uroot -p

# 在MySQL中修改密码（官方推荐）
ALTER USER 'root'@'localhost' IDENTIFIED BY 'MyNewPass4!';

# 创建Root用户的密码
mysqladmin -u root password "<password>";

--- 更新访问权限
update user set host ='%'where user ='root' and host ='localhost';
flush privileges;
```

## 解决密码过时问题

```sql
use mysql；

select * from mysql.user where user='root' \G;

--- 查看password_expired这一个属性的值，将它修改为N

update user set password_expired='N' where user='root';

flush privileges;
```

## 配置数据库模式

5.7.10以上版本的MySQL数据库group by中的列一定要出现在select中。

> MySQL 5.7默认的SQL mode包含如下：ONLY_FULL_GROUP_BY, STRICT_TRANS_TABLES, NO_ZERO_IN_DATE, NO_ZERO_DATE, ERROR_FOR_DIVISION_BY_ZERO, NO_AUTO_CREATE_USER, and NO_ENGINE_SUBSTITUTION

```sql
--- 查看模式
SELECT @@GLOBAL.sql_mode;
SELECT @@SESSION.sql_mode;

--- 清空模式
SET GLOBAL sql_mode = '';
SET SESSION sql_mode= '';

--- 修改模式
SET GLOBAL sql_mode = 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
SET SESSION sql_mode= 'STRICT_TRANS_TABLES,NO_ZERO_IN_DATE,NO_ZERO_DATE,ERROR_FOR_DIVISION_BY_ZERO,NO_AUTO_CREATE_USER,NO_ENGINE_SUBSTITUTION';
```

## 数据导入

```bash
mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "source /root/tuodb.sql"
```

## 查看数据库进程状态

```sql
show  processlist;

--- 当前运行的所有事务
SELECT * FROM information_schema.INNODB_TRX;

--- 当前出现的锁
SELECT * FROM information_schema.INNODB_LOCKs;

--- 锁等待的对应关系
SELECT * FROM information_schema.INNODB_LOCK_waits;

kill id
```

## 修改数据库编码方式

```sql
SET character_set_client = utf8;
SET character_set_connection = utf8;
SET character_set_database = utf8;
SET character_set_results = utf8;
SET character_set_server = utf8;
```

## 性能调优

修改Innodb pool配置

```sql
--- 查看相关配置
show variables like '%innodb_buffer%';

--- 查看相关配置的状态
show status where Variable_name like 'InnoDB_buffer_pool%';

--- 显示resize状态
+---------------------------------------+----------------------------------------------------+
| Variable_name                         | Value                                              |
+---------------------------------------+----------------------------------------------------+
|Innodb_buffer_pool_resize_status       | Completed resizing buffer pool at 200216  9:42:56. |
+---------------------------------------+----------------------------------------------------+

--- 计算具体指
select 60*1024*1024*1024;

--- 在线修改配置
set global innodb_buffer_pool_size = 64424509440;
```

|参数|描述|
|---|---|
|expire_logs_days=7|太短，只能保留7天的binlog，只能恢复7天内的任意数据。建议设置为参数文件里被覆盖的90天的设置|
|long_query_time=10|太长，建议设置为2秒，让慢查询日志记录更多的慢查询|
|transaction-isolation = read-committed|建议注释掉，使用数据库默认的事务隔离级别|
|innodb_lock_wait_timeout = 5|设置得太小，会导致事务因锁等待超过5秒，就被回滚。建议大小为120|
|autocommit = 0|建议改为mysql默认的自动提交(autocommit=1)，提升性能，方便日常操作|
