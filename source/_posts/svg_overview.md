---
title: SVG 初体验
date: 2020-09-17
tags: ['可视化']
---

> 作为一个一直是后端开发的工程师，其实很想做一些炫酷的效果来展示自己的一些简单的想法，但却没有很好的方案，直到遇到了 SVG。

先给大家看两个例子

<embed src="/images/arch.svg" style="width:100%">

<embed src="http://gar2020.opensource-service.cn/svgrenderer/github/X-lab2017/github-analysis-report?path=sqls/working-hour-distribution/image.svg" style="width:100%">

这是两个最近使用 SVG 做的图，第一张图是 Hypertrons 的架构图，第二张是一个工作时间的分布图，用于展示 GitHub 数字报告的分布情况。

两张图都内置了中英两种语言的支持，可以通过下方的按钮进行语言切换。第一张图的特点是具有可交互性，鼠标在不同的模块间移动时会有实时显示的额外说明。第二张图的特点是图里的所有元素都是动态生成的，而且支持数据动态注入，如果你刷新这个页面，会发现每次显示的圆点的分布与大小是不一样的，因为我这里没有指定输入数据，所以图片加载时会自动生成一些随机数据点。

关于 SVG 文件编写的基础内容，我这里就不做介绍了，网上有大把的资料，我比较喜欢的一个是 [W3school](https://www.w3school.com.cn/svg/index.asp) 的标准教程，里面也包含了大量可以参考的示例。而通过[这个网站](http://www.gaituba.com/svg/)，则可以在网页上直接编写 SVG 内容，右边会实时渲染。另外，如果在工程中添加和编写，则可以在 VSCode 中安装 SVG 插件，则可以直接在 VSCode 中进行实时的编辑和渲染。当然使用网站在线编辑的话有更好的调试体验，因为可以通过浏览器 `console` 输出一些内容，而 VSCode 中较难调试动态代码。

接下来这篇文章其实要介绍一些小的技巧和我个人遇到的坑，主要是用来满足一些开源项目自己构建交互图的场景。

# 优缺点分析

首先我们来整体看一下使用 SVG 文件构造图片的优缺点：

## 优点

SVG 是一种使用代码构造图片的方式，具有诸多的优点：

- 有些重复较多的图形可以不用逐一构造，而可以通过代码直接循环构造，例如上边的第二张图。
- 图片文本化，则可以作为开源的源代码，被反复迭代和修改。
- 图片文本化，则存储和网络传输的效率极高，一般一张图至少需要上 MB 的存储空间，而纯文本则要低很多，例如第一张架构图是 16KB，而且其中有近一半是双语文字内容。
- SVG 可内嵌 `css` 与 `ecmascript`，则意味着图片的样式、逻辑、布局可以独立维护，为多工种协作提供了便利。
- SVG 是构造的是矢量图，则可以任意缩放而无需担心失真和模糊。
- 通过动态传参可以大幅提升图片的可复用性，可在参数传递一节来看。

## 缺点

SVG 的优点还是较为明显的，但缺点同样也较明显：

- 代码构造图片，不易构造较为复杂或设计较多的图片，实现困难会很大。
- SVG 作为一种实现标准，各个浏览器的支持不同，目前而言，FireFox 和 IE 下可能出现表现不一致的情况。
- 在开源领域中非常不友好，因为 GitHub 默认不支持 Markdown 中嵌入的 SVG 中的动态内容的展示，所以几乎无法直接在 GitHub 中直接使用 SVG 图片。详见跨域安全策略部分。

# 多语言支持

在开源项目中，尤其是大厂的开源项目，多语言支持一向是非常重要的部分。中国的项目，一般文档都要包含中英双语的，但如何让图片支持双语，其实一直是较为困难的，目前我还没有见过较好的解决方案。

有些项目会使用字符画的形式来表现架构图，则图片直接被文档化了，可以中英双语独立维护，但这种方式的适用范围非常有限，较为复杂的图根本无法使用字符画来表现。有些项目则会维护两张图片，一个是英文内容，一个是中文内容，或干脆只包含英文图片。但使用图片的问题是，图片不仅体积大，修改困难，而且内容修改时需要同时修改两个图片文件，维护成本很高。

而使用 SVG 则可以非常方便的解决这个问题，例如上面的两张图，都是内置了中英双语的实现，而且可以交互式的进行语言切换。其简单的实现思路如下：

所有需要多语言支持的元素，在绘制时先不对其进行文本的渲染注入，但需要给定一个唯一的 id 标识。然后在语言切换的按钮上绑定一个点击事件，在点击时根据点击的按钮内容从一个 `Map` 中获取内容并动态赋值元素的 `innerHTML` 即可。这样就可以做到多语言的无缝切换。而且这种实现方式具有非常好的可扩展性，新增一种语言只要新增一个按钮和对应的文本即可。

这里给一部分简单的代码实现示例

``` javascript
<script type="text/ecmascript">
<![CDATA[

// 用于多语言支持的数据结构，内容为元素 ID -> {语言：对应文本}
// 需要注意 HTML 中对 &, <, > 等特殊字符需要转义为 &amp; &lt; &gt;
var textMap = new Map([
  [
    "digital_space_text", {
      "中文": "数字空间",
      "EN": "Digital Space"
    }
  ], [
    "dsl_visual_prog_text", {
      "中文": "DSL 可视化编程与编排",
      "EN": "DSL visual programming &amp; DSL visual orchestration"
    }
  ]
};

function changeLang(btn) {
  // 获取按钮的文本，作为多语言文本索引的 key
  var lang = btn.innerHTML;

  // 对于所有的 text 元素，根据 ID 到 textMap 中寻找是否包含当前语言对应的文本
  // 包含则替换，否则不处理当前元素
  var textElementList = document.getElementsByTagName("text");
  for (var i = 0; i < textElementList.length; i++) {
    var elem = textElementList[i];
    if (!elem.id) continue;
    var text = textMap.get(elem.id);
    if (text && text[lang]) {
      elem.innerHTML = text[lang];
    }
  }

  // 所有语言切换的按钮都置 name 为 lang_btn，则此时将所有的按钮全部置黑，并将当前按钮置白表示激活状态
  var btns = document.getElementsByName("lang_btn");
  for (var b of btns) {
    b.style.fill = "black";
  }
  btn.style.fill = "white";
}

]]>
</script>

<!-- 多语言切换按钮，绑定 onclick 事件，并置 name 为 lang_btn -->
<text name="lang_btn" id="en_btn_text" x="280" y="330" onclick="onLangBtnClick(evt)">EN</text>
<text name="lang_btn" id="zh_btn_text" x="320" y="330" onclick="onLangBtnClick(evt)">中文</text>
```

另外，这种实现下，默认所有 `text` 元素都是不包含文本内容的，所以需要在 `svg` 元素的 `onload` 事件中绑定要执行的代码，选定一个默认语言并刷新所有元素的文本即可。

当然，如果希望通过传参的方式来控制默认选定语言也是可以的，那就是接下来的内容。

# 参数传递

在完成了上述的多语言支持后，那么我们就会遇到下一个问题，即如果图片已经内置支持了多语言，那么在特定语言的文档中，我就希望其默认显示对应的语言（或者干脆不支持语言切换，而是就显示当前语言），那么要怎么做呢？

于是我们可以使用参数传递来解决这个问题，因为 SVG 文件在浏览器中访问时，无论是从网络上加载还是从本地文件加载都是一个 URI，那么就可以通过 `?key=value` 的方式对其传递一些参数，而在图片内部，由于可以直接编写 `ecmascript`，所以也是可以从地址中获取这些参数的。

下面看这张图：

<embed src="/images/arch.svg?lang=zh&bg_color=lightgoldenrodyellow" style="width:100%">

其实这张图依然是上面的那张架构图，不过在访问时添加了 `?lang=zh&bg_color=lightgoldenrodyellow`，则表示默认显示为中文，而且背景色用传入的颜色来替换。

事实上通过 URI 传参，我们可以实现很多能力，不仅仅是一些简单的参数修改，数据也可以通过这种方式进行定制，例如这张图：

<embed src="http://gar2020.opensource-service.cn/svgrenderer/github/X-lab2017/github-analysis-report?path=sqls/working-hour-distribution/image.svg&data=[1,2,3,3,2,2,4,5,7,8,6,6,7,9,10,10,9,8,8,8,7,7,4,4,3,3,4,3,2,3,5,6,7,7,7,6,7,9,10,9,9,8,8,8,7,6,5,4,3,3,4,3,2,2,4,6,7,7,7,5,7,9,10,9,9,8,8,7,7,5,5,4,3,3,3,3,2,2,4,6,7,7,6,6,7,9,10,10,10,9,9,8,7,6,4,3,3,3,4,4,3,3,4,5,7,7,6,6,6,8,8,9,8,7,6,6,6,6,4,3,2,1,2,1,1,1,1,1,2,2,2,2,3,3,4,5,4,4,4,3,3,2,2,1,1,1,1,1,1,1,1,1,2,2,3,3,3,4,4,4,4,4,4,4,3,3,2,1]&lang=zh" style="width:100%">

这张图也是上面的工作时间分布图，但默认是显示中文，而且通过 `data` 传递参数，这张图显示了真实的 GitHub 行为日志发生的时间分布情况，因此内容也有了意义，而不是随机的排布。

通过这种动态的数据传递方式，我们可以实现图片的高度复用，例如这张工作时间分布图，我们可以通过传入不同的参数来实现展示不同的图。

我们可以用以下的代码来获取访问时带的参数：

``` javascript
function getQueryVariable(variable) {
  var query = window.location.search.substring(1);
  var vars = query.split("&");
  for (var i = 0; i < vars.length; i++) {
    var pair = vars[i].split("=");
    if(pair[0] == variable) {
      return pair[1];
    }
  }
  return false;
}
```

如果返回是 false 则表示参数不存在，注意如果参数真的传递了 false，那么返回的将是字符串的 "false"，而不是布尔值 false。

# 网站嵌入、跨域安全策略

接下来是在开源中使用 SVG 痛点最大的地方，即如何正确设置网站嵌入和跨域安全策略。

引发这个痛点最主要的原因是 GitHub 为了保证平台的安全，防止出现跨域动态代码的安全隐患，其对图片等静态资源都进行了缓存，而且对 SVG 文件会进行“清洗”以去除其中包含了动态内容，这会导致 SVG 中的动态脚本全部失效，所以在 GitHub 的 Markdown 文件渲染中，如果是一个仅包含 XML 语法的 SVG 图是可以显示的，但如果是通过脚本动态构建的图，则肯定会无法正常显示，而且基于脚本的交互能力也会被“清洗”掉。

而如果你想直接使用 `raw.githubusercontent.com` 在你的网站中嵌入 SVG 图，对不起，同样是不可以的。因为 GitHub 的 raw 服务是用于返回仓库文件的原始文本内容的，所以返回的 HTTP header 中的 `Content-Type` 一律是 `text/plain`，所以浏览器是不会渲染这个 SVG 的，你只会得到其原始的文本内容。

那么要在网站中嵌入 SVG 图，而且希望其可以正常交互，应该怎么做呢？

- 请使用 &lt;embed&gt; 标签进行嵌入，如果使用了 &lt;img&gt;，则图片会被转换成一张静态图。
- 既然不能使用 &lt;img&gt;，那么如果你在 Markdown 中嵌入，则同样需要用 &lt;embed&gt;，因为传统的 md 图片嵌入格式在渲染时会被转换成 &lt;img&gt; 标签。
- 如果想要直接使用 GitHub 的原始文件内容来渲染 SVG，就需要自己写一个转换服务了，服务去获取 GitHub 上的原始文件内容，然后返回浏览器，同时需要设置 `Content-Type` 为 `image/svg+xml`。

完成上述内容后，当你打开你的网站时，尤其如果是用的 GitHub Pages 托管时，八成依然是无法显示的，因为你的转换服务和 GitHub Pages 很可能是跨域访问的，当然除非你已经设置好了各种域名，使其在同域内，那就没问题了。

如果是跨域访问，你需要在你的响应头中设置相应的字段让浏览器知道可以安全的渲染这个资源或当前页面对资源的访问是被允许的，这里就涉及到了 CSP（Content-Security-Policy），具体的细节这里不介绍了，可以查看 [MDN 文档](https://developer.mozilla.org/zh-CN/docs/Web/HTTP/CSP)。如果要看效果的话，可以在 Chrome 的 Network 中查看访问上面工作时间分布图时返回的响应头部分。

# 结语

以上就是我在使用 SVG 中遇到的一些坑和体验的心得，总体而言，配合 Hypertrons，在开源项目中用 SVG 来制作多语言可交互的架构图是一件比较愉悦的事情，当然可能还有很多我还没有遇到的坑，之后遇到再来补充。
