# OSI（open system interconnection） Mode
开放系统互连（OSI）模型定义了一个网络框架，用于在层中实现协议控制从一层传递到下一层。它主要用于今天的教学工具中。它在概念上将计算机网络架构划分为7个逻辑层次。较低层处理**电信号**，**二进制数据块**并且将这些数据在网络之间进行路由转发。更高的层次接收**网络请求和响应**，从用户的角度来看就是**数据**和**网络协议**。

OSI模型最初被设想为构建网络系统的**标准体系结构**，实际上，当今许多流行的网络技术也反映了OSI的分层设计理念。

## 物理层
![](https://www.lifewire.com/thmb/XngbmaVnifs5BgUxkWGHHVrIACY=/399x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel_physical-56a1ad0d3df78cf7726cf781.jpg)

这是第一层，OSI模型的物理层负责将**数字数据比特**从发送（源）设备的物理层通过网络通信媒体最终传输到接收（目的地）设备的物理层。

这一层运行的标准网络设备包括：
1. 以太网电缆  
2. 令牌环网络
3. 集线器
4. 其他中继器
5. 电缆连接器

在物理层，使用**物理介质**支持的信令类型来传输数据：`电压`，`射频`或红`外脉冲`或`普通光`。

## 数据链路层
![](https://www.lifewire.com/thmb/zhfAPXwYeaMyhMS_xkpTAXXA_E8=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel_datalink-56a1ad0d5f9b58b7d0c19c59.jpg)

当从物理层获得数据时，数据链路层主要完成的工作：
1. 检查物理传输错误并将比特封装成**数据“帧”**
2. 管理**物理寻址方案**，例如以太网网络的MAC地址，控制各种网络设备对物理介质的访问。

由于数据链路层是OSI模型中最复杂的单层，因此通常将其分为两部分，即“媒体访问控制”子层和“逻辑链路控制”子层。

## 网络层
![](https://www.lifewire.com/thmb/Z8VDL5YiUIiADKlP2jdWi0pmSS4=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel_network-56a1ad0d5f9b58b7d0c19c5c.jpg)

网络层在数据链路层之上添加了**路由**的概念。

1. 当数据到达网络层时，将检查每个帧中包含的源和目标地址，以确定数据是否已到达其最终目的地。
2. 如果数据已到达最终目的地，则此第3层将数据格式化为传输到传输层的数据包。
3. 否则，网络层将更新目标地址并将帧向下推回到较低层。

为了支持路由，网络层维护逻辑地址，例如 网络上设备的IP地址。网络层还管理这些逻辑地址和物理地址之间的映射。在IP网络中，此映射是通过地址解析协议（**ARP**）完成的。

## 传输层
![](https://www.lifewire.com/thmb/4K7iZMuRd7vAgOGWyW09LuOR4Zc=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel-56a1ad0c5f9b58b7d0c19c53.jpg)

传输层通过网络连接提供数据。TCP是传输第4层网络协议的最常见示例。 不同的传输协议可以支持一系列可选功能，包括错误恢复，流量控制和重传支持。
## 会话层
![](https://www.lifewire.com/thmb/4K7iZMuRd7vAgOGWyW09LuOR4Zc=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel-56a1ad0c5f9b58b7d0c19c53.jpg)

会话层管理启动和拆除网络连接的事件的顺序和流程。在第5层，它构建为支持多种类型的连接，这些连接可以动态创建并在各个网络上运行。
## 表示层
![](https://www.lifewire.com/thmb/4K7iZMuRd7vAgOGWyW09LuOR4Zc=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel-56a1ad0c5f9b58b7d0c19c53.jpg)

表示层是任何OSI模型中最简单的功能。在第6层，它处理消息数据的语法处理，例如支持其上方的应用层所需的格式转换和加密/解密。
## 应用层 
![](https://www.lifewire.com/thmb/3FOpKj4Pp9DigW_7edZz6Tv_-Ww=/400x0/filters:no_upscale():max_bytes(150000):strip_icc():format(webp)/basics_osimodel_application-56a1ad0d3df78cf7726cf77e.jpg)

应用层为最终用户应用程序提供网络服务。网络服务通常是与用户数据一起使用的协议。例如，在Web浏览器应用程序中，应用程序层协议HTTP打包发送和接收网页内容所需的数据。第7层向表示层提供数据（并从中获取数据）。