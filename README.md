# bud2exe

- 为了更安全的运行sh脚本,所写的一个编译脚本成二进制文件小工具
- 是 "poetryBeBe"(https://github.com/aspnmy/poetryBeBe.git) 管理器的一个配套编译小工具,目前独立维护,方便进行脚本文件编译

## 版本说明

- bud2exe_poetryBeBe ["poetryBeBe"](https://github.com/aspnmy/poetryBeBe.git) 管理器的一个配套编译小工具,使用时必须放置在poetryBeBe项目的./tools目录下,运行的时候会自动把该项目进行打包

- bud2exe_cli bud2exe的菜单交互工具,运行以后会出现交互菜单,按照菜单提示按键选择即可

- bud2exe_climini bud2exe的命令行工具,通过传参可以打包任意文件,./bud2exe_climini help 查看使用说明

- makeRun bud2exe自身的批量打包交互工具,放在bud2exe项目的Src目录下,可以批量打包bud2exe项目的全版本等。
  
```bash
请选择一个选项:
1) bud2_all/打包bud2exe所有版本
2) bud2sha256/计算哈希值并写文件
3) cleanAll/清理所有编译中间缓存
4) dellAll/清理所有已编译文件
5) 退出
请输入你的选择: 

```

## 目录说明

```bash
.
├── Build # 打包以后存放的输出目录
├── LICENSE
├── README.md
└── Src # 几个工具版本开源代码
    ├── bud2exe_cli # 交互工具版本
    ├── bud2exe_climini # 传参命令行工具版本
    ├── bud2exe_poetryBeBe # poetryBeBe项目配套版本
    ├── makeRun  # 自身打包批量交互工具
    └── newVer.bud # 版本号更新文件,更新此处版本号,自动打包的时候会同步带入版本号

```

## 高级应用

- ### 打包 sh脚本以外的文件

- 比如我们可以打包任意一个文件，输出一个加密的组件
- 需要查看加密组件的明文需要进行反向,无论时shc还是gcc打包默认都是转换成c语言后再编译
- 所以反向就是对c语言进行反向

- ### 合并不同类型之间为文件

- 比如我们可以打包任意多个文件，输出一个加密的组件
- 需要查看加密组件的明文需要进行反向,无论时shc还是gcc打包默认都是转换成c语言后再编译
- 所以反向就是对c语言进行反向

- ### 计划

- 计划使用新的打包组件,使其可以解密成明文
- 是否会有7z组件,哦不会，7z只是压缩,本项目使对sh脚本加密和资源静态编译

- ### 答疑

- 为什么gcc编译的文件需要8.9mb大小,而shc编译的文件只有19kb?
因为gcc采用了静态编译,不依赖外部组件,所有组件已经编译再二进制文件中所以体积比较大
而shc编译未采用独立模式,运行依赖shc组件本身,所以体积非常小