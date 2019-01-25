# 大容量磁盘
在 Linux 中，为磁盘分区通常使用 **fdisk**和 **parted**命令。

通常情况下，使用 fdisk 可以满足日常的使用，==但是它仅仅支持 2 TB 以下磁盘的分区，超出 2 TB 部分无法识别==。

而随着科技的进步，仅仅能识别 2 TB 的fdisk 很明显无法满足需求了，于是乎，**++parted++ & ++GPT++** 磁盘成为了绝佳的搭配。

这里主要讲解下使用 parted 为 MBR 以及 GPT 磁盘进行分区。

### GPT 磁盘分区
首先，你得有一块 GPT 分区的硬盘。小于 2 TB 的磁盘也可以转为 MBR 磁盘，++但是大于 2 TB 的磁盘则需要使用 GPT 分区++，否则大于 2 TB 的部分将被你封印。

挂载硬盘后，打开系统并以 root 身份登陆。使用parted 命令。

使用 ll /dev/ | grep sd 命令**查看当前已挂载的硬盘**，如下：

```
[root@localhost ~]# ll /dev/ | grep sd
lrwxrwxrwx 1 root root 4 Jan 21 03:55 root -> sda3
brw-rw---- 1 root disk 8, 0 Jan 21 04:21 sda
brw-rw---- 1 root disk 8, 1 Jan 21 03:55 sda1
brw-rw---- 1 root disk 8, 2 Jan 21 03:55 sda2
brw-rw---- 1 root disk 8, 3 Jan 21 03:55 sda3
brw-rw---- 1 root disk 8, 4 Jan 21 03:55 sda4
brw-rw---- 1 root disk 8, 5 Jan 21 03:55 sda5
brw-rw---- 1 root disk 8, 6 Jan 21 03:55 sda6
brw-rw---- 1 root disk 8, 7 Jan 21 03:55 sda7
brw-rw---- 1 root disk 8, 8 Jan 21 03:55 sda8
brw-rw---- 1 root disk 8, 9 Jan 21 03:55 sda9
brw-rw---- 1 root disk 8, 16 Jan 21 03:55 sdb
```

可以看出，当前系统挂载了两块硬盘，分别被标识为sda和sdb，其中sda包含了9个
分区，sdb没有分区。

>之前的Linux，会将IDE类型的磁盘命名为hda、hdb...将SATA和SCSI类型的磁盘命名
为sda、sdb...

>但是自从2.6.19内核开始，Linux统一将挂载的磁盘命名为sda、sdb...


使用 fdisk -l 命令查看这两块硬盘，如下:

```
[root@localhost ~]# fdisk -l
Disk /dev/sda: 21.5 GB, 21474836480 bytes
255 heads, 63 sectors/track, 2610 cylinders
Units = cylinders of 16065 * 512 = 8225280 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x000f1e9d

Device Boot Start End Blocks Id System
/dev/sda1 * 1 26 204800 83 Linux
Partition 1 does not end on cylinder boundary.
/dev/sda2 26 942 7357440 83 Linux
Partition 2 does not end on cylinder boundary.
/dev/sda3 942 1725 6291456 83 Linux
/dev/sda4 1725 2611 7116800 5 Extended
/dev/sda5 1726 1987 2097152 82 Linux swap / Solaris
/dev/sda6 1987 2248 2097152 83 Linux
/dev/sda7 2248 2379 1048576 83 Linux
/dev/sda8 2379 2509 1048576 83 Linux
/dev/sda9 2509 2611 819200 83 Linux

WARNING: GPT (GUID Partition Table) detected on '/dev/sdb'! The util fdisk 
doesn't support GPT. Use GNU Parted.

Disk /dev/sdb: 4398.0 GB, 4398046511104 bytes
256 heads, 63 sectors/track, 532610 cylinders
Units = cylinders of 16128 * 512 = 8257536 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disk identifier: 0x3c613c22

Device Boot Start End Blocks Id System
/dev/sdb1 1 266306 2147483647+ ee GPT
```
**WARNING部分描述，fdisk不支持GPT磁盘，请使用GNU Parted**

可以使用fdisk 磁盘名进入交互模式，之后输入字母i查看Id含义
- 82表示Linux Swap；
- 83表示Linux；
- ee表示GPT

之后，选用 Parted 为 GPT 磁盘分区。

### Parted 和 fdisk 一样拥有两种模式

- 命令行模式： parted [option] device [command]
- 交互模式： parted [option] device

以下为具体分区方式, (parted)后字符为输入字符


```
[root@localhost ~]# parted /dev/sdb
GNU Parted 2.1
Using /dev/sdb
Welcome to GNU Parted! Type 'help' to view a list of commands.
(parted) p #p=print，查看所有分区
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 4398GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt #磁盘类型，为GPT

Number Start End Size File system Name Flags #这里为空，表示没有分区

(parted) mkpart #只输入mkpart开始交互式分区
Partition name? []? primary
File system type? [ext2]? ext4
Start? 0
End? 1024G
Warning: The resulting partition is not properly aligned for best performance.
Ignore/Cancel? Ignore
```
#### 命令行方式：
```
(parted) mkpart primary 1024G 3072G //通过命令新建分区，mkpart PART-TYPE 
[FS-TYPE] START END，表示新建一个从1024G开始到3072G结束的大小为2TB的主分区


(parted) mkpart extended ext4 3072G 3500G //中间加入ext4，表示文件系统，
分区类型为扩展分区，然并卵，反正他也不会自动格式化

(parted) mkpart primary 3500G -1 //-1表示结束位置在磁盘末尾

```
```
(parted) p
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 4398GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt

Number Start End Size File system Name Flags
1 17.4kB 1024GB 1024GB primary
2 1024GB 3072GB 2048GB primary
3 3072GB 3500GB 428GB extended
4 3500GB 4398GB 898GB primary

#此时发现“文件系统”一栏为空，表示尚未格式化，之后将进行格式化


(parted) quit //退出parted工具
```
分区完成，开始格式化操作：
```
[root@localhost ~]# mkfs -t ext4 /dev/sdb1
mke2fs 1.41.12 (17-May-2010)
Filesystem label=
OS type: Linux
Block size=4096 (log=2)
Fragment size=4096 (log=2)
Stride=0 blocks, Stripe width=0 blocks
62504960 inodes, 249999995 blocks
12499999 blocks (5.00%) reserved for the super user
First data block=0
Maximum filesystem blocks=4294967296
7630 block groups
32768 blocks per group, 32768 fragments per group
8192 inodes per group
Superblock backups stored on blocks:
32768, 98304, 163840, 229376, 294912, 819200, 884736, 1605632, 2654208,
4096000, 7962624, 11239424, 20480000, 23887872, 71663616, 78675968,
102400000, 214990848

Writing inode tables: done
Creating journal (32768 blocks): done
Writing superblocks and filesystem accounting information: done

This filesystem will be automatically checked every 38 mounts or
180 days, whichever comes first. Use tune2fs -c or -i to override.
```

按同样语句执行下面的命令：

```
mkfs -t ext4 /dev/sdb2
mkfs -t ext4 /dev/sdb3
mkfs -t ext4 /dev/sdb4
```

之前不在 Parted 工具内执行 mkfs 是因为 Parted 无法将文件系统格式为 ext4 格式。

此时如果使用 fdisk -l 命令，是无法查看到 GPT 磁盘的分区的，而需要使用 parted -l。
```
[root@localhost ~]# parted -l
Model: VMware, VMware Virtual S (scsi)
Disk /dev/sdb: 4398GB
Sector size (logical/physical): 512B/512B
Partition Table: gpt

Number Start End Size File system Name Flags
1 17.4kB 1024GB 1024GB ext4 primary
2 1024GB 3072GB 2048GB ext4 primary
3 3072GB 3500GB 428GB ext4 extended
4 3500GB 4398GB 898GB ext4 primary
```
此时磁盘已经成功格式化了，但是没有为其指定挂载点。


### MBR 磁盘分区
MBR 磁盘分区方法和 GPT 磁盘可谓是一模一样，但是MBR 磁盘不能大于 2 TB，否则将会强制只使用 2 TB。

主要步骤和 GPT 磁盘分区一样，但是 MBR 磁盘分区有一点需要注意下：


```
(parted) p
Error: /dev/sdb: unrecognised disk label
```
若出现以上错误，表示MBR磁盘没有主引导记录，需要将磁盘转换为MBR，命令为：

```
(parted) mklabel msdos
```

msdos就是MBR磁盘，此时(parted) p将不会报错

### 挂载磁盘
格式化硬盘后，需要为每个分区设置挂载点，有两种方式：
- 一种是临时挂载，重启失效
- 另一种开机自动挂载

请分别为所有分区设置挂载点。


```
mkdir /build
```

挂载前先建立需要挂载的文件夹名，可以自行定义

- 临时挂载，重启失效

```
mount /dev/sdb1 /build
```


- 开机自动挂载
查看分区的UUID,将分区的UUID填充在XXXXX位置
```
blkid | grep /dev/sdb1
echo 'UUID=XXXXXXXXXXXX /build ext4 defaults 1 2' >> /etc/fstab

#或者

echo '/dev/sdb1 /build ext4 defaults 1 2' >> /etc/fstab

#此命令用于取消挂载
umount /dev/sdb1
```

>注意：有时候会遇到无法卸载的情况，遇到这种情况的原因是因为有其他用户或
进程正在访问该文件系统导致的。

>在Linux系统中，只有当该文件系统上所有访问的用户或进程完成操作并退出后，这个文件系统才能被正常卸载

使用命令“lsof 挂载点”查看哪些进程正在访问该文件系统，之后使用kill命令将
进程杀死来进行卸载

此时，挂载已经设置完成，重启后，可以通过 df 命令查看挂载状态。