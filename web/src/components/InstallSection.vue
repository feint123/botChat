<script setup>
import { useCopy } from '../composables/useCopy.js'

const { label, copy } = useCopy()
</script>

<template>
  <section class="install" id="install">
    <div class="wrap">
      <p class="kicker">INSTALL</p>
      <h2>三行命令，装好即用。</h2>
      <p class="lead">内置 Python / FastAPI 服务随 botChat.app 一起启动，无需自己跑后端。</p>
      <div class="term rv">
        <div class="term-hd"><span class="dots" aria-hidden="true"><span></span><span></span><span></span></span>terminal — zsh<button class="copy" id="cp" type="button" @click="copy"><svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="8" y="8" width="12" height="12" rx="2" /><path d="M16 8V6a2 2 0 0 0-2-2H6a2 2 0 0 0-2 2v8a2 2 0 0 0 2 2h2" /></svg><span id="cpt">{{ label }}</span></button></div>
        <pre id="brew"><span class="p">$ </span>brew tap feint123/tap
<span class="p">$ </span>brew trust feint123/tap
<span class="p">$ </span>brew install --cask botchat</pre>
      </div>
      <p class="sys">系统要求：macOS 26 及以上（建议 26.1+）· Apple Silicon（arm64）· 也可以直接下载 <a href="https://github.com/feint123/botChat/releases/download/v1.1.2/botChat-1.1.2.dmg">botChat-1.1.2.dmg</a> 安装。</p>
      <p class="sys">首次安装用上面任一方式；之后的版本升级由应用内自动完成（Sparkle），无需再次手动下载，也不要使用 brew upgrade。</p>
      <p class="caveat">当前版本未经 Apple 公证，首次打开可能被 Gatekeeper 拦截；可用 <code>--no-quarantine</code> 安装，或执行 <code>sudo xattr -dr com.apple.quarantine /Applications/botChat.app</code> 解除。</p>
    </div>
  </section>
</template>
