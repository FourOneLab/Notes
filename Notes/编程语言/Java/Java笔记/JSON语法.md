JSON 语法是 JavaScript 对象表示法语法的子集。

- 数据在==键值对==中
- 数据由==逗号==分隔
- 大括号保存==对象==
- 中括号保存==数组==

**注意：json的key是字符串,且必须是双引号，不能是单引号**

>json的value是Object,json是js的原生内容，也就意味着js可以直接取出json对象中的数据

## JSON键值对
JSON 数据的书写格式是：名称/值对。

键值对包括字段名称（在双引号中），后面写一个冒号，然后是值：

```
"name" : "JSON"

//等价于JS中的如下语句

name = "JSON"
```
### JSON 值

JSON 值可以是：

1. 数字（整数或浮点数）
2. 字符串（在双引号中）
3. 逻辑值（true 或 false）
4. 数组（在中括号中）
5. 对象（在大括号中）
6. null


### JSON 数字
JSON数字可以整型或者浮点型

```
{ "age" : 30 }
```

### JSON 对象
JSON 对象在大括号{}中书写：

对象可以包含多个键值对

```
{ "name" : "JSON", "value" : "json"}

//等价于JS中如下语句

name = "JSON"
value = "json"
```

### JSON数组
JSON 数组在中括号中书写：

数组可包含多个对象：

```
{
"sites": [
             { "name":"菜鸟教程" , "url":"www.runoob.com" }, 
             { "name":"google" , "url":"www.google.com" }, 
             { "name":"微博" , "url":"www.weibo.com" }
          ]
}

//在上面的例子中，对象 "sites" 是包含三个对象的数组。每个对象代表一条关于某个网站（name、url）的记录
```

### JSON 布尔值

JSON 布尔值可以是 true 或者 false：

```
{ "flag":true }
```

### JSON null

JSON 可以设置 null 值：


```
{ "runoob":null }
```

### JSON 使用 JavaScript 语法

因为 JSON 使用 JavaScript 语法，所以无需额外的软件就能处理 JavaScript 中的 JSON。

通过 JavaScript，您可以创建一个对象数组，并像这样进行赋值：


```
{
"sites": [
             { "name":"菜鸟教程" , "url":"www.runoob.com" }, 
             { "name":"google" , "url":"www.google.com" }, 
             { "name":"微博" , "url":"www.weibo.com" }
          ]
}

//可以向访问对象数组中的第一项那样访问

sites[0].name

//返回内容如下：
菜鸟教程

//可以像修改数组那样修改数据
sites[0].name="新的值"
```


### JSON 文件

- JSON 文件的文件类型是 ".json"
- JSON 文本的 MIME 类型是 "application/json"