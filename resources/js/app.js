import './bootstrap';
import { createApp } from 'vue';
import CallCenterCRM from './components/CallCenterCRM.vue';

const app = createApp({});
app.component('call-center-crm', CallCenterCRM);
app.mount('#app');
