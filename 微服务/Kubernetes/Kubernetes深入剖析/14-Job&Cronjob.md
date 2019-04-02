Deployment、StatefulSet、DaemonSet这三种编排概念，主要编排的对象是“**在线业务**”（即Long Running Task长作业）。比如Nginx、MySQL等等。**这行应用一旦运行起来，除非出错或者停止，它的容器进程会一直保持在Running状态**。

但是，有一类作业显然不满足这个情况，就是“离线业务”（即Batch Job计算任务），这种任务在计算完成后就直接退出了，而此时如果你依然用Deployment来管理这类作业，就会发现Pod计算任务结束后退出，然后Controller不断重启这个任务，向“滚动更新”这样的功能就更不需要了。

# Job
## 来个例子
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  template:
    spec:
      containers:
      - name: pi
        image: resouer/ubuntu-bc 
        command: ["sh", "-c", "echo 'scale=10000; 4*a(1)' | bc -l "]
      restartPolicy: Never
  backoffLimit: 4
```
在这个yaml中包含一个pod模板，即spec.template字段。这个pod 定义了一个计算π的容器。**注意：这个Job对象并没有定义一个spec.selector来描述要控制哪些Pod**。

创建一个job具体看看：
```bash
$ kubectl create -f job.yaml

# 查看一下这个创建成功的job
$ kubectl describe jobs/pi
Name:             pi
Namespace:        default
Selector:         controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
Labels:           controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
                  job-name=pi
Annotations:      <none>
Parallelism:      1
Completions:      1
..
Pods Statuses:    0 Running / 1 Succeeded / 0 Failed
Pod Template:
  Labels:       controller-uid=c2db599a-2c9d-11e6-b324-0209dc45a495
                job-name=pi
  Containers:
   ...
  Volumes:              <none>
Events:
  FirstSeen    LastSeen    Count    From            SubobjectPath    Type        Reason            Message
  ---------    --------    -----    ----            -------------    --------    ------            -------
  1m           1m          1        {job-controller }                Normal      SuccessfulCreate  Created pod: pi-rq5rl

# 处于计算状态
  $ kubectl get pods
NAME                                READY     STATUS    RESTARTS   AGE
pi-rq5rl                            1/1       Running   0          10s

# 任务结束
$ kubectl get pods
NAME                                READY     STATUS      RESTARTS   AGE
pi-rq5rl                            0/1       Completed   0          4m
# 这就是为什么在Job对象的模板中要定义restartPolicy=Never的原因，离线计算的任务永远不该被重启，再计算一遍毫无意义。

# 查看计算结果
$ kubectl logs pi-rq5rl
3.141592653589793238462643383279...

# 如果计算失败
$ kubectl get pods
NAME                                READY     STATUS              RESTARTS   AGE
pi-55h89                            0/1       ContainerCreating   0          2s
pi-tqbcz                            0/1       Error               0          5s
# 根据restartPolicy的定义，如果为never，则会重新创建新的Pod再次计算，如果为onfailure则restart这个pod里面的容器
```
## 控制起模式

通过describe可以看到，这个Job对象在创建后，它的Pod模板，被自动添加上了一个controller-uid=<一个随机字符串> 这样的`label`。而这个Job对象本身，则被自动加上了这个Label对应的`Selector`，从而保证了Job与它所管理的Pod之间的匹配关系。

**Job Controller使用这种携带UID的label的方式，是为了避免不同Job对象所管理的Pod发生重合**。这种自动生成的Label对用户来说很不友好，所以不适合推广到Deployment等长作业编排对象上。

## 失败重启策略

`restartPolicy`在Job对象中只能被设置为Never或者OnFailure

在Job的对象中添加`spec.backoffLimit`字段来定义重试的次数，默认为6次（即backoffLimit=6）。

> 需要注意，重新创建Pod或者重启Pod的间隔是呈指数增长的，即下一次重新创建Pod的动作会分别发生在10s、20s、40s。。。

## 最长运行时间

当Job正常运行结束后，Pod处于Completed状态，如果Pod因为某种原因一直处于运行状态，则可以设置`spec.activeDeadlineSeconds`字段来设置最长运行时间，比如：
```yaml
spec:
 backoffLimit: 5
 activeDeadlineSeconds: 100
```
运行超过100s这个Job的所有Pod都会终止，并且在Pod的状态里看到终止的原因是reason：DeadlineExceeded。

## 并行运行
在Job对象中，负责并行控制的参数有两个：
1. spec.parallelism:定义的是一个JOb在任意时间最多可以启动多少个Pod同时运行
2. spec.completions:定义的是Job至少完成的Pod数目，即Job最小完成数

### 举个例子
```bash
# 添加最大并行数2，最小完成数4
apiVersion: batch/v1
kind: Job
metadata:
  name: pi
spec:
  parallelism: 2
  completions: 4
  template:
    spec:
      containers:
      - name: pi
        image: resouer/ubuntu-bc
        command: ["sh", "-c", "echo 'scale=5000; 4*a(1)' | bc -l "]
      restartPolicy: Never
  backoffLimit: 4

$ kubectl create -f job.yaml

# Job维护两个状态字段，DESIRED和SUCCESSFUL
$ kubectl get job
NAME      DESIRED   SUCCESSFUL   AGE
pi        4         0            3s
# DESIRED就是completions定义的最小完成数

# 同时创建两个
$ kubectl get pods
NAME       READY     STATUS    RESTARTS   AGE
pi-5mt88   1/1       Running   0          6s
pi-gmcq5   1/1       Running   0          6s

# 当每个Pod完成计算后，进入Completed状态时，就会有一个新的Pod被创建出来，并且快速地从Pending状态进入ContainerCreating状态
$ kubectl get pods
NAME       READY     STATUS    RESTARTS   AGE
pi-gmcq5   0/1       Completed   0         40s
pi-84ww8   0/1       Pending   0         0s
pi-5mt88   0/1       Completed   0         41s
pi-62rbt   0/1       Pending   0         0s

$ kubectl get pods
NAME       READY     STATUS    RESTARTS   AGE
pi-gmcq5   0/1       Completed   0         40s
pi-84ww8   0/1       ContainerCreating   0         0s
pi-5mt88   0/1       Completed   0         41s
pi-62rbt   0/1       ContainerCreating   0         0s
# Job Controller第二次创建出来的两个并行的Pod也进入Running状态
$ kubectl get pods 
NAME       READY     STATUS      RESTARTS   AGE
pi-5mt88   0/1       Completed   0          54s
pi-62rbt   1/1       Running     0          13s
pi-84ww8   1/1       Running     0          14s
pi-gmcq5   0/1       Completed   0          54s

# 最后所有Pod都计算完成，并进入Completed状态
$ kubectl get pods 
NAME       READY     STATUS      RESTARTS   AGE
pi-5mt88   0/1       Completed   0          5m
pi-62rbt   0/1       Completed   0          4m
pi-84ww8   0/1       Completed   0          4m
pi-gmcq5   0/1       Completed   0          5m

# 所有Pod都成功退出，Job的SUCCESSFUL字段值为4
$ kubectl get job
NAME      DESIRED   SUCCESSFUL   AGE
pi        4         4            5m
```

Job Controller的控制对象是Pod，在控制循环中进行的协调（Reconcile）操作，是根据：
1. 实际在Running状态Pod的数目
2. 已经成功退出的Pod数目
3. parallelism、completions参数的值

共同计算出在这个周期里，应该创建或者删除的Pod数目，然后调用Kubernetes API来执行这个操作。

**Job Controller 实际上控制了作业执行的`并行度`和总共需要完成的`任务数`这两个重要的参数**。在实际使用中，需要根据作业的特性，来决定并行度和任务数的合理取值。


# 常见的Job使用方法
# 外部管理器+Job模板
把Job的yaml文件定义为一个模板，然后用一个外部工具控制这些模板来生成Job，如下所示：
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: process-item-$ITEM
  labels:
    jobgroup: jobexample
spec:
  template:
    metadata:
      name: jobexample
      labels:
        jobgroup: jobexample
    spec:
      containers:
      - name: c
        image: busybox
        command: ["sh", "-c", "echo Processing item $ITEM && sleep 5"]
      restartPolicy: Never
```
在yaml文件中定义了$ITEM这样的变量。

在控制这种Job时，只需要注意两个方面：
1. 创建Job时替换掉$ITEM这样的变量
2. 所有来自同一个模板的Job，都有一个`jobgroup：jobexample`标签，这一组Job使用这样一个相同的标识。

可以通过shell来替换$ITEM变量：
```bash
$ mkdir ./jobs
$ for i in apple banana cherry
do
  cat job-tmpl.yaml | sed "s/\$ITEM/$i/" > ./jobs/job-$i.yaml
done

# 这样一组yaml文件就生成了，通过create就能执行任务：
$ kubectl create -f ./jobs
$ kubectl get pods -l jobgroup=jobexample
NAME                        READY     STATUS      RESTARTS   AGE
process-item-apple-kixwv    0/1       Completed   0          4m
process-item-banana-wrsf7   0/1       Completed   0          4m
process-item-cherry-dnfu9   0/1       Completed   0          4m
```

通过这种方式很方便的管理Job作业，只需要类似与for循环这样的外部工具，TensorFlow的KubeFlow就是这样实现的。

> 在这种模式下使用Job对象，completions和parallelism这两个字段都应该使用默认值1，而不需要自行设置，作业的并行控制应该交给外部工具来管理（如KubeFlow）。

## 拥有固定任务数目的并行Job
这种模式下，只关心最后是否拥有指定数目（spec.completions）个任务成功退出。至于执行的并行度是多少并不关心。

可以使用工作队列（Work Queue）进行任务分发，job的yaml定义如下：
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-wq-1
spec:
  completions: 8
  parallelism: 2
  template:
    metadata:
      name: job-wq-1
    spec:
      containers:
      - name: c
        image: myrepo/job-wq-1
        env:
        - name: BROKER_URL
          value: amqp://guest:guest@rabbitmq-service:5672
        - name: QUEUE
          value: job1
      restartPolicy: OnFailure
```
在yaml中总共定义了总共有8个任务会被放入工作队列，可以使用RabbitMQ充当工作队列，所以在Pod 的模板中定义BROKER_URL,来作为消费者。

pod中的执行逻辑如下：
```
/* job-wq-1 的伪代码 */
queue := newQueue($BROKER_URL, $QUEUE)
task := queue.Pop()
process(task)
exit
```
创建这个job后，每组两个pod，一共八个，每个pod都会连接BROKER_URL，从RabbitMQ里读取任务，融合各自处理。

每个pod只要将任务信息读取并完成计算，用户只关心总共有8个任务计算完成并退出，就任务整个job计算完成，对应的就是“任务总数固定”的场景。

## 指定并行度，但不设定completions

此时，需要自己想办法决定什么时候启动新的Pod，什么时候Job才算完成。这种情况下，任务的总数未知，所有需要工作队列来分发任务，并且判断队列是否为空（即任务已经完成）。

Job的定义如下，只是不设置completions的值：
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: job-wq-2
spec:
  parallelism: 2
  template:
    metadata:
      name: job-wq-2
    spec:
      containers:
      - name: c
        image: gcr.io/myproject/job-wq-2
        env:
        - name: BROKER_URL
          value: amqp://guest:guest@rabbitmq-service:5672
        - name: QUEUE
          value: job2
      restartPolicy: OnFailure
```

pod 的执行逻辑如下：
```
/* job-wq-2 的伪代码 */
for !queue.IsEmpty($BROKER_URL, $QUEUE) {
  task := queue.Pop()
  process(task)
}
print("Queue empty, exiting")
exit
```
由于任务数目的总数不固定，所以每一个Pod必须能够知道，自己数目时候可以退出。比如队列为空，所有这种用法对应的是“任务总数不固定”的场景。

在实际使用中，需要处理的条件非常复杂，任务完成后的输出，每个任务Pod之间是不是有资源的竞争和协同等。

# CronJob
定时任务，API对象如下：
```yaml
apiVersion: batch/v1beta1
kind: CronJob
metadata:
  name: hello
spec:
  schedule: "*/1 * * * *"
  jobTemplate:
    spec:
      template:
        spec:
          containers:
          - name: hello
            image: busybox
            args:
            - /bin/sh
            - -c
            - date; echo Hello from the Kubernetes cluster
          restartPolicy: OnFailure
```

在这个yaml文件中，最重要的是`jobTemplate`，**CronJob是一个Job对象的控制器**。它创建和删除Job的依据是schedule字段定义的、一个标准[UNix Cron](https://en.wikipedia.org/wiki/Cron)格式的表达式。

Cron表达式中的五个部分分别代表：分钟、小时、日、月、星期。

CronJob对象会记录每次Job执行的时间。

由于定时任务的特殊性，很可能某个Job还没有执行完成，另外一个新job就产生了，这时候可以通过`spec.concurrencyPolicy`字段来定义具体的处理策略，如：
1. concurrencyPolicy=Allow，默认的情况，这些Job可以同时存在
2. concurrencyPolicy=Forbid，不会创建新的Pod，该创建周期被跳过
3. concurrencyPolicy=Replace，新产生的Job会替换旧的，没有执行完的Job

如果某一次Job创建失败，就会被标记为“miss”。当在指定的时间窗口（通过字段`spec.startingDeadlineSeconds`字段指定，单位为秒）内，miss数目达到100时，那个Cronjob会停止再创建这个Job。




