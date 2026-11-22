<template>
  <SiteTopline />
  <SiteNav />
  <main>
    <HeroSection />
    <WorkspaceSection />
    <CapsSection />
    <FlowSection />
    <PluginsSection />
    <ChangelogSection />
    <InstallSection />
  </main>
  <SiteFooter />
</template>

<script setup>
import SiteTopline from './components/SiteTopline.vue'
import SiteNav from './components/SiteNav.vue'
import HeroSection from './components/HeroSection.vue'
import WorkspaceSection from './components/WorkspaceSection.vue'
import CapsSection from './components/CapsSection.vue'
import FlowSection from './components/FlowSection.vue'
import PluginsSection from './components/PluginsSection.vue'
import ChangelogSection from './components/ChangelogSection.vue'
import InstallSection from './components/InstallSection.vue'
import SiteFooter from './components/SiteFooter.vue'
</script>
