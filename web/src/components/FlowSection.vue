<script setup>
const steps = [
  { n: '01', title: '说需求', desc: '在会话里说你要什么，不用拆步骤，不用写流水线配置。', link: true },
  { n: '02', title: '拆解并合成', desc: '主 Agent 拆成子任务，现场合成子 Agent 并行跑；每人身边一枚活动胶囊，实时显示正在做什么。', link: true },
  { n: '03', title: '汇聚交付', desc: '子结果自动投递、汇聚成一份结果；子助手委派完成时单独出一条终态气泡，说明是谁完成、结果如何，失败给出原因。', link: false }
]
</script>

<template>
  <section class="block" id="flow">
    <div class="wrap">
      <p class="kicker">WORKFLOW</p>
      <h2>三步，从一句话到一份结果。</h2>
      <p class="lead rv">父会话不阻塞等待，子 Agent 结果自动投递回来；长任务期间子助手自己会播报进度。</p>
      <div class="flow rv">
        <div v-for="s in steps" :key="s.n" class="step">
          <div class="n">{{ s.n }}</div>
          <h3>{{ s.title }}</h3>
          <p>{{ s.desc }}</p>
          <span v-if="s.link" class="ln"></span>
        </div>
      </div>
    </div>
  </section>
</template>
