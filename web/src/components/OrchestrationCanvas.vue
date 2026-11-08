<template>
  <canvas id="cv" ref="cv" role="img" aria-label="分叉并行再汇聚的编排动效"></canvas>
</template>

<script setup>
import { ref, onMounted, onBeforeUnmount } from 'vue'
import { useOrchestrationCanvas } from '../composables/useOrchestrationCanvas.js'

const props = defineProps({
  phaseEl: { type: Function, required: false, default: null }
})

const cv = ref(null)
let stopFn = null

onMounted(() => {
  const api = useOrchestrationCanvas(cv, props.phaseEl)
  api.start()
  stopFn = api.stop
})

onBeforeUnmount(() => {
  if (stopFn) stopFn()
  stopFn = null
})
</script>
