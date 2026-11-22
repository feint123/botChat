<template>
  <footer>
    <div class="wrap">
      <div class="ft">
        <div class="ft-l">botChat · 桌面客户端 for AI agents</div>
        <nav aria-label="页脚链接">
          <a :href="PLUGINS_DOC_URL">插件开发文档</a>
          <a :href="RELEASES_URL">更新日志</a>
          <a href="https://github.com/feint123/botChat">GitHub</a>
        </nav>
      </div>
      <div class="copy2">botChat · 2025–2026 · macOS 26+ · arm64</div>
    </div>
  </footer>
</template>

<script setup>
import { PLUGINS_DOC_URL, RELEASES_URL } from '../lib/release.js'
</script>
