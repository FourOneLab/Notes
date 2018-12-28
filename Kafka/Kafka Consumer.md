>　Kafka 的 consumer 是以pull的形式获取消息数据的。 producer push消息到kafka cluster ，consumer从集群中pull消息,主要讲解. Parts在消费者中的分配、以及相关的消费者顺序、底层结构元数据信息、Kafka数据读取和存储等。

## Parts在消费者中的分配
- 首先partition和consumer都会字典排序
    - 分区Partition从小到大排序：分区顺序是0,1,2,3,4,5,6,7,8,9
    - 消费者Consumer id按照字典顺序排序：f0b87809-0, f1b87809-0, f1b87809-1
    
- 如何计算分区
    - 首先确认最少分区数： partition/consumer
    - 再确定额外分配数： partition%consumer
    
**假设创建一个Topic有4分partition 每个partition有三个replica**

### 如何分配partition
- 当只有一个consumer的时候，4个partition都分配给该consumer
- 增加一个consumer，会自动触发partition的重新分配，此时每个consumer2个partition


### 如何确定消费者顺序
消费顺序对于组来说：
1. 每一个消费者之间是无序的。
2. 同一个消费者对应一个Partition是offset有序的。
3. 同一个消费者对应多个Partition是顺序消费至最新状态。

## 存储策略
partition存储的时候,分成了多个segment(段),然后通过一个index,索引,来标识第几段.

- 具体流程：
发布者发到某个topic的 消息会被分布到多个partition上（随机或根据用户指定的函数进行分布），broker收到发布消息往对应partition的最后一个segment上添加 该消息，segment达到一定的大小后将不会再往该segment写数据，broker会创建新的segment。

![image](https://img.xiaoxiaomo.com/blog%2Fimg%2F20160514231935.png)

## 高效读取
![image](https://img.xiaoxiaomo.com/blog%2Fimg%2F20160514232049.png)

- 每个片段一个文件并且此文件以该片段中最小的offset命名，查找指定offset的Message的时候，用二分查找就可以定位到该Message在哪个段中。

- 为每个分段后的数据文件建立了索引文件(index)，存储了【offset和message在文件中的position】。index中采用了稀疏存储。


具体查找方法：（假设查找2016的文件）
1. 首先通过zk的元数据信息找到（position、broker、topic）然后我们就能在Partition的内存索引中根据offset 2016找到到相应topic的文件位置和index文件。
2. 把index文件加载到内容中，然后开始读取。
3. 由于是稀疏索引所以相对来说节约空间，跳跃式的查找然后进一步找到2016，读取到对应的posistion。
4. 最后通过posistion去找到message数据。