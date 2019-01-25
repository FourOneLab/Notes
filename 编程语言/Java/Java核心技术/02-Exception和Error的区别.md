只有正确处理好意外情况，才能保证程序的可靠性。

Java语言在设计之初就提供了相对完善的异常处理机制，这是Java得以大行其道的原因之一。

# 对比Exception和Error
1. Exception和Error都是继承了Throwable类，++在Java中只有Throwable类型的实例才可以被抛出（throw）或者捕获（catch）++，**它是异常处理机制的基本组成类型**。
2. Exception和Error体现了Java平台设计者对不同异常情况的分类。
    - Exception是程序正常运行中，可以预料的意外情况，可能并且应该被捕获，进行相应处理
    - Error是指在正常情况下，不大可能出现的情况，绝大部分Error都会导致程序（JVM自身）处于非正常的、不可恢复状态。既然是非正常情况，所以不便于也不需要捕获，常见的比如**OutOfMemoryError**。
3. Exception分为检查型（**checked**）异常和非检查型（**unchecked**）异常，检查型异常在源代码里必须显示地进行捕获处理，这是编译期检查的一部分。

> 非检查型异常就是所谓的运行时异常，类似 **NullPointerException**、**ArrayIndexOutofBoundsException**，通常是可以编码避免的逻辑错误，具体根据需要来判断是否需要捕获，并不会在编译期强制要求。

![image](https://static001.geekbang.org/resource/image/ac/00/accba531a365e6ae39614ebfa3273900.png)

1. 理解Throwable、Exception、Error的设计和分类，掌握应用最广泛的子类，以及如何自定义异常，比如 **NoClassDefFoundError** 和 **ClassNOtFoundException** 有什么区别。

> NoClassDefFoundError是一个错误(Error)，而ClassNOtFoundException是一个异常，在Java中对于错误和异常的处理是不同的，我们可以从异常中恢复程序但却不应该尝试从错误中恢复程序。

- **ClassNotFoundException的产生原因**：Java支持使用Class.forName方法来动态地加载类，任意一个类的类名如果被作为参数传递给这个方法都将导致该类被加载到JVM内存中，如果这个类在类路径中没有被找到，那么此时就会在运行时抛出ClassNotFoundException异常。
- **NoClassDefFoundError产生的原因**：如果JVM或者ClassLoader实例尝试加载（可以通过正常的方法调用，也可能是使用new来创建新的对象）类的时候却找不到类的定义。要查找的类在编译的时候是存在的，运行的时候却找不到了。这个时候就会导致NoClassDefFoundError。造成该问题的原因++可能是打包过程漏掉了部分类，或者jar包出现损坏或者篡改++。解决这个问题的办法是查找那些在开发期间存在于类路径下但在运行期间却不在类路径下的类。

2. 理解Java语言中操作Throwable的元素和实践，掌握最基本的语法，如try-catch-finally块，throw、throws关键字等。

> 异常处理代码比较繁琐，比如需要写很多千篇一律的捕获代码，或者在finally里面做一些资源回收工作。

随着Java语言的发展，引入了一些新特性，比如try-with-resources和multiple catch，在编译期会自动生成相应的处理逻辑，比如自动按照约定俗成close那些扩展了AutoCloseable或者Closeable的对象。


```
try (BufferedReader br = new BufferedReader(…);
     BufferedWriter writer = new BufferedWriter(…)) {// Try-with-resources
// do something
catch ( IOException | Exception e) {// Multiple catch
   // Handle it
} 
```

## 例子分析
以下代码的不当之处：

```
try {
  // 业务代码
  // …
  Thread.sleep(1000L);
} catch (Exception e) {
  // Ignore it
}
```
1. 尽量不要捕获类似Exception 这样的通用异常，应该捕获特定异常，这里是Thread.sleep()抛出的InterruptedException；除非深思熟虑，否则不要捕获Throwable或者Error，这样很难保证正确处理OutofMemoryError。
2. 不要生吞异常，这是异常处理中要特别注意的事情，因为很可能会导致非常难以诊断的诡异情况。

> 生吞代码，往往是基于假设这段代码可能不会发生，或者感觉忽略异常是无所谓的，但是千万不要在产品代码做这样的假设！如果不把异常抛出或者也没有输出到日志之类，程序可能在后续代码以不可控的方式结束。

以下代码的不当之处：
```
try {
   // 业务代码
   // …
} catch (IOException e) {
    e.printStackTrace();
}
```
这段代码作为一段实验代码，没有任何问题，但是在产品代码中，通常都不允许这样处理。

printStackTrace()方法的描述：++将此throwable及其回溯打印到标准错误流++。在复杂的生产系统中，标准出错（STERR）不是一个合适的输出选项，因为很难判断出到底输出到哪去了。尤其是对于分布式系统，如果发生异常，但是无法找到堆栈轨迹（stacktrace），这纯属为诊断设置障碍。**所以最好使用产品日志，详细地输出到日志系统中。**

### Throw early, catch late 原则

```
public void readPreferences(String fileName){
	 //...perform operations... 
	InputStream in = new FileInputStream(fileName);
	 //...read the preferences file...
}
```
如果fileName是null，那么程序就会抛出NullPointerException，但是由于没有第一时间暴露出来问题，堆栈信息可能非常令人费解，往往需要相对复杂的定位。**在发现问题的时候，第一时间抛出，能够更加清晰地反应问题。**

将以上代码修改一下，让问题“throw early”，对异常信息就非常直观了。

```
public void readPreferences(String filename) {
	Objects. requireNonNull(filename);
	//...perform other operations... 
	InputStream in = new FileInputStream(filename);
	 //...read the preferences file...
}
```
至于“catch late”应该在何时？捕获异常后需要怎么处理？最差的方式就是“生吞异常”，如果实在不知道如何处理，选择保留原有异常的cause信息，直接再抛出或者构建新的异常抛出。

## 自定义异常
自定义异常时除了要保证足够的信息，还需要注意以下两点：
1. 是否需要定义成Checked Exception，因为这种类型设计的初衷更是为了从异常情况恢复，作为异常设计者，我们往往有足够信息进行分类
2. 在保证诊断信息足够，同时也要考虑避免敏感信息，因为那样可能会导致潜在的安全问题。用户数据一般是不可以输出到日志里的
> 例如Java的标准类库中，java.net.ConnectException，出错信息是类似“Connection refused”，而不包含具体机器名，IP，端口等

## 性能角度审视Java异常处理

有两个地方会相对昂贵：
1. try-catch代码段会产生额外的性能开销，会影响JVM对代码进行优化，所以建议仅仅捕获有必要的代码段，尽量不要一个大的try包住整段的代码；利用异常控制代码流程，远比通常意义上的条件语句（if/else、switch）要低效。
2. Java每实例化一个Exception，都会对当时的栈进行快照，这是一个相对比较重的操作，如果发生的非常频繁，这个开销就不能被忽略了。

> 对于追求极致性能的底层类库，有种方式是尝试创建不进行栈快照的Exception。这样做的假设在于，创建异常时知道未来是否需要堆栈。问题是实际上，在小范围或许可能，但是在大规模项目中，这么做不是个理智的选择。如果需要堆栈，但是又没有收集这些信息，在复杂的情况下，尤其是类似微服务这种分布式系统，这会大大增加诊断的难度。

**当我们的服务出现反应变慢，吞吐量下降的时候，检查发生最频繁的Exception也是一种思路。**

