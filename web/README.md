# botChat 落地页（Vue 3）

GitHub Pages 站点源码。仓库根目录的 `index.html` 与 `plugins.html` 是**构建产物**，不要手改。

站点现在有两页：

| 页面 | 仓库根产物 | 说明 |
|---|---|---|
| 主页 | `index.html` | 首屏 / 三栏界面 / 能力 / 工作流 / 插件开发导流 / 更新日志 / 安装 |
| 插件开发文档 | `plugins.html` | 清单 v2、`register(ctx)`、IR 面板树、原生面板、hook、权限、排障 |

## 命令

```bash
npm install
npm run dev          # 本地开发（热更新，默认只服务主页）
npm run build        # 两次单入口构建 → dist/index/index.html 与 dist/plugins/plugins.html
npm run publish:dry  # 只校验产物，不写盘
npm run publish      # 校验通过后原子替换仓库根的两页（会先备份旧版）
```

`npm run publish` 的前置校验（任一条不满足即中止，不写盘）：

- 两页都必须含 `id="app"`
- 不得含外链：`<script src>`、外链 `.css`、`/assets/` 引用、`modulepreload` 外链
- 不得内联了另一页的入口脚本
- 两页必须互链：主页含 `plugins.html`，文档页含 `./index.html`

## 为什么是两次单入口构建

`vite-plugin-singlefile` 只能内联**单入口**产物的所有资源。如果用 Rollup 多入口一次构建，两个页面会共享 chunk（如 Vue 的 export helper），singlefile 无法把它内联进各自的 HTML，产物里会残留：

```html
<link rel="modulepreload" href="./_plugin-vue_export-helper-*.js">
```

这会让页面在被单独拷贝、或用 `file://` 打开时脚本加载失败，Vue 根本不挂载（实测渲染只剩 9 个 DOM 节点，而正常是 330+）。所以 `scripts/build.mjs` 对两页各跑一次独立构建，配置里显式 `inlineDynamicImports: true`。

`vite.config.js` 只服务 dev。发布构建共用 `vite.define.js` 的常量，避免版本号与更新日志两套口径。

## 为什么是单文件产物

Pages 从 `main` 根目录发布，且根目录同时有 `appcast.xml`（Sparkle 自动更新依赖 `feint123.github.io/botChat/appcast.xml` 不能失效）。因此：

- 源码在 `web/`，产物落回仓库根，Pages 无需改任何配置
- 用 `vite-plugin-singlefile` 把 JS/CSS/图片全部内联，产物保持自包含，`file://` 可直接打开预览
- `.gitignore` 只忽略 `node_modules/`、`web/dist/` 等，**根的 `index.html` 与 `plugins.html` 必须继续被 git 跟踪**

## 结构

```
web/
  index.html            主页 Vite 模板
  plugins.html          插件开发文档页 Vite 模板
  vite.config.js        dev 配置（base:'./'、singlefile，常量来自 vite.define.js）
  vite.define.js        构建期常量：版本号 / DMG 地址 / 更新日志（读 appcast.xml 与 notes/）
  scripts/build.mjs     两次单入口构建
  scripts/publish.mjs   产物校验 + 备份 + 原子替换两页
  src/
    main.js             主页入口：注入 html.js / html.noanim、挂载、启用滚动进场、h1 淡入
    App.vue             主页按 DOM 顺序组装区块组件
    lib/release.js      主页读取构建期常量的唯一入口
    components/
      SiteTopline.vue   SiteNav.vue       SiteFooter.vue
      HeroSection.vue   OrchestrationCanvas.vue
      WorkspaceSection.vue                （三栏界面复刻，数据驱动）
      CapsSection.vue   FlowSection.vue
      PluginsSection.vue                   （插件开发导流区）
      ChangelogSection.vue                 （版本动态，数据来自 notes/）
      InstallSection.vue
    plugins/
      main.js           文档页入口
      App.vue           文档页（章节结构 + 左侧目录）
      styles/plugins-page.css  文档页全部样式
    composables/
      useReveal.js               IntersectionObserver 滚动进场（.rv → .in）
      useOrchestrationCanvas.js  canvas 编排动效（分叉 → 并行 → 汇聚，CYCLE 7600ms）
    assets/                     真实应用图标 app-icon.webp + 吉祥物贴纸 sticker-1..9.webp
    styles/                    全局 CSS，按原分区拆分，index.css 控制导入顺序
```

## 版本号与更新日志只有一个来源

`vite.define.js` 在构建时读仓库根 `appcast.xml` 与 `notes/*.html`，注入：

- `__APP_VERSION__`（shortVersionString，如 `1.1.24`）
- `__APP_BUILD__`（build 号）
- `__DMG_URL__`（`releases/download/v<version>/botChat-<version>.dmg`）
- `__RELEASES__`：最近 4 个版本（主线一句 + 各分组前 3 条，从 `notes/botChat-<版本>.html` 解析）
- `__RELEASE_ARCHIVE__`：更早版本的版本号 / 日期 / 详情链接

业务代码只从 `src/lib/release.js` 读，**不要在组件里硬编码版本号、下载链接或版本条目**。发版只改 `appcast.xml` 并写 `notes/`，落地页重新 build + publish 即可跟上；更新日志区块会自动跟上新版本，不需要改代码。

`notes/` 里某个文件解析失败不会中断构建：该版本退化为「只有版本号与详情链接」。

## 图片素材

- 全部是 webp，放 `src/assets/`，由 `import` 引入（`assetsInlineLimit` 已拉满，构建时内联成 base64，保持单文件产物）
- 贴纸是装饰层：`position:absolute` + `pointer-events:none` + `alt=""`，语义上不进无障碍树；样式统一在 `src/styles/stickers.css`，小屏在 `responsive.css` 里收敛或隐藏
- 现在用到的：hero 2 张（sticker-3 等待 / sticker-2 困惑）、能力区 1 张（sticker-8 放大镜）、下载卡片 3 张（sticker-1/4/9）；sticker-5/6/7 备用

## 改样式 / 改文案的约定

- 样式一律改 `src/styles/*.css`（文档页改 `src/plugins/styles/plugins-page.css`），不在组件里写 `<style scoped>`。原因是原页面用的是全局 class（`.ws-*`、`.card`、`.flow` 等），改成 scoped 会改变选择器语义。
- class 名沿用原命名，不要改成 BEM 新命名，否则 CSS 与模板会脱节。
- 重复结构改数据数组（`CapsSection` 的 `cards`、`FlowSection` 的 `steps`、`WorkspaceSection` 的 `groups` / `entries` / `inspector`、`PluginsSection` 的 `points` / `samples`），不要复制粘贴 DOM。
- 图标统一用 `shapes` / `paths` 数据数组 + `v-for`，**不要用 `v-html`**。
- 页面文案必须能追溯到 `notes/botChat-<版本>.html` 或 `skills/botchat-plugin-authoring/references/*.md`；**不要写这两处都没有的事实**。

## 已知上游问题（待产品确认）

`CapsSection.vue` 第 8 张能力卡保留了原文的重复标题：`<h3>设计系统库</h3><h3>设计系统库<span class="tag">76 套</span></h3>`。迁移时按 1:1 保真保留，代码里有注释标记。要修的话删掉第一个 `h3` 并去掉 `dupTitle` 标记即可。

## 验收

工作区上级目录 `.supervisor/` 下的脚本（不在本仓库内）：

| 脚本 | 作用 |
|---|---|
| `verify-pages.sh [src\|pub]` | 双页总验收：文件存在、无外链、双页互链、真实渲染节点数、关键区块、四档截图；`src` 校验 `dist/`，`pub` 校验仓库根产物 |
| `measure-overflow.mjs <url> <w> <h>` | CDP 实测 `scrollWidth` 与 `clientWidth`，列出横向溢出的元素 |
| `css-audit.py` | 逐个选择器/声明比对 CSS 是否覆盖改造前基线 |
| `dom-diff.py` | headless Chrome `--dump-dom` 取运行时 DOM，逐节点比对结构 |
| `verify-vue.sh` + `imgdiff.py` | 四档视口（1440/1280/390/整页）截图 + 像素差异 |
| `behavior-check.mjs` | CDP 真实交互：复制按钮三态、canvas 动画推进、`.rv` 进场、无 JS 异常 |

渲染节点数是判断「Vue 是否真的挂载」的快速指标：正常主页 330+、文档页远大于 60；**个位数说明构建产物坏了（多为残留外链），不是样式问题**。
