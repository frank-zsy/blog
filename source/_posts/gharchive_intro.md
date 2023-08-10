---
title: GitHub 数据分析踩坑指南
date: 2023-08-10
---

# GHArchive

对 GitHub 数据分析比较了解的人应该知道，GitHub 提供了 API 可以获取全域的 GitHub 行为日志，这使得对大规模的仓库进行分析成为了可能，而 OpenRank 算法则更是需要全域的协作网络来进行分析，所以 GitHub 行为日志就是数据来源的不二之选。

而网上曾存在多个服务对 GitHub 行为日志进行归档和提供下载服务。在开源数据分析的很多论文中，大家看到的很多都是 [GHTorrent](https://github.com/ghtorrent/ghtorrent.org) 项目，该项目在 2016 到 2020 年之间都比较活跃，因为他们不仅提供了日志文件的归档和下载，而且提供了基于 MongoDB 的网络服务。这使得他们对科研团体非常友好，但随着日志量的快速增长，MongoDB 已经无法满足在线查询和分析的需求，而提供在线服务的成本过高也使得该服务难以为续。2019 年 7 月 GHTorrent 关闭了在线服务访问，2020 年后项目逐渐停止维护，目前已不再提供任何服务。

另一个服务就是我们实验室一直在使用的 [GHArchive](http://gharchive.org/)，该项目按小时为粒度收集和归档 GitHub 的全域行为日志并压缩成 gzip 文件提供下载。该服务的后端非常简单，并且作者本身不提供任何的在线服务，也因此维护成本较低，能够持续的提供相对稳定的服务。该服务的用户众多，例如 ClickHouse 官方的 [Playground 数据集](https://ghe.clickhouse.tech/)，PingCAP 开发的托管在 TiDB Cloud 上的 [OSS Insight](https://ossinsight.io/)，以及我们实验室开发的开源指标数据的开源项目 [OpenDigger](https://github.com/X-lab2017/open-digger) 等，均使用了 GHArchive 为数据源。另外，GHArchive 与 GCP 合作在 BigQuery 产品上提供一个[开放数据集](http://www.gharchive.org/#bigquery)，可以直接在 BigQuery 上按量付费进行查询。

随着越来越多的开发者开始对开源数据分析感兴趣，我这里也介绍了一下 GHArchive 存在的一些问题和自己的一些踩坑经历，其中也有一部分是 GitHub 事件数据的问题，供大家参考。

## 数据时间区间

GHArchive 提供了 2011 年至今的数据，但由于 2015 年初实现上有所变化，数据结构不同，因此解析方式也会不一样。

因此 OpenDigger 仅使用了 2015 年之后的数据，截止到 2023 年 8 月的数据量已经超过 59 亿条，加上 2011 - 2015 年的数据一共是 62 亿条。

## 数据完整性

出于成本和性能考量，GitHub 的行为日志 API 只能查询最近一段时间内的事件数据，这意味着如果在特定时间段内没有完成事件数据采集的话，之后将再也无法通过 API 补充这部分数据。而 GHArchive 作为一个在线服务，一旦出现任何问题，就可能出现数据上的永久缺失。

而这样的缺失是存在的，按照我们的统计，从 2015 至今共有约 327 个文件缺失，其中最为严重的两次服务故障导致的缺失发生在 [2020 年 8 月](https://github.com/igrigorik/gharchive.org/issues/232) 和 [2021 年 10 月](https://github.com/igrigorik/gharchive.org/issues/261)，分别导致了 55 个文件和 171 个文件永久缺失。

除了日志归档服务本身的原因外，GitHub API 的稳定性、数据完整性等也有一定影响，使得大家会发现全域日志中存在一些数据缺失，都是非常正常的。这对于很多初次接触 GHArchive 的开发者而言，可能都觉得不可思议，但全域日志确实不能作为精确的数据来源使用。

## 关于 Star

一旦开始使用全域日志分析，大家第一个想要尝试的可能就是看看项目的 star 数了，然后会发现日志数据中只有一个 `WatchEvent` 类型，而并没有 `StarEvent` 类型，而由于在 Web 页面上也存在 Watch 这个操作，这里就有了一个很大的困惑。其实由于 GitHub 的历史遗留原因，事件日志中的 `WatchEvent` 就是 star 事件，而 watch 事件在日志数据中是并没有记录的。

当然，由于是记录事件，如果同一个用户在仓库上反复的 star 和 unstar，会被记录为多个 `WatchEvent`，而且日志中并不会记录 unstar 事件，所以如果直接统计 `WatchEvent` 的数据，结果一定是大于当前仓库的实际 star 数的，而且由于有些用户会利用这个漏洞来刷 star，如果不对用户去重统计，也可能会远远高出实际的 star 数量。

## 关于仓库数据

细心的人会发现在有些日志数据上面，是带有仓库的详细数据的，例如仓库的描述信息（description）、默认分支（default_branch）、许可证（license）等等，但这类数据仅会出现在 pull request 的类型上面，也就是说仅有与 PR 有关的事件才带有这类数据，如 `PullRequestEvent`， `PullRequestReviewEvent`，`PullRequestReviewCommentEvent` 等。所以我们确实可以根据日志数据来获取仓库的信息，但对于没有 PR 日志的仓库，这部分数据是缺失的，而且由于不是所有类型的事件都会带有这部分数据，所以也有一定的时效性。

## 关于 PR Review

在第一次使用日志数据时，一定会有的一个困惑是，PR 上的评论被分为了两类，有些是 `IssueCommentEvent`，而有些是 `PullReuqestReviewCommentEvent`。仔细观察的话会发现，直接在 PR 上进行评论回复的话，事件会被记录为前者，而对于具体代码行的 review 评论是后者。

## 关于 Issue 和 PR 上的评论

遇上一个问题相关，由于 PR 上的直接评论会被记录为 `IssueCommentEvent`，因此如何区分到底是一个 issue 上的评论还是 PR 上的评论就是问题。在 `payload.comment` 字段内，如果存在一个 `pull_request` 字段则表示这是一个 PR 上的评论，但要注意的是，此时 `payload.issue` 字段上的数据库唯一 ID 与 PR 的 ID 的不一致的。通过这个细节我们也能知道，GitHub 平台内部 PR 的实现上，其实数据上是包含了一个 issue 实体的，并且与 PR 共享了一个 number 编号。

# GitHub API

对于全域日志数据中不存在的数据，我们可能还需要通过 GitHub API 来补齐，但这中间也有一些小问题。

## 贡献者数量

企业对于开源项目的数据统计，贡献者数量是一个基础指标，GitHub 也提供了相应的 API 来获取一个项目的贡献者数据，结果与页面上的展示相同。对于自己完全从头开发的项目这样是大概率没问题的，但开源办公室对所有项目统计时，就会发现有很多问题。

GitHub 对贡献者数量的统计，本质逻辑上是通过对项目 commit 历史的 author 信息进行统计的，而 GitHub 内部会尽可能对 author 和 GitHub 的用户体系进行关联。因为这部分是 Git 和 GitHub 的一个交界面，因此有点困惑。

但由于是通过 commit 历史统计，因此 fork 的仓库显然会继承所有上游仓库的贡献者数据，而且即便不是 fork 的仓库，如果提交的 git commit 里包含历史记录，也会额外引入其他的贡献者，因此大规模统计时偏差会很大。

例如字节开源的 [Byconity](https://github.com/ByConity/ByConity) 是直接分叉了 ClickHouse 进行二开的，因此 commit 历史中也会继承 ClickHouse 的贡献者的信息。而 Linux kernel 的下游项目均会保留 kernel 的 commit 历史，因此即便一个贡献者都没有，从 API 上也可以获取到 5000+ 的贡献者数量。

因此我们实验室直接使用了有 PR 被合入的 GitHub 用户数作为贡献者数量的统计口径，这样不仅避免了与 Git 的提交历史产生关系而导致困惑，而且可以从日志数据中直接获得。

## Token 限制

另外一个常见的难点是 token 的限制，GitHub 平台上用户可以自己生成 token 用于 API 访问鉴权，而每个 token 有每小时 5000 次请求的限制，这里的 5000 次是指 v3 的 REST API，如果是 v4 GraphQL 的 API，则需要根据请求的内容来计算，可能在一次请求中消耗多次请求次数。

相较而言，我个人比较喜欢使用 GraphQL API，不仅一次可以请求更加丰富的数据，而且可以按需返回字段，而 REST API 则会返回大量的冗余数据，对网络也不是很友好。

如果要突破每小时 5000 次的限制，则需要自己对 token 进行池化管理，请求时使用还有配额的 token 请求，一旦 token 配额超限，则需要等待下一个小时的配额刷新后再使用即可。

当然，还有另一个有趣的实现方式，如果可以让请求的仓库安装你的 GitHub Apps，则可以通过安装的 App 应用来获取临时 token，这类 token 也是每个 token 5000 次请求的限制，但是一次性的，即用完就失效了，不会在一个小时后刷新。但好处就是一旦安装了 App，就可以不受限的生成临时 token，用完销毁，之后可以继续生成新的 token，因此可以认为是可无限使用的。
