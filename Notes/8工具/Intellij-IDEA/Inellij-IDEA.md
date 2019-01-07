IntelliJ IDEA 官网下载 - Ultimate 终极版：

https://www.jetbrains.com/idea/download/#section=windows

激活方法： 安装完成后 → 选择License → 输入：http://intellij.mandroid.cn

# IDEA vs eCLIPSE

 Eclipse|IDEA
---|---
Workspace|Project
Project|Module
Facet|Facet
Library|Library
JRE|SDK
ClassPath variable | Path variable

## 1.1 为什么要取消工作空间？
IDEA不需要设置工作空间，因为每一个Project都具备一个工作空间！对于每一个IDEA的项目工程（Project）而言，它的每一个子模块（Module）都可以**使用独立的JDK和MAVEN**。

> 这对于传统项目迈向新项目的重构添加了极大的便利性，这种多元化的灵活性正是Eclipse所缺失的，因为开始Eclipse在初次使用时已经绑死了工作空间。

## 1.2 为什么IDEA里面的子工程要称为Module ？

这是模块化的概念，作为聚合工程亦或普通的根目录，它称之为Project，而下面的子工程称为模块，每一个子模块之间可以相关联，也可以没有任何关联。

# 当前项目配置VS 默认配置
IDEA没有工作空间的概念，所以每个新项目（Project）都需要设置自己的JDK和MAVEN等相关配置，这样虽然提高了灵活性，但是却要为每个新项目都要重新配置，这显然不符合我们的预期。在这个背景下，默认配置给予当前项目配置提供了Default选项，问题自然就迎刃而解了。

## 初始化步骤

1. 打开默认配置：顶部导航栏 -> File -> Other Settings -> Settings for new Project/Structure for New Projects
2. 打开当前配置：顶部导航栏 -> File -> Settings/ProjectStructs


### 全局JDK（默认配置）
顶部工具栏 File ->Other Settings -> Structure for New Projects -> SDKs -> JDK
### 全局Maven（默认配置）
顶部工具栏 File ->Other Settings -> Settings for new Project -> Build & Tools -> Maven
### 版本控制Git/Svn（默认配置）
顶部工具栏 File ->Other Settings ->  Settings for new Project -> Version Control -> Git

> IDEA默认集成了对Git/Svn的支持 直接设置执行程序，右边Test提示成功即可。

- Git 客户端 推荐 [Sourcetree](https://www.sourcetreeapp.com/)

### 自动导包和智能移除 （默认配置）
顶部工具栏 File ->Other Settings ->  Settings for new Project -> Auto Import
- Add unambiguous imports on the fly：即时添加明确的导入
- Optimize imports on the fly (for current project) ：即时优化导入

### 自动编译
顶部工具栏 File ->Other Settings -> Settings for new Project -> Auto Import

> 开启自动编译之后，结合Ctrl+Shift+F9 会有热更新效果

### 打开Maven神器（强烈推荐！）
右侧直接点击 Maven Project 管理插件 ，记得先打开常用工具栏