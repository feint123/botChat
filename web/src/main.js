// 等价于原 index.html L215：先标记 js，资源报错时降级为 noanim（关闭动效）。
document.documentElement.className = 'js'
window.addEventListener('error', () => {
  document.documentElement.className = 'js noanim'
})

import { createApp } from 'vue'
import './styles/index.css'
import App from './App.vue'
import { useReveal } from './composables/useReveal.js'

// 全局一次性进场观察（含 h1 淡入，由各组件内 .rv 标记配合）
const { observe } = useReveal()

const app = createApp(App)
app.mount('#app')

// 挂载后启用滚动进场；h1 淡入类由 HeroSection 内处理
observe()

// 标题淡入：原 L345 逻辑——给 .fade 加延迟后加 .in
requestAnimationFrame(() => {
  const h1 = document.getElementById('h1')
  if (!h1) return
  const spans = h1.querySelectorAll('.fade')
  spans.forEach((sp, i) => {
    sp.style.transitionDelay = i * 0.12 + 's'
  })
  h1.classList.add('in')
})
