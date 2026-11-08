<script setup>
import { ref } from 'vue'
import OrchestrationCanvas from './OrchestrationCanvas.vue'
import { APP_VERSION, DMG_URL } from '../lib/release.js'
import stickerWaiting from '../assets/sticker-3.webp'
import stickerDizzy from '../assets/sticker-2.webp'

const phase = ref(null)
function getPhaseEl () {
  return phase.value
}
</script>

<template>
  <section class="hero">
    <div class="wrap hero-grid">
      <div>
        <span class="eyebrow"><i></i>群聊式 Agent 任务编排 · macOS 原生客户端</span>
        <h1 id="h1"><span class="fade">说要什么，</span><br><span class="fade">剩下的交给分身。</span></h1>
        <p class="sub">左右分栏的群聊式 Agent 任务编排应用——你只说要什么，主 Agent 拆解并现场合成子 Agent 并行执行，再汇聚成一份结果。</p>
        <p class="sub-en">supervisor fans out at runtime · sub-agents run in parallel · results converge</p>
        <div class="btns">
          <a class="btn btn-p" :href="DMG_URL"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M12 4v11m0 0 4-4m-4 4-4-4M5 20h14"/></svg>下载 macOS 版<span class="btn-ver">v{{ APP_VERSION }}</span></a>
          <a class="btn btn-s" href="https://github.com/feint123/botChat"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="M9 9l-4 3 4 3M15 9l4 3-4 3M13 5l-2 14"/></svg>查看源码</a>
        </div>
        <ul class="facts"><li>Swift + SwiftUI · Apple Silicon 构建</li><li>内置服务随应用启动 · 健康探测通过才放行</li><li>AG-UI 单流 · REST + SSE · 不用 WebSocket</li></ul>
      </div>
      <div class="stage-wrap">
        <img class="sticker st-hero-a" :src="stickerWaiting" alt="" aria-hidden="true" loading="lazy" decoding="async" width="104" height="92">
        <img class="sticker st-hero-b" :src="stickerDizzy" alt="" aria-hidden="true" loading="lazy" decoding="async" width="88" height="85">
        <div class="stage" aria-label="编排示意：主 Agent 分叉出三个子 Agent 并行执行后汇聚">
          <div class="stage-hd"><span class="dots" aria-hidden="true"><span></span><span></span><span></span></span>orchestration · live<span><b id="phase" ref="phase">fan-out</b></span></div>
          <OrchestrationCanvas :phase-el="getPhaseEl" />
          <div class="legend" aria-hidden="true"><span><s class="lp"></s>pending 等待</span><span><s class="lr"></s>running 执行中</span><span><s class="ld"></s>done 已完成</span></div>
        </div>
      </div>
    </div>
  </section>
</template>
