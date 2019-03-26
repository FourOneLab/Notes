# Cookie
Cookie是服务器在本地机器上存储的小段文本并随每一个请求发送至同一个服务器。

> IETF RFC 2965 HTTP State Management Mechanism 是通用cookie规范。

1. 服务器通过在HTTP的响应头中加上一行特殊的指示以提示浏览器按照指示生成响应的Cookie（纯粹的客户端脚本如JS也可以生成Cookie）
2. 在客户端的浏览器解析这些Cookie并将它们保存为一个本地文件
3. 浏览器按照一定的原则在后台自动发送给服务器
4. 浏览器存储所有Cookie，如果某个Cookie所声明的作用范围大于等于将要请求的资源所在的位置，则把该Cookie附在请求资源的HTTP请求头上发送给服务器


**Cookie机制采用的是在`客户端`保持状态的方法**。

在客户端的`会话状态`的存储机制，需要用户打开客户端的Cookie支持，Cookie的作用就是为了解决HTTP协议无状态的缺陷。

## Cookie的内容
1. 名字
2. 值
3. 过期时间 

> 如果不设置过期时间，则表示这个Cookie的生命周期为浏览器会话期间，关闭浏览器后Cookie消失,这样的Cookie保存在内存中。对于保存在内存中的Cookie不同的浏览器有不同的处理方式。

> 如果设置了过期时间，浏览器会把Cookie保存在硬盘上，关闭浏览器再次打开，Cookie仍然有效，直到超时过期。存储在硬盘上的Cookie可以在不同的浏览器进程间共享。

4. 路径
5. 域

> 路径与域一起构成Cookie的作用范围。

# Session
**Session机制采用的是在`服务器`保存状态的方法**。

采用服务器端保持状态的方案，使用散列表来保存信息。在客户端也需要保存一个标识，所以Session机制可能需要借助于Cookie机制来达到保存标识的目的。Session提供了方便管理全局变量的方式。

当程序为某个客户端请求创建Session时：
1. 服务器首先检查这个请求里是否已经包含了一个Session标识（SessionID）
2. 如果已经包含，则说明之前已经为这个客户端创建过Session，服务器按照SessionID将session检索出来使用
3. 如果不包含，则为这个客户端创建一个Session并生成一个相关的SessionID（ID的值应该是一个既不会重复有容易找到规律的字符串）
4. SessionID在本次响应时返回给客户端保存
5. 当客户端禁用Cookie时，这个值可能设置为由get来返回给服务器

> Session相对安全，不会任意读取客户端存储的信息。


- URL重写，就是把SessionID直接附加在URL路径后面。
- 表单隐藏字段，就是服务器会自动修改表单，添加一个隐藏字段，以便在表单提交时能够把SessionID传递回服务器。

# 对比
Cookie与Session都能够进行会话跟踪，但是原理不同。

## 存取方式不同
- Cookie中只能保管`ASCII字符串`（需存取Unicode字符或者二进制数据时要先进行编码）。Cookie中也不能直接存取Java对象。若要存储略微复杂的信息，运用Cookie是比拟艰难的。

- Session中能够存取`任何类型的数据`，包括而不限于String、Integer、List、Map等。Session中也能够直接保管Java Bean乃至任何Java类，对象等，可以把Session看做是一个Java容器类。

## 隐私策略的不同
- Cookie存储在客户端阅读器中，对客户端是可见的，客户端的一些程序可能会窥探、复制以至修正Cookie中的内容。

- Session存储在服务器上，对客户端是透明的，不存在敏感信息泄露的风险。

> 选用Cookie，比较好的方法是，敏感的信息如账号密码等尽量不要写到Cookie中。**将Cookie信息加密**，提交到服务器后再进行解密，保证Cookie中的信息只要本人能读得懂。Session里任何隐私都能够有效的保护。

## 有效期上的不同
- Google的登录信息长期有效。用户不用每次访问都重新登录，Google会持久地记载该用户的登录信息。要到达这种效果，运用Cookie会是比较好的选择。只需要设置Cookie的过期时间属性为一个很大很大的数字。

- 由于Session依赖于名为JSESSIONID的Cookie，而Cookie JSESSIONID的过期时间默许为–1，只需关闭了阅读器该Session就会失效，因而Session不能完成信息永世有效的效果。

> 运用URL地址重写也不能完成。而且假如设置Session的超时时间过长，服务器累计的Session就会越多，越容易招致内存溢出。

## 服务器压力的不同
- Cookie保管在客户端，不占用服务器资源。假如并发阅读的用户十分多，Cookie是很好的选择。

- Session是保管在服务器端的，每个用户都会产生一个Session。假如并发访问的用户十分多，会产生十分多的Session，耗费大量的内存。

## 浏览器支持的不同
- Cookie是需要客户端浏览器支持的。假如客户端禁用了Cookie，或者不支持Cookie，则会话跟踪会失效。

> 假如客户端浏览器不支持Cookie，需要运用Session以及URL地址重写。需要注意的是一切的用到Session程序的URL都要进行URL地址重写，否则Session会话跟踪还会失效。

> 假如客户端支持Cookie，则Cookie既能够设为本浏览器窗口以及子窗口内有效（把过期时间设为–1），也能够设为一切阅读器窗口内有效（把过期时间设为某个大于0的整数）。

- Session只能在本阅读器窗口以及其子窗口内有效。假如两个浏览器窗口互不相干，它们将运用两个不同的Session。

## 跨域支持上的不同

Cookie支持跨域名访问，例如将domain属性设置为“.biaodianfu.com”，则以“.biaodianfu.com”为后缀的一切域名均能够访问该Cookie。跨域名Cookie如今被普遍用在网络中。而Session则不会支持跨域名访问。Session仅在他所在的域名内有效。

> 仅运用Cookie或者仅运用Session可能完成不了理想的效果。这时应该尝试一下同时运用Cookie与Session。Cookie与Session的搭配运用在实践项目中会完成很多意想不到的效果。

Tomcat就是用ConcurrentHashMap，key为sessionId，value为要保存的信息来进行cookie和sesssin的交互的。