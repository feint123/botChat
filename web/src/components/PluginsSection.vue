<script setup>
import { PLUGINS_DOC_URL } from '../lib/release.js'

// 事实来源：skills/botchat-plugin-authoring/references/manifest.md（能力 kind 与槽位）、
// SKILL.md（六个档位）、examples/extensions/*（真实示例形态）。
// 只陈述这几份文档里写明的东西，不写未实现的承诺。
const points = [
  {
    shapes: [
      { tag: 'path', d: 'M6 3h9l4 4v14H6z' },
      { tag: 'path', d: 'M15 3v4h4M9.5 13h6M9.5 16.5h4' }
    ],
    title: '一个目录 + 一份清单',
    desc: '插件就是一个目录：manifest.json 声明能力，一个 register(ctx) 入口文件注册工具与视图。id 必须等于目录名。'
  },
  {
    shapes: [
      { tag: 'rect', x: '3.5', y: '4.5', width: '17', height: '15', rx: '2' },
      { tag: 'path', d: 'M3.5 9h17M9 19.5V9' }
    ],
    title: '五个挂载点',
    desc: 'panel 面板列、window 独立窗口、composer.accessory 输入条、sidebar.section 侧栏分区、settings.section 设置页。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M8 4H5.5A1.5 1.5 0 0 0 4 5.5v13A1.5 1.5 0 0 0 5.5 20H8M16 4h2.5A1.5 1.5 0 0 1 20 5.5v13a1.5 1.5 0 0 1-1.5 1.5H16M12 3v18' }
    ],
    title: '面板两条路线',
    desc: '预制节点用 IR 树（宿主排版取色），表达不了就写原生 SwiftUI 面板；后者以 @_cdecl 导出入口。'
  },
  {
    shapes: [
      { tag: 'circle', cx: '12', cy: '12', r: '3.2' },
      { tag: 'path', d: 'M12 3v3M12 18v3M3 12h3M18 12h3M5.6 5.6l2.1 2.1M16.3 16.3l2.1 2.1M18.4 5.6l-2.1 2.1M7.7 16.3l-2.1 2.1' }
    ],
    title: 'hook 与时间线',
    desc: '声明 server.hook 后可在轮次收尾产出一行自己的记录，或用轮次起止钩子采集本轮事实。'
  }
]

// 示例名与职责取自 examples/extensions/ 下的真实包
const samples = [
  { id: 'examples.hello-tool', what: '纯工具，零界面' },
  { id: 'examples.hello-hook', what: '轮次钩子' },
  { id: 'examples.hello-panel', what: 'IR 面板与原生面板并存' },
  { id: 'examples.todo-list', what: '原生面板 + 四个待办工具' },
  { id: 'examples.svg-icon', what: 'SVG 图标作入口图标' }
]
</script>

<template>
  <section class="block" id="plugins">
    <div class="wrap">
      <p class="kicker">EXTENSIONS</p>
      <h2>不够用，就自己接。</h2>
      <p class="lead rv">插件能往宿主里加工具、面板、命令与主题：一份声明式清单，加一个 register(ctx) 入口。</p>

      <div class="grid">
        <div v-for="p in points" :key="p.title" class="card rv">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><template v-for="(s, i) in p.shapes" :key="i"><path v-if="s.tag === 'path'" :d="s.d" /><rect v-else-if="s.tag === 'rect'" :x="s.x" :y="s.y" :width="s.width" :height="s.height" :rx="s.rx" /><circle v-else :cx="s.cx" :cy="s.cy" :r="s.r" /></template></svg>
          <h3>{{ p.title }}</h3>
          <p>{{ p.desc }}</p>
        </div>
      </div>

      <div class="pl-more rv">
        <div class="pl-samples">
          <p class="pl-samples-t">仓库内随附示例</p>
          <ul>
            <li v-for="s in samples" :key="s.id"><code>{{ s.id }}</code><span>{{ s.what }}</span></li>
          </ul>
        </div>
        <div class="pl-cta">
          <p>从最小闭环开始：先让一个零权限插件被启用、被点击、被 Agent 调用，再往里填功能。</p>
          <a class="btn btn-p" :href="PLUGINS_DOC_URL">查看插件开发文档
            <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M5 12h13m0 0-5-5m5 5-5 5"/></svg>
          </a>
        </div>
      </div>
    </div>
  </section>
</template>
