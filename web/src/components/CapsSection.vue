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
    desc: '主 Agent 拆解需求，现场合成子 Agent 并行执行，完成后汇聚成一份结果；每个子 Agent 的进度实时可见。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M4 5h16v10H9l-5 4V5z' },
      { tag: 'path', d: 'M8 9h8M8 12.5h5' }
    ],
    title: '群聊式时间线',
    desc: '主 Agent 与子 Agent 同一条时间线，每人身边一枚活动胶囊显示正在做什么；出错时故障气泡给人话标题，机读细节折叠。'
  },
  {
    shapes: [
      { tag: 'rect', x: '4', y: '4', width: '16', height: '12', rx: '2' },
      { tag: 'path', d: 'M8 9l2 2 4-4M4 20h16' }
    ],
    title: '决策卡与提问卡',
    desc: '需要你拍板的问题在卡片上直接作答，答复作为独立段落注入执行 prompt；聊天模式下决策卡与故障提示照常显示。'
  },
  {
    shapes: [
      { tag: 'rect', x: '3.5', y: '4', width: '7', height: '16', rx: '1.5' },
      { tag: 'rect', x: '13.5', y: '4', width: '7', height: '16', rx: '1.5' }
    ],
    title: '多列工作区',
    desc: '分栏可拖拽调宽、可分组，同一屏只显示一列，其余走分页切换；文件预览跟随写盘自动刷新，引用是正文里的 markdown 行锚链接。'
  },
  {
    shapes: [
      { tag: 'rect', x: '3', y: '5', width: '18', height: '11', rx: '2' },
      { tag: 'path', d: 'M9 20h6M12 16v4M7 10l2 2 4-4' }
    ],
    title: '桌面操作',
    desc: '经独立 mac_use 委派变体派出：先 observe 稳定读，再 act 动作并读回验证；按键可定向到目标进程或系统全局。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M5 5l7 7-7 7M12 19h7' }
    ],
    title: '工具与插件',
    desc: '工具按本地 / MCP / 插件三轨注册，core 之外按需 tool_search 检索、tool_invoke 调用；插件可声明工具、hook、命令与主题，能产出时间线行、读写目标台账，界面只保留原生面板一种形态。'
  },
  {
    shapes: [
      { tag: 'circle', cx: '12', cy: '12', r: '7.5' },
      { tag: 'path', d: 'M12 8.5V12l2.5 2' }
    ],
    title: '定时与 Skill',
    desc: '定时任务到点在自己的执行会话里跑，侧栏任务行右键暂停/恢复、立即运行、编辑、删除，暂停中置灰不隐藏；输入 / 弹出技能候选。'
  },
  {
    shapes: [
      { tag: 'path', d: 'M4 18V9l8-5 8 5v9' },
      { tag: 'path', d: 'M4 18h16M9 18v-5h6v5' }
    ],
    title: '主题与设计 token',
    tag: '8 套',
    desc: '内置 8 套主题包与 46 个语义角色，切主题走运行时快照、不重挂根视图；面板配色跟随主题浅深外观。'
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
