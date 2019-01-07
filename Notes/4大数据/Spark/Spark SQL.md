## Spark SQL 与 Hvie的关系
Spark SQL并不是直接全部替换Hive，而只是替换了Hive的查询引擎部分，通过Spark SQL的查询引擎去操作表或是HDFS上的目录文件，从而提高了查询速度。