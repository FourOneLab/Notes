命令| 描述
---|---
git add <filename> |添加修改后的文件
git commit -m "describe" |提交修改
git status |查看仓库当前状态
git diff  |查看文件的区别
git log [--pretty = oneline] |查看历史版本
git reset --hard <hash值> |回退到上一个版本
git reflog |记录每一次执行的命令
git checkout -- <filename> |把工作区的修改撤掉（让文件回到最近一次git add或git commit之前那一刻的状态）
git reset HEAD <filename> |把暂存区的修改撤销掉 （HEAD 表示最新版 HEAD^b表示上一版本，HEAD为一个指针）
git rm <filename> |删除文件
git push origin master |把本地内容推送到远程（第一次推送分支时，用-u参数）
git clone |克隆一个远程仓库到本地（Git支持多种协议）
git branch | 查看当前仓库中的所有分支（当前分支用*标记出）
git branch <branchname> |创建分支
git checkout <branchname> |切换到分支
git merge <branchname> |合并指定分支到当前分支
git log --graph |查看分支合并图
git stash |保存当前工作现场（暂存区）
git stash list |显示保存的所有工作现场
git stash pop |恢复之前保存的工作现场并把保存在stash列表中的内容删除
git stash apply |恢复之前保存的工作现场保留保存在stash列表中的内容
git stash drop| 把保存在stash列表中的内容删除
git remote |查看远程仓库信息
git push origin <分支名称> |把该分支上的所有本地文件推送到远程仓库
git clone| 克隆一个远程仓库到本地
git pull |从远程拉取最新的分支
git tag <name><commit ID> |打一个新标签或者查看所有标签
git show <tagname> |查看tag的说明文字
git push origin <tagname> |推送某个标签到远程
git push origin ：refs/tags/<tagname> |删除远程的某个标签


## 分支管理的基本策略：
- master分支仅用于发布新版本，不在上面干活


- 干活的时候都单独创建一个分支dev，开发完成将分支合并到master上发布


- 团队的每个人在dev上创建分支进行开发，开发完成后合并到dev上