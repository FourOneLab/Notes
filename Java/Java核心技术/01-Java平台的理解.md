#### 对Java平台的理解
Java本身是一种面向对象的语言，显著的特性有两个方面:
1. 一次编写，到处运行，能够非常容易地获得跨平台能力
2. 垃圾收集，Java通过垃圾收集器回收分配内存，大多数情况下，程序员都不需要自己操心内存的分配和回收

- JRE ：Java运行环境，包含JVM和Java类库以及一些模块
- JDK：是JRE的超集，提供了更多工具，如编译器、各种诊断工具等

##### 知识扩展
Java平台的理解：

特性 | 知识点
---|---
Java语言特性|泛型、Lambda等语言特性
基础类库|集合、IO/NIO、网络、并发、安全等基础类库

JVM的基础概念和机制：
1. 类加载器，常用JDK版本内嵌的Class-Loader（bootstrap、Application、Extension Class-Loader）
2. 类加载大致过程：加载、验证、链接、初始化
3. 自定义Class-Loader

垃圾收集器的基本原理：
- 常见的垃圾收集器：SerialGC、Parallel GC、CMS、G1等
- 什么样的工作负载合适什么样的垃圾收集器?

JDK包含哪些工具，Java领域内其他工具：
- 编译器
- 运行时环境
- 安全工具
- 诊断和监控工具

![image](https://static001.geekbang.org/resource/image/20/32/20bc6a900fc0b829c2f0e723df050732.png)

#### Java是解释执行？
1. Java的源代码首先通过Javac编译为字节码（bytecode）
2. 运行时通过JVM内嵌的解释器将字节码转换为最终的机器码

> 常见的JVM（如Oracle JDK提供的Hotspot JVM）都提供了**JIT**（Just-In-Time）编译器，也就是通常所说的动态编译器，它能够在运行时将热点代码编译成机器码，这种情况下部分热点代码就属于编译执行，而不是解释执行。

##### Java分为编译器和运行时：
Java的编译和C/C++有这不同的意义：
- Javac的编译：编译Java源码生成.class文件里面其实是字节码，而不是能直接执行的机器码
> Java通过字节码和JVM这种跨平台的抽象、屏蔽了操作系统和硬件的细节，这也是实现“一次编译，到处执行”的基础

在运行时，JVM会通过类加载器（Class-Loader）加载字节码，解释或编译执行。

> 主流的Java版本，如JDK8实际是解释和编译混合的一种模式，即所谓的混合模式（Xmined）。

- 运行在server模式的JVM，会进行上万次调用以收集足够的信息进行高效的编译
- client模式这个门限是1500次

Oracle Hotspot JVM 内置两个不同的JIT compiler：
- C1对应client模式，适用于对启动速度敏感的应用，如普通Java桌面应用
- C2对应server模式，它的优化是为长时间运行的服务器端应用设计的

**默认采用分层编译。**

Java虚拟机启动时，可以指定不同的参数对运行模式进行选择：

参数| 效果
---|---
-Xint|告诉JVM只进行解释执行，不对代码进行编译，抛弃了JIT可能带来的性能优势
-Xcomp|告诉JVM关闭解释器，不进行解释执行，或者称为最大优化级别

**解释器逐条读入，逐条解释运行**

**-Xcomp会导致JVM启动变慢非常多，有些JIT编译器优化方式，比如分支预测， 如果不进行profiling，往往不能进行有效优化**

> 除了常见的Java使用模式，还有一种新的编译方式，AOT（Ahead-of-Time Compilation），直接将字节码编译成为机器代码，避免了JIT预热等各方面的开销

利用下面的命令，把某个类或者模块编译成为AOT库：

```
jaotc --output libHelloWorld.so HelloWorld.class

jaotc --output libjava.base.so --module java.base
```
然后，在启动时直接指定就可以：

```
java -XX:AOTLibrary=./libHelloWorld.so,./libjava.base.so HelloWorld
```

JVM作为一个强大的平台，不仅Java语言可以运行在JVM上，本质上合规的字节码都能运行，Java语言自身也提供了便利，类似Clojure、Scala、Groovy、Jruby、Jython等大量JVM语言，活跃在不同的场景。