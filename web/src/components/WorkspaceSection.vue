<script setup>
// WorkspaceSection: section#workspace 三栏复刻（L244-L289），数据驱动。
// class 契约（样式来自 workspace.css，只读）：
// .ws-win / .ws-bar / .ws-dots / .ws-title / .ws-state
// .ws-cols / .ws-sess / .ws-tools / .ws-new / .ws-layout
// .ws-gcap / .ws-more / .ws-me / .ws-face / .ws-gear
// .ws-flow / .ws-tl-hd / .ws-tl-t / .ws-tl-s / .ws-go
// .ws-tl / .ws-meta / .ws-dot / .ws-who2 / .ws-time
// .ws-body / .ws-bl / .ws-status / .ws-tool / .ws-path
// .ws-delta / .ws-runline / .ws-cmp / .ws-box / .ws-ph
// .ws-crow / .ws-plus / .ws-pill / .ws-stop / .ws-insp
// .ws-ibar / .ws-chip / .ws-ctx / .ws-task / .ws-tc
// .ws-note （以上 ws- 类名全部沿用原文，一个不改名）

const layoutRects = [
  { x: '4', y: '4', w: '7', h: '16', rx: '1.5' },
  { x: '13', y: '4', w: '7', h: '16', rx: '1.5' }
]
const faceRects = [{ x: '4', y: '8', w: '16', h: '11', rx: '3' }]
const facePaths = ['M12 4v4M9 13h.01M15 13h.01']
const gearCircle = { cx: '12', cy: '12', r: '3' }
const gearPaths = ['M19 12a7 7 0 0 0-.1-1.2l2-1.5-2-3.4-2.3 1a7 7 0 0 0-2-1.2L14.2 3h-4l-.4 2.7a7 7 0 0 0-2 1.2l-2.3-1-2 3.4 2 1.5a7 7 0 0 0 0 2.4l-2 1.5 2 3.4 2.3-1a7 7 0 0 0 2 1.2l.4 2.7h4l.4-2.7a7 7 0 0 0 2-1.2l2.3 1 2-3.4-2-1.5c.06-.4.1-.8.1-1.2z']
const stopRects = [{ x: '7', y: '7', w: '10', h: '10', rx: '1.5' }]

const groups = [
  {
    name: 'botChatRelease',
    count: 3,
    items: [
      { title: '重构主页动效与编排演示', meta: '1m 37s', active: true, pill: true },
      { title: '整理设计 token 与色板', meta: '22:30' },
      { title: '修构建脚本与发布流程', meta: '刚刚' }
    ]
  },
  {
    name: '未分类',
    count: 15,
    items: [
      { title: '写发布说明初稿', meta: '2天前' },
      { title: '对齐群聊时间线文案', meta: '2天前' }
    ]
  },
  { name: '已归档', items: [] }
]

const entries = [
  {
    dot: 'done',
    who: 'botChatRelease',
    time: '00:45',
    body: '已按三栏结构重做工作区复刻：左侧分组会话、中间时间线、右侧 Inspector。',
    status: '完成 · 3 个步骤 · 4s',
    tools: [
      { d: 'M4 4h16v12H4zM4 20h16', text: 'write ~/botChat/index.html', delta: '+78 -12' },
      { d: 'M12 4v6m0 0 3-3m-3 3-3-3M5 20h14', text: 'delegate GOAL 重做工作区界面区块…' }
    ]
  },
  {
    dot: 'run',
    who: 'botChatRelease',
    time: '00:58',
    running: true,
    body: '正在校验 1280 与 390 宽截图，确认无横向溢出。',
    status: '完成 · 2 个步骤 · 3s',
    tools: []
  }
]

const pills = ['5%', '最高 ▾', 'DeepSeek V4.1 ▾']

const ibarFirst = [
  { rects: [], paths: ['M4 20l1-4L16.5 4.5a2.1 2.1 0 0 1 3 3L8 19l-4 1z'] },
  { rects: [], paths: ['M6 9l6 6 6-6'] },
  {
    rects: [{ x: '9', y: '9', w: '11', h: '11', rx: '2' }],
    paths: ['M5 15V5a1 1 0 0 1 1-1h9']
  }
]
const xpPaths = ['M9 4H4v5M15 4h5v5M9 20H4v-5M15 20h5v-5']

const inspector = {
  chip: '工作区界面复刻',
  ctx: '上下文：你上一轮产出的「botChat/index.html」…',
  more: '显示完整消息',
  tasks: [
    {
      dot: 'done',
      title: '工作区界面复刻',
      time: '00:58',
      body: '按真实三栏结构重做复刻区块。',
      status: '完成 · 2 个步骤 · 3s',
      toolCalls: [
        {
          paths: ['M6 3h8l4 4v14H6z', 'M14 3v4h4'],
          path: 'read_file ~/botChat/index.html',
          desc: '已定位 Hero 结束与 CAPABILITIES 开始的锚点。'
        },
        {
          paths: ['M6 3h8l4 4v14H6z', 'M14 3v4h4'],
          path: 'edit ~/botChat/index.html',
          desc: '替换时间线与 Inspector，保持外壳与锚点不动。'
        }
      ]
    }
  ]
}
</script>

<template>
<section class="block" id="workspace">
  <div class="wrap">
    <p class="kicker">WORKSPACE</p>
    <h2>一个窗口，三列分工。</h2>
    <p class="lead rv">左边是会话列表，中间主 Agent 与子 Agent 在同一条消息流里推进，右边 Inspector 只看任务、上下文与用量。</p>
    <div class="ws-win rv" role="img" aria-label="botChat 工作区示意：左侧分组会话列表，中间工具执行时间线与输入框，右侧 Inspector 工具调用详情">
      <div class="ws-bar">
        <span class="ws-dots" aria-hidden="true"><span v-for="n in 3" :key="n"></span></span>
        <span class="ws-title">botChat · botChatRelease</span>
        <span class="ws-state">embedded server · ready</span>
      </div>
      <div class="ws-cols">
        <div class="ws-sess">
          <div class="ws-tools">
            <span class="ws-new">+</span>
            <span class="ws-layout">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect v-for="(r, i) in layoutRects" :key="i" :x="r.x" :y="r.y" :width="r.w" :height="r.h" :rx="r.rx" /></svg>
            </span>
          </div>
          <template v-for="g in groups" :key="g.name">
            <p class="ws-gcap">{{ g.count ? `${g.name} ${g.count}` : g.name }} <span class="tri">▾</span></p>
            <ul v-if="g.items.length">
              <template v-for="it in g.items" :key="it.title">
                <li v-if="it.active" class="on"><span class="t">{{ it.title }}</span><span class="m">{{ it.meta }}</span></li>
                <li v-else><span class="t">{{ it.title }}</span><span class="m">{{ it.meta }}</span></li>
              </template>
            </ul>
          </template>
          <p class="ws-more">显示更多会话 还有 2 条</p>
          <div class="ws-me">
            <span class="ws-face" aria-hidden="true">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><rect v-for="(r, i) in faceRects" :key="i" :x="r.x" :y="r.y" :width="r.w" :height="r.h" :rx="r.rx" /><path v-for="(d, i) in facePaths" :key="'p' + i" :d="d" /></svg>
            </span>botChat<span class="ws-gear">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle :cx="gearCircle.cx" :cy="gearCircle.cy" :r="gearCircle.r" /><path v-for="(d, i) in gearPaths" :key="i" :d="d" /></svg>
            </span>
          </div>
        </div>
        <div class="ws-flow">
          <div class="ws-tl-hd">
            <p class="ws-tl-t">botChat index.html</p>
            <p class="ws-tl-s">群聊协作</p>
            <span class="ws-go">继续</span>
          </div>
          <div class="ws-tl">
            <template v-for="(e, ei) in entries" :key="ei">
              <div class="ws-meta">
                <span :class="['ws-dot', e.dot]" aria-hidden="true"></span>
                <span class="ws-who2">{{ e.who }}</span>
                <span class="ws-time">{{ e.time }}</span>
              </div>
              <p v-if="!e.running" class="ws-body ws-bl">{{ e.body }}<span class="x">&gt;</span></p>
              <div v-else class="ws-runline">
                <span class="rl">运行中</span>
                <p class="ws-body ws-bl">{{ e.body }}<span class="x">&gt;</span></p>
              </div>
              <div class="ws-status">
                <span class="ws-dot done" aria-hidden="true"></span>{{ e.status }}
              </div>
              <div v-for="(t, ti) in e.tools" :key="ti" class="ws-tool">
                <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path v-for="d in (Array.isArray(t.d) ? t.d : [t.d])" :key="d" :d="d" /></svg>
                <span class="ws-path">{{ t.text }}</span>
                <span v-if="t.delta" class="ws-delta">{{ t.delta }}</span>
              </div>
            </template>
          </div>
          <div class="ws-cmp">
            <div class="ws-box">
              <span class="ws-ph">发送消息…</span>
              <div class="ws-crow">
                <span class="ws-plus">+</span>
                <span v-for="p in pills" :key="p" class="ws-pill">{{ p }}</span>
                <span class="ws-stop">
                  <svg viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><rect v-for="(r, i) in stopRects" :key="i" :x="r.x" :y="r.y" :width="r.w" :height="r.h" :rx="r.rx" /></svg>
                </span>
              </div>
            </div>
          </div>
        </div>
        <div class="ws-insp">
          <div class="ws-ibar">
            <svg v-for="(c, ci) in ibarFirst" :key="ci" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect v-for="(r, ri) in c.rects" :key="'r' + ri" :x="r.x" :y="r.y" :width="r.w" :height="r.h" :rx="r.rx" /><path v-for="(d, di) in c.paths" :key="'p' + di" :d="d" /></svg>
            <span class="xp">
              <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path v-for="d in xpPaths" :key="d" :d="d" /></svg>
            </span>
          </div>
          <div class="ws-chip">
            <span class="tx">{{ inspector.chip }}</span>
            <span class="bd"></span>
            <span class="cx">×</span>
          </div>
          <div class="ws-ctx">{{ inspector.ctx }}<span class="more">{{ inspector.more }}</span></div>
          <template v-for="t in inspector.tasks" :key="t.title">
            <div class="ws-task">
              <span :class="['ws-dot', t.dot]" aria-hidden="true"></span>
              <span class="tt">{{ t.title }}</span>
              <span class="ws-time">{{ t.time }}</span>
            </div>
            <p class="ws-body">{{ t.body }}</p>
            <template v-for="(c, ci) in t.toolCalls" :key="c.path">
              <div class="ws-tc">
                <div class="r1">
                  <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path v-for="d in c.paths" :key="d + ci" :d="d" /></svg>
                  <span class="ws-path">{{ c.path }}</span>
                </div>
                <p class="tx">{{ c.desc }}</p>
              </div>
              <div v-if="ci === 0 && t.status" class="ws-status">
                <span class="ws-dot done" aria-hidden="true"></span>{{ t.status }}
              </div>
            </template>
          </template>
        </div>
      </div>
    </div>
    <p class="ws-note">界面示意 · 非实时</p>
  </div>
</section>
</template>
