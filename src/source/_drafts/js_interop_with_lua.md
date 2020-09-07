---
title: JavaScript 实现 Lua 互操作
date: 2020-09-07
tags: ['Hypertrons', 'Lua']
---

> 在 [Hypertrons 介绍](/hypertrons_overview)中提到在项目设计中，使用了 Lua 来进行业务端自定义流程的编写，利用 [Fengari](https://github.com/fengari-lua/fengari) 提供 Lua 代码在 Node.js 中的运行能力。
> 本文将介绍如何实现 JavaScript 和 Lua 互操作的技术细节。

本文将从 Lua 互操作基础、数据互通、逻辑互通三个方面进行介绍。

# Lua 互操作基础

Lua 作为一门典型的胶水语言，在游戏开发中是极其常用的，因为可以用于服务端和客户端的业务逻辑代码编写，从而实现高度可配与热更新。

通常在大型游戏开发中，服务端可能会选用 C++ + Lua 的方式。即游戏的底层框架，如物理引擎、战斗系统、场景管理等都会运行在 C++ 层以最大化运行效率，提升每台服务器可容纳的同时在线玩家数量。而业务逻辑，例如剧情、技能、日常任务、活动等则一般在 Lua 层，原因是这部分逻辑需要策划进行开发，Lua 代码可以让策划在拥有足够灵活度的情况下又不需要和服务器直接打交道，而且脚本运行提供了足够友好的热更新能力。

而手游开发中，很多客户端代码同样是通过 Lua 编写的。原因是在最常见的游戏开发引擎 Unity3D 中，一般底层用 C# 编写，但由于 iOS 对于代码段和数据段有严格的区分，无法做到加载动态库，所有 C# 编译后的 CIL 代码需要在发布前转换成 Native Code，这导致无法通过替换 lib 来达到热更新效果。而游戏更新是一项极为重要的能力，所以一般都会选择用脚本语言来实现业务逻辑从而实现简单热更新。当然也有一些其他方案，例如 C# 解释运行时等，但并不是常见方案。

由于本人的游戏开发经验，对 Lua 还算较为熟悉，也大概了解其作为胶水代码如何与宿主代码进行互操作，故 Hypertrons 选择了使用 Lua 代码作为自定义流程逻辑的编写代码。

与宿主语言的互操作，主要需要解决两个问题，即数据互通与逻辑互通。对于 Lua 运行时的栈模型，尤其是与 C++ 的互操作教程较多，这里不再详细介绍，主要介绍一些与 JavaScript 交互时较为 tricky 的点，尤其是在 Hypertrons 特定框架下权衡与实现。

# 数据互通

在 JavaScript 和 Lua 相互调用函数时，需要传递一些参数给对方（也可以直接注入全局变量），此时就需要可以在两种语言之间做数据互通，主要是指数据类型的相互转换。在讨论数据转换之前，我们需要先看一下两种语言各自拥有的数据类型，才能做较好的对应。

在 JavaScript 中，主要包含的数据类型可以通过 `typeof` 关键字的返回值类型来观察，包括了 `number`，`bigint`，`string`，`boolean`，`object`，`symbol`，`function` 和 `undefined`。而 Lua 的数据类型则包括 `number`，`string`，`boolean`，`function`，`table`，`userdata`、`thread` 和 `nil`。

了解了两种语言的数据类型，就可以开始设计不同类型之前的转换规则了，下表展示了两者的对应数据结构：

| type | JavaScript | Lua |
|:--:|:--:|:--:|
| 数值 | `number`, `bigint` | `number` |
| 字符串 | `string` | `string` |
| 布尔 | `boolean` | `boolean` |
| 对象 | `object` | `table` |
| 空值 | `undefined` | `nil` |

其中 `function` 为函数或闭包类型，属于逻辑互通范畴，在这里先不讨论，`symbol` 为 ES6 新增的类型，有诸多的特性，不易在 Lua 中实现，也暂不讨论。而 Lua 中的 `userdata` 为宿主语言注入的数据对象，Lua 无法处理这类对象，但可以进行传递，同样不讨论。而 `thread` 为 Lua 特有数据类型，传入 JavaScript 后也无法处理，这里不做讨论。

## 基本数据类型

而按照上述表里的对应关系，就可以很容易写出数据类型的互转方式，在 Fengari 提供的运行时下，JavaScript 数据向 Lua 传递，即变量压栈可以这样来写：

``` TypeScript
private pushStackValue(L: any, value: any, target?: any): number {
  const type = typeof value;
  switch (type) {
    case 'number':
    case 'bigint':
      lua.lua_pushnumber(L, value);
      break;
    case 'string':
      lua.lua_pushstring(L, value);
      break;
    case 'boolean':
      lua.lua_pushboolean(L, value);
      break;
    default:
      break;
  }
}
```

其中 `L` 为当前运行时堆栈，`value` 为要传递的值，`target` 稍后介绍，是 JavaScript 函数对象传递时可能存在的 `this` 对象。

同理，Lua 数据向 JavaScript 传递，即从 Lua 栈中获取值，则可以这样来写：

``` TypeScript
private getStackValue(L: any, index: number): any {
  if (lua.lua_gettop(L) === 0) {
    // no value, return undefined first
    // otherwise, absindex will fail
    return undefined;
  }
  index = lua.lua_absindex(L, index); // change to abs index in case iterate call error
  const type = lua.lua_type(L, index);
  switch (type) {
    case lua.LUA_TNUMBER:
      return lua.lua_tonumber(L, index);
    case lua.LUA_TSTRING:
      return lua.lua_tojsstring(L, index);
    case lua.LUA_TBOOLEAN:
      return lua.lua_toboolean(L, index);
    default:
      break;
  }
}
```

其中 `L` 为当前运行时堆栈，`index` 为当前要获取的堆栈变量的位置。

## 复杂数据类型

对于基本类型，这种简单的转换即可达成预期的效果，但对于对象类型的转换则需要一些 trick，因为 `object` 在 JavaScript 端事实上还可以细分为多种类型，如数组、Map 等，可能并非都是纯数据的结构。而对于 Lua 而言，所有的对象都只有 `table` 这一种，所以在转换时需要一些特殊处理。

在 JavaScript 向 Lua 传递 `object` 对象时，需要区分一下当前对象的具体类型，数组需要特殊处理，而一般对象类型则通过 key，value 对的方式注入，因为这两种对象在 JavaScript 端的遍历方式和在 Lua 栈上的构造方式均不同。

``` TypeScript
if (Array.isArray(value)) {
  // if pass in an array, push as a table, set index and value
  lua.lua_newtable(L);
  (value as any[]).forEach((v, i) => {
    const n = this.pushStackValue(L, v);
    if (n !== 0) {
      lua.lua_rawseti(L, -2, i + 1);
    } else {
      lua.lua_pop(L, 1);
    }
  });
} else {
  lua.lua_newtable(L);
  Object.keys(value).forEach(key => {
    lua.lua_pushstring(L, key);
    const v = value[key];
    let n = 0;
    if (typeof v === 'function') {
      // if the value is function, wrap and bind target and push back
      const f = this.wrapFunc(v.name, v, target);
      n = this.pushStackValue(L, f, value);
    } else {
      n = this.pushStackValue(L, value[key]);
    }
    if (n === 0) {
      // not support type or not push into stack
      // pop out the key
      lua.lua_pop(L, 1);
    } else {
      // set table value into table
      lua.lua_settable(L, -3);
    }
  });
}
```

在注入时，如果是数组类型，需要遍历数据，并通过 `lua_rawseti` 方法直接设置下标，从而使 Lua 端获取到的同样是数组。而如果不是数组，则通过遍历 key 的方式进行注入，这里需要特别注意如果是 `function` 函数，需要特殊处理包装，并绑定 `target` 后注入，这个部分在后面的逻辑互通中介绍。

而如果是从 Lua 中获取一个对象，则同样需要判断其类型，从而在 JavaScript 可以重新构造：

``` TypeScript
let v: any;
try {
  lua.lua_rawgeti(L, index, 1);
  v = this.getStackValue(L, -1);
  lua.lua_pop(L, 1);
// tslint:disable-next-line: no-empty
} catch { }
if (v !== null && v !== undefined) {  // need to check like this
  // array
  const arr: any[] = [];
  for (let i = 1; ; i++) {
    lua.lua_rawgeti(L, index, i);
    const v = this.getStackValue(L, -1);
    lua.lua_pop(L, 1);
    if (!v) break;
    arr.push(v);
  }
  return arr;
} else {
  const ret: any = {};
  lua.lua_pushnil(L);
  while (lua.lua_next(L, index) !== 0) {
    // iterate keys and values from table at index
    // lua_next will push key and value on stack
    const value = this.getStackValue(L, -1);
    const key = this.getStackValue(L, -2);
    if (value && key) {
      ret[key] = value;
    }
    lua.lua_pop(L, 1);
  }
  return ret;
```

由于 Lua 中的下标从 1 开始，则可以通过尝试获取下标 1 的值，如果获取到则认为当前值为数组，否则为一般对象。如果是数据，通过 `lua_rawgeti` 方法反复获取其连续下标的值，直到取不到退出，返回一个数组即可。如果是对象，则通过 `lua_next` 方法对当前 `table` 进行遍历，最终返回一个对象即可。

通过以上的方法，就可以做到 JavaScript 和 Lua 大部分数据结构的互转，而且这种互转方式可以让两种语言在各自端做到完全 Native 的方式来使用数据，而不是例如一些其他的互操作实现，需要通过函数来进行数据对象的操作，多大降低了 Lua 层代码的编写难度。

# 逻辑互通

// 待续...
