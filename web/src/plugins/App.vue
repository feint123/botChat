<template>
  <div class="pp-top">
    <div class="pp-top-in">
      <a class="pp-back" href="./index.html">← botChat</a>
      <span class="pp-brand">插件开发文档</span>
      <span class="pp-tag">manifest v2</span>
      <span class="sp"><a href="https://github.com/feint123/botChat">GitHub ↗</a></span>
    </div>
  </div>

  <div class="pp-layout">
    <aside class="pp-toc">
      <p class="pp-toc-t">目录</p>
      <nav aria-label="章节目录">
        <a v-for="s in sections" :key="s.id" :href="'#' + s.id">
          <span class="n">{{ s.n }}</span><span>{{ s.title }}</span>
        </a>
      </nav>
    </aside>

    <main class="pp-main">
      <header class="pp-hero">
        <p class="pp-kicker">BOTCHAT · EXTENSIONS</p>
        <h1>写一个 botChat 插件</h1>
        <p class="lead">一个目录、一份 <code>manifest.json</code>、一个 <code>register(ctx)</code> 入口 —— 就是插件。
          这份文档的目标不是背 API，而是让你读完做出第一个能启用、能点、能被 Agent 调用的插件。</p>
        <div class="pp-chips">
          <span class="pp-chip"><b>清单</b> v2</span>
          <span class="pp-chip"><b>面板</b> botchat.panel/1</span>
          <span class="pp-chip"><b>SwiftUI</b> 唯一渲染体</span>
          <span class="pp-chip"><b>5</b> 个 slot + 1 个轮级行</span>
          <span class="pp-chip"><b>9</b> 个权限键</span>
          <span class="pp-chip"><b>6</b> 个档位 T1–T6</span>
        </div>
      </header>

      <section v-for="s in sections" :id="s.id" :key="s.id" class="pp-sec">
        <p class="pp-kicker">{{ s.n }} / {{ s.kicker }}</p>
        <h2>{{ s.n }} {{ s.title }}</h2>

        <template v-for="(b, bi) in s.blocks" :key="bi">
          <p v-if="b.k === 'p'" class="md">
            <span v-for="(x, xi) in b.v" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
          </p>

          <ul v-else-if="b.k === 'ul'" class="pp-list">
            <li v-for="(item, li) in b.v" :key="li">
              <span v-for="(x, xi) in item" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
            </li>
          </ul>

          <pre v-else-if="b.k === 'code'" class="pp-code" :data-lang="b.lang"><code>{{ b.v }}</code></pre>

          <div v-else-if="b.k === 'note'" class="pp-note" :class="{ warn: b.tone === 'warn' }">
            <span class="t">{{ b.title }}</span>
            <p v-for="(item, ni) in b.v" :key="ni">
              <span v-for="(x, xi) in item" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
            </p>
          </div>

          <h3 v-else-if="b.k === 'h3'">
            <span v-for="(x, xi) in b.v" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
          </h3>

          <div v-else-if="b.k === 'chips'" class="pp-chips">
            <span v-for="(ch, ci) in b.v" :key="ci" class="pp-chip"><b>{{ ch.t }}</b> {{ ch.d }}</span>
          </div>

          <div v-else-if="b.k === 'tbl'" class="pp-tbl-wrap">
          <table class="pp-tbl">
            <thead>
              <tr><th v-for="(h, hi) in b.head" :key="hi">{{ h }}</th></tr>
            </thead>
            <tbody>
              <tr v-for="(row, ri) in b.rows" :key="ri">
                <td v-for="(cell, ci) in row" :key="ci" :data-th="b.head[ci]">
                  <span v-for="(x, xi) in cell" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
                </td>
              </tr>
            </tbody>
          </table>
          </div>

          <div v-else-if="b.k === 'step'" class="pp-step">
            <div class="h"><span class="n">{{ b.n }}</span><span class="w">{{ b.w }}</span></div>
            <template v-for="(sb, si) in b.blocks" :key="si">
              <p v-if="sb.k === 'p'">
                <span v-for="(x, xi) in sb.v" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
              </p>
              <pre v-else-if="sb.k === 'code'" class="pp-code" :data-lang="sb.lang"><code>{{ sb.v }}</code></pre>
              <div v-else-if="sb.k === 'tbl'" class="pp-tbl-wrap">
              <table class="pp-tbl">
                <thead><tr><th v-for="(h, hi) in sb.head" :key="hi">{{ h }}</th></tr></thead>
                <tbody>
                  <tr v-for="(row, ri) in sb.rows" :key="ri">
                    <td v-for="(cell, ci) in row" :key="ci" :data-th="sb.head[ci]">
                      <span v-for="(x, xi) in cell" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
                    </td>
                  </tr>
                </tbody>
              </table>
              </div>
              <h3 v-else-if="sb.k === 'h3'">
                <span v-for="(x, xi) in sb.v" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
              </h3>
              <div v-else-if="sb.k === 'note'" class="pp-note" :class="{ warn: sb.tone === 'warn' }">
                <span class="t">{{ sb.title }}</span>
                <p v-for="(item, ni) in sb.v" :key="ni">
                  <span v-for="(x, xi) in item" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
                </p>
              </div>
              <ul v-else-if="sb.k === 'ul'" class="pp-list">
                <li v-for="(item, li) in sb.v" :key="li">
                  <span v-for="(x, xi) in item" :key="xi"><code v-if="x.code">{{ x.code }}</code><b v-else-if="x.strong">{{ x.text }}</b><template v-else>{{ x.text }}</template></span>
                </li>
              </ul>
            </template>
          </div>
        </template>
      </section>
    </main>
  </div>

  <footer class="pp-foot">
    <div class="in">
      <a href="./index.html">← 回到 botChat 主页</a>
      <span>契约正文：<code>docs/extension-plugin-contract.md</code> / <code>docs/extension-plugin-ui.md</code> / <code>docs/extension-panel-native.md</code></span>
      <span class="r">2025–2026 · macOS 26+ · arm64</span>
    </div>
  </footer>
</template>

<script setup>
// ── 极小的行内标记解析：反引号 ⇒ <code>，**双星** ⇒ 加粗。
// 只为了让正文数据可读，不引入 v-html 与任何依赖。
function md (raw) {
  const out = []
  const re = /`([^`]+)`|\*\*([^*]+)\*\*/g
  let last = 0
  let m
  while ((m = re.exec(raw)) !== null) {
    if (m.index > last) out.push({ text: raw.slice(last, m.index) })
    if (m[1] != null) out.push({ code: m[1] })
    else out.push({ text: m[2], strong: true })
    last = m.index + m[0].length
  }
  if (last < raw.length) out.push({ text: raw.slice(last) })
  return out
}

const p = (s) => ({ k: 'p', v: md(s) })
const ul = (...items) => ({ k: 'ul', v: items.map(md) })
const code = (lang, lines) => ({ k: 'code', lang, v: lines.join('\n') })
const note = (title, ...items) => ({ k: 'note', title, v: items.map(md) })
const warn = (title, ...items) => ({ k: 'note', tone: 'warn', title, v: items.map(md) })
const chips = (...items) => ({ k: 'chips', v: items.map(([t, d]) => ({ t, d })) })
const tbl = (head, rows) => ({ k: 'tbl', head, rows: rows.map((r) => r.map(md)) })
const h3 = (title) => ({ k: 'h3', title, v: md(title) })
const step = (n, w, ...blocks) => ({ k: 'step', n, w, blocks })

const sections = [
  {
    n: '01',
    id: 'what',
    kicker: '什么是插件',
    title: '插件是什么',
    blocks: [
      p('一个插件就是**一个目录**：目录名等于清单 `id`，目录里有一份 `manifest.json` 声明「我要什么」，一个 `register(ctx)` 入口把「怎么做」注册给宿主。没有第二套 API —— `sandboxed` 与 `in-process` 两种信任档复用**同一份**接口与错误语义。'),
      p('扫描阶段零代码执行：只有激活时才 import 你的入口，所以**模块顶层 MUST 无副作用**。一个插件也只有一个代码入口 —— `server.tool.entry` 与 `server.ui.entry` MUST 指向同一文件。'),
      chips(
        ['server.tool', '让 Agent 做得到'],
        ['server.ui', '产视图数据（面板拿到的 data）'],
        ['client.view', '把视图挂到五个槽位之一'],
        ['client.panel', '包内 Swift 原生面板'],
        ['client.command', 'QuickBar 可检索命令'],
        ['client.theme', '纯 JSON 主题包'],
        ['server.hook', '模型前 / 收尾钩子']
      ),
      p('五分钟能到什么程度：**一个零权限的 `hello` 包在真实宿主里被启用、被点击、被 Agent 调用**之后，剩下的都是往同一个形状里填内容。插件目录不在仓库里，落在运行时根 `<home_root>/Extensions/<id>/`。'),
      warn('这些是明确做不到的，别绕',
        '`server.masking.rules` / `server.provider` 登记但未实现：写了只得到一条诊断，不会生效。',
        '`dylib` / `.app` / 符号链接直接拒收；插件不能自带可执行二进制。',
        '`client.command.shortcut` 只是提示文本，客户端**不注册**任何热键。',
        '主题包唯一 root 是 `Bundle.main.resourceURL/Extensions`，第三方主题必须随 app 分发；插件互依赖 / 市场 / 远程安装 / `.bcext` 打包都不做。')
    ]
  },
  {
    n: '02',
    id: 'first',
    kicker: '第一个插件',
    title: '第一个插件：五步跑通最小闭环',
    blocks: [
      p('顺序是固定的：**生成骨架 → 填逻辑 → 静态对账 → 安装/启用/授权/重启 → 活体验证**。别跳步，也别手搓清单。'),
      step('1', '生成骨架', 
        p('脚手架会替你守住两条硬规则：包目录名 MUST 等于清单 `id`、`id` MUST NOT 以 `builtin.` 开头（内置包确实要该前缀时显式加 `--allow-builtin-prefix`）。'),
        code('bash', [
          'SKILL=~/.agents/skills/botchat-plugin-authoring',
          'python3 $SKILL/scripts/scaffold_plugin.py --id acme.hello --name "我的面板" --dir ~/dev/plugins --mode ui --slot panel',
          '#   --mode ui（缺省）| tool | native | theme',
          '#   --slot panel | window | composer.accessory | sidebar.section | settings.section（ui / native）',
          '#   --with-tool 在 ui 骨架里同时生工具入口（T5）；--with-hook 叠 server.hook',
          '#   生成 <dir>/<id>/ 并自动跑一次静态对账；--no-check 可跳过'
        ])),
      step('2', '填逻辑，并让声明与注册逐字对齐',
        p('这是最高频的翻车点。清单里写的东西和 `register(ctx)` 里注册的东西，必须一一对上：'),
        tbl(['清单里', '代码里', '不一致的后果'], [
          ['`server.ui.views: ["main","settings"]`', '`ctx.view("main", …)` / `ctx.view("settings", …)`', '声明了没注册 ⇒ 渲染时 `capabilityEntryMissing`；注册了没声明 ⇒ 该 view 永远挂不上'],
          ['`server.tool.tools: ["todo_add"]`', '`ctx.tool("todo_add", …)`', 'doctor 判硬伤（声明与登记不一致）'],
          ['`client.command.id: "acme.hello.open"`', '`ctx.command("acme.hello.open", …)`', '命令点不动'],
          ['`client.panel.views[].view`', '同上，且该 view 的 `client.view[].render` 为 `"native"`', '`render: native` 无同名 `client.panel` ⇒ 撤下该条']
        ])),
      step('3', '静态对账（每次改完清单都跑）',
        code('bash', [
          'python3 ~/.agents/skills/botchat-plugin-authoring/scripts/check_plugin.py ~/dev/plugins/acme.hello',
          '# 等价于：cd serverSide && BOTCHAT_EXTENSIONS_ROOT=<父目录> .venv/bin/python -m app.extensions.doctor'
        ]),
        p('退出码 `0` 通过 / `1` 有硬伤 / `2` 环境问题（找不到 `serverSide`，用 `--server-root` 指定）。输出里 `[info] userRootDisabled` 是**预期的**。'),
        p('这个包装器比裸 doctor 多做一件事：**原生面板源码门禁预检**（`client.panel` 的 `.swift` 按 `PanelSourceGate` 同一份规则查 import 白名单 / 禁用符号 / 写死颜色 / 体积）。但 doctor 口径必须看懂：它只做**静态**判定，**通过 ≠ 能激活**。')),
      step('4', '安装 → 启用 → 授权 → 重启宿主',
        p('插件目录落在运行时根：`<home_root>/Extensions/<id>/`（缺省 = `serverRoot()`，实际运行 app 时是 `~/Library/Application Support/botChat/server`，受 `BOTCHAT_HOME` 影响）。三条路任选一条：'),
        ul('**设置页安装（推荐）**：把包目录喂给 `POST /api/extensions/install`，body `{"source_path": "<本机绝对路径>"}`（只收本机目录，`~/` 可展开；MUST NOT 传 URL）。装完是「未启用、空授权」（`enabled` 恒为 false）。',
          '直接把包目录拷进 `Extensions/`（目录名 = id），重启宿主后在设置里启用。',
          '内置包（随 app 分发）走 `clientSide/botChat/Extensions/`，构建时进 bundle。'),
        code('http', [
          'POST /api/extensions/install                       { "source_path": "/abs/path/to/acme.hello" }',
          'POST /api/extensions/{id}/enable                    { "enabled": true }',
          'POST /api/extensions/{id}/permissions               { "permissions": { "fs.read": ["~/.botchat/todos"] } }',
          'POST /api/extensions/host/restart'
        ]),
        p('**改完代码必须重启宿主**：`host/restart` 会停 → 重扫磁盘 → 按库内 `enabled` 重新激活。本期没有热重载，停用只做到「工具不可调用」，宿主仍持有旧模块；若改的是 `serverSide/` 源码，app 形态下必须重新构建 App。')),
      step('5', '活体验证：三个探针，缺一个都不算跑通',
        tbl(['探针', '怎么做', '不通说明什么'], [
          ['启用态', '设置页能看到该插件且可启用；`GET /api/extensions` 里 `registered=true` / `enabled=true`', '包形态或清单被拒（看诊断码）'],
          ['视图', '打开面板：先看到树，再**点一次按钮数字要变**', '链路断在渲染或动作回包'],
          ['能力', '让 Agent 做一次该工具要做的事；看不到工具就先 `tool_search`', '工具没进能力目录 / 未启用 / 仍是 `extended`']
        ]),
        p('**插件工具缺省是 `extended`**：它不会被注入模型的 `tools` 数组，只经 `tool_search` 被发现。所以「写了工具但主 Agent 直接看不见」是预期行为，不是 bug。'))
    ]
  },
  {
    n: '03',
    id: 'tiers',
    kicker: '六个档位',
    title: '六个档位：先问形态，再写代码',
    blocks: [
      p('写任何一行代码之前先问出「要的是哪一档」。ID 与名称逐字固定，MUST NOT 另造别名；**MUST NOT 沉默假设** —— 不问就动手，返工成本是重写整包。'),
      tbl(['ID', '名称', '什么时候选它'], [
        ['T1', '`tool` 纯工具', '只要 Agent「做得到」、不需要人看见界面：查数据、记账、调本机工具'],
        ['T2', '`ui` 面板', '要面板 / 设置页 / 侧栏段 / 输入条配件；界面写 SwiftUI。与 T3 同形'],
        ['T3', '`native` 面板（= T2）', '与 T2 同形；保留这个 ID 只为兼容旧对话与脚本'],
        ['T4', '`theme` 主题包', '只换观感（46 角色配色；字体/度量 MUST NOT 进主题数据），没有任何代码与能力'],
        ['T5', '`combo` 工具+面板+命令组合', '一个包同时要「Agent 能调」+「人能看到能点」，并带 QuickBar 可检索命令'],
        ['T6', '`modify` 修改或调试已有插件', '包已存在，要改行为、加能力、修「不生效/空白/点不动」']
      ]),
      p('`server.hook` **不是第 7 种包型**，而是能力（capability）：可叠在 T1/T2/T3/T5 这类有代码入口的包上，也可单独成包（只有 hook、没有工具与界面）。'),
      h3('T2 与 T3 已合并'),
      p('`botchat.ui/1`（预制节点 IR）已全量下线，插件 UI 只剩**一种渲染体**：编译版 SwiftUI 面板。因此 T2 与 T3 产出的包同形 —— `server.ui` + `client.view(render: native)` + `client.panel` + 包内 `Panels/*.swift`。保留两个 ID 只为兼容旧对话与脚本，不再有「先用 IR、表达不了才升原生」这条路。'),
      p('面板的代价：编译链（首次挂载 `swiftc -Onone` 约 0.83s，`-O` 首编实测约 5.3s）、在宿主主进程内**同权运行**（不是沙箱）、以及出错时用户只看到占位。无工具链的机器上插件 UI 显示宿主导航占位（安装指引），**没有旁路渲染**。'),
      tbl(['需求', '选择'], [
        ['只要 Agent 做得到、人不需要看', 'T1 纯工具，不开界面'],
        ['人要看到数据 / 点按钮 / 改设置', '面板（`client.panel` + 包内 SwiftUI）']
      ]),
      p('档位 → 下一步命令的对应关系：`--mode tool --tool <name>`（T1）、`--mode ui --slot <slot>`（T2）、`--mode native --slot <slot>`（T3）、`--mode theme`（T4）、`--mode ui --with-tool`（T5）、T6 不生成骨架直接按「修改与调试」五条走。')
    ]
  },
  {
    n: '04',
    id: 'manifest',
    kicker: '清单 v2',
    title: '清单 v2：顶层字段与填错后果',
    blocks: [
      p('清单是 `manifest.json`（插件包 v2）。契约正文见 `docs/extension-plugin-contract.md` §一/§二/§三/§四，与代码冲突时以代码为准。顶层未知键记 `unknownKey` warning，**不拒包**。'),
      tbl(['字段', '必需', '缺省', '取值与填错后果'], [
        ['`schemaVersion`', '是', '—', '只认 `1` / `2`；未知值**拒整包**（`unknownSchemaVersion`）'],
        ['`id`', '是', '—', '全局唯一；**MUST 等于包目录名**（否则 `packageDirNameMismatch` 硬伤）；`builtin.` 前缀保留'],
        ['`name`', '是', '—', '展示名'],
        ['`version`', '是', '—', '点分版本；升/降级影响授权收敛（升版本新增权限不自动授予，收缩自动收敛）'],
        ['`minAppVersion`', '是', '—', '高于当前 app 版本即**拒整包**（`minAppVersionTooHigh`）。预发布后缀比同号正式版**旧**（`1.0.0-beta < 1.0.0`）'],
        ['`trust`', '否', '`data`', '`data` / `sandboxed` / `in-process`；非法值（含 `dylib` / `.app`）**拒整包**'],
        ['`activationEvents`', '否', '`[]`', '`onStartup` / `onCommand:<id>` / `onTool:<对外名>` / `onSlot:<slot>:<view>`；前缀外的项记 warning 并跳过。**本期只做声明与校验**，不驱动激活'],
        ['`permissions`', '否', '全空', '见「权限与信任」；未知键按**未授权**处理（不猜测放行）'],
        ['`capabilities`', '是', '—', '键带端前缀的开放集合，值是**嵌套 JSON 对象**（`client.view` 也可是对象数组）']
      ]),
      h3('能力 kind：键名带端前缀'),
      tbl(['kind', '必需下级键', '状态'], [
        ['`server.tool`', '`entry`（`.py`）、`tools`（非空字符串数组）', '已实现'],
        ['`server.ui`', '`entry`（`.py`）、`views`（非空字符串数组）', '已实现'],
        ['`client.view`', '`slot`、`view`、`title`；可选 `icon` `priority` `size` `lazy` `render`', '已实现'],
        ['`client.panel`', '`views: [{view, entry}]`；可选 `apiVersion`（只认 `1`）', '已实现'],
        ['`client.command`', '`id`、`title`；可选 `shortcut`', '已实现'],
        ['`client.theme`', '`entry`（`.json`）', '已实现'],
        ['`server.hook`', '`entry`、`events`；可选 `onError` `priority`', '已实现'],
        ['`server.masking.rules` / `server.provider`', '—', '**登记但未实现**：写了只得到一条诊断']
      ]),
      h3('两条硬约束（写错就是「能用一半」）'),
      warn('硬约束 1 — 目录名 MUST 等于 id',
        '`id` 与包目录名不一致 ⇒ `packageDirNameMismatch`，插件直接不出现在设置页。包目录名以点开头会被扫描器当隐藏目录跳过，所以 `acme.demo` 这种点**必须在中间**。'),
      warn('硬约束 2 — server.ui.entry 与 server.tool.entry MUST 指向同一文件',
        '一个插件只有一个 `register(ctx)`。两处不同文件时记 error 并**撤下 `server.ui`**（工具能力保留）—— 这就是「**工具能用、面板打不开**」的常见成因。'),
      p('另外两条会静默降级：`client.view.view` MUST 出现在同包 `server.ui.views` 里，否则解码期剔除（`capabilityEntryMissing`）；`slot` 是封闭集合 `panel` / `window` / `composer.accessory` / `sidebar.section` / `settings.section`，集合外取值**跳过该条**、不拒整包。'),
      h3('一段真实完整的清单（`examples/extensions/examples.hello-tool/manifest.json`）'),
      code('json', [
        '{',
        '  "schemaVersion": 2,',
        '  "id": "examples.hello-tool",',
        '  "name": "Hello Tool（样例插件）",',
        '  "version": "0.1.0",',
        '  "minAppVersion": "0.1.0",',
        '  "trust": "sandboxed",',
        '  "activationEvents": ["onTool:hello"],',
        '  "permissions": {},',
        '  "capabilities": {',
        '    "server.tool": {',
        '      "entry": "tools.py",',
        '      "tools": ["hello"]',
        '    }',
        '  }',
        '}'
      ]),
      p('`activationEvents` 里的 `onTool:` 写的是**对外名**（`<id 归一>__<工具名>`，点号与连字符变下划线），不是插件内名。口径写对是为了将来接上事件驱动时不用返工 —— 本期它不参与激活判定。')
    ]
  },
  {
    n: '05',
    id: 'api',
    kicker: 'register(ctx)',
    title: 'register(ctx) 与工具',
    blocks: [
      p('入口只有这一个函数：`def register(ctx):`。宿主在激活时调用一次；插件之间互不可见（模块名 `botchat_ext_<sanitized_id>`，跨插件 `import` 必失败），激活预算 10s，超时该插件本期整体不可用（`pluginActivationTimeout`）。'),
      tbl(['方法', '说明', '违反时'], [
        ['`ctx.tool(name, handler, *, description="", input_schema=None)`', '注册工具；`name` 是**插件内名**', '空名 / 重名 ⇒ 抛 `HostFault`（不静默覆盖）'],
        ['`ctx.view(name, handler)`', '注册视图渲染器；`name` MUST 在清单 `server.ui.views` 里', '空名 / 不可调用 / 重名 ⇒ 抛'],
        ['`ctx.command(command_id, handler)`', '注册命令处理器；`id` MUST 与清单 `client.command.id` 一致', '同上'],
        ['`ctx.log(message, **fields)`', '写宿主日志（落主进程诊断面）', 'MUST NOT 打明文/凭据'],
        ['`ctx.tools` / `ctx.views` / `ctx.commands`', '已注册项的只读快照（属性，不是方法）', '—']
      ]),
      p('工具对外名 = `<sanitized_id>__<sanitized_tool_name>`（点号与连字符归一下划线，总长 ≤ 64）。模型与能力目录只认**对外名**；`ext.tool.call` 只认插件内名。工具预算 30s，清单不可放大。'),
      h3('工具注册（`examples/extensions/examples.hello-tool/tools.py` 节选）'),
      code('python', [
        'def register(ctx):',
        '    """注册 `hello` 工具（由 extension-host 在激活时调用一次）。"""',
        '',
        '    def hello(arguments):',
        '        """回一句问候：`name` 缺省为「世界」。"""',
        '        name = arguments.get("name")',
        '        target = name.strip() if isinstance(name, str) and name.strip() else "世界"',
        '        return {"message": f"你好，{target}！这句来自样例插件的工具。"}',
        '',
        '    ctx.tool(',
        '        "hello",',
        '        hello,',
        '        description="向指定名字打招呼（样例插件的示例工具，零权限）",',
        '        input_schema={',
        '            "type": "object",',
        '            "properties": {"name": {"type": "string", "description": "要问候的名字"}},',
        '        },',
        '    )'
      ]),
      p('handler 收一个 `dict`、回一个**可 JSON 序列化**的值；返回值不可序列化 ⇒ `invalid_result`（宿主不会 `str()` 兜底）；抛异常 ⇒ 该次工具调用失败（不中断 run），业务失败请用返回体表达，用户能读到原因。'),
      h3('视图注册与渲染（`examples/extensions/examples.hello-panel/ui.py` 节选）'),
      code('python', [
        'def render_main(payload: dict[str, Any]) -> dict[str, Any]:',
        '    instance_key = str(payload.get("instanceKey", "") or "")',
        '    if payload.get("nodeId") == "press":',
        '        _bump(instance_key)',
        '    values = payload.get("values") or {}',
        '    verbose = bool(values.get("verbose")) if isinstance(values, dict) else False',
        '    return _panel_tree(',
        '        instance_key=instance_key,',
        '        pressed=verbose,',
        '        count=_COUNTS.get(instance_key or "-", 0),',
        '    )',
        '',
        'def register(ctx: Any) -> None:',
        '    """插件唯一入口（`server.ui.entry` 指向本文件）。"""',
        '    ctx.view("main", render_main)',
        '    ctx.view("compact", render_compact)',
        '    ctx.view("settings", render_settings)',
        '    ctx.view("native", render_native)',
        '    ctx.command("examples.hello-panel.open", on_open)'
      ]),
      p('视图 handler 是**渲染与交互共用**同一个函数，`payload` 的键：`view` / `instanceKey` / `state` 恒有（`state` 只含白名单公开事实：`workspaceName`、有会话时的 `conversationTitle`），交互时多出 `nodeId` / `values` / `arguments`。'),
      p('返回**整棵树**（`botchat.ui/1`）或**数据对象**（`botchat.panel/1`），由清单 `render` 决定，**插件不能自己选**。没有 patch / diff：回一模一样的树 ⇒ 界面不变，用户会以为「点了没反应」。'),
      p('`ctx.host` 只有三个命名空间：`ctx.host.fs.read(path: str)` / `ctx.host.fs.write(path: str, text: str)` / `ctx.host.net.fetch(url, *, method="GET", headers=None, body=None)` / `ctx.host.llm.invoke(role: str, messages: list[dict[str, str]])`。四条口径：实参 MUST 是绝对路径（`${workspace}` **不会**被替换）；`net` 权限是精确 host（不许通配）；**渲染期禁写**（`fs.write` / `net.fetch` 在 `ui.render` 期间直接 `permissionDenied`）；`llm.invoke` 本期显式失败（`hostUnavailable`）。')
    ]
  },
  {
    n: '06',
    id: 'panels',
    kicker: '面板',
    title: '面板：插件 UI 的唯一渲染体',
    blocks: [
      p('`botchat.ui/1`（预制节点 IR）已全量下线。**插件 UI 只有一种渲染体**：编译版 SwiftUI 面板（`botchat.panel/1`）。没有第二套渲染器，也没有「零工具链也能看」的降级渲染面 —— 本机没有 Swift 工具链时，插件 UI 显示宿主导航占位（安装指引），MUST NOT 回落到任何旁路渲染。'),
      h3('三处声明必须同时成立'),
      p('缺任何一条，该 `client.view` 会在**解码期被撤下**（打开它只剩占位）：`client.view[].render` MUST 是 `"native"`；`client.panel.views[].view` MUST 与该条 `client.view` 的 `view` 同名；该 `view` MUST 也在 `server.ui.views` 里。**没有「纯客户端面板」** —— 原生面板仍由服务端产数据。'),
      code('json', [
        '"client.view": [{ "slot": "panel", "view": "hits", "title": "命中", "render": "native" }],',
        '"client.panel": { "views": [{ "view": "hits", "entry": "Panels/Hits.swift", "apiVersion": 1 }] }'
      ]),
      p('`entry` MUST 是包内相对路径、`.swift`、不逃出包根、单文件 ≤ 256 KB；另一种形态是 `bundle`（作者侧用自带 Xcode + Kit 预编好的自包含产物，`.bundle`）。两者至少一个，都给时由客户端按「bundle 优先、否则 entry」解析。`apiVersion` 只认 `1`。'),
      h3('入口必须是一个 C 符号'),
      warn('旧的固定类名已被门禁拦下',
        '入口 MUST 用 `@_cdecl("botchat_panel_entry")` **导出恰好一次**，MUST NOT 给入口挂固定 ObjC 类名。`@objc(BotChatPanelEntry)` 这类写法报 `nativeSourceRejected`（文案「入口类名固定（已废弃写法）」）—— 类名是**进程级全局命名空间**，ObjC runtime 对同名类只注册先到者，同进程第二个面板必然拿不到自己的类。',
        '宿主只认这个 **C 符号**（按镜像解析，不按类名查表）；缺符号或入口返空 ⇒ `nativeEntryMissing`（不是白屏）；导出两次是链接期重复符号 ⇒ `nativeCompileFailed`。'),
      code('swift', [
        'struct MainPanelEntry: PanelEntry {',
        '    static func makeInstance(host: PanelHost) -> PanelInstance { MainPanelInstance(host: host) }',
        '}',
        '',
        '/// 宿主按符号 `botchat_panel_entry` 取它（按镜像解析，不按类名查表）。',
        '@_cdecl("botchat_panel_entry")',
        'public func mainPanelEntry(_ hostRaw: UnsafeMutableRawPointer) -> UnsafeMutableRawPointer? {',
        '    botchatPanelInstance(MainPanelEntry.self, hostRaw)',
        '}'
      ]),
      p('`PanelInstance` 的实现类**仍需**是 `NSObject` 子类（它是 `@objc` 协议，要 ObjC 兼容）；入口类型只 conform `PanelEntry`，可以是 struct / enum。'),
      h3('视图函数回的是数据，不是树'),
      p('顶层 MUST 是 JSON 对象、≤256 KB、深度 ≤8、单数组 ≤2000 项、键名 `[A-Za-z_][A-Za-z0-9_]*` 且 MUST NOT 以 `_` 开头、图片只允许裸 `assetId` 或 `/api/media/{id}`。越界是**整帧拒 + 占位，MUST NOT 截断后继续渲染**（截断会让面板显示半张表，用户看不出少了什么）。本地第二个纯函数：`app.extensions.ui_panel_payload.validate_panel_data(data)`。'),
      tbl(['纪律', '口径'], [
        ['实例持有视图', '`update(data:)` 里只换 `hosting.rootView`，MUST NOT 重建 `NSView` / `NSHostingView` —— 实测同类型 `rootView` 赋值能保住 `@State`（滚动、焦点、输入框内容），重建会全丢'],
        ['幂等', '同一份 data 连推两次结果一致'],
        ['取色', '只经 `host.panelColor(role)`（或 `host.color(role)`），返回动态色，MUST NOT 转成固定 RGB 缓存，否则主题切换后不跟随'],
        ['视觉同源', '用 `BotChatKit` 的组件与角色；面板根 MUST 挂 `panelKitRoot(host)` 注入 palette 并钉住字号缩放，MUST NOT 自建 palette'],
        ['不许自己取数', '数据一律来自 `data`，动作一律 `host.dispatch`（宿主生成幂等 action_id 并串行发给服务端）'],
        ['尺寸', '由宿主钳制（`composer.accessory` ≤44pt、`sidebar.section` ≤240pt、`panel` 随列宽）']
      ]),
      p('源码门禁（`PanelSourceGate.swift`，**注释文本同样命中**）：import 只许 `SwiftUI` `AppKit` `Foundation` `Observation` `CoreGraphics` `AVKit` `AVFoundation` `BotChatKit`；禁用符号子串匹配 `FileManager` `URLSession` `Process(` `NSTask` `NSAppleScript` `NSWorkspace` `dlopen` `dlsym` `SecItem` `CGEvent` `AXUIElement` `NSWindow(` `NSPanel(`；写死颜色一律拒；≤256 KB / ≤4000 行。'),
      p('编译链：包内 `Panels/X.swift` → 门禁 → `swiftc`（SDK 源 + 面板源同批）→ `Panel.bundle` → 实例。参数固定 `-emit-library -Xlinker -bundle -module-name P_<hash8> -swift-version 5 -Onone`，模块名必带哈希。缓存键 = 面板源码 + SDK 源 + 参数 + `swiftc --version`，落 `~/Library/Application Support/botChat/PanelBuilds/<hash>/`。无工具链 ⇒ `nativeToolchainMissing` 占位 + 安装指引，**没有旁路渲染**。'),
      p('两个客户端侧事实：1.1.22 起插件界面**只保留原生面板一种呈现形态** —— 仍只提供旧式预制节点界面的插件，其界面不再显示，面板位置给出说明与入口（该插件需要更新）；同一版修好了面板**取色不完整**导致的部分配色异常（浅色主题下曾出现黑底输入框、黑字按钮），面板配色现在完整跟随主题的浅/深外观。'),
    ]
  },
  {
    n: '07',
    id: 'hooks',
    kicker: 'hook 与生命周期',
    title: 'hook 与生命周期：每轮收尾产出一行',
    blocks: [
      p('`server.hook` 让插件在**模型调用前**或 **run 结束后**注入消息片段。它由清单声明与模块导出两半组成：清单声明事件、优先级、失败策略；代码导出**模块级 `hooks` 字典**（不是 `ctx.hook(...)` —— 宿主在激活时只读这个字典的键名，真正调用发生在 `ext.hook.run`）。'),
      tbl(['字段', '必需性', '缺省', '拒绝条件'], [
        ['`entry`', '**必需**', '—', '缺失 / 非字符串 ⇒ error，能力不可用；MUST 与 `server.tool` / `server.ui` 同文件'],
        ['`events`', '**必需**', '—', '缺失 / 非字符串数组 ⇒ error'],
        ['`onError`', '可选', '`"continue"`', '非法取值 ⇒ error；`abort` **只在 `pre_model` 有效**，其它事件降级为 `continue` 并记 `hookAbortInvalidEvent`'],
        ['`priority`', '可选', '`100`', '布尔值 ⇒ warning + 回落。内置注入块最大卡位 44，故插件恒在其后，**不建议设更小值**']
      ]),
      p('**事件放行集** = `{pre_model, run_finished}`；已知集六项 = `{pre_model, post_model, pre_tool, post_tool, idle, run_finished}`，其余四事件声明后会记 `hookEventWithoutDispatch`（认识但无派发点），不会拒清单。`trust` 不能写 `data`（记 `trustMismatch` 并跳过该能力）；多代码类 kind 指向不同 entry 记 `entryMismatch`。'),
      p('payload 是**白名单投影**五项顶层键：`conversationId` / `userContent` / `messages` / `extra` / `omittedMessageCount`。`messages` 每项只有 `role` / `content`，**拿不到** `bot` / `attachments` / `tool_calls` / `reasoning_content` / 图片字节；不可投影项是**整条省略**并用 `omittedMessageCount` 表达，不是置空。'),
      p('回传体只认两键 `messages` / `extra`，消息项只认三键 `position` / `role` / `content`；`position` 四枚举：'),
      tbl(['position', '插入语义'], [
        ['`after-system-prefix`', '插在所有前导 system 消息之后（最安全默认）'],
        ['`end`', '追加到可见消息末尾'],
        ['`user-before`', '插在**最后一个** user 消息之前；没有 user 消息时追加到末尾'],
        ['`index:N`', '插在第 N 个可见项之前（越界 ⇒ `index_out_of_range` / `index_in_prefix`）']
      ]),
      p('`role` 只允许 `system` / `user`，写 `assistant` / `tool` 整次拒绝。预算：新增条数 8、单条 content 65 536 字节、新增总量 262 144 字节、`extra` 8 192 字节、事件累计 524 288 字节；任一不合规**整次拒绝、不部分生效**（`hookRejected`）。'),
      code('python', [
        'def pre_model(payload):',
        '    seen = len(payload.get("messages") or [])',
        '    return {',
        '        "messages": [',
        '            {',
        '                "position": "after-system-prefix",',
        '                "role": "system",',
        '                "content": (',
        '                    "[HelloHook] 这条注入来自样例插件 examples.hello-hook 的 pre_model 钩子；"',
        '                    f"它看到的可见消息数是 {seen}。样例用途，可在设置里停用。"',
        '                ),',
        '            }',
        '        ]',
        '    }',
        '',
        '',
        'hooks = {"pre_model": pre_model}'
      ]),
      p('执行预算 `HOOK_TIMEOUT_SECONDS = 2.0`；异常隔离：插件异常不影响 run，只把失败类别记为 `crashed` 并继续（连续崩溃 2 次拉黑宿主，连续失败 3 次强制重建）。注册名格式三段冒号 `<extension_id>:<event>:<hook_name>`；启用时注册、停用时逐项摘除（**MUST NOT 清事件**）。'),
      h3('时间线行与工作区快照'),
      p('自 1.1.21 起插件能在**时间线上产出自己的行卡片**：清单声明 `client.row`（「每轮收尾自动产生一行」），配合轮次起止 hook 采集本轮事实，行内用原生面板渲染。**行不是 slot** —— 它无实例键、无 rev、不进快照 LRU，载荷只有 32 KiB。'),
      p('同一版新增**工作区快照接口**：插件在 hook 里取本轮变更文件清单时**不能指定路径**，读哪个仓库由宿主按会话决定 —— 因此不存在借插件绕开路径授权的口子。'),
      p('1.1.20 起插件还能**读取并操作目标台账**：待办类插件能把用户交代的事变成 botChat 真正执行的目标；写入仍只走既有状态机。'),
      warn('生命周期口径：没有热重载',
        '只改插件包内容（`.py` / `.swift` / `manifest.json`）⇒ `POST /api/extensions/host/restart`（停 → 重扫 → 按库内 `enabled` 重激活，黑名单不清）。',
        '改了 `serverSide/` 源码 ⇒ app 形态下必须**重新构建 App** 再启动（运行的是 bundle 里的 server 拷贝）。',
        '被拉黑（连续 2 次崩溃）⇒ `POST /api/extensions/{id}/unblock`（幂等；未拉黑回 `removed=false`）再启用。',
        '停用只做到「不可调用」：宿主仍持有模块，改包仍需重启宿主。')
    ]
  },
  {
    n: '08',
    id: 'trust',
    kicker: '权限与信任',
    title: '权限与信任：授权是人的显式动作',
    blocks: [
      p('缺省全空：零出网、零 keychain、零 workspace 写、零宿主工具、零模型调用。清单只写「请求」，实际授权落 `extension_state.permissions_json`。'),
      tbl(['键', '形态', '生效点'], [
        ['`fs.read` / `fs.write`', '路径前缀数组（`${workspace}` 会被**清单侧**展开）', '宿主代发 + `realpath` 前缀比对；**写不隐含读**'],
        ['`net`', 'host 数组（精确匹配，不许通配）', '`ctx.host.net.fetch` 由宿主代发'],
        ['`keychain`', '键名数组', '预留（本期无实现路径）'],
        ['`tools`', '宿主工具名数组', '预留'],
        ['`llm`', '角色数组', '`ctx.host.llm.invoke`（协议齐备但**显式失败** `hostUnavailable`）'],
        ['`clipboard`', '布尔', '预留']
      ]),
      p('**授权是人的显式动作**：`enabled: true` MUST 来自人的动作，MUST NOT 由扫描自动触发。授权端点里出现过的键**整体替换**，没出现的键保持原样，给空数组即撤销；清单没请求过的键会被拒并记 `permissionDenied`（不是静默丢弃）。升版本新增权限不自动授予，权限收缩自动收敛，响应带 `pending_keys`（请求了但未授权）与 `converged_keys`（被裁掉的键）。'),
      h3('三档执行位置（trust）'),
      tbl(['档位', '执行位置', '适用'], [
        ['`data`', '**不执行代码**', '主题包、纯数据包。声明代码能力 ⇒ 拒绝该能力（warning），不拒包'],
        ['`sandboxed`（代码缺省）', 'extension-host 子进程', '外部插件'],
        ['`in-process`', '主进程内导入', '仅用户 root **且** 设置里开了「信任本地插件」（`EXTENSIONS_TRUST_LOCAL`）；`builtin.` 一律降级']
      ]),
      p('`trust` 与原生面板无关：`trust` 管服务端 Python 在哪跑。文件权限最容易踩的坑是路径形态 —— **`${workspace}` 只在清单侧展开**，插件代码里 `ctx.host.fs.write("${workspace}/x")` 必被判越界（不是绝对路径）；**两侧都用 `~` 前缀**才是唯一能对齐的形态。'),
      code('json', [
        '"permissions": {',
        '  "fs.read":  ["~/.botchat/todos"],',
        '  "fs.write": ["~/.botchat/todos"]',
        '}'
      ]),
      p('另一条硬边界：**渲染期禁写**。`fs.write` / `net.fetch` 在 `ui.render` 期间调用会被直接拒（`permissionDenied`）且不发出任何请求；读盘可以放渲染首帧，写只能发生在动作（`ui.action`）与工具调用里。')
    ]
  },
  {
    n: '09',
    id: 'debug',
    kicker: '排障',
    title: '排障：现象 → 原因 → 处置',
    blocks: [
      p('三步定位法（别跳步）：① `check_plugin.py <包目录>` 查清单 / 包形态 / 原生面板门禁（离线、零副作用）；② 本地跑载荷校验纯函数 `app.extensions.ui_panel_payload.validate_panel_data(data)`（面板 ≤256 KB / 深度 ≤8 / 单数组 ≤2,000 项；行 ≤32 KiB）；③ 装好后看 `GET /api/extensions` 的诊断列表与 `GET /api/extensions/views`。'),
      tbl(['现象', '原因', '处置'], [
        ['设置页根本没有这个插件', '目录名 ≠ `id`（`packageDirNameMismatch`）/ 清单 JSON 坏（`invalidJSON`）/ `minAppVersion` 高于当前 app（`minAppVersionTooHigh`）/ `schemaVersion` 不是 1、2（`unknownSchemaVersion`）', '跑 `check_plugin.py` 看 error 级诊断'],
        ['插件在、启用后没反应', '宿主没重扫 / 没激活（装配层只在启动、启用、`host/restart` 时激活）', '`POST /api/extensions/host/restart`，再看该行诊断'],
        ['面板空白 / 显示占位', '`data` 不合规（码名 `irInvalid`，历史包袱但语义已收敛为「载荷不合规」）或超预算；也可能是三向声明缺一条', '本地用 `validate_panel_data(data)` 复现看 `code` + `path`；再查 `render: native` ↔ `client.panel` ↔ `server.ui.views` 是否同名齐备'],
        ['点了按钮界面不变', '交互分支回了和上次**逐字相同**的树（本通道无 patch）', '让返回值带上变化量（计数、时间、状态）'],
        ['工具「存在但模型看不到」', '插件工具缺省 `extended`', '让 Agent 先 `tool_search`；或把能力目录里该工具启用'],
        ['工具调不到 / 调用报 `permissionDenied`', '清单请求了但没授权、渲染期写盘、路径越界、清单没请求的键', '补 `permissions` + 授权端点；把写操作移出渲染路径'],
        ['声明了挂载点却看不到', '`client.view.view` 不在 `server.ui.views`（`capabilityEntryMissing` 剔除）/ `slot` 拼错（跳过该条）/ 插件未启用', '`GET /api/extensions/views` 只回已启用插件的槽位'],
        ['工具能用、面板打不开', '`server.ui.entry` ≠ `server.tool.entry` ⇒ `server.ui` 被静默撤下', '两个 entry 指向同一文件'],
        ['面板一片报错（`nativeSourceRejected`，文案「入口类名固定（已废弃写法）」）', '入口还挂着 `@objc(BotChatPanelEntry)` 之类固定类名', '删掉该注解，改用 `@_cdecl("botchat_panel_entry")` 导出入口'],
        ['面板一片报错（`nativeEntryMissing`）', '没导出符号（写错 / 导出两次 / entry 路径不在包内 / 客户端用了自己拼的根路径）、`apiVersion` ≠ 1', '改入口导出与 `client.panel.entry`；包根只认服务端下发的 `roots`'],
        ['原生面板编译失败（`nativeCompileFailed` / `nativeSourceRejected`）', '用了门禁 API（出网 / 文件 / 子进程相关）或不是 bundle 友好代码；**注释里出现禁用词也算**', '只经 `data` 取数、只经 `host.dispatch` 动作'],
        ['`nativeToolchainMissing`', '本机没有 `swiftc`', '装 Xcode Command Line Tools；插件 UI 只显示安装指引占位，无旁路渲染'],
        ['`pluginBlacklisted`', '连续 2 次崩溃被拉黑', '修好后 `POST /api/extensions/{id}/unblock` 再启用'],
        ['改完代码行为没变', '无热重载，宿主还持有旧模块', '重启宿主（app 形态要重启整个 app）']
      ]),
      p('其它常在诊断里出现的码：`unknownCapabilityKind`（拼错的 kind）、`missingPrefix`（键没有 `client.` / `server.` 前缀）、`unimplementedCapabilityKind`（`server.masking.rules` / `server.provider`）、`unknownKey`（下级键不认识，如 `server.tool.timeout_ms`）、`trustMismatch`、`entryMismatch`、`entryFileMissing` / `entryOutsidePackage`、`packageEntrySuffix`、`packageForbiddenFile`、`extensionIdConflict`、`viewNotDeclared`、`actionRejected`、`extensionDisabled`、`toolNameConflict`、`pluginCrashed`、`pluginActivationTimeout`、`hookRejected`、`nativeConsentDeclined`。'),
      warn('诊断面在哪看',
        '`GET /api/extensions`（列表 + 诊断）、`GET /api/extensions/views`（槽位与命令投影，含 `roots.user` / `roots.builtin` —— 原生面板定位的唯一依据）、`GET /api/extensions/views/{ext}/{view}`（渲染一帧）、`POST /api/extensions/commands/{command_id}`、`POST /api/extensions/host/restart`。',
        'doctor 通过只代表「静态可加载」：entry 文件存在且可读，**它不证明子进程能起来**。')
    ]
  },
  {
    n: '10',
    id: 'examples',
    kicker: '示例索引',
    title: '示例索引：五个能直接跑的真身',
    blocks: [
      p('仓库内路径都在 `examples/extensions/`（服务端样例目录；在服务端代码树里是 `serverSide/examples/extensions/`）。读一个形态最接近你要的包，比从零写快。'),
      tbl(['示例包', '演示什么', '仓库内路径'], [
        ['`examples.hello-tool`', '`server.tool` 最小可用形态：纯逻辑、零权限、无 UI。「启用 → 激活 → 注册 → 调用 → 返回」这条链路的真身', '`examples/extensions/examples.hello-tool/`（`manifest.json` + `tools.py`）'],
        ['`examples.hello-panel`', '多槽位面板：同一个 `server.ui` 入口，`main`（面板）/ `compact`（窗口）/ `settings`（设置区）各产 data，三个视图各有包内 SwiftUI 源；还挂了一条只回 `{"text": …}` 的命令', '`examples/extensions/examples.hello-panel/`（`manifest.json` + `ui.py` + `Panels/Hello.swift`）'],
        ['`examples.hello-hook`', '`server.hook` 与工具共用同一 entry：模块级 `hooks` 字典 + `pre_model` 注入一条 `after-system-prefix` 消息', '`examples/extensions/examples.hello-hook/`（`manifest.json` + `hooks.py`）'],
        ['`examples.todo-list`', '持久化 + 工具 + 原生面板的组合（T5 形态）：`fs.read` / `fs.write` 权限、四个工具、`render: native` 面板、设置区', '`examples/extensions/examples.todo-list/`（`manifest.json` + `plugin.py` + `Panels/Todo.swift`）'],
        ['`examples.svg-icon`', '包内 SVG 图标的三种形态：`tint` 缺省 `template` 由宿主着色、`tint: original` 保留自带渐变、非方 `viewBox` 等比缩放。图标是清单 `client.view.icon` 的字段，**不进面板 data**、不计入任何预算', '`examples/extensions/examples.svg-icon/`（`manifest.json` + `ui.py` + `Icons/mark.svg` 等）']
      ]),
      p('拿不准的时候：契约正文在 `docs/extension-plugin-contract.md`（清单 / 接口 / 诊断码 / 未实现清单）；行为真相在 `serverSide/tests/extensions/**` —— 读测试比读文档快，且测试锁的就是当前行为。'),
      note('在本页还没提到的一步：授权前先自己验一遍',
        '载荷校验是不需要数据库、不需要起服务、不需要装插件的纯函数：`validate_panel_data(data)`。先让它在本地通过，再去装包 —— 装完之后你看到的是「占位」，本地看到的是 `code` + `path`。'),
      p('下一步：翻 `references/intake.md` 的七类目录决定你的包该长什么样，然后回到第 2 章按五步走一遍。页脚印着回主页的链接。')
    ]
  }
]
</script>
