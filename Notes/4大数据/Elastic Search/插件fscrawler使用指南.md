# FileSystem Crawler for Elasticsearch

此爬虫有助于从本地文件系统和SSH中索引文档。它爬取文件系统中的新文档，然后更新已经存在的索引并删除久的索引。

需要安装匹配csearch的版本

|    Elasticsearch   |  FS Crawler | Released |                                       Docs                                   |
|--------------------|-------------|----------|------------------------------------------------------------------------------|
| 2.x, 5.x, 6.x      | 2.4-SNAPSHOT|          |See below                                                                     |
| 2.x, 5.x, 6.x      | **2.3**     |2017-07-10|[2.3](https://github.com/dadoonet/fscrawler/blob/fscrawler-2.3/README.md)     |
| 1.x, 2.x, 5.x      | 2.2         |2017-02-03|[2.2](https://github.com/dadoonet/fscrawler/blob/fscrawler-2.2/README.md)     |
| 1.x, 2.x, 5.x      | 2.1         |2016-07-26|[2.1](https://github.com/dadoonet/fscrawler/blob/fscrawler-2.1/README.md)     |
|    es-2.0          | 2.0.0       |2015-10-30|[2.0.0](https://github.com/dadoonet/fscrawler/blob/fscrawler-2.0.0/README.md) |


# Installation Guide

## Download fscrawler

 从[Maven Central](https://repo1.maven.org/maven2/fr/pilato/elasticsearch/crawler/fscrawler/)下载二进制文件。


文件以 `.zip`为后缀名。

例如，下载 [fscrawler-2.3](https://repo1.maven.org/maven2/fr/pilato/elasticsearch/crawler/fscrawler/2.3/fscrawler-2.3.zip):

```sh
wget https://repo1.maven.org/maven2/fr/pilato/elasticsearch/crawler/fscrawler/2.3/fscrawler-2.3.zip

unzip fscrawler-2.3.zip
```

分发的内容包括:

```
$ tree
.
├── LICENSE
├── NOTICE
├── README.md
├── bin
│   ├── fscrawler
│   └── fscrawler.bat
└── lib
    ├── ... All needed jars
```

请注意，还可以下载快照版本，
[from sonatype](https://oss.sonatype.org/content/repositories/snapshots/fr/pilato/elasticsearch/crawler/fscrawler/2.3-SNAPSHOT/)而不需要自己构建快照版本。


## Upgrade fscrawler

It can happen that you need to [upgrade a mapping](#upgrading-an-existing-mapping) before starting fscrawler after a
version upgrade.
Read carefully the following update instructions.

To update fscrawler, just download the new version, unzip it in another directory and launch it as usual.
It will still pick up settings from the configuration directory. Of course, you need to stop first the existing
running instances.

### Upgrade to 2.2

* fscrawler comes with new default mappings for files. They have better defaults as they consume less disk space
and CPU at index time. You should remove existing files in `~/.fscrawler/_default/_mappings` before starting the new
version so default mappings will be updated. If you modified manually mapping files, apply the modification you made
on sample files.

* `excludes` is now set by default for new jobs to `["~*"]`. In previous versions, any file or directory containing a
`~` was excluded. Which means that if in your jobs, you are defining any exclusion rule, you need to add `*~*` if
you want to get back the exact previous behavior.

* If you were indexing `json` or `xml` documents with the `filename_as_id` option set, we were previously removing the
suffix of the file name, like indexing `1.json` was indexed as `1`. With this new version, we don't remove anymore the
suffix. So the `_id` for your document will be now `1.json`.

### Upgrade to 2.3

* fscrawler comes with new mapping for folders. The change is really tiny so you can skip this step if you wish.
We basically removed `name` field in the folder mapping as it was unused.

* The way FSCrawler computes now `path.virtual` for docs has changed. It now includes the filename.
Instead of `/path/to` you will now get `/path/to/file.txt`.

* The way FSCrawler computes now `virtual` for folders is now consistent with what you can see for folders.

* `path.encoded` in documents and `encoded` in folders have been removed as not needed by FSCrawler after all.

* [OCR](#ocr-integration) is now properly activated for PDF documents. This can be time, cpu and memory consuming though.
You can disable explicitly it by setting `fs.pdf_ocr` to `false`.

* All dates are now indexed in elasticsearch in UTC instead of without any time zone. For example, we were indexing
previously a date like `2017-05-19T13:24:47.000`. Which was producing bad results when you were located in a time zone
other than UTC. It's now indexed as `2017-05-19T13:24:47.000+0000`.

* In order to be compatible with the coming 6.0 elasticsearch version, we need to get rid of types as only one type
per index is still supported. Which means that we now create index named `job_name` and `job_name_folder` instead
of one index `job_name` with two types `doc` and `folder`. If you are upgrading from FSCrawler 2.2, it requires that
you reindex your existing data either by deleting the old index and running again FSCrawler or by using the
[reindex API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html) as follows:

```
# Create folder index job_name_folder based on existing folder data
POST _reindex
{
  "source": {
    "index": "job_name",
    "type": "folder"
  },
  "dest": {
    "index": "job_name_folder"
  }
}
# Remove old folder data from job_name index
POST job_name/folder/_delete_by_query
{
  "query": {
    "match_all": {}
  }
}
```

Note that you will need first to create the right settings and mappings so you can then run the reindex job.
You can do that by launching `bin/fscrawler job_name --loop 0`.

Better, you can run `bin/fscrawler job_name --upgrade` and let FSCrawler do all that for you. Note that this can take
a loooong time.

Also please be aware that some APIs used by the upgrade action are only available from elasticsearch 2.3 (reindex) or
elasticsearch 5.0 (delete by query). If you are running an older version than 5.0 you need first to upgrade elasticsearch.

This procedure only applies if you did not set previously `elasticsearch.type` setting (default value was `doc`).
If you did, then you also need to reindex the existing documents to the default `doc` type as per elasticsearch 6.0:

```
# Copy old type doc to the default doc type
POST _reindex
{
  "source": {
    "index": "job_name",
    "type": "your_type_here"
  },
  "dest": {
    "index": "job_name",
    "type": "doc"
  }
}
# Remove old type data from job_name index
POST job_name/your_type_here/_delete_by_query
{
  "query": {
    "match_all": {}
  }
}
```

But note that this last step can take a very loooong time and will generate a lot of IO on your disk.
It might be easier in such case to restart fscrawler from scratch.

* As seen in the previous point, we now have 2 indices instead of a single one. Which means that `elasticsearch.index`
setting has been split to `elasticsearch.index` and `elasticsearch.index_folder`. By default, it's set to the
crawler name and the crawler name plus `_folder`. Note that the `upgrade` feature performs that change for you.

* fscrawler has removed now mapping files `doc.json` and `folder.json`. Mapping for doc is merged within `_settings.json`
file and folder mapping is now part of `_settings_folder.json`. Which means you can remove old files to avoid confusion.
You can simply remove existing files in `~/.fscrawler/_default` before starting the new version so default
files will be created again.

# User Guard

## Starting use

至少安装 **Java 1.8.** 并且正确配置 `JAVA_HOME` 路径.例如在MacOS 上修改`~/.bash_profile` 文件:

```sh
export JAVA_HOME=`/usr/libexec/java_home -v 1.8`
```

使用以下命令启动FScrawler

```sh
bin/fscrawler job_name
```

FS crawler 将会读取本地文件(默认为 `~/.fscrawler/{job_name}/_settings.json`).
如果文件不存在, FS crawler 将会先创建一个job.

```sh
$ bin/fscrawler job_name
18:28:58,174 WARN  [f.p.e.c.f.FsCrawler] job [job_name] does not exist
18:28:58,177 INFO  [f.p.e.c.f.FsCrawler] Do you want to create it (Y/N)?
y
18:29:05,711 INFO  [f.p.e.c.f.FsCrawler] Settings have been created in [~/.fscrawler/job_name/_settings.json]. Please review and edit before relaunch
```

新建一个路径 `/tmp/es` or `c:\tmp\es`, 然后添加一些想要创建为索引的文件并重新启动FS scrawler:

```sh
$ bin/fscrawler --config_dir ./test job_name
18:30:34,330 INFO  [f.p.e.c.f.FsCrawlerImpl] Starting FS crawler
18:30:34,332 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler started in watch mode. It will run unless you stop it with CTRL+C.
18:30:34,682 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler started for [job_name] for [/tmp/es] every [15m]
```

如果路径不存在, FS crawler 会报错:

```
18:30:34,683 WARN  [f.p.e.c.f.FsCrawlerImpl] Error while indexing content from /tmp/es: /tmp/es doesn't exists.
```
不带参数的执行 FS crawler 时，它会列出已经存在的jobs并允许你选择其中一个：
```
$ bin/fscrawler
18:33:00,624 INFO  [f.p.e.c.f.FsCrawler] No job specified. Here is the list of existing jobs:
18:33:00,629 INFO  [f.p.e.c.f.FsCrawler] [1] - job_name
18:33:00,629 INFO  [f.p.e.c.f.FsCrawler] Choose your job [1-1]...
1
18:33:06,151 INFO  [f.p.e.c.f.FsCrawlerImpl] Starting FS crawler
```

## 检索 docs

在elasticsearch中这是一个很常见的案例

```json
GET docs/doc/_search
{
  "query" : {
    "match" : {
        "_all" : "I am searching for something !"
    }
  }
}
```


## Crawler 选项

默认的情况下 FS crawler 每15分钟将会读取 `/tmp/es` .可以通过修改 `~/.fscrawler/{job_name}/_settings.json` 文件来改变这些参数，  `{job_name}` 是刚刚创建的job 的名字。

```json
{
  "name" : "job_name",
  "fs" : {
    "url" : "/path/to/data/dir",
    "update_rate" : "15m"
  }
}
```

通过修改`update_rate` 参数来改变检查文件修改的频率。

如果只想 FS crawler运行一次后就退出, 那么执行时带上`--loop` 参数:

```sh
$ bin/fscrawler job_name --loop 1
18:47:37,487 INFO  [f.p.e.c.f.FsCrawlerImpl] Starting FS crawler
18:47:37,854 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler started for [job_name] for [/tmp/es] every [15m]
...
18:47:37,855 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler is stopping after 1 run
18:47:37,959 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler [job_name] stopped
```

如果已经运行过FS crawler 并且希望重启它 (即对已经存在的文档重新建立索引),
使用`--restart` 参数:

```sh
$ bin/fscrawler job_name --loop 1 --restart
```

在下一章节会有更多关于配置的信息:

* [CLI options](#cli-options)
* [Local FS settings](#local-fs-settings)
* [SSH settings](#ssh-settings)
* [Elasticsearch settings](#elasticsearch-settings)

## Starting with a REST gateway
如果您想上传二进制文档并将其索引到ElasticSearch中，那么FS crawler 是连接ElasticSearch的一个很好的网关，而无需自己编写提取数据和与ElasticSearch通信的所有代码。

若要使用REST服务启动FS crwaler，请使用`--rest`选项 。通常可以与`--loop 0`结合起来，这样就不会索引本地文件，而只会侦听传入的REST请求：


```sh
$ bin/fscrawler job_name --loop 0 --rest
18:55:37,851 INFO  [f.p.e.c.f.FsCrawlerImpl] Starting FS crawler
18:55:39,237 INFO  [f.p.e.c.f.FsCrawlerImpl] FS crawler Rest service started on [http://127.0.0.1:8080/fscrawler]
```

通过以下命令检查服务是否在运行:

```sh
curl http://127.0.0.1:8080/fscrawler/
```

将会返回一个JSON文档。

然后可以开始上传二进制文件：

```sh
echo "This is my text" > test.txt
curl -F "file=@test.txt" "http://127.0.0.1:8080/fscrawler/_upload"
```

将会在elasticsearch中建立该文件的索引并返回已经创建的文档索引在 elasticsearch中的URL，返回信息如下所示：

```json
{
  "ok" : true,
  "filename" : "test.txt",
  "url" : "http://127.0.0.1:9200/fscrawler-rest-tests_doc/doc/dd18bf3a8ea2a3e53e2661c7fb53534"
}
```

在如下的章节中可以看到更多关于REST设置相关的信息：

* [REST settings](#rest-settings)

## Supported formats

FS crawler 支持全格式 [Tika version 1.15 supports](http://tika.apache.org/1.15/formats.html#Supported_Document_Formats), 例如:

* HTML
* Microsoft Office
* Open Office
* PDF
* Images
* MP3
* ...




# Administration guide

一旦crawler运行起来, 它将写入状态信息和统计数据到如下文件中：

* `~/.fscrawler/{job_name}/_settings.json`
* `~/.fscrawler/{job_name}/_status.json`

这意味着，如果在某个时候停止工作，FS crawler 将从它停止的地方重新启动。


FS crawler 也会存储elasticsearch的默认mapping和index设置在如下文件中： `~/.fscrawler/_default/_mappings`:

* `1/_settings_doc.json`:关于ElasticSearch 1.x系列文档索引设置
* `1/_settings_folder.json`: 关于ElasticSearch 1.x系列文件夹索引设置
* `2/_settings_doc.json`: 关于ElasticSearch 2.x系列文档索引设置
* `2/_settings_folder.json`: 关于ElasticSearch 2.x系列文件夹索引设置
* `5/_settings_doc.json`:关于ElasticSearch 5.x系列文档索引设置
* `5/_settings_folder.json`:关于ElasticSearch 5.x系列文件夹索引设置
* `6/_settings_doc.json`: 关于ElasticSearch 6.x系列文档索引设置
* `6/_settings_folder.json`: 关于ElasticSearch 6.x系列文件夹索引设置

更多信息点击这里 [Mapping](#mapping) .

## CLI options

* `--help` 显示帮助信息
* `--silent` 以静默模式运行。不产生输出。
* `--debug` 在调试模式下运行。
* `--trace` 在跟踪模式下运行(比调试输出信息更多)。
* `--config_dir` 定义存储作业的目录，而不是默认目录 `~/.fscrawler`.
* `--username` 定义在使用ElasticSearch群集的安全版本时使用的用户名。 Read
[Using Credentials](#using-credentials). (From 2.2)
* `--upgrade_mapping` 尝试升级文档和文件夹的现有mappings。 Read
[Upgrading an existing mapping](#upgrading-an-existing-mapping). (From 2.2)
* `--loop x` 定义在退出前想要的运行次数。  (From 2.2):

    * `X` 其中x是负值意味着无限, 如 `-1` (default)
    * `0`意味着不运行任何爬取作业(与REST一起使用时有用)
    * `X` 其中X是一个正值，是停止前的运行次数。

如果您只想扫描一次硬盘驱动器，请使用`--loop 1`.

* `--restart` 从头开始重新启动作业 (From 2.2). See below.
* `--rest` 启动REST服务 (From 2.2):

如果想要运行 [REST Service](#rest-service) 而不扫描硬盘驱动器，使用如下命令：

```sh
bin/fscrawler --rest --loop 0
```

使用`--restart` 选项来告诉FS crawler 在启动器必须重启：

```sh
bin/fscrawler job_name --restart
```

在这种情况下，`{job_name}/_status.json` 文件会被删除。

## JVM Settings

如果您想提供JVM设置，比如定义分配给FS Crawler的内存，您可以定义一个名为`FS_JAVA_OPTS`的系统属性： 

```sh
FS_JAVA_OPTS="-Xmx521m -Xms521m" bin/fscrawler
```

## Job file specification

Job文档必须符合以下`json‘规格：

```json
{
  "name" : "job_name",
  "fs" : {
    "url" : "/path/to/data/dir",
    "update_rate" : "15m",
    "includes": [
      "*.*"
    ],
    "excludes": [
      "*.json"
    ],
    "json_support" : false,
    "xml_support" : false,
    "ignore_folders" : false,
    "attributes_support" : false,
    "raw_metadata" : false,
    "filename_as_id" : false,
    "add_filesize" : true,
    "remove_deleted" : true,
    "store_source" : false,
    "lang_detect" : false,
    "continue_on_error" : false,
    "pdf_ocr" : true,
    "indexed_chars" : "10000"
  },
  "server" : {
    "hostname" : null,
    "port" : 22,
    "username" : null,
    "password" : null,
    "protocol" : "local",
    "pem_path" : null
  },
  "elasticsearch" : {
    "nodes" : [ {
      "host" : "127.0.0.1",
      "port" : 9200,
      "scheme" : "HTTP"
    } ],
    "index" : "docs",
    "index_folder" : "folders",
    "bulk_size" : 100,
    "flush_interval" : "5s",
    "username" : "username",
    "password" : "password",
    "pipeline" : "pipeline-id-if-any"
  },
  "rest" : {
    "enabled" : false,
    "scheme" : "HTTP",
    "host" : "127.0.0.1",
    "port" : 8080,
    "port" : "fscrawler"
  }
}
```

以下是现有顶级设置的列表：

|       Name      |                       Documentation                         |
|-----------------|-------------------------------------------------------------|
| `name`          | [the job name](#the-most-simple-crawler) (mandatory field)  |
| `fs`            | [Local FS settings](#local-fs-settings)                     |
| `elasticsearch` | [Elasticsearch settings](#elasticsearch-settings)           |
| `server`        | [SSH settings](#ssh-settings)                               |
| `rest`          | [REST settings](#rest-settings)                             |

### The most simple crawler

定义一个最简单的 crawler job 通过编辑一个 `~/.fscrawler/test/_settings.json` 文件，如下所示:

```json
{
  "name" : "test"
}
```

这将每15分钟扫描一次`/tmp/es`目录中可用的所有文档，并将它们编入`test_doc` ”索引中。它将连接到运行在`127.0.0.1`端口`9200`的ElasticSearch集群。

**Note**: `name`是必须字段

### Local FS settings

这是Local FS的设置列表 (under `fs.` prefix)`:

|               Name               | Default value |                                 Documentation                                     |
|----------------------------------|---------------|-----------------------------------------------------------------------------------|
| `fs.url`                         | `"/tmp/es"`   | [Root directory](#root-directory)                                                 |
| `fs.update_rate`                 | `"15m"`       | [Update Rate](#update-rate)                                                       |
| `fs.includes`                    | `null`        | [Includes and Excludes](#includes-and-excludes)                                   |
| `fs.excludes`                    | `["~*"]`      | [Includes and Excludes](#includes-and-excludes)                                   |
| `fs.json_support`                | `false`       | [Indexing JSon docs](#indexing-json-docs)                                         |
| `fs.xml_support`                 | `false`       | [Indexing XML docs](#indexing-xml-docs) (from 2.2)                                |
| `fs.add_as_inner_object`         | `false`       | [Add as Inner Object](#add-as-inner-object)                                       |
| `fs.ignore_folders`              | `false`       | [Ignore folders](#ignore-folders) (from 2.2)                                      |
| `fs.attributes_support`          | `false`       | [Adding file attributes](#adding-file-attributes)                                 |
| `fs.raw_metadata`                | `true`        | [Disabling raw metadata](#disabling-raw-metadata)                                 |
| `fs.filename_as_id`              | `false`       | [Using Filename as `_id`](#using-filename-as-elasticsearch-_id)                   |
| `fs.add_filesize`                | `true`        | [Disabling file size field](#disabling-file-size-field)                           |
| `fs.remove_deleted`              | `true`        | [Ignore deleted files](#ignore-deleted-files)                                     |
| `fs.store_source`                | `false`       | [Storing binary source document](#storing-binary-source-document-base64-encoded)  |
| `fs.index_content`               | `true`        | [Ignore content](#ignore-content)                                                 |
| `fs.lang_detect`                 | `false`       | [Language detection](#language-detection) (from 2.2)                              |
| `fs.continue_on_error`           | `false`       | [Continue on File Permission Error](#continue-on-error) (from 2.3)                |
| `fs.pdf_ocr`                     | `true`        | [Run OCR on PDF documents](#ocr-integration) (from 2.3)                           |
| `fs.indexed_chars`               | `100000.0`    | [Extracted characters](#extracted-characters)                                     |
| `fs.checksum`                    | `null`        | [File Checksum](#file-checksum)                                                 |

#### Root directory

定义`fs.url`属性在 `~/.fscrawler/test/_settings.json` 文件中:

```json
{
  "name" : "test",
  "fs" : {
    "url" : "/path/to/data/dir"
  }
}
```

Windows用户的路径如下 `c:/tmp` or `c:\\tmp`.

#### Update rate

默认情况下 `update_rate` 设置为`15m`. 可以使用任意兼容的
[time unit](https://www.elastic.co/guide/en/elasticsearch/reference/current/common-options.html#time-units)来修改这个值.

例如 这里设置的是15分钟的更新频率:

```json
{
  "name": "test",
  "fs": {
    "update_rate": "15m"
  }
}
```

或者是3小时的更新频率:

```json
{
  "name": "test",
  "fs": {
    "update_rate": "3h"
  }
}
```

`update_rate` 是上次读取文件系统到下一次读取文件系统的暂停时间。这意味着，如果将其设置为`15m`，则下一次扫描将在当前扫描结束后15分钟进行，无论扫描持续时间如何。

#### Includes and excludes

如果只想要索引 `*.doc` and `*.pdf` 而不是 `resume*`这样的文件.那么 `resume_david.pdf` 这个文件将不会被索引。

定义`fs.includes` 和 `fs.excludes` 属性在 `~/.fscrawler/test/_settings.json` 文件中:

```json
{
  "name" : "test",
  "fs": {
    "includes": [
      "*.doc",
      "*.pdf"
    ],
    "excludes": [
      "resume*"
    ]
  }
}
```

这也适用于目录名。如果要忽略`.ignore`目录 , 只要添加`.ignore` 作为一个排除的名字。
注意： `includes` 不适用于目录，只适用于文件。

默认情况下 FS crawler 将会排除以 `~`开头的文件。

#### Indexing JSon docs

如果想要不通过Tika解析而直接索引Json文件, 需要设置 `json_support` 为 `true`。

JSon内容将被直接存储在 _source中。 如果要保持Json文档和索引同步，
设置选项 [Add as Inner Object](#add-as-inner-object) 这将存储额外元数据和Json内容`object`字段.

```json
{
  "name" : "test",
  "fs" : {
    "json_support" : true
  }
}
```
如果在启动之前没有定义mapping，那么Elasticsearch会自动的猜测mapping。

#### Indexing XML docs

If you want to index XML files and convert them to JSON, you can set `xml_support` to `true`.
The content of XML files will be added directly under _source. If you need to keep XML documents synchronized to the
index, set option [Add as Inner Object](#add-as-inner-object) which stores additional metadata and the XML contents
under field `object`.

```json
{
  "name" : "test",
  "fs" : {
    "xml_support" : true
  }
}
```

Of course, if you did not define a mapping before launching the crawler, Elasticsearch will auto guess the mapping.

#### Add as Inner Object

The default settings store the contents of json and xml documents directly onto the _source element of elasticsearch
documents. Thereby, there is no metadata about file and path settings, which are necessary to determine if a document
is deleted or updated.
New files will however be added to the index, (determined by the file timestamp).

If you need to keep json or xml documents synchronized to elasticsearch, you should set this option.

```json
{
  "name" : "test",
  "fs" : {
    "add_as_inner_object" : true
  }
}
```

#### Ignore folders

By default FS Crawler will index folder names in the index using a specific `folder` type.
If you don't want to index those folders, you can set `ignore_folders` to `true`.

Note that in that case, FS Crawler won't be able to detect removed folders so any document has been indexed
in elasticsearch, it won't be removed when you remove or move the folder.

```json
{
  "name" : "test",
  "fs" : {
    "ignore_folders" : true
  }
}
```

##### Dealing with multiple types and multiple dirs

If you have more than one type, create as many crawlers as types:

`~/.fscrawler/test_type1/_settings.json`:

```json
{
  "name": "test_type1",
  "fs": {
	"url": "/tmp/type1",
	"json_support" : true
  },
  "elasticsearch": {
    "index": "mydocs1",
    "index_folder": "myfolders1"
  }
}
```

`~/.fscrawler/test_type2/_settings.json`:

```json
{
  "name": "test_type2",
  "fs": {
	"url": "/tmp/type2",
	"json_support" : true
  },
  "elasticsearch": {
    "index": "mydocs2",
    "index_folder": "myfolders2"
  }
}
```

`~/.fscrawler/test_type3/_settings.json`:

```json
{
  "name": "test_type3",
  "fs": {
	"url": "/tmp/type3",
	"xml_support" : true
  },
  "elasticsearch": {
    "index": "mydocs3",
    "index_folder": "myfolders3"
  }
}
```

##### Dealing with multiple types within the same dir

You can also index many types from one single dir using two crawlers scanning the same dir and by setting
`includes` parameter:

`~/.fscrawler/test_type1.json`:

```json
{
  "name": "test_type1",
  "fs": {
	"url": "/tmp",
    "includes": [ "type1*.json" ],
	"json_support" : true
  },
  "elasticsearch": {
    "index": "mydocs1",
    "index_folder": "myfolders1"
  }
}
```

`~/.fscrawler/test_type2.json`:

```json
{
  "name": "test_type2",
  "fs": {
	"url": "/tmp",
    "includes": [ "type2*.json" ],
	"json_support" : true
  },
  "elasticsearch": {
    "index": "mydocs2",
    "index_folder": "myfolders2"
  }
}
```

`~/.fscrawler/test_type3.json`:

```json
{
  "name": "test_type3",
  "fs": {
	"url": "/tmp",
    "includes": [ "*.xml" ],
	"xml_support" : true
  },
  "elasticsearch": {
    "index": "mydocs3",
    "index_folder": "myfolders3"
  }
}
```

#### Using filename as elasticsearch `_id`

Please note that the document `_id` is always generated (hash value) from the filename to avoid issues with
special characters in filename.
You can force to use the `_id` to be the filename using `filename_as_id` attribute:

```json
{
  "name" : "test",
  "fs" : {
    "filename_as_id" : true
  }
}
```

#### Adding file attributes

If you want to add file attributes such as `attributes.owner` and `attributes.group`, you can set `attributes_support` to `true`.

```json
{
  "name" : "test",
  "fs" : {
    "attributes_support" : true
  }
}
```

#### Disabling raw metadata

By default, FS Crawler will extract all found metadata within `meta.raw` object.
If you want to disable this feature, you can set `raw_metadata` to `false`.

```json
{
  "name" : "test",
  "fs" : {
    "raw_metadata" : false
  }
}
```

Generated raw metadata depends on the file format itself.

For example, a PDF document could generate:

* `"date" : "2016-07-07T08:37:42Z"`
* `"pdf:PDFVersion" : "1.5"`
* `"xmp:CreatorTool" : "Microsoft Word"`
* `"Keywords" : "keyword1, keyword2"`
* `"access_permission:modify_annotations" : "true"`
* `"access_permission:can_print_degraded" : "true"`
* `"subject" : "Test Tika Object"`
* `"dc:creator" : "David Pilato"`
* `"dcterms:created" : "2016-07-07T08:37:42Z"`
* `"Last-Modified" : "2016-07-07T08:37:42Z"`
* `"dcterms:modified" : "2016-07-07T08:37:42Z"`
* `"dc:format" : "application/pdf; version=1.5"`
* `"title" : "Test Tika title"`
* `"Last-Save-Date" : "2016-07-07T08:37:42Z"`
* `"access_permission:fill_in_form" : "true"`
* `"meta:save-date" : "2016-07-07T08:37:42Z"`
* `"pdf:encrypted" : "false"`
* `"dc:title" : "Test Tika title"`
* `"modified" : "2016-07-07T08:37:42Z"`
* `"cp:subject" : "Test Tika Object"`
* `"Content-Type" : "application/pdf"`
* `"X-Parsed-By" : "org.apache.tika.parser.DefaultParser"`
* `"creator" : "David Pilato"`
* `"meta:author" : "David Pilato"`
* `"dc:subject" : "keyword1, keyword2"`
* `"meta:creation-date" : "2016-07-07T08:37:42Z"`
* `"created" : "Thu Jul 07 10:37:42 CEST 2016"`
* `"access_permission:extract_for_accessibility" : "true"`
* `"access_permission:assemble_document" : "true"`
* `"xmpTPg:NPages" : "2"`
* `"Creation-Date" : "2016-07-07T08:37:42Z"`
* `"access_permission:extract_content" : "true"`
* `"access_permission:can_print" : "true"`
* `"meta:keyword" : "keyword1, keyword2"`
* `"Author" : "David Pilato"`
* `"access_permission:can_modify" : "true"`

Where a MP3 file would generate:

* `"xmpDM:genre" : "Vocal"`
* `"X-Parsed-By" : "org.apache.tika.parser.DefaultParser"`
* `"creator" : "David Pilato"`
* `"xmpDM:album" : "FS Crawler"`
* `"xmpDM:trackNumber" : "1"`
* `"xmpDM:releaseDate" : "2016"`
* `"meta:author" : "David Pilato"`
* `"xmpDM:artist" : "David Pilato"`
* `"dc:creator" : "David Pilato"`
* `"xmpDM:audioCompressor" : "MP3"`
* `"title" : "Test Tika"`
* `"xmpDM:audioChannelType" : "Stereo"`
* `"version" : "MPEG 3 Layer III Version 1"`
* `"xmpDM:logComment" : "Hello but reverted"`
* `"xmpDM:audioSampleRate" : "44100"`
* `"channels" : "2"`
* `"dc:title" : "Test Tika"`
* `"Author" : "David Pilato"`
* `"xmpDM:duration" : "1018.775146484375"`
* `"Content-Type" : "audio/mpeg"`
* `"samplerate" : "44100"`

As elasticsearch will by default to automatically guess the type, you could end up having conflicts between
metadata raw fields: a field which is first detected as a date but is getting for another document a value like
"in the seventies". In such a case, you could imagine forcing the mapping or defining an index mapping template.

Note that dots in metadata names will be replaced by a `:`. For example `PTEX.Fullbanner` will be indexed as
`PTEX:Fullbanner`.

#### Disabling file size field

By default, FS crawler will create a field to store the original file size in octets.
You can disable it using `add_filesize' option:

```json
{
  "name" : "test",
  "fs" : {
    "add_filesize" : false
  }
}
```

#### Ignore deleted files

If you don't want to remove indexed documents when you remove a file or a directory, you can
set `remove_deleted` to `false` (default to `true`):


```json
{
  "name" : "test",
  "fs" : {
    "remove_deleted" : false
  }
}
```

#### Ignore content

If you don't want to extract file content but only index filesystem metadata such as filename, date, size and path,
you can set `index_content` to `false` (default to `true`):


```json
{
  "name" : "test",
  "fs" : {
    "index_content" : false
  }
}
```

#### Continue on Error

By default FS Crawler will immediately stop indexing if he hits a Permission denied exception.
If you want to just skip this File and continue with the rest of the directory tree you can 
set `continue_on_error` to `true` (default to `false`):


```json
{
  "name" : "test",
  "fs" : {
    "continue_on_error" : true
  }
}
```


#### Language detection

From FS crawler 2.2, you can ask for language detection using `lang_detect` option:

```json
{
  "name" : "test",
  "fs" : {
    "lang_detect" : true
  }
}
```

In that case, a new field named `meta.language` is added to the generated JSon document.

If you are using elasticsearch 5.0 or superior, you can use this value to send your document to a specific index
using a [Node Ingest pipeline](#using-ingest-node-pipeline).

For example, you can define a pipeline named `langdetect` with:

```sh
PUT _ingest/pipeline/langdetect
{
  "description" : "langdetect pipeline",
  "processors" : [
    {
      "set": {
        "field": "_index",
        "value": "myindex-{{meta.language}}"
      }
    }
  ]
}
```

In FS crawler settings, set both `fs.lang_detect` and `elasticsearch.pipeline` options:

```json
{
  "name" : "test",
  "fs" : {
    "lang_detect" : true
  },
  "elasticsearch" : {
    "pipeline" : "langdetect"
  }
}
```

And then, a document containing french text will be sent to `myindex-fr`.
A document containing english text will be sent to `myindex-en`.

You can also imagine changing the field name from `content` to `content-fr` or `content-en`. That will help you
to define the correct analyzer to use.

Language detection might detect more than one language in a given text but only the most accurate will be set.
Which means that if you have a document containing 80% of french and 20% of english, the document will be marked
as `fr`.

Note that language detection is CPU and time consuming.

#### Storing binary source document (BASE64 encoded)

You can store in elasticsearch itself the binary document using `store_source` option:

```json
{
  "name" : "test",
  "fs" : {
    "store_source" : true
  }
}
```

In that case, a new field named `attachment` is added to the generated JSon document. This field is not indexed.
Default mapping for `attachment` field is:

```json
{
  "doc" : {
    "properties" : {
      "attachment" : {
        "type" : "binary",
        "doc_values" : false
      }
      // ... Other properties here
    }
  }
}
```

#### Extracted characters

By default FS crawler will extract only the first 100 000 characters.
But, you can set `indexed_chars` to `5000` in FS crawler settings in order to overwrite this default settings.

```json
{
  "name": "test",
  "fs": {
    "indexed_chars": "5000"
  }
}
```

This number can be either a fixed size, number of characters that is, or a percent using `%` sign.
The percentage value will be applied to the filesize to determine the number of character the crawler needs
to extract.

If you want to index only `80%` of filesize, define `indexed_chars` to `"80%"`.
Of course, if you want to index the full document, you can set this property to `"100%"`. Double values are also
supported so `"0.01%"` is also a correct value.

**Compressed files**: If your file is compressed, you might need to increase `indexed_chars` to more than `"100%"`.
For example, `"150%"`.

If you want to extract the full content, define `indexed_chars` to `"-1"`.

**Note**: Tika requires to allocate in memory a data structure to extract text. Setting `indexed_chars` to a high
number will require more memory!

#### File checksum

If you want FS crawler to generate a checksum for each file, set `checksum` to the algorithm you wish to use
to compute the checksum, such as `MD5` or `SHA-1`.

```json
{
  "name": "test",
  "fs": {
    "checksum": "MD5"
  }
}
```


### SSH settings

You can index files remotely using SSH.

Here is a list of SSH settings (under `server.` prefix)`:

|               Name               | Default value |                     Documentation                        |
|----------------------------------|---------------|----------------------------------------------------------|
| `server.hostname`                | `null`        | Hostname                                                 |
| `server.port`                    | `22`          | Port                                                     |
| `server.username`                | `null`        | [Username](#username--password)                          |
| `server.password`                | `null`        | [Password](#username--password)                          |
| `server.protocol`                | `"local"`     | Set it to `ssh`                                          |
| `server.pem_path`                | `null`        | [Using Username / PEM file](#using-username--pem-file)   |

#### Username / Password

Let's say you want to index from a remote server using SSH:

* FS URL: `/path/to/data/dir/on/server`
* Server: `mynode.mydomain.com`
* Username: `username`
* Password: `password`
* Protocol: `ssh` (default to `local`)
* Port: `22` (default to `22`)


```json
{
  "name" : "test",
  "fs" : {
    "url" : "/path/to/data/dir/on/server"
  },
  "server" : {
    "hostname" : "mynode.mydomain.com",
    "port" : 22,
    "username" : "username",
    "password" : "password",
    "protocol" : "ssh"
  }
}
```

#### Using Username / PEM file

Let's say you want to index from a remote server using SSH:

* FS URL: `/path/to/data/dir/on/server`
* Server: `mynode.mydomain.com`
* Username: `username`
* PEM File: `/path/to/private_key.pem`
* Protocol: `ssh` (default to `local`)
* Port: `22` (default to `22`)

```json
{
  "name" : "test",
  "fs" : {
    "url" : "/path/to/data/dir/on/server"
  },
  "server" : {
    "hostname" : "mynode.mydomain.com",
    "port" : 22,
    "username" : "username",
    "protocol" : "ssh",
	"pem_path": "/path/to/private_key.pem"
  }
}
```


### Elasticsearch settings

Here is a list of Elasticsearch settings (under `elasticsearch.` prefix)`:

|               Name               |    Default value     |                                 Documentation                                     |
|----------------------------------|----------------------|-----------------------------------------------------------------------------------|
| `elasticsearch.index`            | job name             | Index name for docs. See [Index settings](#index-settings)                        |
| `elasticsearch.index_folder`     | job name + _folder   | Index name for folders. See [Index settings](#index-settings)                     |
| `elasticsearch.bulk_size`        | `100`                | [Bulk settings](#bulk-settings)                                                   |
| `elasticsearch.flush_interval`   | `"5s"`               | [Bulk settings](#bulk-settings)                                                   |
| `elasticsearch.pipeline`         | `null`               | [Using Ingest Node Pipeline](#using-ingest-node-pipeline) (from 2.2)              |
| `elasticsearch.nodes`            |http://127.0.0.1:9200 | [Node settings](#node-settings)                                                   |
| `elasticsearch.username`         | `null`               | Username. See [Using credentials (X-Pack)](#using-credentials-x-pack) (from 2.2)  |
| `elasticsearch.password`         | `null`               | Password. See [Using credentials (X-Pack)](#using-credentials-x-pack) (from 2.2)  |

#### Index settings

By default, FS crawler will index your data in an index which name is the same as the crawler name (`name` property)
plus `_doc` suffix, like `test_doc`. You can change it by setting `index` field:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "index" : "docs"
  }
}
```

When FS crawler needs to create the doc index, it applies some default settings and mappings which are read from
`~/.fscrawler/_default/5/_settings_doc.json`.
You can read its content from [the source](src/main/resources/fr/pilato/elasticsearch/crawler/fs/_default/5/_settings_doc.json).

Settings define an analyzer named `fscrawler_path` which uses a
[path hierarchy tokenizer](https://www.elastic.co/guide/en/elasticsearch/reference/current/analysis-pathhierarchy-tokenizer.html).

FS crawler will also index folders in an index which name is the same as the crawler name (`name` property)
plus `_folder` suffix, like `test_folder`. You can change it by setting `index_folder` field:

```json
{
 "name" : "test",
 "elasticsearch" : {
   "index_folder" : "folders"
 }
}
```

FS crawler applies as well a mapping automatically which is read from `~/.fscrawler/_default/5/_settings_folder.json`.
[Source here](src/main/resources/fr/pilato/elasticsearch/crawler/fs/_default/5/_settings_folder.json).

You can also display the index mapping being used with Kibana:

```
GET docs/_mapping
```

Or fall back to the command line:

```sh
curl 'http://localhost:9200/docs/_mapping?pretty'
```

##### Creating your own mapping (analyzers)

If you want to define your own index settings and mapping to set analyzers for example, you can either create the index
and push the mapping or define a
`~/.fscrawler/_default/5/_settings_doc.json` document which contains the index settings and mappings you wish
**before starting the FS crawler**.

The following example uses a `french` analyzer to index the `content` field.

```json
{
  "settings": {
    "analysis": {
      "analyzer": {
        "fscrawler_path": {
          "tokenizer": "fscrawler_path"
        }
      },
      "tokenizer": {
        "fscrawler_path": {
          "type": "path_hierarchy"
        }
      }
    }
  },
  "mappings": {
    "doc": {
      "properties" : {
        "attachment" : {
          "type" : "binary",
          "doc_values" : false
        },
        "attributes" : {
          "properties" : {
            "group" : {
              "type" : "keyword"
            },
            "owner" : {
              "type" : "keyword"
            }
          }
        },
        "content" : {
          "type" : "text",
          "analyzer" : "french"
        },
        "file" : {
          "properties" : {
            "content_type" : {
              "type" : "keyword"
            },
            "filename" : {
              "type" : "keyword"
            },
            "extension" : {
              "type" : "keyword"
            },
            "filesize" : {
              "type" : "long"
            },
            "indexed_chars" : {
              "type" : "long"
            },
            "indexing_date" : {
              "type" : "date",
              "format" : "dateOptionalTime"
            },
            "last_modified" : {
              "type" : "date",
              "format" : "dateOptionalTime"
            },
            "checksum": {
              "type": "keyword"
            },
            "url" : {
              "type" : "keyword",
              "index" : false
            }
          }
        },
        "meta" : {
          "properties" : {
            "author" : {
              "type" : "text"
            },
            "date" : {
              "type" : "date",
              "format" : "dateOptionalTime"
            },
            "keywords" : {
              "type" : "text"
            },
            "title" : {
              "type" : "text"
            },
            "language" : {
              "type" : "keyword"
            }
          }
        },
        "path" : {
          "properties" : {
            "real" : {
              "type" : "keyword",
              "fields": {
                "tree": {
                  "type" : "text",
                  "analyzer": "fscrawler_path",
                  "fielddata": true
                }
              }
            },
            "root" : {
              "type" : "keyword"
            },
            "virtual" : {
              "type" : "keyword",
              "fields": {
                "tree": {
                  "type" : "text",
                  "analyzer": "fscrawler_path",
                  "fielddata": true
                }
              }
            }
          }
        }
      }
    }
  }
}
```

Note that if you want to push manually the mapping to elasticsearch you can use the classic REST calls:

```
# Create index (don't forget to add the fscrawler_path analyzer)
PUT docs
{
  // Same index settings as previously seen
}
```

##### Define explicit mapping/settings per job

Let's say you created a job named `job_name` and you are sending documents against an elasticsearch cluster
running version `5.x`.

If you create the following files, they will be picked up at job start time instead of the
[default ones](#autogenerated-mapping):

* `~/.fscrawler/{job_name}/_mappings/5/_settings_doc.json`
* `~/.fscrawler/{job_name}/_mappings/5/_settings_folder.json`

You can do the same for other elasticsearch versions with:

* `~/.fscrawler/{job_name}/_mappings/1/_settings_doc.json` for 1.x series
* `~/.fscrawler/{job_name}/_mappings/1/_settings_folder.json` for 1.x series
* `~/.fscrawler/{job_name}/_mappings/2/_settings_doc.json` for 2.x series
* `~/.fscrawler/{job_name}/_mappings/2/_settings_folder.json` for 2.x series
* `~/.fscrawler/{job_name}/_mappings/6/_settings_doc.json` for 6.x series
* `~/.fscrawler/{job_name}/_mappings/6/_settings_folder.json` for 6.x series


##### Replace existing mapping

Unfortunately you can not change the mapping on existing data.
Therefore, you'll need first to remove existing index, which means remove all existing data, and then restart FS crawler
with the new mapping.

You might to try [elasticsearch Reindex API](https://www.elastic.co/guide/en/elasticsearch/reference/current/docs-reindex.html) though.


#### Bulk settings

FS crawler is using bulks to send data to elasticsearch. By default the bulk is executed every 100 operations or 
every 5 seconds. You can change default settings using `bulk_size` and `flush_interval`:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "bulk_size" : 1000,
    "flush_interval" : "2s"
  }
}
```

Note that elasticsearch has a [default limit of `100mb` per HTTP request](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-http.html).
Which means that if you are indexing a massive bulk of documents, you might hit that limit and FSCrawler will throw
an error like `entity content is too long [xxx] for the configured buffer limit [104857600]`.

You can either change this limit on elasticsearch side by setting `http.max_content_length` to a higher value but please
be aware that this will consume much more memory on elasticsearch side.

Or you can decrease the `bulk_size` setting to a smaller value.

#### Using Ingest Node Pipeline

If you are using an elasticsearch cluster running a 5.0 or superior version, you
can use an Ingest Node pipeline to transform documents sent by FS crawler before they are actually indexed.
Please note that folder objects are not sent through the pipeline as they are more internal objects.

For example, if you have the following pipeline:

```sh
PUT _ingest/pipeline/fscrawler
{
  "description" : "fscrawler pipeline",
  "processors" : [
    {
      "set" : {
        "field": "foo",
        "value": "bar"
      }
    }
  ]
}
```

In FS crawler settings, set the `elasticsearch.pipeline` option:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "pipeline" : "fscrawler"
  }
}
```

Note that this option is available from FS crawler 2.2.

#### Node settings

FS crawler is using elasticsearch REST layer to send data to your running cluster.
By default, it connects to `127.0.0.1` on port `9200` which are the default settings when
running a local node on your machine.

Of course, in production, you would probably change this and connect to a production cluster:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "nodes" : [
      { "host" : "mynode1.mycompany.com", "port" : 9200, "scheme" : "HTTP" }
    ]
  }
}
```

You can define multiple nodes:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "nodes" : [
      { "host" : "mynode1.mycompany.com", "port" : 9200, "scheme" : "HTTP" },
      { "host" : "mynode2.mycompany.com", "port" : 9200, "scheme" : "HTTP" },
      { "host" : "mynode3.mycompany.com", "port" : 9200, "scheme" : "HTTP" }
    ]
  }
}
```

You can use HTTPS instead of default HTTP (from 2.2):

```json
{
  "name" : "test",
  "elasticsearch" : {
    "nodes" : [
      { "host" : "CLUSTERID.eu-west-1.aws.found.io", "port" : 9243, "scheme" : "HTTPS" }
    ]
  }
}
```


#### Using Credentials (X-Pack)

If you secured your elasticsearch cluster with [X-Pack](https://www.elastic.co/downloads/x-pack), you can provide
`username` and `password` to FS crawler:

```json
{
  "name" : "test",
  "elasticsearch" : {
    "username" : "elastic",
    "password" : "changeme"
  }
}
```

**WARNING**: note that for the current version, the elasticsearch password is stored in plain text in
your job setting file.

A better practice is to only set the username or pass it with `--username elastic` option when starting
FS Crawler.

If the password is not defined, you will be prompted when starting the job:

```
22:46:42,528 INFO  [f.p.e.c.f.FsCrawler] Password for elastic:
```

#### Generated fields

FS crawler creates the following fields :

|         Field        |                Description                  |                    Example                  |
|----------------------|---------------------------------------------|---------------------------------------------|
| `content`            | Extracted content                           | `"This is my text!"`                        |
| `attachment`         | BASE64 encoded binary file                  | BASE64 Encoded document                     |
| `meta.author`        | Author if any in document metadata          | `"David Pilato"`                            |
| `meta.title`         | Title if any in document metadata           | `"My document title"`                       |
| `meta.date`          | Document date if any in document metadata   | `"2013-04-04T15:21:35"`                     |
| `meta.keywords`      | Keywords if any in document metadata        | `["river","fs","elasticsearch"]`            |
| `meta.language`      | Detected Language if any                    | `"fr"`                                      |
| `meta.raw`           | An object with all raw metadata             | `"meta.raw.channels" : "2"`                 |
| `file.content_type`  | Content Type                                | `"application/vnd.oasis.opendocument.text"` |
| `file.last_modified` | Last modification date                      | `1386855978000`                             |
| `file.indexing_date` | Indexing date                               | `"2013-12-12T13:50:58.758Z"`                |
| `file.filesize`      | File size in bytes                          | `1256362`                                   |
| `file.indexed_chars` | Extracted chars if `fs.indexed_chars` > 0   | `100000`                                    |
| `file.filename`      | Original file name                          | `"mydocument.pdf"`                          |
| `file.extension`     | Original file name extension (from 2.2)     | `"pdf"`                                     |
| `file.url`           | Original file url                           | `"file://tmp/mydir/otherdir/mydocument.pdf"`|
| `file.checksum`      | Checksum if `fs.checksum` set               | `"c32eafae2587bef4b3b32f73743c3c61"`        |
| `path.virtual`       | Relative path from root path                | `"/mydir/otherdir/mydocument.pdf"`          |
| `path.root`          | MD5 encoded parent path (for internal use)  | `"112aed83738239dbfe4485f024cd4ce1"`        |
| `path.real`          | Actual real path name                       | `"/tmp/mydir/otherdir/mydocument.pdf"`      |
| `attributes.owner`   | Owner name                                  | `"david"`                                   |
| `attributes.group`   | Group name                                  | `"staff"`                                   |


Here is a typical JSON document generated by the crawler:

```json
{
   "file":{
      "filename":"test.odt",
      "extension":"odt",
      "last_modified":1386855978000,
      "indexing_date":"2013-12-12T13:50:58.758Z",
      "content_type":"application/vnd.oasis.opendocument.text",
      "url":"file:///tmp/testfs_metadata/test.odt",
      "indexed_chars":100000,
      "filesize":8355,
      "checksum":"c32eafae2587bef4b3b32f73743c3c61"
   },
   "path":{
      "root":"bceb3913f6d793e915beb70a4735592",
      "virtual":"/test.odt",
      "real":"/tmp/testfs_metadata/test.odt"
   },
   "attributes": {
      "owner": "david",
      "group": "staff"
   },
   "meta":{
      "author":"David Pilato",
      "title":"Mon titre",
      "date":"2013-04-04T15:21:35",
      "keywords":[
         "fs",
         "elasticsearch",
         "crawler"
      ],
      "language":"fr"
   },
   "content":"Bonjour David\n\n\n"
}
```

#### Search examples

You can use the content field to perform full-text search on

```
GET docs/_search
{
  "query" : {
    "match" : {
        "content" : "the quick brown fox"
    }
  }
}
```

You can use meta fields to perform search on.

```
GET docs/_search
{
  "query" : {
    "term" : {
        "file.filename" : "mydocument.pdf"
    }
  }
}
```

Or run some aggregations on top of them, like:

```
GET docs/_search
{
  "size": 0,
  "aggs": {
    "by_extension": {
      "terms": {
        "field": "file.extension"
      }
    }
  }
}
```

### REST service

From 2.2, FS crawler comes with a REST service available by default at `http://127.0.0.1:8080/fscrawler`.
To activate it, launch FS Crawler with `--rest` option.

#### FS Crawler status

To get an overview of the running service, you can call `GET /` endpoint:

```sh
curl http://127.0.0.1:8080/fscrawler/
```

It will give you a response similar to:

```json
{
  "ok" : true,
  "version" : "2.2",
  "elasticsearch" : "5.1.1",
  "settings" : {
    "name" : "fscrawler-rest-tests",
    "fs" : {
      "url" : "/tmp/es",
      "update_rate" : "15m",
      "json_support" : false,
      "filename_as_id" : false,
      "add_filesize" : true,
      "remove_deleted" : true,
      "store_source" : false,
      "index_content" : true,
      "attributes_support" : false,
      "raw_metadata" : true,
      "xml_support" : false,
      "index_folders" : true,
      "lang_detect" : false
    },
    "elasticsearch" : {
      "nodes" : [ {
        "host" : "127.0.0.1",
        "port" : 9200,
        "scheme" : "HTTP"
      } ],
      "index" : "fscrawler-rest-tests_doc",
      "index_folder" : "fscrawler-rest-tests_folder",
      "bulk_size" : 100,
      "flush_interval" : "5s",
      "username" : "elastic"
    },
    "rest" : {
      "scheme" : "HTTP",
      "host" : "127.0.0.1",
      "port" : 8080,
      "endpoint" : "fscrawler"
    }
  }
}
```

#### Uploading a binary document

To upload a binary, you can call `POST /_upload` endpoint:

```sh
echo "This is my text" > test.txt
curl -F "file=@test.txt" "http://127.0.0.1:8080/fscrawler/_upload"
```

It will give you a response similar to:

```json
{
  "ok" : true,
  "filename" : "test.txt",
  "url" : "http://127.0.0.1:9200/fscrawler-rest-tests_doc/doc/dd18bf3a8ea2a3e53e2661c7fb53534"
}
```

The `url` represents the elasticsearch address of the indexed document.
If you call:

```sh
curl http://127.0.0.1:9200/fscrawler-rest-tests_doc/doc/dd18bf3a8ea2a3e53e2661c7fb53534?pretty
```

You will get back your document as it has been stored by elasticsearch:

```json
{
  "_index" : "fscrawler-rest-tests_doc",
  "_type" : "doc",
  "_id" : "dd18bf3a8ea2a3e53e2661c7fb53534",
  "_version" : 1,
  "found" : true,
  "_source" : {
    "content" : "This file contains some words.\n",
    "meta" : {
      "raw" : {
        "X-Parsed-By" : "org.apache.tika.parser.DefaultParser",
        "Content-Encoding" : "ISO-8859-1",
        "Content-Type" : "text/plain; charset=ISO-8859-1"
      }
    },
    "file" : {
      "extension" : "txt",
      "content_type" : "text/plain; charset=ISO-8859-1",
      "indexing_date" : "2017-01-04T21:01:08.043",
      "filename" : "test.txt"
    },
    "path" : {
      "virtual" : "test.txt",
      "real" : "test.txt"
    }
  }
}
```


If you started FS crawler in debug mode with `--debug` or if you pass `debug=true` query parameter,
then the response will be much more complete:

```sh
echo "This is my text" > test.txt
curl -F "file=@test.txt" "http://127.0.0.1:8080/fscrawler/_upload?debug=true"
```

will give

```json
{
  "ok" : true,
  "filename" : "test.txt",
  "url" : "http://127.0.0.1:9200/fscrawler-rest-tests_doc/doc/dd18bf3a8ea2a3e53e2661c7fb53534",
  "doc" : {
    "content" : "This file contains some words.\n",
    "meta" : {
      "raw" : {
        "X-Parsed-By" : "org.apache.tika.parser.DefaultParser",
        "Content-Encoding" : "ISO-8859-1",
        "Content-Type" : "text/plain; charset=ISO-8859-1"
      }
    },
    "file" : {
      "extension" : "txt",
      "content_type" : "text/plain; charset=ISO-8859-1",
      "indexing_date" : "2017-01-04T14:05:10.325",
      "filename" : "test.txt"
    },
    "path" : {
      "virtual" : "test.txt",
      "real" : "test.txt"
    }
  }
}
```

#### Simulate Upload

If you want to get back the extracted content and its metadata but without indexing into elasticsearch
you can use `simulate=true` query parameter:

```sh
echo "This is my text" > test.txt
curl -F "file=@test.txt" "http://127.0.0.1:8080/fscrawler/_upload?debug=true&simulate=true"
```

#### Document ID

By default, FS crawler encodes the filename to generate an id. Which means that if you send 2 files
with the same filename `test.txt`, the second one will overwrite the first one because they will both share
the same ID.

You can force any id you wish by adding `id=YOUR_ID` in the form data:

```sh
echo "This is my text" > test.txt
curl -F "file=@test.txt" -F "id=my-test" "http://127.0.0.1:8080/fscrawler/_upload"
```

There is a specific id named `_auto_` where the ID will be autogenerated by elasticsearch.
It means that sending twice the same file will result in 2 different documents indexed.

#### REST settings

Here is a list of REST service settings (under `rest.` prefix)`:

|       Name       | Default value |             Documentation               |
|------------------|---------------|-----------------------------------------|
| `rest.scheme`    | `http`        | Scheme. Can be either `http` or `https` |
| `rest.host`      | `127.0.0.1`   | Bound host                              |
| `rest.port`      | `8080`        | Bound port                              |
| `rest.endpoint`  | `fscrawler`   | Endpoint                                |

REST service is running at `http://127.0.0.1:8080/fscrawler` by default.

You can change it using `rest` settings:

```json
{
  "name" : "test",
  "rest" : {
    "scheme" : "HTTP",
    "host" : "192.168.0.1",
    "port" : 8180,
    "endpoint" : "my_fscrawler"
  }
}
```

It also means that if you are running more than one instance of FS crawler locally, you can (must) change
the `port`.

# Tips and tricks

## Indexing on HDFS

There is no specific support for HDFS in FS crawler. But you can [mount your HDFS on your machine](https://wiki.apache.org/hadoop/MountableHDFS)
and run FS crawler on this mount point. You can also read details about
[HDFS NFS Gateway](http://hadoop.apache.org/docs/stable/hadoop-project-dist/hadoop-hdfs/HdfsNfsGateway.html).

## OCR integration

To deal with images containing text, just [install Tesseract](https://github.com/tesseract-ocr/tesseract/wiki). Tesseract will be auto-detected by Tika.
Then add an image (png, jpg, ...) into your Fscrawler [root directory](#root-directory). After the next index update, the text will be indexed and placed in "_source.content".

By default, FS crawler will try to extract also images from your PDF documents and run OCR on them.
This can be a CPU intensive operation. If you don't mean to run OCR on PDF but only on images, you can set `fs.pdf_ocr`
to `false`:

```json
{
  "name" : "test",
  "fs" : {
    "pdf_ocr" : false
  }
}
```

## Using docker

To use FS crawler with [docker](https://www.docker.com/), check
[docker-fscrawler](https://github.com/shadiakiki1986/docker-fscrawler) recipe.

# License

```
This software is licensed under the Apache 2 license, quoted below.

Copyright 2011-2017 David Pilato

Licensed under the Apache License, Version 2.0 (the "License"); you may not
use this file except in compliance with the License. You may obtain a copy of
the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
License for the specific language governing permissions and limitations under
the License.
```
