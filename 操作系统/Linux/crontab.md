# crontab 定时任务

通过crontab命令，可以在**固定的间隔时间**执行指定的**系统指令**或**shell脚本**。时间间隔的单位可以是**分钟**、**小时**、**日**、**月**、**周**及以上的任意组合。

这个命令非常适合周期性的日志分析或数据备份等工作。

## 命令格式

```bash
usage:  crontab [-u user] file
        crontab [ -u user ] [ -i ] { -e | -l | -r }
                (default operation is replace, per 1003.2)
        -e  # 编辑某个用户的crontab文件内容，默认为当前用户
        -l  # 显示某个用户的crontab文件内容，默认为当前用户
        -r  # 从`/var/spool/cron`目录中删除某个用户的crontab文件，默认为当前用户
        -i  # 在删除用户的crontab文件时给确认提示

# -u user：用来设定某个用户的crontab服务
# file：file是命令文件的名字,表示将file做为crontab的任务列表文件并载入crontab
# 如果在命令行中没有指定这个文件，crontab命令将接受标准输入（键盘）上键入的命令，并将它们载入crontab
```

## crontab的文件格式

```
分 时 日 月 星期 要运行的命令
```

| 列|属性|参数|
|---|---|---|
|第1列|分钟|0～59
|第2列|小时|0～23（0表示子夜）
|第3列|日|1～31
|第4列|月|1～12
|第5列|星期|0～7（0和7表示星期天）
|第6列|要运行的命令

## 创建一个新的crontab文件

1. 向cron进程提交一个crontab文件之前，首先要设置环境变量`EDITOR`

2. cron进程根据它来确定使用哪个编辑器编辑crontab文件

>99%的UNIX和LINUX用户都使用vi，如果你也是这样，那么你就编辑`$HOME`目录下的`.profile`文件，在其中加入这样一行:

```bash
EDITOR=vi; export EDITOR
```

3. 然后保存并退出

创建一个名为<user>cron的文件，其中<user>是用户名，例如，davecron。在该文件中加入如下的内容:

```bash
# (put your own initials here)echo the date to the console every
# 15minutes between 6pm and 6am
0,15,30,45 18-06 * * * /bin/echo 'date' > /dev/console
```

**注意前面5个域用空格分隔。**

在上面的例子中，系统将每隔15分钟向控制台输出一次当前时间。在有些系统中，用tty1来表示控制台，可以根据实际情况对上面的例子进行相应的修改。

为了提交你刚刚创建的crontab文件，可以把这个新创建的文件作为cron命令的参数:

```bash
crontab davecron
```

现在该文件已经提交给cron进程，它将每隔15分钟运行一次。同时，新创建文件的一个副本已经被放在`/var/spool/cron`目录中，文件名就是用户名(即dave)。

## 使用注意事项

### 注意环境变量问题

有时我们创建了一个crontab，但是这个任务却无法自动执行，而手动执行这个任务却没有问题，这种情况一般是由于在crontab文件中没有配置环境变量引起的。

> 在crontab文件中定义多个调度任务时，需要特别注环境变量的设置，因为手动执行某个任务时是在当前shell环境下进行的，程序当然能找到环境变量，而系统自动执行任务调度时，是不会加载任何环境变量的，因此，就需要在crontab文件中指定任务运行所需的所有环境变量，这样，系统执行任务调度时就没有问题了。

所以要保证在shelll脚本中提供所有必要的路径和环境变量，除了一些自动设置的全局变量。所以注意如下3点：

1. 脚本中涉及文件路径时写全局路径；

2. 脚本执行要用到java或其他环境变量时，通过source命令引入环境变量，如:

```bash
cat start_cbp.sh
!/bin/sh
source /etc/profile
export RUN_CONF=/home/d139/conf/platform/cbp/cbp_jboss.conf
/usr/local/jboss-4.0.5/bin/run.sh -c mev &
```

当手动执行脚本OK，但是crontab死活不执行时,很可能是环境变量惹的祸，可尝试在crontab中直接引入环境变量解决问题。如:

```bash
0 * * * * . /etc/profile;/bin/sh /var/www/java/audit_no_count/bin/restart_audit.sh
```

### 注意清理系统用户的邮件日志

每条任务调度执行完毕，系统都会将任务输出信息通过电子邮件的形式发送给当前系统用户，这样日积月累，日志信息会非常大，可能会影响系统的正常运行，因此，将每条任务进行重定向处理非常重要。 

例如，可以在crontab文件中设置如下形式，忽略日志输出:

```bash
0 */3 * * * /usr/local/apache2/apachectl restart >/dev/null 2>&1
```

“`/dev/null 2>&1`”表示先将标准输出重定向到/dev/null，然后将标准错误重定向到标准输出，由于标准输出已经重定向到了/dev/null，因此标准错误也会重定向到/dev/null，这样日志输出问题就解决了。

### 系统级任务调度与用户级任务调度

- 系统级任务调度主要完成系统的一些维护操作，
- 用户级任务调度主要完成用户自定义的一些任务，

可以将用户级任务调度放到系统级任务调度来完成（不建议这么做），但是反过来却不行。

root用户的任务调度操作可以通过”`crontab –uroot –e`”来设置，也可以将调度任务直接写入`/etc/crontab`文件，需要注意的是，如果要定义一个定时重启系统的任务，就必须将任务放到`/etc/crontab`文件，即使在root用户下创建一个定时重启系统的任务也是无效的。

### 其他注意事项

新创建的cron job，不会马上执行，至少要过2分钟才执行。如果重启cron则马上执行。

当crontab失效时，可以尝试`/etc/init.d/crond restart`解决问题。或者查看日志看某个job有没有执行/报错`tail -f /var/log/cron`。

千万别乱运行`crontab -r`。它从Crontab目录（`/var/spool/cron`）中删除用户的Crontab文件。删除了该用户的所有crontab都没了。

在crontab中`%`是有特殊含义的，表示换行的意思。如果要用的话必须进行转义%，如经常用的`date ‘+%Y%m%d’`在crontab里是不会执行的，应该换成`date ‘+\%Y\%m\%d’`。

更新系统时间时区后需要重启cron,在ubuntu中服务名为cron:

```bash
$service cron restart

# ubuntu下启动、停止与重启cron:
$sudo /etc/init.d/cron start
$sudo /etc/init.d/cron stop
$sudo /etc/init.d/cron restart
```
