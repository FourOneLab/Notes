如何使用iptables和firewalld工具来管理Linux防火墙连接规则。

# 防火墙

**++防火墙是一组规则++**。当数据包流入或流出受保护的网络空间时，将根据防火墙规则测试其内容（特别是有关其**来源**，**目标**和**计划使用的协议**的信息），++以确定是否应允许其通过++。 

这是一个简单的例子：

![image](http://p99.pstatp.com/large/pgc-image/1537747193425750b2febd7)

防火墙可以根据**协议**或**基于规则**过滤请求:
- iptables是一种在Linux机器上管理防火墙规则的工具。
- firewalld也是用于管理Linux机器上的防火墙规则的工具。

> 这一切都始于Netfilter，它控制Linux内核模块级别的网络堆栈访问。几十年来，用于管理Netfilter钩子的主要命令行工具是iptables规则集。

1. 因为调用这些规则所需的语法可能会有点神秘，Ufw和firewalld等各种用户友好的实现被引入为更高级别的Netfilter解释器。
2. 但是，Ufw和firewalld主要用于**解决独立计算机所面临的各种问题**。构建全网络解决方案通常需要额外的iptables，或者自2014年以来，它需要更换nftables（通过nft命令行工具）。

iptables仍然被广泛使用，是nftables通过添加到经典的Netfilter工具集，带来了一些重要的新功能。

