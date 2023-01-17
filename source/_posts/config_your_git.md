---
title: 如何高效配置你的 Git
date: 2023-01-17
---

我一直以来不是很喜欢总结学到的东西，这就会导致很多事情再做之时有需要查资料，所以还是需要记录一下的。

这篇博客并不会介绍常见的 Git 配置，例如配置用户名密码、添加 Remote 和常见的操作等，这些内容网上非常多，尤其是 Git 本身的[文档](https://git-scm.com/)是完善的，因此这里会记录一些与我自己的日常工作相关的配置，可以有效提升我自己的研发效率。

## 多账号管理

在个人开发者，例如学生或 Freelancer 中，一般只有一个 GitHub 账号就够用了。但在企业内的研发同学中，其实一般来说除了对开源贡献的 GitHub 账号以外，还有对内使用的账号，例如 GitLab 或内部研发平台的账号，这就意味着需要至少维护两套账号，以保证可以在对应的平台上使用对应的账号。

### 刀耕火种

最初我的方式比较原始，由于有多个平台，这意味着无法使用一套全局配置来适配所有的项目，因此最简单的方式就在对于每个仓库，都单独在 .git/config 中配置对应的用户名密码或者 ssh key 等，但这样重复的工作太多，而且在对开源贡献时，可能随时都会 fork 新的项目，如果每个都要单独配置，是非常麻烦的一件事。

### 一种自动化

Git 其实有一个功能，是 IncludeIf 条件包含，在全局配置中，可以使用该方式，当项目处于不同的目录下时，使用不同的用户配置。具体的配置方式很简单，通过路径匹配，非常直观，这里就不赘述，给出官方的[文档链接](https://git-scm.com/docs/git-config#_includes)。

但这种方式依然意味着你需要人工维护项目所处的目录，将公司项目和开源项目放在不同的目录下，如果 clone 时放错了路径，依然是麻烦的。而且如果一个项目在内外部同时维护，这意味着你需要在同一个项目目录下同时与 GitHub 和 GitLab 交互，那么这样的方式就不太可行了。

### 另一种自动化

如上所述，虽然基于目录的自动化是一种解决方案，但还是有不便之处。就我个人而言，一种更加理想的方式是直接根据推送的平台自动选择对应的账号。但在 Git 里是不支持这样的配置方式的，这时可以使用 SSH 验证的方式，也就是对于不同的平台，均使用 SSH 登录验证的方式，并且在 SSH 的配置中对于对应的域名配置对应的私钥文件。此时在与 remote 交互时就会自动通过域名来判断要使用的 SSH 私钥，当然这种需要配置 remote 时使用 SSH 的 endpoint 接入。对于绝大多数情况，这种配置可以很好的解决不同平台的账号隔离问题，而且不用关心目录问题。

``` shell
# ~/.ssh/config
Host github.com
  Hostname github.com
  IdentityFile ~/.ssh/id_rsa_github
```

上述配置会在与 GitHub 交互时自动使用 `~/.ssh/id_rsa_github` 私钥文件，从而将其对应的公钥文件上传到 GitHub 即可完成用户绑定，GitLab 平台类似。

## 工作流优化

另外在长期的开源开发中，我们可以通过一些自定义的脚本来简化操作，从而降低流程成本，防止因为总要做一些重复性的操作而降低积极性，其中包含一些重要的 Tips。

### PR 协作

很多时候，尤其是在自己发起或者管理的开源项目上，经常需要在 PR 上与贡献者进行协作，无论是要做一些修改或者是要将对应的代码拉到本地测试或 Debug，都是非常常见的操作。

在 GitHub 提供 CLI 工具之前，需要将贡献者 fork 的仓库添加到本地的 remote，然后将对应的分支 checkout 到本地，做完以后一般还需要清理 remote，否则本地会残留很多 remote，看上去很不舒服。虽然这样也是可行的，但反复做的流程成本也很高。

而在 GitHub 提供了 CLI 工具之后，这件事容易了很多，安装 CLI 工具后可以直接 `gh pr checkout 119`，就可以把 #119 PR 对应的分支拉到本地，并且也是和上游挂钩的，修改后可以直接 push 回去，即可修改对应的 PR，也是非常方便。

因此 GitHub CLI 也是项目维护者非常好的一个工具。

### 本地 Git 流程

按照常见的 GitHub 协作流程，一般是 fork 项目到自己的账号下，clone 项目到本地，origin 配置为自己的仓库，upstream 配置为上游仓库。

之后本地新开分支开发，开发后先推送到 origin，然后从 origin 向 upstream 发起 PR，上游合并后拉回本地，然后再同步到 origin，从而完成完整的一次的贡献流程。

前面的贡献部分一般都没有问题，但在上游合并后的清理工作是比较繁琐的，具体流程涉及到：

- 本地切回 master 分支
- 拉取 upstream master 分支内容
- 将 upstream master 分支同步到本地和 origin 的 master 分支
- 删除对应的开发 branch，一般 origin 分支通过 PR 中直接删除，但本地需要手动删除

尤其是最后两步，经常会出现问题，我的解决方式是：拉取到 upstream master 分支后，直接 force push 到 origin master 分支完成同步，同时本地使用 reset --hard 来完成同步。之后 git fetch -p 来获取远端已经删除的分支，此时再通过脚本把远端删除的分支在本地自动删除，否则手动删除是非常麻烦的。

``` shell
git checkout master
git fetch upstream master
git push -f origin FETCH_HEAD:master # 将 FETCH_HEAD 也就是 upstream/master 强制同步到 origin/master
git reset --hard origin/master # 使用已经完成同步的 origin/master 来强制同步本地 master
git fetch origin -p | awk '{split($0,a," "); split(a[5],b,"/"); joined=sep=""; for(i=2;i in b;i++){joined=joined sep b[i]; sep="/"}; print joined;}' | xargs git branch -D # 删除本地对应的在 origin 远端已经删除的分支
```

之前的第三步，我本来使用的是 rebase and push，但这种情况在 master 分支仅用于同步上游时可行，但有时候我们必须用 master 分支来做一些实验，例如对 issue、PR 模板的修改，需要在 master 分支才会生效，此时可能出现与上游 master 分叉的情况，直接用强制同步的方式最为妥当。

在最后一步，使用了 awk 来处理 git fetch -p 时的输出，因为远端删除的分支在获取到时会输出类似 `- [deleted] (none) -> origin/branch-name` 的信息，所以直接用 awk 将最后的分支名提取出来，然后再用 git branch -D 将其对应的本地分支删除即可。通过这个脚本，可以将最为繁琐的每次在开发分支合并以后的删除工作给自动化了，还是非常方便的。

后续会继续更新自己觉得有用的 Git 配置，目的就是将所有的繁琐的机械性工作给自动化，让自己只需要关心项目的开发即可。
