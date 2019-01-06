### kafka client
5.x, 位于TDH-Client下
```
cd /mnt/disk1/TDH-Client/kafka/bin/
```

4.x，位于/usr/lib/kafka/
```
cd /usr/lib/kafka/bin/
```


### kafka配置文件
```
vim /etc/kafka1/conf/server.properties
```

### 管理

```
## 创建主题（4个分区，2个副本）
bin/kafka-topics.sh --create --zookeeper localhost:2181 --replication-factor 2 --partitions 4 --topic test

## list topic
./kafka-topics.sh --zookeeper tdh-204:2181 --list

## describe topic
./kafka-topics.sh --zookeeper tdh-204:2181 --describe --topic test

## 删除topic
./kafka-topics.sh --zookeeper tdh-204:2181 --delete --topic test
```

### 查询



```
# 查询集群描述
bin/kafka-topics.sh --describe --zookeeper 

## 新消费者列表查询（支持0.9版本+）
bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --list

## 显示某个消费组的消费详情（仅支持offset存储在zookeeper上的）
bin/kafka-run-class.sh kafka.tools.ConsumerOffsetChecker --zkconnect localhost:2181 --group test

## 显示某个消费组的消费详情（支持0.9版本+）
bin/kafka-consumer-groups.sh --new-consumer --bootstrap-server localhost:9092 --describe --group test-consumer-group
```

### 发送和消费


```
## 生产者
bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test

## 消费者
bin/kafka-console-consumer.sh --zookeeper localhost:2181 --topic test

## 新生产者（支持0.9版本+）
bin/kafka-console-producer.sh --broker-list localhost:9092 --topic test --producer.config config/producer.properties

## 新消费者（支持0.9版本+）
bin/kafka-console-consumer.sh --bootstrap-server localhost:9092 --topic test --new-consumer --from-beginning --consumer.config config/consumer.properties

## 高级点的用法
bin/kafka-simple-consumer-shell.sh --brist localhost:9092 --topic test --partition 0 --offset 1234  --max-messages 10
```


### offset

```

#从头消费
./kafka-console-consumer.sh --bootstrap-server tdh-204:9092 --topic test --from-beginning


# 指定consumer group
./kafka-console-consumer.sh --bootstrap-server tdh-204:9092 --topic test --from-beginning --consumer.config consumer.properties

./kafka-console-consumer.sh --bootstrap-server tdh-204:9092 --topic test --from-beginning --consumer-property group.id=testing


# 查看consumer group

./kafka-consumer-groups.sh --bootstrap-server tdh-204:9092 --list


# 查看consumer group offsets
Slipstream 默认consumer group id格式 [Application]-[database].[inputstream].[streamjob]

./kafka-consumer-groups.sh --bootstrap-server tdh-204:9092 --describe --group testing


# 重置consumer group offsets
./kafka-streams-application-reset.sh --bootstrap-servers tdh-204:9092 --application-id testing --input-topics test
```



### 平衡leader
```
bin/kafka-preferred-replica-election.sh --zookeeper zk_host:port/chroot
```


### kafka自带压测命令

```
bin/kafka-producer-perf-test.sh --topic test --num-records 100 --record-size 1 --throughput 100  --producer-props bootstrap.servers=localhost:9092
```
