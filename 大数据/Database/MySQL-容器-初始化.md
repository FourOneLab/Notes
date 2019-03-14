默认情况下，MySQL镜像创建的Docker容器启动时只是一个空的数据库实例，为了简化Docker部署,需要在Docker创建MySQL容器时：
1. 自动建好数据库和表，
2. 并且自动录入初始化数据，

也就是说容器启动后数据库就可用了。**这就需要容器启动时能自动执行sql脚本**。 

在MySQL官方镜像中提供了容器启动时自动执行`/docker-entrypoint-initdb.d`文件夹下的脚本的功能(包括**shell脚本**和**sql脚本**) 。`docker-entrypoint.sh`中下面这段代码就是干这事儿的。
```bash
# usage: process_init_file FILENAME MYSQLCOMMAND...
#    ie: process_init_file foo.sh mysql -uroot
# (process a single initializer file, based on its extension. we define this
# function here, so that initializer scripts (*.sh) can use the same logic,
# potentially recursively, or override the logic used in subsequent calls)
process_init_file() {
	local f="$1"; shift
	local mysql=( "$@" )

	case "$f" in
		*.sh)     echo "$0: running $f"; . "$f" ;;
		*.sql)    echo "$0: running $f"; "${mysql[@]}" < "$f"; echo ;;
		*.sql.gz) echo "$0: running $f"; gunzip -c "$f" | "${mysql[@]}"; echo ;;
		*)        echo "$0: ignoring $f" ;;
	esac
	echo
}

echo
ls /docker-entrypoint-initdb.d/ > /dev/null
for f in /docker-entrypoint-initdb.d/*; do
	process_init_file "$f" "${mysql[@]}"
done
```
也就是说只要把初始化脚本放到`/docker-entrypoint-initdb.d/`文件夹MySQL容器在启动的时候就会执行这些初始化脚本。

