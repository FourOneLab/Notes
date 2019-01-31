# 开头
所有bash脚本都以下面几句为开场白：
```bash
#!/bin/bash

set -o nounset

set -o errexit
```

这样做会避免两种常见的问题：

1. 引用未定义的变量(缺省值为“”)

2. 执行失败的命令被忽略

# 注意
1. 有些Linux命令的某些参数可以**强制忽略发生的错误**,例如:
```bash
mkdir -p
rm -f
```

2. 在“errexit”模式下，虽然**能有效的捕捉错误**，但并**不能捕捉全部失败的命令**，在某些情况下，一些失败的命令是无法检测到的。

# 脚本函数
在bash里可以定义函数，它们就跟其它命令一样，可以随意的使用；它们能让脚本更具可读性：
```bash
ExtractBashComments() {
egrep "^#"
}

cat myscript.sh | ExtractBashComments | wc
comments=$(ExtractBashComments < myscript.sh)
```

```bash
SumLines() {
# iterating over stdin - similar to awk
local sum=0
local line=" "
while read line
do
  sum=$((${sum} + ${line}))
done
echo ${sum}
}

SumLines < data_one_number_per_line.txt

log() {
# classic logger
local prefix="[$(date +%Y/%m/%d %H:%M:%S)]: "
echo "${prefix} $@" >&2
}

log "INFO" "a message"
```
**尽可能的把bash代码移入到函数里，仅把全局变量、常量和对“main”调用的语句放在最外层。**

# 变量注释
Bash里可以对变量进行有限的注解。最重要的两个注解是：
1. local(函数内部变量)
2. readonly(只读变量)

```bash
# a useful idiom: DEFAULT_VAL can be overwritten
# with an environment variable of the same name
readonly DEFAULT_VAL=${DEFAULT_VAL:-7}
myfunc() {
# initialize a local variable with the global default
local some_var=${DEFAULT_VAL}
...
}
```
这样，可以将一个以前不是只读变量的变量声明成只读变量：
```bash
x=5
x=6
readonly x
x=7
# failure
```
1. 尽量对bash脚本里的所有变量使用local或readonly进行注解。
2. 用$()代替反单引号(`)反单引号很难看，在有些字体里跟正单引号很相似。$()能够内嵌使用，而且避免了转义符的麻烦。

```bash
# both commands below print out: A-B-C-D
echo "A-`echo B-`echo C-\`echo D\```"
echo "A-$(echo B-$(echo C-$(echo D)))"
```
用[[]](双层中括号)替代[]
使用[[]]能避免像异常的文件扩展名之类的问题，而且能带来很多语法上的改进，而且还增加了很多新功能：

操作符功能说明

||逻辑or(仅双中括号里使用)

&&逻辑and(仅双中括号里使用)

<字符串比较(双中括号里不需要转移)

-lt数字比较

=字符串相等

==以Globbing方式进行字符串比较(仅双中括号里使用，参考下文)

=~用正则表达式进行字符串比较(仅双中括号里使用，参考下文)

-n非空字符串

-z空字符串

-eq数字相等

-ne数字不等

单中括号：

[ "${name}" > "a" -o ${name} < "m" ]

双中括号

[[ "${name}" > "a" && "${name}" < "m" ]]

正则表达式/Globbing

使用双中括号带来的好处用下面几个例子最能表现：

t="abc123"

[[ "$t" == abc* ]]

# true (globbing比较)

[[ "$t" == "abc*" ]]

# false (字面比较)

[[ "$t" =~ [abc]+[123]+ ]]

# true (正则表达式比较)

[[ "$t" =~ "abc*" ]]

# false (字面比较)

注意，从bash 3.2版开始，正则表达式和globbing表达式都不能用引号包裹。如果你的表达式里有空格，你可以把它存储到一个变量里：

r="a b+"

[[ "a bbb" =~ $r ]]

# true

按Globbing方式的字符串比较也可以用到case语句中：

case $t in

abc*) <action> ;;

esac
