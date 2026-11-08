<script setup>
import stickerCurious from '../assets/sticker-8.webp'

// 图形按原文子元素顺序平铺成 shapes，避免 paths/rects 分组导致渲染顺序改变
const cards = [
  {
    shapes: [
      { tag: 'path', d: 'M4 6h6M4 12h10M4 18h6' },
      { tag: 'circle', cx: '18', cy: '6', r: '2.4' },
      { tag: 'circle', cx: '18', cy: '18', r: '2.4' }
    ],
    title: '任务编排',
    desc: '主 Agent 拆解需求，现场合成子 Agent 并行执行，完成后汇聚成一份结果。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M4 5h16v10H9l-5 4V5z' },
      { tag: 'path', d: 'M8 9h8M8 12.5h5' }
    ],
    title: '群聊式时间线',
    desc: '主 Agent 与子 Agent 的消息、工具调用同流展示，可取消、可续跑。'
  },
  {
    shapes: [
      { tag: 'rect', x: '4', y: '4', width: '16', height: '12', rx: '2' },
      { tag: 'path', d: 'M8 9l2 2 4-4M4 20h16' }
    ],
    title: '任务预确认卡',
    desc: '关键提交前弹一张结构化确认卡，确认后再执行，不用重写提示词。'
  },
  {
    shapes: [
      { tag: 'rect', x: '3.5', y: '4', width: '7', height: '16', rx: '1.5' },
      { tag: 'rect', x: '13.5', y: '4', width: '7', height: '16', rx: '1.5' }
    ],
    title: '多列工作区',
    desc: '可拖拽分栏，相邻列可锁定成组整体移动，3 个布局预设一键切换。'
  },
  {
    shapes: [
      { tag: 'rect', x: '3', y: '5', width: '18', height: '11', rx: '2' },
      { tag: 'path', d: 'M9 20h6M12 16v4M7 10l2 2 4-4' }
    ],
    title: '桌面操作',
    desc: '经独立 mac_use 委派变体派出，看窗口、点按钮、输文本。桌面操作有动作分级。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M5 5l7 7-7 7M12 19h7' }
    ],
    title: '工具与 MCP',
    desc: 'bash 合并登录 shell 环境（服务端优先 + PATH 并集），文件读写与 MCP 池接入。'
  },
  {
    shapes: [
      { tag: 'circle', cx: '12', cy: '12', r: '7.5' },
      { tag: 'path', d: 'M12 8.5V12l2.5 2' }
    ],
    title: '定时与 Skill',
    desc: '到点自动发起一轮运行；项目 Skill 按需装载，会话记忆可跨会话回捞。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M4 18V9l8-5 8 5v9' },
      { tag: 'path', d: 'M4 18h16M9 18v-5h6v5' }
    ],
    title: '设计系统库',
    tag: '76 套',
    desc: '内置 76 套设计 token（Claude / Vercel / Stripe / Spotify 风格）供设计任务取用。'
  }
]
</script>

<template>
  <section class="block" id="caps">
    <div class="wrap">
      <p class="kicker">CAPABILITIES</p>
      <h2>过程可见，结果可收。</h2>
      <p class="lead rv caps-lead">主 Agent 与子 Agent 的消息出现在同一条时间线上。谁在干什么、卡在哪里，都看得见，也都能追问。
        <img class="sticker st-caps" :src="stickerCurious" alt="" aria-hidden="true" loading="lazy" decoding="async" width="96" height="92">
      </p>
      <div class="grid">
        <div v-for="c in cards" :key="c.title" class="card rv">
          <svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><template v-for="(s, i) in c.shapes" :key="i"><path v-if="s.tag === 'path'" :d="s.d" /><rect v-else-if="s.tag === 'rect'" :x="s.x" :y="s.y" :width="s.width" :height="s.height" :rx="s.rx" /><circle v-else :cx="s.cx" :cy="s.cy" :r="s.r" /></template></svg>
          <h3>{{ c.title }}<span v-if="c.tag" class="tag">{{ c.tag }}</span></h3>
          <p>{{ c.desc }}</p>
        </div>
      </div>
    </div>
  </section>
</template>
