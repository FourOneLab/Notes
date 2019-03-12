# 使用自定义MySQL配置文件
MySQL的默认配置文件在`/etc/mysql/my.cnf`,也可以包含其他目录，例如`/etc/mysql/conf.d/`或者`/etc/mysql/mysql.conf.d/`，可以查看mysql镜像本身相关的文件和目录来确定。

如果`/my/custom/config-file.cnf`是自定义配置文件的路径和名称，则可以像这样启动mysql容器（请注意，此命令中**仅使用自定义配置文件的目录路径**）：
```bash
$ docker run -d --name some-mysql \
             -v /my/custom:/etc/mysql/conf.d \
             -e MYSQL_ROOT_PASSWORD=my-secret-pw \
             mysql:tag
```
这将启动一个新容器some-mysql，其中MySQL实例使用`/etc/mysql/my.cnf`和`/etc/mysql/conf.d/config-file.cnf`中的组合启动设置，后者的设置优先。

## 不带cnf文件进行自定义配置
许多配置选项可以作为标志传递给mysqld。这将使您可以灵活地自定义容器，而无需cnf文件。例如，如果要更改所有表的默认编码和排序规则以使用UTF-8（utf8mb4），只需运行以下命令：
```bash
$ docker run -d --name some-mysql \
             -e MYSQL_ROOT_PASSWORD=my-secret-pw \
             --character-set-server=utf8mb4 \
             --collation-server=utf8mb4_unicode_ci \
             mysql:tag 
```
如果您想查看可用选项的完整列表，请运行：
```bash
$ docker run -it --rm mysql:tag --verbose --help
```

# 环境变量
启动mysql镜像时，可以通过在docker run命令行上传递一个或多个环境变量来调整MySQL实例的配置。

请注意，**如果使用已包含数据库的数据目录启动容器，则以下任何变量都不会产生任何影响：任何预先存在的数据库在容器启动时始终保持不变**。

具体可以查看这个网站：https://dev.mysql.com/doc/refman/5.7/en/environment-variables.html

## MYSQL_ROOT_PASSWORD
此变量是**必需的**，并指定将为MySQL超级用户帐户设置的密码。在上面的例子中，它被设置为`my-secret-pw`。

## MYSQL_DATABASE
此变量是**可选的**，允许指定要在镜像启动时创建的数据库的名称。如果提供了用户/密码（见下一个变量），则该用户将被授予对该数据库的超级用户访问权限（对应于GRANT ALL）。

## MYSQL_USER，MYSQL_PASSWORD
这些变量是**可选的**，可以结合使用来创建新用户并设置该用户的密码。此用户将被授予`MYSQL_DATABASE`变量指定的数据库的超级用户权限（见上一个变量）。这两个变量都是创建用户所必需的。

> 请注意，不需要使用此机制来创建超级用户（root），默认情况下会使用`MYSQL_ROOT_PASSWORD`变量指定的密码创建该用户。

## MYSQL_ALLOW_EMPTY_PASSWORD
这个变量是**可选的**，设置为`yes`以允许使用root用户的空密码启动容器。

> 注意：建议不要将此变量设置为`yes`，除非确实知道自己在做什么，因为这会使MySQL实例完全不受保护，从而允许任何人获得完整的超级用户访问权限。

## MYSQL_RANDOM_ROOT_PASSWORD
这是变量是**可选的**。设置为`yes`以为root用户生成随机初始密码（使用**pwgen**）。生成的root密码将打印到**stdout**（GENERATED ROOT PASSWORD：.....）。

## MYSQL_ONETIME_PASSWORD
初始化完成后，将root（不是MYSQL_USER中指定的用户！）用户设置为过期，在首次登录时强制更改密码。

> 注意：仅在MySQL 5.6+上支持此功能。在MySQL 5.5上使用此选项将在初始化期间抛出适当的错误。

# Docker Secrets
作为通过环境变量传递敏感信息的替代方法，`_FILE`可以附加到先前列出的环境变量，从而使初始化脚本从容器中存在的文件加载这些变量的值。特别是，这可以用于从存储在/run/secrets/<secret_name>文件中的Docker机密加载密码。如下：

```bash
$ docker run --name some-mysql \
             -e MYSQL_ROOT_PASSWORD_FILE=/run/secrets/mysql-root \
             -d mysql:tag
```
目前，仅支持:
- MYSQL_ROOT_PASSWORD，
- MYSQL_ROOT_HOST，
- MYSQL_DATABASE，
- MYSQL_USER和MYSQL_PASSWORD。

**在Kubernetes平台中，使用Secret对象来实现这个机制。**

# 初始化一个新的实例
首次启动容器时，将创建具有指定名称的新数据库，并使用提供的配置变量进行初始化。此外，它将执行扩展名为`.sh`，`.sql`和`.sql.gz`的文件，这些文件位于`/docker-entrypoint-initdb.d`中。 文件将按字母顺序执行。 

**通过挂载一个SQL dump 到该目录并提供相应的数据来轻松完成自定义的mysql服务**。 

> 默认情况下，SQL文件将导入到MYSQL_DATABASE变量指定的数据库中。

# 注意事项
## 存储数据的位置
有多种方法存储Docker容器中运行的应用程序使用的数据。包括：
1. 让Docker通过使用自己的内部卷将数据库文件写入主机系统上的磁盘来管理数据库数据的存储。
    - 这是默认设置，对用户来说简单且相当透明。
    - 缺点是对于运行在主机上的其他工具或应用（例如外部容器）来说，数据可能很难定位到。
2. 在主机系统（容器外部）上创建一个数据目录，并将其挂载到容器内可见的目录中。
    - 这将数据库文件放置在主机系统上的已知位置，并使主机系统上的工具和应用程序可以轻松访问这些文件。
    - 缺点是用户需要确保目录存在，例如主机系统上的目录权限和其他安全机制已正确设置。


### 例子
1. 在主机系统上的适当卷上创建数据目录，例如`/my/own/datadir`。
2. 使用如下命令启动mysql容器：
```bash
$ docker run -d --name some-mysql \
             -v /my/own/datadir:/var/lib/mysql \
             -e MYSQL_ROOT_PASSWORD=my-secret-pw  \
             mysql:tag
```
该命令的`-v /my/own/datadir：/var/lib/mysql`部分将`/my/own/datadir`目录从底层主机系统挂载到容器内的`/var/lib/mysql`，默认情况下MySQL将数据文件写在这里。

## 在MySQL init完成之前没有连接
如果在容器启动时没有初始化数据库，则将创建**默认数据库**。 虽然这是预期的行为，但这意味着在初始化完成之前它不会接受传入的连接。 当使用自动化工具（例如docker-compose）同时启动多个容器时，这可能会导致问题。

> 如果尝试连接到MySQL的应用程序无法处理MySQL停机或等待MySQL正常启动，则可能需要在服务启动之前进行连接重试循环。 有关官方镜像中此类实现的示例，请参阅[WordPress](https://github.com/docker-library/wordpress/blob/1b48b4bccd7adb0f7ea1431c7b470a40e186f3da/docker-entrypoint.sh#L195-L235)或[Bonita](https://github.com/docker-library/docs/blob/9660a0cccb87d8db842f33bc0578d769caaf3ba9/bonita/stack.yml#L28-L44)。

## 针对已有数据库的用法
如果使用已包含数据库的数据目录（特别是mysql子目录）启动mysql容器实例，应该从运行命令行中省略`MYSQL_ROOT_PASSWORD`变量;这个变量在任何情况下都会被忽略，并且不会以任何方式更改预先存在的数据库。

## 作为任意用户运行
如果目录的权限已经设置正确（例如针对已有数据库运行，如上一小节所写）需要使用特定的`UID/GID`运行mysqld，可以使用`--user`设置为任何值（root/0除外）来调用此镜像，以实现所需的访问/配置：

```bash
$ mkdir data

$ ls -lnd data
drwxr-xr-x 2 1000 1000 4096 Aug 27 15:54 data

$ docker run -d --name some-mysql \
             -v "$PWD/data":/var/lib/mysql \
             --user 1000:1000  \
             -e MYSQL_ROOT_PASSWORD=my-secret-pw  \
             mysql:tag
```

## 创建数据库转存（dump）
大多数常规工具都可以使用，尽管在某些情况下它们的使用可能有点复杂，以确保它们可以访问mysqld服务器。确保这一点的一种简单方法是使用docker exec并从同一容器运行该工具，类似于以下内容：
```bash
$ docker exec some-mysql \
              sh -c 'exec mysqldump \
              --all-databases -uroot \
              -p"$MYSQL_ROOT_PASSWORD"' \
              > /some/path/on/your/host/all-databases.sql
```