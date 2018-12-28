- **final** 用来修饰 **类**、**方法**、**变量**，分别有不同的意义。
    - final修饰的class代表不可以继续扩展
    - final 的方法也数不可以重写的（overrife）
    - final的变量表示不可以修改的

- **finally** 是Java保证重点代码一定要被执行的一种机制。可以使用**try-finally**或者**try-catch-finally**来进行类似关闭jdbc连接、保证unlock锁等动作。

- **finalize** 是基础类 java.lang.Object的一个方法，它的设计目的是保证对象在被垃圾收集前完成特定资源的回收。（++finalize机制现在已经不推荐使用，并且JDK9开始被标记为deprecated++）

# final
推荐使用final关键字来明确表示代码的语义、逻辑意图，这已经被证明在很多场景下是非常好的实践，比如：
- 将方法或类声明为final，明确告诉别人，这些行为是不允许修改的。
> 在Java核心类库java.lang包下面有很多类，相当一部分都被声明为final class，在第三方类库的一些基础类中同样如此，这可以有效避免API使用者更改基础功能，某种程度上，这是保证平台安全的必要手段。

- 使用final修饰参数或者变量，可以清楚地避免意外赋值导致的编程错误，（甚至有人明确推荐奖所以方法参数、本地变量、成员变量声明为final）
- final变量产生了某种程度的不可变（immutable）的效果，所以可以用于保护只读数据，尤其是在并发编程中，因为明确地不能赋值final变量，有利于减少额外的同步开销，也可以省去一些防御性拷贝的必要。

# finally
对于 finally，明确知道怎么使用就足够了。

需要关闭的连接等资源，更推荐使用 Java 7 中添加的try-with-resources 语句，因为通常 Java平台能够更好地处理异常情况，编码量也要少很多，何乐而不为呢。

另外，我注意到有一些常被考到的 finally 问题（也比较偏门），至少需要了解一下。比如，下面代码会输出什么？

```
try {
  // do something
  System.exit(1);
} finally{
  System.out.println(“Print from finally”);
}
```
**上面 finally 里面的代码可不会被执行的哦，这是一个特例。**


# finalize
对于 finalize，我们要明确它是不推荐使用的，业界实践一再证明**它不是个好的办法**，在 Java 9中，甚至明确将Object.finalize() 标记为deprecated！

> 如果没有特别的原因，不要实现 finalize方法，也不要指望利用它来进行资源回收。
你无法保证 finalize什么时候执行，执行的是否符合预期。使用不当会影响性能，导致程序死锁、挂起等。

通常来说，利用上面的提到的 try-with-resources 或者try-finally 机制，是非常好的回收资源的办法。

如果确实需要额外处理，可以考虑 Java 提供的 **Cleaner** 机制或者其他替代方法。

# 扩展知识
## final不是immutable（不可变）

```
 final List<String> strList = new ArrayList<>();
 strList.add("Hello");
 strList.add("world");  
 List<String> unmodifiableStrList = List.of("hello", "world");
 unmodifiableStrList.add("again");
```

- final只能约束strList这个引用不可以被赋值，但是strList对象行为不被final影响，添加元素等操作完全正常。


- 如果希望对象本身不可变，就需要相应的类支持不可变的行为。如上面例子中的List.of方法创建的本身就是不可变List，最后的add方法会在运行时抛出异常的。

immutable在很多场景是非常棒的选择，某种意义上来说，Java语言目前并没有原生的不可变支持，如果要实现immutable的类，需要如下操作：
1. 将class自身声明为final，这样别人就不能扩展来绕过限制了。
2. 将所要成员变量定义为private和final，并且不要实现setter方法。
3. 通常构造对象时，成员变量使用深拷贝来初始化，而不是直接赋值，这是一种防御措施，因为无法确定输入对象不被其他人修改。
4. 如果确实需要实现getter方法，或者其他可能会返回内部状态的方法，使用copy-on-write原则，创建私有的copy。

**这些原则在并发编程实践中经常被提到。**

关于 setter/getter方法，建议最好是确定有需要时再实现，而不是直接用 IDE 一次全部生成。

## finalize 
前面简单介绍了finalize是一种已经被业界证明了的非常不好的实践，那么为什么会导致那些问题呢？

> finalize 的执行是和垃圾收集关联在一起的，一旦实现了非空的 finalize 方法，就会导致相应对象回收呈现数量级上的变慢，有人专门做过 benchmark，大概是 40~50 倍的下降。

因为，finalize被设计成**在对象被垃圾收集前调用**，这就意味着实现了finalize方法的对象是个“特殊公民”，JVM要对它进行额外处理。f++inalize本质上成为了快速回收的阻碍者++，可能导致你的对象经过多个垃圾收集周期才能被回收。

有人也许会问，我用System.runFinalization()告诉JVM积极一点，是不是就可以了？也许有点用，但是问题在于，这还是不可预测、不能保证的，所以本质上还是不能指望。实践中，因为
finalize 拖慢垃圾收集，导致大量对象堆积，也是一种典型的导致OOM的原因。

从另一个角度，我们要确保回收资源就是因为资源都是有限的，垃圾收集时间的不可预测，可能会极大加剧资源占用。这意味着对于消耗非常高频的资源，千万不要指望finalize去承担资源释放的主要职责，最多让finalize作为最后的“守门员”，况且它已经暴露了如此多的问题。这也是为什么我推荐，资源用完即显式释放，或者利用资源池来尽量重用。finalize还会掩盖资源回收时的出错信息，我们看下面一段JDK的源代码，截取自java.lang.ref.Finalizer：

```
 private void runFinalizer(JavaLangAccess jla) {
 //  ... 省略部分代码
 try {
    Object finalizee = this.get(); 
    if (finalizee != null && !(finalizee instanceof java.lang.Enum)) {
       jla.invokeFinalize(finalizee);
       // Clear stack slot containing this variable, to decrease
       // the chances of false retention with a conservative GC
       finalizee = null;
    }
  } catch (Throwable x) { }
    super.clear(); 
 }
```
这里的Throwable 是被生吞了的！也就意味着一旦出现异常或者出错，你得不到任何有效信息。况
且，Java 在 finalize 阶段也没有好的方式处理任何信息，不然更加不可预测。

## 有什么机制可以替换 finalize 吗？
Java 平台目前在逐步使用 java.lang.ref.Cleaner 来替换掉原有的 finalize 实现。

Cleaner 的实现利用了幻象引用（PhantomReference），这是一种常见的所谓post-mortem清理机制。利用幻象引用和引用队列，可以保证对象被彻底销毁前做一些类似资源回收的工作，比如关闭文件描述符（操作系统有限的资源），它比 finalize 更加轻量、
更加可靠。

吸取了 finalize里的教训，每个Cleaner的操作都是独立的，它有自己的运行线程，所以可以避免意外死锁等问题。

实践中，我们可以为自己的模块构建一个 Cleaner，然后实现相应的清理逻辑。下面是 JDK 自身提供的样例程序：

```
public class CleaningExample implements AutoCloseable {
        // A cleaner, preferably one shared within a library
        private static final Cleaner cleaner = <cleaner>;
        static class State implements Runnable { 
            State(...) {
                // initialize State needed for cleaning action
            }
            public void run() {
                // cleanup action accessing State, executed at most once
            }
        }
        private final State;
        private final Cleaner.Cleanable cleanable
        public CleaningExample() {
            this.state = new State(...);
            this.cleanable = cleaner.register(this, state);
        }
        public void close() {
            cleanable.clean();
        }
    }
```
注意，从可预测性的角度来判断，Cleaner 或者幻象引用改善的程度仍然是有限的，如果由于种种原因导致幻象引用堆积，同样会出现问题。所以，Cleaner 适合作为一种最后的保证手段，而不是完全
依赖 Cleaner进行资源回收，不然我们就要再做一遍 finalize 的噩梦了。

很多第三方库自己直接利用幻象引用定制资源收集，比如广泛使用的 MySQL JDBC driver 之一的mysql-connector-j，就利用了幻象引用机制。幻象引用也可以进行类似链条式依赖
关系的动作，比如，进行总量控制的场景，保证只有连接被关闭，相应资源被回收，连接池才能创建
新的连接。

另外，这种代码如果稍有不慎添加了对资源的强引用关系，就会导致循环引用关系，前面提到的
MySQL JDBC 就在特定模式下有这种问题，导致内存泄漏。上面的示例代码中，将 State 定义为
static，就是为了避免普通的内部类隐含着对外部对象的强引用，因为那样会使外部对象无法进入幻
象可达的状态。

