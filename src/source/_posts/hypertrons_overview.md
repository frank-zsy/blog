---
title: Hypertrons 介绍
date: 2020-08-26
tags: ['Hypertrons']
---

[Hypertrons](https://github.com/hypertrons/hypertrons) 是本人在 2019.11 发起的一个面向开源项目的 RPA 开发平台，该项目的目的是提供开源代码平台上的流程自动化定制和运行能力。

# Hypertrons 演进历史

事实上 Hypertrons 的开发经历了多次的演进。

最初，在阿里巴巴开源办公室工作时，开始深入调研开源相关的内容，发现了 [k8s-ci-robot](https://github.com/k8s-ci-robot) 这个神奇的存在，并开始入坑深入了解 GitHub 集成开发的相关工作。正值当时的 [Pouch container](https://github.com/alibaba/pouch) 项目负责人孙宏亮也自己开发了一款 Go 语言编写的用于协助进行自动化协作的 GitHub 机器人项目 [pouchrobot](https://github.com/pouchcontainer/pouchrobot)，本人当时也参与了部分 pouchrobot 的开发工作。

但由于 k8s-ci-robot 与 pouchrobot 均直接使用 [GitHub access token](https://docs.github.com/en/github/authenticating-to-github/creating-a-personal-access-token) 配置而扮演具体 GitHub 账号的方式进行协作，鉴于当时 GitHub 的[角色体系](https://docs.github.com/en/github/setting-up-and-managing-your-github-user-account/managing-access-to-your-personal-repositories)尚不完善，导致机器人即使要进行简单的协作，例如 issue label 的管理等都需要进行仓库写权限的授权，这个要求违反了 Apache 基金会对于必须由自然人才能拥有代码仓库写入权限的[要求](http://apache.org/foundation/how-it-works.html#committers)，故本人开始探索另外的实现方式。

在开发开源相关工具的同时，本人在阿里也开始了对 GitHub 全域数据进行分析的工作，这个工作也曾在 Open Source Summit 2019 上对外展示，当时的分享主题为[「Alibaba Digital Driven Open Source Community Exploration」](https://www.youtube.com/watch?v=64RiOyQf_kU)，即「阿里巴巴数字化驱动开源社区的探索」。在大数据的探索中，发现了国际上在大量使用 [GitHub App](https://github.com/marketplace) 作为协作机器人的开发方式。

于是诞生了第一版由本人独立开发的阿里巴巴通用 GitHub 协作机器人 [Collabobot](https://github.com/alibaba/collabobot)，该项目使用 TypeScript 编写，基于目前世界上最活跃的 GitHub App 开发框架 [Probot](https://github.com/probot/probot) 进行二次开发，支持一个机器人实例服务一个机器人后端。但由于 Probot 是一个较为简单的开发框架，不支持项目级自定义流程配置，架构层面也不支持插件式开发，故该项目虽然支持了插件式开发，却使用了一些非常规的手法。而本人也向 Probot 官方社区[提问](https://github.com/probot/probot/issues/909)，询问是否支持插件式开发即其他三方平台的对接，得到了[否定的答案](https://github.com/probot/probot/issues/909#issuecomment-489711216)，其官方社区认为如果开发的是一个复杂的自动化流程系统，应基于 GitHub 官方组件库自行开发框架。

在离开阿里巴巴进入同济大学读博后，本人再次重新审视流程自动化的需求，并设计了 Hypertrons 这个项目，使用 [Egg.js](https://github.com/eggjs/egg) 作为底层 Web 框架，提供高可用的 Web 服务能力，上层则兼容了各种开放平台，GitHub 仅为其中之一。在这种设计模式下，实现了：

- 一个服务实例可以扮演多个机器人后端，即 Hypertrons 并非一个机器人实例，而是一个机器人的运行时环境。
- 支持的多个机器人可以是异构的，即可以是 GitHub App、GitLab 账号、Gitee 账号等，且通过接口设计屏蔽了平台差异，使机器人可以在多平台上无缝迁移。
- 作为机器人运行平台，项目自身的配置由项目本身定制，而不与部署环境耦合，做到每个项目的流程自定义。
- 通过支持在 Node.js 环境中直接执行 Lua 代码的能力，使项目不仅可以自定义配置，同时可以通过编写定制的 Lua 脚本来自定义项目流程。

目前 Hypertrons 已在 [X-lab](http://www.x-lab.info/) 实验室内部广泛使用，统一管理 X-lab GitHub 与 GitLab 平台上的项目协作流程。

# Hypertrons 架构

目前整体 Hypertrons 的架构设计如下图所示：

![arch](https://frank-cdn.opensource-service.com/image/hypertrons_arch.png)

## 接口层

首先，Hypertrons 作为一个 [RPA](https://baike.baidu.com/item/rpa/50175182) 开发平台，其主要是做与开源项目相关的跨平台自动化能力，故底层对接的是各种开源生产相关的开放平台（Open platform），首先需要注意的是这里强调的是开放平台，即第一不要求对接的平台或工具是开源的，但第二需要这些平台无论是否开源都必须有开放的接口可被集成。

这里的开放平台包括例如 GitHub、GitLab、Gitee 等，这些目前较主流的开源协作平台，事实上这些平台都包含了三种功能特性，即版本控制管理系统托管（git）、协作流程管理（issue、PR/MR）、项目管理等，而例如 [TAPD](https://www.tapd.cn/) 等开放平台则仅包含了项目管理的能力。另外，在开源项目中，自动化测试或 CI/CD 有重要的地位，故需要对接例如 Jenkins 或 Travis 等 CI 服务。其他还包含如邮件服务（Gmail、AliMail...）、IM 服务（Slack、Mattermost）、线上会议服务（Zoom，Tencent meeting）、在线文档服务（Google docs，shimo）等。

另外，在接口层面，还需要一套特定的 IAM 与配置管理系统。其中 IAM 接口主要是对接 IAM 系统，用于进行统一的项目内跨平台的角色身份管理，而配置管理则定义了整个机器人的运行时配置是如何生成。

## 核心层

在接口定义的上层应用的核心层，这一部分使用了由 TypeScript 和 Egg.js 支撑的一个 Web 应用框架。其中 TypeScript 主要是通过强类型以及装饰器等特性提升项目的开发效率和质量。这一层并不包含按具体的业务逻辑，而是再向上层提供例如定时任务调度机制、事件管理机制、数据自动更新、配置自动更新等一系列框架层的支持。

## 流程引擎层

在核心层之上，通过封装 [Fengari](https://github.com/fengari-lua/fengari) 提供了一个 Lua 的 Node.js 运行时环境，并自己开发了一个 Lua Interop 层用于做核心层功能与 Lua 层功能的互操作。这一层选用 Lua 作为 DSL 的原因有如下几点：

- Hypertrons 是使用 Node.js + TypeScript 编写，但同时希望提供任意仓库的的流程定制能力。
- 直接使用 JavaScript 编写是较为简单和直观的，也可以做到直接在框架中运行定制逻辑。
- 但使用 JavaScript 的问题是很难做到有效的隔离，很容易在框架中出现[沙箱逃逸问题](https://www.baidu.com/s?wd=js%20%E6%B2%99%E7%AE%B1%E9%80%83%E9%80%B8)。如果提供公有服务，则客户定制代码需要在有足够能力的情况下做到一定的安全保障。
- 使用 Lua VM 可以有效解决隔离问题，客户定制代码直接使用 Lua 编写，并且仅加载部分核心基础功能（字符串处理、table 处理、math 处理、coroutine 处理），而不加载例如网络通信、系统交互、文件操作等相关的类库，从而使得用户代码在图灵完备的语言中高度灵活编写的同时又能有效做到对框架的隔离保护。

关于如何实现 JavaScript 与 Lua 的互操作请参考[这篇文章](/js_interop_with_lua)。

## 流程定制层

最终，用户在使用 Hypertrons 时，则可直接在 Lua 代码中进行流程定制，Hypertrons 会提供一些通用的基础组件供项目直接选用，而项目也可以在自己的项目仓库中定制自己的 Lua 组件，框架会直接从用户仓库中加载这些组件并运行。

之后我们还会进一步提供 Lua 组件的可视化编辑和编排能力。

以上就是 Hypertrons 项目的演进过程和目前的框架设计，对于 Hypertrons 项目的实现细节，之后还会有更多的博文产出，也可以通过 [Hypertrons 标签列表](/tags/Hypertrons/)快速查看与之相关的文章。
