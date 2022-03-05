---
title: 开源码力榜背后的算法模型
date: 2022-03-05
---

> 近期与思否合作发布的中国开源码力榜受到了众多开发者的关注，而其中大部分开发者会更加好奇这个排名是如何产生的，背后的算法是什么，为什么有些开发者上榜了，而有些没有。这篇博客就会大家了解一下这个榜单背后的算法，并希望得到大家的一些反馈，可以持续优化该榜单，使其可以更加全面和公正。

# 开源价值网络

之前的三篇博客已经介绍了一种[基于协作数据的开源价值网络的异质图 PageRank 算法](http://blog.frankzhao.cn/how_to_measure_open_source_3/)，而本次使用的就是仅包含协作数据的 GitHub 全域开发者-项目的价值网络，其结构如下所示：

![](//www.plantuml.com/plantuml/png/SoWkIImgAStDuIhEpimhI2nAp5L8IKrBBCqfSSlFA_5Bp4rLS0nI2F1H2FLEp5HmzkFYoaqiK7Ywf-5f_yGN3QqArLmA2azsRt_QiCVMxjdK3K2QgnQYvkN2dSzdhyEX06w0bHL4Ki56LzSEgWSkPgNmRClk5zkRd-vQnkMGcfS2T2S0)

这是原先设计的价值网络的一个简化版本，没有纳入开发者对项目的关注度关系（star、fork）、开发者之间的关注关系（follow）和项目之间的依赖关系（dependent），主要是考虑到算力的问题，以及某些尚未支持的对于缺失数据的鲁棒问题。

在建立起完整的网络后，我们按月对全域的开发者和项目进行协同排序，并得到所有开发者和项目的价值排名。即我们可以得到 2015 年至今每个月全域中活跃的所有开发者和项目的排名情况，而中国开源码力榜使用的则是 2021 全年的开发者加和数据。

# 与传统 PageRank 相比

这个算法模型与传统的 PageRank 算法类似，是使用全域的关系数据来进行协同排序，有几个基本的价值主张：

1、越有价值的项目容易吸引到越有价值的开发者来贡献
2、越有价值的项目容易吸引到越多的开发者来贡献
3、越有价值的开发者会在越有价值的项目上活跃

而与传统 PageRank 算法不同的地方在于，在开源价值网络中，不同类型的节点（开发者、项目）的计算方式可以是不同的，而且这个算法引入了先验知识，即节点的固有属性作为一部分参考，而不仅仅使用网络关系的数据。

也就是说：在开源价值网络中，每个月的项目和开发者的价值，将不仅仅取决于开发者和项目当月的活跃情况，也有一部分是继承于上个月的数据，这使得整个算法得到的结果具有非常好的平滑性，而且也是因为我们相信开源的长期价值，是不仅仅依赖当下的情况的。

# 具体参数

在本次的模型中，我们使用了如下的一些参数：

1、开发者-项目活跃度，使用的是实验室在往年的中国开源年报、GitHub 洞察报告中使用的计算方式，即 $A=\sqrt{1 * C_{issue\_comment} + 2 * C_{open\_issue} + 3 * C_{open\_pull} + 4 * C_{pull\_review\_comment} + 2 * C_{merged\_pull}}$ 。即 Issue 评论计 1 分，打开新 Issue 计 2 分，提交 PR 计 3 分，PR 上的 review 评论计 4 分，合入 PR 额外计 2 分，最终开方，用以修正过高的活跃度。
2、开发者和项目的初始价值，即第一次开始活跃时的价值均为 1。
3、开发者每个月有 50% 的价值来源于自身的历史价值，50% 来源于当月的开源价值网络。
4、项目每个月有 30% 的价值来源于自身的历史价值，70% 来源于当月的开源价值网络。

# 常见问题

- 为什么有些用户量和人气极高的项目作者没有入选，如 Vue 的作者尤大？

其实看完上面的说明，大家就应该明白了，本次的算法主要是以协作关系来计算的，并没有纳入如开源软件的用户数量这样的指标（当然，开源软件用户量一直是非常难以获取的，即便是项目自己可能也无法知道具体的数值）。所以对于那些有大批开发者持续活跃的项目来说，其较有优势，而对于用户量较大的项目，则无法体现，这与使用的数据和模型的参数有极大的关系，尤其是 Vue 是一个以尤大为核心相对独立维护的项目（可参考 [2019 年 Vue 项目协作网络图](https://github.com/X-lab2017/github-analysis-report-2019/blob/master/static/vue_04.png)）。

- 为什么有些非常活跃的开发者没有出现在榜单中？

虽然我们对全域的开发者和项目进行的协同排序，但我们没有办法准确知道哪些账号是中国开发者，所以我们花了较大精力进行了人工标注，但依然难免疏漏，目前已经有标注的中国用户清单已沉淀到 OpenDigger 中，可以从[这里](https://github.com/X-lab2017/open-digger/blob/master/labeled_data/regions/China.yml#L104)看到。如果有新的账号希望标注为中国开发者，可以[提 Issue](https://github.com/X-lab2017/open-digger/issues/new?assignees=&labels=&template=submit_chinese_developer_data.md) 给 OpenDigger，合入后之后的计算就会纳入进来。

# 未来改进

1、引入 star、fork 关系。在本次的榜单中，从算力角度考虑，我们没有引入 star 和 fork 等数据，因为类 PageRank 的迭代类算法的时间复杂度与图密度是正相关的，而 star 这种低成本的操作会使得整个图的密度非常快的提升，从而使运算时间大幅增加，尤其是在对数千万节点的协同排序时。

2、引入开发者之间的 follow 关系。开发者的 follow 关系对于识别开发者 KOL 有很好的指导意义，但这里有一个数学层面的问题，就是在解决不完全数据下的 Rank Sink 问题，目前还没有来得及实现，会考虑引入类似 LeaderRank 的方式来低成本解决单向关系导致的一些问题。

3、项目依赖关系。事实上从用户角度出发，如果无法有效得到用户数量，那么项目的依赖关系是一个非常适合的数据，可以用来标识项目之间的使用关系，尤其在语言生态内会极为有效。但同样有与上述开发者 follow 关系一样的问题，并且还有额外的一些其他工程问题。

- 以 Node.js 生态为例，已经发布到 npm 的包很好追踪其依赖关系，而只有仓库并未发布制品包的项目，就需要进一步以仓库中 package.json 文件的内容来解析其依赖关系，在全域上做这件事的成本是极高的。
- 以 Java 生态为例，Maven 中心仓的元数据中并不包含上游仓库地址的信息，所以制品和仓库的关联是较大的问题，而且 Java 的发布策略中，仓库与制品包多对多的情况较多，这使得构建项目依赖关系更加复杂。

如果有同学对上述问题比较熟悉，而且知道如何解决，请一定联系我~~