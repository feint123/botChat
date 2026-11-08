// 原 botChat/index.html L349 起「主动效：分叉→并行→汇聚」IIFE 的语义等价迁移。
// 用法：const { start, stop } = useOrchestrationCanvas(canvasRef, phaseRef)
//   canvasRef: canvas 元素的 ref（或元素本身）；phaseRef: phase 元素的 ref / 元素 / () => el。
// 由 OrchestrationCanvas.vue 在 onMounted 里 start()、onBeforeUnmount 里 stop()。
export const CYCLE = 7600

function unwrapEl (r) {
  if (!r) return null
  if (typeof r === 'function') {
    try { return r() || null } catch (e) { return null }
  }
  if (r instanceof Element) return r
  if (typeof r === 'object' && 'value' in r) {
    const v = r.value
    if (typeof v === 'function') {
      try { return v() || null } catch (e) { return null }
    }
    return v instanceof Element ? v : null
  }
  return null
}

export function useOrchestrationCanvas (canvasRef, phaseRef) {
  let cv = null
  let ctx = null
  let W = 0
  let H = 0
  let DPR = 1
  let raf = 0
  let hidden = false
  let t0 = 0
  let pauseAt = 0
  let rz = 0
  let started = false
  const RM = typeof window !== 'undefined' && window.matchMedia &&
    window.matchMedia('(prefers-reduced-motion: reduce)').matches

  function geom (w, h) {
    const gx = w < 560 ? 0.86 : 1
    return {
      mx: Math.round(w * (w < 560 ? 0.13 : 0.11)),
      my: Math.round(h * 0.5),
      subs: [0.22, 0.5, 0.78].map(function (f) {
        return { x: Math.round(w * 0.55 * gx), y: Math.round(h * f) }
      }),
      sx: Math.round(w * (w < 560 ? 0.9 : 0.88)),
      sy: Math.round(h * 0.5)
    }
  }

  function bz (a, c, b, t) {
    const u = 1 - t
    return { x: u * u * a.x + 2 * u * t * c.x + t * t * b.x, y: u * u * a.y + 2 * u * t * c.y + t * t * b.y }
  }

  function ctrl (a, b) {
    return { x: (a.x + b.x) / 2, y: a.y }
  }

  function fit () {
    if (!cv || !ctx) return
    DPR = Math.min(window.devicePixelRatio || 1, 2)
    const r = cv.getBoundingClientRect()
    W = Math.max(280, r.width)
    H = Math.max(240, cv.clientHeight || 340)
    cv.width = Math.round(W * DPR)
    cv.height = Math.round(H * DPR)
    ctx.setTransform(DPR, 0, 0, DPR, 0, 0)
  }

  function line (a, b, from, to, style, lw, dash) {
    const c = ctrl(a, b)
    ctx.save()
    ctx.strokeStyle = style
    ctx.lineWidth = lw || 1.4
    ctx.lineCap = 'round'
    if (dash) ctx.setLineDash(dash)
    ctx.beginPath()
    let drew = false
    for (let i = 0; i <= 40; i++) {
      const t = from + (to - from) * i / 40
      if (t <= 0) continue
      const p = bz(a, c, b, Math.min(1, Math.max(0, t)))
      if (!drew) { ctx.moveTo(p.x, p.y); drew = true } else ctx.lineTo(p.x, p.y)
    }
    ctx.stroke()
    ctx.restore()
  }

  function node (p, st, r, glow) {
    ctx.save()
    if (glow) {
      const g = ctx.createRadialGradient(p.x, p.y, 2, p.x, p.y, 54)
      g.addColorStop(0, 'rgba(201,151,43,.30)')
      g.addColorStop(1, 'rgba(201,151,43,0)')
      ctx.fillStyle = g
      ctx.beginPath()
      ctx.arc(p.x, p.y, 54, 0, 7)
      ctx.fill()
    }
    if (st === 'run') {
      const pl = 1 + 0.22 * Math.sin(performance.now() / 180)
      ctx.strokeStyle = '#C9972B'
      ctx.lineWidth = 1.6
      ctx.beginPath()
      ctx.arc(p.x, p.y, (r + 5) * pl, 0, 7)
      ctx.stroke()
    }
    ctx.beginPath()
    ctx.arc(p.x, p.y, r, 0, 7)
    if (st === 'main') { ctx.fillStyle = '#1A1D21'; ctx.fill() } else if (st === 'run') { ctx.fillStyle = '#C9972B'; ctx.fill() } else if (st === 'done') { ctx.fillStyle = '#2F7CF6'; ctx.fill() } else { ctx.fillStyle = '#FFFEFB'; ctx.fill(); ctx.strokeStyle = '#C9C4B8'; ctx.lineWidth = 1.5; ctx.stroke() }
    if (st === 'done' || st === 'run') {
      ctx.strokeStyle = '#fff'
      ctx.lineWidth = 1.8
      ctx.lineCap = 'round'
      ctx.beginPath()
      const k = r * 0.42
      ctx.moveTo(p.x - k * 0.9, p.y + k * 0.05)
      ctx.lineTo(p.x - k * 0.1, p.y + k * 0.75)
      ctx.lineTo(p.x + k, p.y - k * 0.6)
      ctx.stroke()
    }
    ctx.restore()
  }

  function label (p, t, mono, col) {
    ctx.save()
    ctx.font = '11px ui-monospace,SF Mono,Menlo,monospace'
    ctx.textAlign = 'center'
    ctx.fillStyle = col || '#5A5F66'
    ctx.fillText(t, p.x, p.y + (p.main ? 34 : 26))
    ctx.restore()
  }

  function roundRect (x, y, w, h, r) {
    ctx.beginPath()
    ctx.moveTo(x + r, y)
    ctx.arcTo(x + w, y, x + w, y + h, r)
    ctx.arcTo(x + w, y + h, x, y + h, r)
    ctx.arcTo(x, y + h, x, y, r)
    ctx.arcTo(x, y, x + w, y, r)
    ctx.closePath()
  }

  function clamp (v) {
    return Math.max(0, Math.min(1, v))
  }

  function draw (ms) {
    const G = geom(W, H)
    const el = ((ms % CYCLE) + CYCLE) % CYCLE
    const t = el / CYCLE
    ctx.clearRect(0, 0, W, H)
    /* 纸网格 */
    ctx.save()
    ctx.strokeStyle = 'rgba(26,29,33,.045)'
    ctx.lineWidth = 1
    ctx.beginPath()
    for (let gx = 0.5; gx < W; gx += 26) { ctx.moveTo(gx, 0); ctx.lineTo(gx, H) }
    for (let gy = 0.5; gy < H; gy += 26) { ctx.moveTo(0, gy); ctx.lineTo(W, gy) }
    ctx.stroke()
    ctx.restore()
    const grow = [clamp((t - 0.04) / 0.16), clamp((t - 0.12) / 0.16), clamp((t - 0.20) / 0.16)]
    const states = grow.map(function (g, i) {
      if (g >= 1) {
        const runEnd = 0.44 + i * 0.07
        if (t < runEnd) return 'run'
        return 'done'
      }
      return g > 0.02 ? 'run' : 'wait'
    })
    /* 主线 */
    for (let i = 0; i < 3; i++) {
      line({ x: G.mx, y: G.my }, G.subs[i], 0, grow[i], 'rgba(47,124,246,.55)', 1.5)
    }
    /* travelling dots (<=12) */
    let dots = 0
    for (let j = 0; j < 3; j++) {
      if (grow[j] > 0 && grow[j] < 1 && states[j] !== 'wait') {
        const c = ctrl({ x: G.mx, y: G.my }, G.subs[j])
        for (let k = 0; k < 2; k++) {
          const tt = (ms / 900 + k * 0.5 + j * 0.33) % 1
          if (tt < grow[j] && dots < 12) {
            const p = bz({ x: G.mx, y: G.my }, c, G.subs[j], tt)
            ctx.save()
            ctx.fillStyle = 'rgba(47,124,246,.85)'
            ctx.beginPath()
            ctx.arc(p.x, p.y, 2.4, 0, 7)
            ctx.fill()
            ctx.restore()
            dots++
          }
        }
      }
    }
    /* 汇聚 */
    const cg = clamp((t - 0.62) / 0.18)
    if (cg > 0) {
      for (let m = 0; m < 3; m++) {
        line(G.subs[m], { x: G.sx, y: G.sy }, 0, cg, 'rgba(201,151,43,.6)', 1.3, [5, 4])
      }
    }
    /* 光晕一次 */
    const glow = (t > 0.82 && t < 0.94) ? Math.sin((t - 0.82) / 0.12 * Math.PI) : 0
    /* 节点 */
    node({ x: G.mx, y: G.my }, 'main', 13, false)
    label({ x: G.mx, y: G.my, main: true }, 'main', 0, '#1A1D21')
    const names = ['agent-a', 'agent-b', 'agent-c']
    for (let n = 0; n < 3; n++) {
      node(G.subs[n], states[n], 10, false)
      ctx.save()
      ctx.font = '11px ui-monospace,SF Mono,Menlo,monospace'
      ctx.textAlign = 'center'
      ctx.fillStyle = '#5A5F66'
      ctx.fillText(names[n], G.subs[n].x, G.subs[n].y - 18)
      ctx.restore()
      label(G.subs[n], states[n] === 'done' ? 'done' : states[n] === 'run' ? 'running' : 'pending')
    }
    /* sink 卡 */
    ctx.save()
    const sw = Math.min(118, W * 0.2)
    const sh = 64
    const rx = G.sx - sw / 2
    const ry = G.sy - sh / 2
    if (glow > 0) {
      const gg = ctx.createRadialGradient(G.sx, G.sy, 4, G.sx, G.sy, 70)
      gg.addColorStop(0, 'rgba(201,151,43,' + (0.28 * glow) + ')')
      gg.addColorStop(1, 'rgba(201,151,43,0)')
      ctx.fillStyle = gg
      ctx.beginPath()
      ctx.arc(G.sx, G.sy, 70, 0, 7)
      ctx.fill()
    }
    ctx.fillStyle = cg >= 1 ? '#EAF1FE' : '#FFFEFB'
    ctx.strokeStyle = cg >= 1 ? '#2F7CF6' : '#EDE6D8'
    ctx.lineWidth = cg >= 1 ? 1.8 : 1.4
    roundRect(rx, ry, sw, sh, 10)
    ctx.fill()
    ctx.stroke()
    ctx.fillStyle = '#1A1D21'
    ctx.font = '700 12px -apple-system,PingFang SC,sans-serif'
    ctx.textAlign = 'center'
    ctx.fillText('结果卡片', G.sx, G.sy - 2)
    ctx.fillStyle = '#5A5F66'
    ctx.font = '10px ui-monospace,Menlo,monospace'
    ctx.fillText(cg >= 1 ? 'merged' : 'merging…', G.sx, G.sy + 15)
    ctx.restore()
    const ph = unwrapEl(phaseRef)
    if (ph) ph.textContent = t < 0.36 ? 'fan-out' : t < 0.62 ? 'parallel run' : t < 0.82 ? 'converge' : 'merged · loop'
  }

  function frame (ms) {
    if (hidden) return
    if (!t0) t0 = ms
    draw(ms - t0 + 1200)
    raf = requestAnimationFrame(frame)
  }

  function static_ () {
    fit()
    draw(CYCLE * 0.9)
  }

  function onVis () {
    hidden = document.hidden
    if (hidden) {
      pauseAt = performance.now()
      if (raf) cancelAnimationFrame(raf)
      raf = 0
    } else if (!RM) {
      t0 += performance.now() - pauseAt
      raf = requestAnimationFrame(frame)
    }
  }

  function onResize () {
    clearTimeout(rz)
    rz = setTimeout(function () {
      fit()
      if (RM) static_()
    }, 120)
  }

  function start () {
    if (started) return
    cv = unwrapEl(canvasRef)
    if (!cv) return
    ctx = cv.getContext('2d')
    if (!ctx) return
    started = true
    hidden = false
    t0 = 0
    pauseAt = 0
    if (RM) {
      fit()
      static_()
    } else {
      fit()
      raf = requestAnimationFrame(frame)
    }
    document.addEventListener('visibilitychange', onVis)
    window.addEventListener('resize', onResize, { passive: true })
  }

  function stop () {
    started = false
    if (raf) cancelAnimationFrame(raf)
    raf = 0
    clearTimeout(rz)
    if (typeof document !== 'undefined') document.removeEventListener('visibilitychange', onVis)
    if (typeof window !== 'undefined') window.removeEventListener('resize', onResize)
    cv = null
    ctx = null
    t0 = 0
  }

  return { start, stop }
}
