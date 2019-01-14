# 写法一：

``` bash
#!/bin/bash

while read line
do
    echo $line
done < file(待读取的文件)
```

# 写法二：

```bash
#!/bin/bash

cat file(待读取的文件) | while read line
do
    echo $line
done
```

# 写法三：

```bash
for line in `cat file(待读取的文件)`
do
    echo $line
done
```

## 说明：

for逐行读和while逐行读是有区别的,如:

```bash
$ cat file
aaaa
bbbb
cccc dddd
```

```bash
$ cat file | while read line; do echo $line; done
aaaa
bbbb
cccc dddd
```

```bash
$ for line in $(<file); do echo $line; done
aaaa
bbbb
cccc
dddd
```

# 实践

```bash
#! bin/sh

#$str='http://images.stylight.de/static/res200/s2870/2870657.1.jpg%0D'
#echo ${str##*fo}
#echo ${str#fo}
while read line
do
   wget -p ${line:0:59}
done < '/root/mysql/mysql.log';
```

### 解压多个tar.gz文件

```bash
for tar in *.tar.gz;do tar xvf $tar;done
```

### 解压多个gz文件

```bash
for gz in *.gz;do gunzip $gz; done
```
