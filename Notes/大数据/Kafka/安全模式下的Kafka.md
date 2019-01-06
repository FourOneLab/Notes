#### 安全模式下在Terminal使用Kafka的脚本需要实现设置一个KAFKA_OPTS的环境变量, 指定jaas文件的路径:
```
export KAFKA_OPTS="-Djava.security.auth.login.config=/etc/kafka1/conf/jaas.conf -Djava.security.krb5.conf=/etc/kafka1/conf/krb5.conf"
```


- 使用prodcuer可以配置一个producer.properties文件，里面几个重要的参数
```
bootstrap.servers=172.16.140.84:9092
sasl.mechanism=GSSAPI
security.protocol=SASL_PLAINTEXT
sasl.kerberos.service.name=kafka
```

- 使用consumer可以配置一个consumer.properties文件，里面几个重要的参数
```
security.protocol=SASL_PLAINTEXT
sasl.mechanism=GSSAPI
sasl.kerberos.service.name=kafka
sasl.jaas.config=com.sun.security.auth.module.Krb5LoginModule required \
     useKeyTab=true \
     storeKey=true \
     keyTab="/etc/security/keytabs/kafka_client.keytab" \
     principal="kafka/tdh-84@TDH";
```
## 执行命令在/usr/lib/kafka/bin目录下
1. 创建Kafka Topic（创建Topic只需要保证jaas.comf文件中配置了正确的对Zookeeper的访问配置项，即“Client”选项，默认开启安全该选项会自动生成）
```
./kafka-topics.sh  --zookeeper 172.16.1.128:2181 --create --topic demo --partition 3 --replication-factor 1 
```
```
./kafka-broker-topics.sh --bootstrap-server 172.16.140.84:9092 --create 
    --topic topic0 --partitions 1 --replication-factor 1 --consumer.config  /etc/kafka1/conf/consumer.properties
```

2. 查看Kafka Topic
```
./kafka-topics.sh  --zookeeper 172.16.1.128:2181 --describe --topic demo
```

3. 删除一个Topic
```
bin/kafka-broker-topics.sh --bootstrap-server 172.16.140.84:9092 --delete --topic topic0 --consumer.config /etc/kafka1/conf/consumer.properties
```

#### 在使用安全的producer和consumer之前, 还需要对topic做赋权限的操作:
```
kafka-acls.sh --authorizer-properties zookeeper.connect=172.16.140.84:2181
--add --allow-principal User:* --allow-host "*"  --operation ALL --topic test  --group "*"
```

- 消费者脚本
```
kafka-console-consumer.sh --topic t1 --bootstrap-server hostname1:9092 --from-beginning --consumer.config /etc/kafka1/conf/consumer.properties
```

- 生产者脚本
```
kafka-console-producer.sh --topic t1 --broker-list hostname1:9092 --producer.config /etc/kafka1/conf/producer.properties
```

- 赋予权限
```
kafka-acls.sh --authorizer-properties zookeeper.connect=172.16.140.842181 --add --allow-principal User:user1 --operation CREATE --cluster
```
```
kafka-acls.sh --authorizer kafka.security.auth.SimpleAclAuthorizer --authorizer-properties zookeeper.connect=172.16.140.:2181 
--add --allow-principal User:kafka2 --allow-host "*" --operation All, --topic test --group "*"
```

### 常见问题：
1. 通过kafka-acl.sh脚本给用户授权（授权语句授予的是用户在brocker层认证权限）

2. 使用kafka-topic.sh创建topic是直接与zookeeper通信的，因此通过kafka-acl.sh授权的用户无法再znode上创建topic

3. 在命令行创建, 可以使用kafka-broker-topics.sh脚本（kafka-broker-topics.sh脚本主要的行为就是帮助合法的用户通过broker层面的认证, 然后使用kafka jaas.conf的Client配置项中对Zookeeper有写权限的用户创建topic）
