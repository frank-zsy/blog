---
title: 基于 OpenRank 的开源项目内开发者贡献评价
date: 2022-10-19
tags: ['开源', '数据分析', '经济学']
---

> [WIP] 为了完成开源项目的价值流转闭环，除了全域的开源项目影响力计算，事实上还需要对项目内的开发者贡献做出更加精细的评价，而且项目内的评价算法对开发者行为的激励效果更加明显，所以我们也需要更加小心的设计。

# 前言

在之前的如何评价一个开源项目的一系列文章中（[活跃度](https://blog.frankzhao.cn/how_to_measure_open_source_1)，[协作影响力](https://blog.frankzhao.cn/how_to_measure_open_source_2)，[价值网络](https://blog.frankzhao.cn/how_to_measure_open_source_3)），我从一种简单的统计指标开始，到引入复杂的价值网络与 OpenRank 算法，给出了从开源全域数据来评价项目价值的一种方法，而[影响力榜单](https://open-leaderboard.x-lab.info/)也已被各大开源报告广泛采用，有了一定的认知度。

在后来的[「开放协作的世界里，每一份贡献都值得回报」](https://blog.frankzhao.cn/how_to_measure_open_source_4)中，虽然提出开源作为一种大规模的协作方式，需要有完整的价值闭环才能持续健康的发展，并且喊出了「在开放协作的世界里，每一份贡献都值得回报！」的价值口号。但事实上仅仅是通过全域价值网络的协作影响力计算出每个项目的影响力，并不能构成完整的价值闭环，因为最终的价值分配还是需要触达到每个具体的开发者。

因此之后我将价值网络的算法扩展到了具体的每个项目上，通过构建项目内部的协作网络并计算 OpenRank 值，来估计项目内每个开发者的贡献量，以及这种度量体系对人的激励作用是什么，也一并在这里和大家分享一下。

# 开源项目内协作网络与贡献者影响力

在[价值网络](https://blog.frankzhao.cn/how_to_measure_open_source_3)一文中，我提到 OpenRank 旨在构建一种高可扩展的数学模型，可以随时容纳各类开放数据，并根据数据与计算规则得到期望的结果。

既然 OpenRank 提供的是个一种高可扩展的价值网络计算模型，那么除了开源项目的全域影响力，其显然也可以应用于单独的开源项目内部的数据，来计算一个开源项目内部每个具体贡献者的相对于在该项目中的影响力。而这个数值事实上就可以用于估计项目内每个开发者的贡献，并给予相应的激励，从而构建一个开源项目内部的贡献评价体系。因此如何构建项目内的开发者协作网络是关键所在。

## 开源项目内协作网络构建

在全域协作网络中，我们以项目与开发者为节点，以活跃度为边构建了一个庞大的协作网络，事实上其含义就是以项目作为开发者的**协作单元**，即在同一个项目上活跃就看做是一种协作。

但在项目内部，显然我们需要更加精细化的协作单元，最直观的就是使用 Issue 和 PR 作为基本的协作单元，在同一个 Issue 或 PR 进行的讨论就被看成是一种协作。因此我们就得到了如下一个项目内的协作网络图：

![](https://www.plantuml.com/plantuml/png/SoWkIImgAStDuIhEpimhI2nAp5L8IKrBBCqfSSlFA_5Bp4rLS0nI2F1H2FLEp5HmzkFYoaqiK7Ywf-5f_yGN3QqArLmA2azsRt_QiCVMxjdK3K2QgnQYnhEuk3GLZtn041x9bmjtFf-z3eS2XEswkdPGUwmK_0jIytISytDpK_DAq9G41A79wmIbbcMcbdE1zOAKG2q4AdkwSTwJNNrS0K5OXRaSKlDIWC450000)

由此就构建出了一个开源项目内的精细化协作网络，需要注意的是：

- 除了“属于”关系外，所有的日常协作行为（Open，Comment，Review）都是具有时间属性的，即需要记录具体发生的时刻。
- 后续或许还可以增加更多的关联，如开发者之间对彼此评论的点赞也可以看成是一种价值传递。

## 贡献者的影响力计算

在上述的协作网络中，为了计算每个开发者在项目内的影响力，我们首先需要确定计算的时间窗口大小，即以多久的数据为一个计算单元。考虑到在现实中，工资发放是以月为维度的，我们暂时选用了以月为维度进行计算，而以更小的粒度（如周）或更大的粒度（如季）计算也是可以的。

接下来就是对于算法中各种参数的确定了，目前使用的策略如下：

- 对于项目
    - 首次初始的影响力是 1
    - 每月完整继承上个月的影响力
    - 项目的价值交换仅通过“属于”关系与 Issue 和 PR 交换
- 对于 Issue 和 PR
    - 首次初始的影响力分别是 1 和 5，根据评分策略有 2 至 9 倍的初始影响力加成（具体策略见后）
    - 对于历史活跃的 Issue 或 PR，若当月没有任何开发者活跃，则影响力降低为上月的 50%
    - 每月完整继承上个月的影响力
    - Issue 和 PR 的价值交换，90% 通过日常协作行为与开发者交换，10% 通过“属于”关系与项目交换
- 对于开发者
    - 首次初始的影响力为 1
    - 对于历史活跃的开发者，若当月没有任何日常协作活跃，则影响力降低为上月的 85%
    - 每月完整继承上个月的影响力

另，所有节点本身的影响力权重比例为 15%，而受到协作网络影响的比例为 85%，即主要依赖网络关系计算影响力。

### Issue 与 PR 的初始价值计算

这里需要额外说明一下 Issue 与 PR 的初始价值计算，因为某个具体的项目中，与全域项目不同，我们可以通过制定社区的规则，使社区中的成员可以常态化的表达更多的价值倾向，从而帮助我们更好的评判每个节点的价值。

在 Issue 与 PR 的初始价值计算中，我们使用了低成本的 GitHub reactions 来进行，即所有开发者都可以对 Issue 和 PR 进行 reactions 评价，如👍 2 倍、❤️ 3 倍、🚀 4 倍，所以如果一个开发者使用了三个 reactions 进行评价，则最多可以把一个 Issue 或 PR 的基础倍率提高到默认的 9 倍。

但这里我们对不同开发者做出的评价权重是不同的，一个开发者的评价倍率对最终倍率的影响与其在项目中的上个月的影响力有关。如一个开发者在上个月的影响力占比是 20%，那么如果他对一个 Issue 给出了 9 倍倍率的评价，但仅有他给出了评价，则最终这个 Issue 的基础倍率将是 $ 0.2 * 9 + (1 - 0.2) = 2.6 $。因此 9 倍看上去是一个非常高的倍率，但其实个别账号的高评价并不会带来非常大的影响。

也就是说这是一种去中心化的评价体系，每个开发者如果想要自己的评价更有意义，就需要自己在项目中的影响力更大才行，如果一个对项目完全没有贡献的开发者，他的 reactions 评价则完全不影响结果。

# 项目内开发者影响力的价值导向

正如管理学中的一句话：“你考核什么，就会得到什么”，那么在上述的数学模型和计算方法下，如果一个开发者想要在社区中获得更高的影响力，他应该做什么呢，以及这些行为会对社区后续带来什么变化呢？

![value-orientation](/images/how_to_measure_open_source/value_orientation.png)

## 提升与社区中影响力较高开发者的协作深度

由于协作网络是构建在 Issue 和 PR 等协作单元之上的，因此最简单的一种策略就是要提升与社区中影响力较高的开发者的协作深度。

如果是一个刚刚进入社区的开发者，最简单的方式就是在社区核心开发者的 Issue 或 PR 中进行交互，无论是进行讨论或者去 Review 他们的代码提出一些问题都是可以的。

而对项目已经有一些了解的开发者，则更好的策略是通过自己高质量的 Issue 和 PR 来吸引核心的开发者与自己进行协作，例如参与自己提出的问题的讨论，或来 Review 自己提的 PR 等。

所以这里就已经对开发者有一些价值引导了，即需要想办法与社区中的核心开发者交流协作，而不是自己一味的提低质量的 Issue 或 PR，若没有人愿意与你讨论，则你的影响力依然是很难提升的。

而对于项目中的核心开发者，其策略其实是要与更多的开发者产生协作关系，即尽可能去与其他的开发者进行交流与协作来巩固自己的核心位置。

## 获得社区中影响力较高开发者的认可

上一项相当于是鼓励协作数量，但这一项则更加强调贡献的质量。由于 Issue 和 PR 具有初始价值，而这个初始价值其实对于提升开发者的影响力非常重要。

那么如果一个开发者希望社区中的核心开发者来给自己的 Issue 和 PR 点赞，从而获取更高的初始价值，那么他们就要想办法去提高自己贡献的质量，来赢得其他开发者的认可。

事实上，在真正落地运作时，我们会发现这个价值引导会带来额外的好处，那就是常态化的相互点赞，可以很好的活跃社区的氛围。毕竟很多时候并没有那么多严肃的讨论可以进行，这种点赞在评价的同时，也变成了一种社交手段，使得社区中开发者之间有了更融洽的氛围。

## 尽可能长期参与贡献

在该算法中，任何刚刚进入社区的开发者的初始影响力均为 1，这意味着开发者如果仅有短期的贡献，一定很难上升到一定的高度，而由于每个月都会继承上个月的影响力作为初始值，那么长期贡献基本意味着影响力的长期增长。

而一旦贡献中断，则影响力会以 85% 的速度逐渐衰减，其实这里之所以选择 85% 这样一个并不高的比例，而不是直接清零，就是防止贡献者因为偶然中断的贡献而流失。85% 的速度意味着 4 个月停止贡献依然保留超过原始 50% 的影响力，而一年不贡献还保有 15% 的影响力。则开发者随时回到社区时，就可以快速续接之前的影响力，不会需要从头再来。

## 结论

仅从单项目内部的影响力获取这件事，OpenRank 算法对贡献者行为的主要激励就是如上三个方面，然而我认为这已经非常足够了，因为这三项就意味着这个评价方式在真切的鼓励**高质量的长期贡献与深度协作**。只要没有出现核心开发者破坏性的抱团摆烂，算法本身就是相当有效的，很难出现简单的刷榜行为。

# 总结与思考

项目内的开发者影响力的 OpenRank 模型是全域协作网络评价的一个补充与扩展，仅仅通过替换数据与参数就可以将 OpenRank 模型迁移到一个更加具体的场景。并且通过对项目内开发者的引导与教育就可以获得比全域评价更加精细和准确的评价，也因此更能体现去中心化的核心思想。

另外想要说的是，有时候有些人会说，这个算法并没有告诉我们具体做什么事就可以提升自己的影响力。而我想说的是，把评价度量与具体的行为指导混在一起并不是一个好的做法，度量的目标是尽可能做出客观的评价，好的评价体系还会可以将管理思维注入其中，带来正向的价值引导，但具体的行为依然需要发挥每个个体的主观能动性。

在经济学中，我们会说做大蛋糕是分蛋糕的物质基础，但如果蛋糕分不好，那么就永远做不大。也就是说没有好的贡献度量体系，给到每个个体应有的荣誉与回报，那么一个组织就永远都做不大。

事实上关于这套评价体系，我们在一些社区中已经有了落地与部分的实验结果，我后续会独立写一篇案例篇，而关于这个算法中的一些保险机制的设计，我也会在这篇中细化讨论。

当然也希望更多的社区可以使用这套算法，一起优化与迭代，把开源价值网络做扎实，做到位，才能真正带来一些改变。有需要的社区朋友可以联系我，我可以为大家提供社区数据的分析能力。