Git分布式版本控制系统

# 1. 安装Git

## Linux
```
sudo apt-get install git    //Debain or Ubunt
sudo yum install git        //Redhat or Centos
```
老版本可能叫 git-core。

## Mac OS X
1. 安装homebrew，然后通过homebrew安装Git，具体方法请参考homebrew的文档：http://brew.sh/。

2. 直接从AppStore安装Xcode，Xcode集成了Git，不过默认没有安装，你需要运行Xcode，选择菜单“**Xcode**”->“**Preferences**”，在弹出窗口中找到“**Downloads**”，选择“**Command** **Line** **Tools**”，点“**Install**”就可以完成安装了。


## Windows
在Windows上使用Git，可以从[Git官网](https://git-scm.com/downloads)直接下载安装程序，然后按默认选项安装即可。

安装完成后，在开始菜单里找到“**Git**”->“**Git** **Bash**”，蹦出一个类似命令行窗口的东西，就说明Git安装成功！

安装完成后，还需要最后一步设置，在命令行输入：

```
$ git config --global user.name "Your Name"
$ git config --global user.email "email@example.com"
```

# 2.创建或导入仓库
初始化一个Git仓库:

```
git init
```

从github 克隆仓库到本地：

```
git clone  <github上的仓库地址>     //通过ssh或者https协议进行clone
```

添加文件或者提交文件修改到Git仓库，分两步：

```
git add <file>      //注意，可反复多次使用，添加多个文件

git add .           //将当前仓库的所有文件提交到git本地仓库中
git commit -m <message>
```

## 注意
所有的版本控制系统，只能跟踪文本文件的改动，比如**TXT文件**，**网页**，所有的**程序代码**等。版本控制系统可以告诉你每次的改动，比如在第5行加了一个单词“Linux”，在第8行删了一个单词“Windows”。

而**图片**、**视频**这些二进制文件，虽然也能由版本控制系统管理，++但没法跟踪文件的变化++，只能把二进制文件每次改动串起来，也就是只知道图片从100KB改成了120KB，但到底改了啥，版本控制系统不知道，也没法知道。

> Microsoft的Word格式是二进制格式，版本控制系统是没法跟踪Word文件的改动的，如果要真正使用版本控制系统，就要以纯文本方式编写文件。

因为文本是有编码的，强烈建议使用标准的UTF-8编码，所有语言使用同一种编码，既没有冲突，又被所有平台所支持。

# 3.版本控制
查看仓库当前状态：

```
git status
```

查看具体文件的修改内容：

```
git diff <file>     //显示的格式是Unix通用的diff格式
```

查看历史修改版本：

```
git log   --pretty=oneline   //显示从最近到最远的提交日志,查看的是提交历史
```
git log 返回的一大串字符串是commit id（版本号），每提交一个新版本，实际上Git就会把它们自动串成一条时间线。如果使用可视化工具查看Git历史，就可以更清楚地看到提交历史的时间线。

## 切换到历史版本
首先，Git必须知道当前版本是哪个版本，在Git中：
- 用 **HEAD** 表示当前版本
- 上一个版本就是 **HEAD^**
- 上上一个版本就是** HEAD^^**
- 当然往上100个版本写100个^比较容易数不过来，所以写成**HEAD~100**

输入如下执行，回退到上一个版本：

```
git reset --hard HEAD^      //会退到当前版本之前的一个版本
```
或者
```
git reset --hard <commit id>    //回退到指定的版本
```

可以理解为，Git的Head指针会指向当前的版本，回退的过程是在修改指针的位置，然后顺便把工作区的文件更新。

当回退之后，通过git log无法查看到最新的版本号，可以使用如下命令：

```
git reflog      //记录每一次命令，查看的是命令历史
```

# 4.工作区和暂存区
Git和其他版本控制系统如SVN的一个不同之处就是有暂存区的概念。

### 工作区（Working Directory）
在电脑中能看到的 **git init**或者 **git clone** 的那个目录就是工作区。

### 版本库（Repository）
工作区有一个隐藏目录**.git**，这个不算工作区，而是Git的版本库。

Git的版本库里存了很多东西，其中最重要的就是称为**stage**（或者叫**index**）的**暂存区**，还有Git为我们自动创建的第一个分支**master**，以及指向master的一个指针叫**HEAD**。

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384907702917346729e9afbf4127b6dfbae9207af016000/0)

我们在向Git仓库中添加文件的时候：
1. 用**git add**把文件添加进去，实际上就是把文件修改添加到**暂存区**；
2. 用**git commit**提交更改，实际上就是把暂存区的所有内容提交到**当前分支**。

> 创建Git仓库时，Git自动创建唯一一个master分支，所以，git commit就是往master分支上提交更改。

# 5.管理修改
为什么Git比其他版本控制系统设计得优秀，因为Git跟踪并管理的是**修改**，**而非文件**。

Git管理的是修改，当你用git add命令后，在工作区的第一次修改被放入暂存区，准备提交，但是，在工作区的第二次修改并没有放入暂存区，所以，git commit只负责把暂存区的修改提交了，也就是第一次的修改被提交了，第二次的修改不会被提交。

每次修改，如果不用git add到暂存区，那就不会加入到commit中。

## 丢弃工作区修改
撤销工作区修改的命令，如果没有 -- 表示切换分支：
```
git checkout -- file        //让这个文件回到最近一次git commit或git add时的状态
```
这里有两种情况：
1. file自修改后还没有被放到暂存区，现在，撤销修改就回到和版本库一模一样的状态；
2. file已经添加到暂存区后，又作了修改，现在，撤销修改就回到添加到暂存区后的状态。

另一个命令：
```
git reset HEAD file         //把暂存区的修改撤销
```
git reset命令既可以回退版本，也可以把暂存区的修改回退到工作区。当我们用HEAD时，表示最新的版本。

## 删除文件
在Git中，删除也是一个修改操作。

1. 一般情况下，你通常直接在文件管理器中把没用的文件删了，或者用rm命令删了
2. 这个时候，Git知道删除了文件，因此，工作区和版本库就不一致了，git status命令会立刻告诉你哪些文件被删除了
3. 现在你有两个选择，一是确实要从版本库中删除该文件，那就用命令git rm删掉，并且git commit：

```
git rm file
git commit -m "delete  file"
```
4. 另一种情况是删错了，因为版本库里还有呢，所以可以很轻松地把误删的文件恢复到最新版本：

```
git checkout -- file
```
git checkout其实是用版本库里的版本替换工作区的版本，无论工作区是修改还是删除，都可以“一键还原”。

**命令git rm用于删除一个文件。如果一个文件已经被提交到版本库，那么你永远不用担心误删，但是要小心，你只能恢复文件到最新版本，你会丢失最近一次提交后你修改的内容。**

# 6.远程仓库
Git是分布式版本控制系统，同一个Git仓库，可以分布到不同的机器上。最早，肯定只有一台机器有一个原始版本库，此后，别的机器可以“*克隆*”这个原始版本库，而且每台机器的版本库其实都是一样的，并没有主次之分。

## Github
### 第一步：创建SSH Key
在用户主目录下，看看有没有.ssh目录，如果有，再看看这个目录下有没有id_rsa和id_rsa.pub这两个文件，如果已经有了，可直接跳到下一步。如果没有，打开Shell（Windows下打开Git Bash），创建SSH Key：

```
 ssh-keygen -t rsa -C "youremail@example.com"
```
在用户主目录里找到.ssh目录，里面有id_rsa和id_rsa.pub两个文件，这两个就是SSH Key的秘钥对，id_rsa是私钥，不能泄露出去，id_rsa.pub是公钥，可以放心地告诉任何人。

### 第二步：登陆GitHub
1. 打开“Account settings”，“SSH Keys”页面
2. 点“Add SSH Key”，填上任意Title，在Key文本框里粘贴id_rsa.pub文件的内容
3. 点“Add Key”，就应该看到已经添加的Key

为什么GitHub需要SSH Key呢？因为GitHub需要识别出你推送的提交确实是你推送的，而不是别人冒充的，而Git支持SSH协议，所以，GitHub只要知道了你的公钥，就可以确认只有你自己才能推送。

当然，GitHub允许你添加多个Key。假定你有若干电脑，你一会儿在公司提交，一会儿在家里提交，只要把每台电脑的Key都添加到GitHub，就可以在每台电脑上往GitHub推送了。

### 第三步：添加远程仓库
在本地创建了一个Git仓库后，想在GitHub创建一个Git仓库，并且让这两个仓库进行远程同步，这样，GitHub上的仓库既可以作为备份，又可以让其他人通过该仓库来协作。

1. 登陆GitHub，
2. 在右上角找到“Create a new repo”按钮，创建一个新的仓库
3. 在Repository name填入仓库的名字(如 my_repo)，其他保持默认设置，点击“Create repository”按钮，就成功地创建了一个新的Git仓库
> 在GitHub上的这个my_repo仓库还是空的，GitHub告诉我们，可以从这个仓库克隆出新的仓库，也可以把一个已有的本地仓库与之关联，然后，把本地仓库的内容推送到GitHub仓库。

4. 根据GitHub的提示，在本地的my_repo仓库下运行命令：

```
git remote add origin git@github.com:<your Github name>/my_repo.git     //根据github页面给的提示输入命令即可
```
添加后，远程库的名字就是origin（这是Git默认的叫法，也可以改成别的)，但是origin这个名字一看就知道是远程库。

5. 最后，就可以把本地库的所有内容推送到远程库上：

```
git push -u origin master
```
把本地库的内容推送到远程，用git push命令，实际上是把当前分支master推送到远程。

由于远程库是空的，第一次推送master分支时，加上了-u参数，Git不但会把本地的master分支内容推送到远程新的master分支，还会把本地的master分支和远程的master分支关联起来，在以后的推送或者拉取时就可以简化命令。

6. 推送成功后，可以立刻在GitHub页面中看到远程库的内容已经和本地一模一样。

从现在起，只要本地作了提交，就可以通过命令：

```
git push origin master
```
把本地master分支的最新修改推送至GitHub，现在，你就拥有了真正的分布式版本库！

### 第四步：从远程库克隆
假设我们从零开发，那么最好的方式是先创建远程库，然后，从远程库克隆。

1. 登陆GitHub，创建一个新的仓库，名字叫zero
2. 勾选Initialize this repository with a README，这样GitHub会自动为我们创建一个README.md文件。创建完毕后，可以看到README.md文件
3. 远程库已经准备好了，下一步是用命令git clone克隆一个本地库：

```
git clone git@github.com:<your github name>/zero.git        //在页面的右上角可以直接复制该链接
```
4. 进入本地的目录就可以看到初始化创建的README.md文件


++如果有多个人协作开发，那么每个人各自从远程克隆一份就可以了。++

GitHub给出的地址不止一个，还可以用 https://github.com/yourgithubname/zero.git 这样的地址。

实际上，Git支持多种协议，**默认的git://使用ssh**，但也可以使用https等其他协议。

使用https除了速度慢以外，还有个最大的麻烦是每次推送都必须输入口令，但是在某些只开放http端口的公司内部就无法使用ssh协议而只能用https。


# 7.分支管理
创建一个属于你自己的分支，别人看不到，还继续在原来的分支上正常工作，而你在自己的分支上干活，想提交就提交，直到开发完毕后，再一次性合并到原来的分支上，这样，既安全，又不影响别人工作。

## 创建与合并分支

### 原理
每次提交，Git都把它们串成一条时间线，这条时间线就是一个分支。截止到目前，只有一条时间线，在Git里，这个分支叫主分支，即**master**分支。**HEAD**严格来说不是指向提交，而是指向master，master才是指向提交的，所以，**HEAD指向的就是当前分支**。

一开始的时候，master分支是一条线，Git用master指向最新的提交，再用HEAD指向master，就能确定当前分支，以及当前分支的提交点：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/0013849087937492135fbf4bbd24dfcbc18349a8a59d36d000/0)

每次提交，master分支都会向前移动一步，这样，随着你不断提交，master分支的线也越来越长。

当我们创建新的分支，例如**dev**时，Git新建了一个指针叫**dev**，指向master相同的提交，再把**HEAD**指向dev，就表示当前分支在dev上：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384908811773187a597e2d844eefb11f5cf5d56135ca000/0)

> Git创建一个分支很快，因为除了增加一个dev指针，改改HEAD的指向，工作区的文件都没有任何变化！

不过，从现在开始，对工作区的修改和提交就是针对dev分支了，比如新提交一次后，dev指针往前移动一步，而master指针不变：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/0013849088235627813efe7649b4f008900e5365bb72323000/0)

假如我们在dev上的工作完成了，就可以把dev合并到master上。Git怎么合并呢？最简单的方法，就是直接把master指向dev的当前提交，就完成了合并：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/00138490883510324231a837e5d4aee844d3e4692ba50f5000/0)

所以Git合并分支也很快！就改改指针，工作区内容也不变！合并完分支后，甚至可以删除dev分支。删除dev分支就是把dev指针给删掉，删掉后，我们就剩下了一条master分支：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384908867187c83ca970bf0f46efa19badad99c40235000/0)

### 命令
创建分支的命令：

```
git checkout -b dev     //参数表示创建并切换，相当于以下两条命令：

git branch dev          //创建分支
git checkout dev        //切换分支
```
查看分支的命令：

```
git branch      //会列出所有分支，当前分支前面会标一个*号。
```

合并分支的命令：

```
git checkout master         //切换到master分支
git merge dev               //合并指定分支到当前分支，即将dev分支合并到master分支
git branch -d dev           //合并完成后，可以删除dev分支
```
此时的合并是快进模式Fast-forward，也就是直接把master指向dev的当前提交，所以合并速度非常快。

## 解决冲突
当同时在新的分支如feature1和master上进行修改时，情况如下：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384909115478645b93e2b5ae4dc78da049a0d1704a41000/0)

这种情况下，Git无法执行“快速合并”，只能试图把各自的修改合并起来，但这种合并就可能会有冲突。Git告诉我们，存在冲突的文件，并且必须手动解决冲突后再提交。git status也可以告诉我们冲突的文件。

Git用<<<<<<<，=======，>>>>>>>标记出不同分支的内容，如下例子：

```
Git is a distributed version control system.
Git is free software distributed under the GPL.
Git has a mutable index called stage.
Git tracks changes of files.
<<<<<<< HEAD
Creating a new branch is quick & simple.
=======
Creating a new branch is quick AND simple.
>>>>>>> feature1
```
手动解决冲突（打开文件后修改为我们需要的结果）后再次提交，现在，master分支和feature1分支变成了下图所示：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/00138490913052149c4b2cd9702422aa387ac024943921b000/0)

用带参数的git log --graph 命令可以看到分支的合并图：

```
 git log --graph --pretty=oneline --abbrev-commit
*   cf810e4 (HEAD -> master) conflict fixed
|\  
| * 14096d0 (feature1) AND simple
* | 5dc6824 & simple
|/  
* b17d20e branch test
* d46f35e (origin/master) remove test.txt
* b84166e add test.txt
* 519219b git tracks changes
* e43a48b understand how stage works
* 1094adb append GPL
* e475afc add distributed
* eaadf4e wrote a readme file
```
最后，删除feature1分支。

## 分支管理策略
通常，合并分支时，如果可能，Git会用**Fast forward**模式，++但这种模式下，删除分支后，会丢掉分支信息++。

**如果要强制++禁用++Fast forward模式，Git就会在merge时生成一个新的commit，这样，从分支历史上就可以看出分支信息。**

### 举个例子
禁用 Fast forward 需要带上 --no-ff参数方式的git merge。

1. 首先，仍然创建并切换dev分支：
```
git checkout -b dev
```
2. 修改README文件，并提交
```
git add readme.txt 
git commit -m "add merge"
```
3. 切回主分支

```
git checkout master
```
4. 准备合并dev分支，请注意--no-ff参数，表示禁用Fast forward

```
git merge --no-ff -m "merge with no-ff" dev     //因为本次合并要创建一个新的commit，所以加上-m参数，把commit描述写进去。
```
5. 合并后，我们用git log看看分支历史

```
 git log --graph --pretty=oneline --abbrev-commit
*   e1e9c68 (HEAD -> master) merge with no-ff
|\  
| * f52c633 (dev) add merge
|/  
*   cf810e4 conflict fixed
```

可以看到，不使用Fast forward模式，merge后就像这样：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384909222841acf964ec9e6a4629a35a7a30588281bb000/0)

### 分支策略
在实际开发中，我们应该按照几个基本原则进行分支管理：
1. master分支应该是非常稳定的，也就是仅用来发布新版本，平时不能在上面干活；
2. 干活都在dev分支上，即dev分支是不稳定的，到某个时候，比如1.0版本发布时，再把dev分支合并到master上，在master分支发布1.0版本；
3. 每个人都在dev分支上干活，每个人都有自己的分支，时不时地往dev分支上合并就可以了。

所以，团队合作的分支看起来就像这样：

![image](https://cdn.liaoxuefeng.com/cdn/files/attachments/001384909239390d355eb07d9d64305b6322aaf4edac1e3000/0)

### 修复bug的操作
在Git中，每个bug都可以通过一个新的临时分支来修复，修复后，合并分支，然后将临时分支删除。

#### 举个例子
当你接到一个修复一个代号101的bug的任务时，创建一个分支issue-101来修复它，但是，等等，当前正在dev上进行的工作还没有提交：

```
git status
On branch dev
Changes to be committed:
  (use "git reset HEAD <file>..." to unstage)

    new file:   hello.py

Changes not staged for commit:
  (use "git add <file>..." to update what will be committed)
  (use "git checkout -- <file>..." to discard changes in working directory)

    modified:   readme.txt
```
并不是你不想提交，而是工作只进行到一半，还没法提交，预计完成还需1天时间。但是，必须在两个小时内修复该bug，怎么办？

幸好，Git还提供了一个**stash功能**，可以++把当前工作现场“储藏”起来++，等以后恢复现场后继续工作：

```
git stash
```
现在，用git status查看工作区，就是干净的（除非有没有被Git管理的文件），因此可以放心地创建分支来修复bug。

首先确定要在哪个分支上修复bug，假定需要在master分支上修复，就从master创建临时分支：

```
git checkout master
git checkout -b issue-101
```
现在修复bug，然后提交：

```
git add readme.txt 
git commit -m "fix bug 101"
```
修复完成后，切换到master分支，并完成合并，最后删除issue-101分支：

```
git checkout master
git merge --no-ff -m "merged bug fix 101" issue-101
```
bug修复完成，回到dev继续开发：

```
git checkout dev
git status          //查看当前工作区
git stash list      //查看临时存储的工作区的列表
git stash apply     //恢复临时存储起来的工作区，恢复后临时存储还在
git stash drop      //删除临时存储起来的工作区
git stash pop       //恢复并删除临时存储起来的工作区
```

你可以多次stash，恢复的时候，先用git stash list查看，然后恢复指定的stash，用命令：

```
git stash apply stash@{0}
```
### 新需求开发
每添加一个新功能，最好新建一个feature分支，在上面开发，完成后，合并，最后，删除该feature分支。现在，你终于接到了一个新任务：开发代号为Vulcan的新功能，该功能计划用于下一代星际飞船。

```
git checkout -b feature-vulcan      //新建feature分支
git add vulcan.py                   //开发完成提交，但是还没合并
git status                          //查看当前状态
git checkout dev                    //切换主分支
git branch -d feature-vulcan        //功能被砍，删除分支，-D强制删除（此时未合并，删除后丢失）
```
### 多人协作
**从远程仓库克隆时，实际上Git自动把本地的master分支和远程的master分支对应起来了，并且，远程仓库的默认名称是origin。**

查看远程库的信息：
```
git remote      //-v参数，显示更详细信息，包括可以抓取和推送的origin的地址，如果没有推送权限，就看不到push的地址。
```
#### 推送分支
推送分支，就是把该分支上的所有本地提交推送到远程库。推送时，要指定本地分支，这样，Git就会把该分支推送到远程库对应的远程分支上：


```
git push origin master      //推送到master分支
git push origin dev         //推送到dev分支
```
**哪些分支需要推送，哪些不需要呢？**
- master分支是主分支，因此要时刻与远程同步；
- dev分支是开发分支，团队所有成员都需要在上面工作，所以也需要与远程同步；
- bug分支只用于在本地修复bug，就没必要推到远程了，除非老板要看看你每周到底修复了几个bug；
- feature分支是否推到远程，取决于你是否和你的小伙伴合作在上面开发。

++**总之，就是在Git中，分支完全可以在本地自己藏着玩，是否推送，视你的心情而定！**++

#### 抓取分支
多人协作时，大家都会往master和dev分支上推送各自的修改。
```
git clone git@github.com:<github name>/repo name.git       //从远程库clone时，默认情况下，只能看到本地的master分支。

git branch      //查看本地分支情况
```
要在dev分支上开发，就必须创建远程origin的dev分支到本地，用命令创建本地dev分支：
```
git checkout -b dev origin/dev      //可以在dev上继续修改
git add env.txt                     
git commit -m "add env"
git push origin dev                 //时不时地把dev分支push到远程
```
小伙伴已经向origin/dev分支推送了他的提交，而碰巧你也对同样的文件作了修改，并试图推送：


```
git add env.txt
git commit -m "add new env"
git push origin dev     //推送失败

To github.com:michaelliao/learngit.git
 ! [rejected]        dev -> dev (non-fast-forward)
error: failed to push some refs to 'git@github.com:michaelliao/learngit.git'
hint: Updates were rejected because the tip of your current branch is behind
hint: its remote counterpart. Integrate the remote changes (e.g.
hint: 'git pull ...') before pushing again.
hint: See the 'Note about fast-forwards' in 'git push --help' for details.
```

推送失败，因为你的小伙伴的最新提交和你试图推送的提交有冲突，解决办法也很简单，Git已经提示我们，先用git pull把最新的提交从origin/dev抓下来，然后，在本地合并，解决冲突，再推送：


```
git pull
There is no tracking information for the current branch.
Please specify which branch you want to merge with.
See git-pull(1) for details.

    git pull <remote> <branch>

If you wish to set tracking information for this branch you can do so with:

    git branch --set-upstream-to=origin/<branch> dev
```

git pull也失败了，原因是没有指定本地dev分支与远程origin/dev分支的链接，根据提示，设置dev和origin/dev的链接：


```
branch --set-upstream-to=origin/dev dev
Branch 'dev' set up to track remote branch 'dev' from 'origin'.

git pull
Auto-merging env.txt
CONFLICT (add/add): Merge conflict in env.txt
Automatic merge failed; fix conflicts and then commit the result.
```

这回git pull成功，但是合并有冲突，需要手动解决，解决的方法和分支管理中的解决冲突完全一样。解决后，提交，再push：


```
git commit -m "fix env conflict"
git push origin dev
```

**多人协作的工作模式通常是这样：**

1. 试图用git push origin <branch-name>推送自己的修改；
2. 如果推送失败，则因为远程分支比你的本地更新，需要先用git pull试图合并；
3. 如果合并有冲突，则解决冲突，并在本地提交；
4. 没有冲突或者解决掉冲突后，再用git push origin <branch-name>推送就能成功！
5. 如果git pull提示no tracking information，则说明本地分支和远程分支的链接关系没有创建，用如下命令：
```
git branch --set-upstream-to <branch-name> origin/<branch-name>
```

这就是多人协作的工作模式，一旦熟悉了，就非常简单。

# 标签管理
发布一个版本时，我们通常先在版本库中打一个标签（tag），这样，就唯一确定了打标签时刻的版本。将来无论什么时候，取某个标签的版本，就是把那个打标签的时刻的历史版本取出来。所以，**标签也是版本库的一个快照**。

Git的标签虽然是版本库的快照，但其实它就是指向某个commit的指针，所以，创建和删除标签都是瞬间完成的。

tag就是一个让人容易记住的有意义的名字，它跟某个commit绑在一起。

## 创建标签
在Git中打标签非常简单，首先，切换到需要打标签的分支上：


```
git branch                  //查看所有分支
git checkout master         //切换分支
git tag v1.0                //打标签
git tag                     //查看所有标签
```
默认标签是打在最新提交的commit上的。

给历史版本打标签，方找到历史提交的commit id，然后打上就可以了：
```
git log --pretty=oneline --abbrev-commit        //查看提交历史
12a631b (HEAD -> master, tag: v1.0, origin/master) merged bug fix 101
4c805e2 fix bug 101
e1e9c68 merge with no-ff
f52c633 add merge
cf810e4 conflict fixed
5dc6824 & simple
14096d0 AND simple
b17d20e branch test
d46f35e remove test.txt
b84166e add test.txt
519219b git tracks changes
e43a48b understand how stage works
1094adb append GPL
e475afc add distributed
eaadf4e wrote a readme file

git tag v0.9 f52c633            //对add merge这次提交打标签
git tag                         //查看所有标签，注意，标签不是按时间顺序列出，而是按字母排序的
git show v0.9                   //查看标签信息
git tag -a v0.1 -m "version 0.1 released" 1094adb       //-a 指定标签名 -m 指定说明文字
```

**注意：标签总是和某个commit挂钩。如果这个commit既出现在master分支，又出现在dev分支，那么在这两个分支上都可以看到这个标签。**

## 操作标签

```
git tag -d v0.1             //删除标签，创建的标签不会自动推送到远程，打错的标签可以在本地安全删除。
git push origin v1.0        //推送某个标签到远程
git push origin --tags      //一次性推送全部尚未推送到远程的本地标签
```
如果标签已经推送到远程，要删除远程标签需要先从本地删除：
```
git tag -d v0.9         //删除本地标签
git push origin :refs/tags/v0.9     //删除远程标签
```
登陆GitHub查看远程库中的标签情况。

# 使用Github
1. 点“Fork”就在自己的账号下克隆了一个开源项目的仓库
2. 从自己的账号下clone：

```
git clone git@github.com:promacanthus/repo-name.git
```
**一定要从自己的账号下clone仓库，这样你才能推送修改。如果从开源项目的作者的仓库地址克隆，因为没有权限，你将不能推送修改。**

3. 如果你希望开源项目的的官方库能接受你的修改，你就可以在GitHub上发起一个pull request。