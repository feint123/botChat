# botChat 落地页（Vue 3）

GitHub Pages 站点源码。仓库根目录的 `index.html` 是**构建产物**，不要手改。

## 命令

```bash
npm install
npm run dev        # 本地开发（热更新）
npm run build      # 构建到 web/dist/index.html（单文件内联）
npm run publish:dry # 只校验产物，不写盘
npm run publish    # 校验通过后覆盖仓库根 index.html（会先备份旧版）
```

`npm run publish` 的前置校验：产物必须含 `id="app"`、不含外链 `<script src>`、不含 `<link rel="stylesheet">`、不含 `/assets/` 引用。任一条不满足即中止，不会写盘。

## 为什么是单文件产物

Pages 从 `main` 根目录发布，且根目录同时有 `appcast.xml`（Sparkle 自动更新依赖 `feint123.github.io/botChat/appcast.xml` 不能失效）。因此：

- 源码在 `web/`，产物落回仓库根 `index.html`，Pages 无需改任何配置
- 用 `vite-plugin-singlefile` 把 JS/CSS 全部内联，产物保持自包含，`file://` 可直接打开预览
- `.gitignore` 只忽略 `node_modules/`、`web/dist/` 等，**根 `index.html` 必须继续被 git 跟踪**

## 结构

```
web/
  index.html            Vite 模板（title / meta / #app 挂载点）
  vite.config.js        base:'./'、outDir:'dist'、singlefile
  scripts/publish.mjs   产物校验 + 备份 + 原子替换根 index.html
  src/
    main.js             注入 html.js / html.noanim、挂载、启用滚动进场、h1 淡入
    App.vue             按原 DOM 顺序组装 8 个区块组件
    lib/release.js      版本号入口（构建期从 appcast.xml 注入，见下）
    components/
      SiteTopline.vue   SiteNav.vue       SiteFooter.vue
      HeroSection.vue   OrchestrationCanvas.vue
      WorkspaceSection.vue                （三栏界面复刻，数据驱动）
      CapsSection.vue   FlowSection.vue   InstallSection.vue
    composables/
      useReveal.js               IntersectionObserver 滚动进场（.rv → .in）
      useOrchestrationCanvas.js  canvas 编排动效（分叉 → 并行 → 汇聚，CYCLE 7600ms）
    assets/                     真实应用图标 app-icon.webp + 吉祥物贴纸 sticker-1..9.webp
    styles/                    全局 CSS，按原分区拆分，index.css 控制导入顺序
```

## 版本号只有一个来源

`vite.config.js` 在构建时读仓库根 `appcast.xml`，取语义版本最大的 `<item>`，注入三个常量：

- `__APP_VERSION__`（shortVersionString，如 `1.1.2`）
- `__APP_BUILD__`（build 号）
- `__DMG_URL__`（`releases/download/v<version>/botChat-<version>.dmg`）

业务代码只从 `src/lib/release.js` 读，**不要在组件里硬编码版本号或下载链接**。发版只改 appcast.xml，落地页重新 build + publish 即可跟上。

## 图片素材

- 全部是 webp，放 `src/assets/`，由 `import` 引入（`assetsInlineLimit` 已拉满，构建时内联成 base64，保持单文件产物）
- 贴纸是装饰层：`position:absolute` + `pointer-events:none` + `alt=""`，语义上不进无障碍树；样式统一在 `src/styles/stickers.css`，小屏在 `responsive.css` 里收敛或隐藏
- 现在用到的：hero 2 张（sticker-3 等待 / sticker-2 困惑）、能力区 1 张（sticker-8 放大镜）、下载卡片 3 张（sticker-1/4/9）；sticker-5/6/7 备用

## 改样式 / 改文案的约定

- 样式一律改 `src/styles/*.css`，不在组件里写 `<style scoped>`。原因是原页面用的是全局 class（`.ws-*`、`.card`、`.flow` 等），改成 scoped 会改变选择器语义。
- class 名沿用原命名，不要改成 BEM 新命名，否则 CSS 与模板会脱节。
- 重复结构改数据数组（`CapsSection` 的 `cards`、`FlowSection` 的 `steps`、`WorkspaceSection` 的 `groups` / `entries` / `inspector`），不要复制粘贴 DOM。
- 图标统一用 `shapes` / `paths` 数据数组 + `v-for`，**不要用 `v-html`**。

## 已知上游问题（待产品确认）

`CapsSection.vue` 第 8 张能力卡保留了原文的重复标题：`<h3>设计系统库</h3><h3>设计系统库<span class="tag">76 套</span></h3>`。迁移时按 1:1 保真保留，代码里有注释标记。要修的话删掉第一个 `h3` 并去掉 `dupTitle` 标记即可。

## 验收

工作区上级目录 `.supervisor/` 下有四个校验脚本（不在本仓库内）：

| 脚本 | 作用 |
|---|---|
| `css-audit.py` | 逐个选择器/声明比对 CSS 是否覆盖改造前基线 |
| `dom-diff.py` | headless Chrome `--dump-dom` 取运行时 DOM，逐节点比对结构 |
| `verify-vue.sh` + `imgdiff.py` | 四档视口（1440/1280/390/整页）截图 + 像素差异 |
| `behavior-check.mjs` | CDP 真实交互：复制按钮三态、canvas 动画推进、`.rv` 进场、无 JS 异常 |
