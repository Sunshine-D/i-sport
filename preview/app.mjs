import { totalKcal, totalNutrient, effectiveKcal, localDay, upsert, mealsOn, aggregate, exportMeals, restore, copyText } from './core.mjs';

const app = document.querySelector('#app'), nav = document.querySelector('#nav'), dialog = document.querySelector('#editor');
const storageKey = 'lightmeal-preview-v2';
let meals = [], storageLocked = false, initialError = '', page = 'today', selectedDay = localDay(), range = 7;
let goal = Number(localStorage.getItem('lightmeal-preview-goal')) || 1800;
if (!Number.isFinite(goal) || goal < 500 || goal > 10000) goal = 1800;
let draft = null, image = null, note = '', draftDate = '', draftKind = '午餐', selectedMeal = null, busy = false;
let failRecognition = false;
try { const stored = localStorage.getItem(storageKey); if (stored) meals = restore(stored); }
catch { storageLocked = true; initialError = '历史文件格式异常，已保留原数据并禁止覆盖。请在我的页面导出原始备份。'; }
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const round = value => Math.round(value);
const icon = name => `<i data-lucide="${name}" aria-hidden="true"></i>`;
function id() { return crypto.randomUUID(); }
function toast(text) {
  const element = document.querySelector('#toast'); element.textContent = text; element.style.display = 'block';
  clearTimeout(toast.timer); toast.timer = setTimeout(() => { element.style.display = 'none'; }, 3400);
}
function persist(next) {
  if (storageLocked) throw new Error('原始历史需要恢复，当前禁止覆盖');
  localStorage.setItem(storageKey, exportMeals(next)); meals = next;
}
function changePage(value) { if (busy) return; page = value; render(); window.scrollTo(0, 0); }
function dateTimeInput(date) {
  const d = new Date(date); return `${localDay(d)}T${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
}
function photoMarkup(value, empty = '餐食照片') {
  return value && /^data:image\/(jpeg|png|webp);base64,/.test(value)
    ? `<img class="photo" src="${escape(value)}" alt="用户选择的餐食照片">` : `<div class="photo-empty">${escape(empty)}</div>`;
}
function row(meal) {
  return `<button class="meal-row" data-detail="${escape(meal.id)}"><span class="meal-kind">${meal.kind}</span><span class="meal-text"><b>${meal.kind} ${meal.sample ? '<span class="sample-tag">示例</span>' : ''}</b><small>${new Date(meal.date).toLocaleTimeString('zh-CN', {hour:'2-digit',minute:'2-digit'})} · ${escape(meal.foods.map(f => f.name).join('、'))}</small></span><strong>${round(totalKcal(meal.foods))} kcal</strong></button>`;
}
const notice = text => `<div class="notice">${text}</div>`;
const backTitle = title => `<div class="subpage-title"><button data-page="mine" aria-label="返回我的">${icon('chevron-left')}</button><h2>${title}</h2></div>`;
function todayView() {
  const todayMeals = mealsOn(meals, new Date()), total = totalKcal(todayMeals.flatMap(m => m.foods));
  return `<div class="date">${new Date().toLocaleDateString('zh-CN',{month:'long',day:'numeric',weekday:'long'})}</div><div class="header"><h2>今日</h2><button data-page="mine" aria-label="我的">${icon('user-round')}</button></div>
  <section class="card"><div class="card-top"><h3>热量</h3><button data-page="sync" aria-label="数据同步">${icon('chevron-right')}</button></div><div class="summary"><div class="ring" style="--progress:${Math.min(total/goal,1)*360}deg"><div class="ring-inner"><strong>${round(total)}</strong><small>已记录摄入</small><small>${total > goal ? '超过 ' : '距目标 '}${round(Math.abs(goal-total))}</small></div></div><div class="legend"><div><span><i></i>已摄入</span><b>${round(total)}</b></div><div><span><i style="background:#c4c4d0"></i>基础消耗</span><b>—</b></div><div><span><i style="background:#27c765"></i>活动消耗</span><b>—</b></div></div></div></section>
  <section class="card"><div class="card-top"><h3>今日消耗</h3><button class="small orange" data-page="sync">尚未读取</button></div><div class="metrics">${['活动 kcal','步数','体重 kg','训练 min'].map(t=>`<div class="metric"><b>—</b><small>${t}</small></div>`).join('')}</div><p class="small">真实数据需在 iOS 应用中授权 Apple 健康</p></section>
  <section class="card"><div class="card-top"><h3>今日餐食</h3><button class="small orange" data-capture>照片日记</button></div>${todayMeals.length ? todayMeals.map(row).join('') : '<div class="empty">今天尚未记录<br>拍下第一餐，开始记录</div>'}</section>${notice('本机保存 · 小米自动写入未接通 · 完整历史 iCloud 同步待验证')}${initialError ? `<p class="error">${initialError}</p>` : ''}`;
}
function diaryView() {
  const dayMeals = mealsOn(meals, `${selectedDay}T12:00:00`), total = totalKcal(dayMeals.flatMap(m=>m.foods));
  const anchor = new Date(`${selectedDay}T12:00:00`);
  const weekdays = Array.from({length:7}, (_, i) => { const d = new Date(anchor); d.setDate(d.getDate() + i - 3); return d; });
  return `<div class="header"><h2>餐食日记</h2><label aria-label="选择日期"><input id="date" type="date" value="${selectedDay}"></label></div><div class="week">${weekdays.map(d=>`<button data-day="${localDay(d)}" class="${localDay(d)===selectedDay?'selected':''}"><span>${d.toLocaleDateString('zh-CN',{weekday:'narrow'})}</span>${d.getDate()}</button>`).join('')}</div><div class="card metrics"><div class="metric"><b class="orange">${round(total)}</b><small>已记录 kcal</small></div><div class="metric"><b>—</b><small>消耗未读取</small></div><div class="metric"><b>—</b><small>热量缺口</small></div></div>${dayMeals.map(m=>`<section class="card diary-card">${photoMarkup(m.photo, m.kind+'照片')}${row(m)}<div class="chips">${m.foods.map(f=>`<span>${escape(f.name)} ${round(effectiveKcal(f))} kcal</span>`).join('')}</div></section>`).join('')}${!dayMeals.length?'<div class="empty">这一天尚未记录，未记录不代表零摄入。</div>':''}<button class="primary" data-capture>补记这一餐</button>${notice('照片与热量保存在当前浏览器本机；这不是 iCloud 同步。')}`;
}
function captureView() {
  return `<div class="subpage-title"><button data-page="today" aria-label="返回">${icon('x')}</button><h2>拍照识别</h2></div><div class="capture-image">${photoMarkup(image, '拍下或选择餐食照片')}</div><label class="file-button">${icon('camera')} 拍照 / 从相册选择<input id="photo" type="file" accept="image/jpeg,image/png,image/webp" capture="environment"></label><section class="card"><label class="field">餐次<select id="kind">${['早餐','午餐','晚餐','加餐'].map(k=>`<option ${k===draftKind?'selected':''}>${k}</option>`).join('')}</select></label><label class="field">餐食时间<input id="meal-date" type="datetime-local" value="${draftDate}"></label><label class="field">补充说明<textarea id="note" rows="2" maxlength="2000" placeholder="如：一人份、米饭剩了一半">${escape(note)}</textarea></label></section><button class="primary" id="analyze" ${!image||busy?'disabled':''}>${busy?'正在生成演示结果…':'演示识别（不调用模型）'}</button><button class="text-button" id="manual">手动记录 · 离线可用</button><label class="settings-row small">模拟服务失败<input type="checkbox" id="fail" class="switch" ${failRecognition?'checked':''}></label>${notice('预览中的照片不会上传。真实 AI 请求、相机及健康功能在原生 iOS 工程中实现，尚待真机验证。')}`;
}
function resultView() {
  if (!draft) return captureView();
  const foods = draft.foods;
  return `<div class="subpage-title"><button data-page="capture" aria-label="返回照片">${icon('chevron-left')}</button><h2>${selectedMeal?'编辑餐食':'识别结果'}</h2></div>${photoMarkup(draft.photo)}<p class="small">${escape(draft.kind)} · ${new Date(draft.date).toLocaleString('zh-CN')}${draft.sample?' · <span class="sample-tag">演示识别</span>':''}</p><section class="card"><div class="card-top"><h3>${selectedMeal?'餐食明细':'识别结果'} · ${foods.length} 种食物</h3><button class="small orange" id="add-food">添加</button></div>${foods.map(f=>`<div class="food-row"><button class="meal-text" data-edit="${escape(f.id)}"><b>${escape(f.name)}</b><small>约 ${round(f.grams*f.fraction)}g · 吃下 ${round(f.fraction*100)}% ${icon('pencil')}</small></button><strong>${round(effectiveKcal(f))} kcal</strong><button data-remove="${escape(f.id)}" aria-label="移除${escape(f.name)}">${icon('x')}</button></div>`).join('')}</section><section class="card"><div class="card-top"><h3>合计估算热量</h3><strong class="total orange">${round(totalKcal(foods))}<span style="font-size:13px"> kcal</span></strong></div><div class="macros">${[['protein','蛋白质'],['fat','脂肪'],['carbs','碳水']].map(([k,t])=>`<div><b>${totalNutrient(foods,k)==null?'—':round(totalNutrient(foods,k))+'g'}</b><small>${t}</small></div>`).join('')}</div></section>${notice('点食物调整份量与摄入比例；热量包含估算用油。未知营养素显示 —。')}<button class="primary" id="save-meal" ${!foods.length||busy?'disabled':''}>${busy?'保存中…':'确认并保存到本机'}</button><p class="small" style="text-align:center">Apple 健康、小米和 iCloud 未连接</p>`;
}
function detailView() {
  const meal = meals.find(m=>m.id===selectedMeal);
  if (!meal) return '<div class="empty">餐食不存在</div>';
  return `<div class="subpage-title"><button data-page="diary" aria-label="返回日记">${icon('chevron-left')}</button><h2>餐食详情</h2></div>${photoMarkup(meal.photo)}<p class="small">${escape(meal.kind)} · ${new Date(meal.date).toLocaleString('zh-CN')}${meal.sample?' · 示例':''}</p><section class="card"><div class="card-top"><h3>本餐估算</h3><b class="total orange">${round(totalKcal(meal.foods))} <small>kcal</small></b></div>${meal.foods.map(f=>`<div class="food-row"><span class="meal-text"><b>${escape(f.name)}</b><small>约${round(f.grams*f.fraction)}克 · ${round(f.fraction*100)}%</small></span><strong>${round(effectiveKcal(f))} kcal</strong></div>`).join('')}</section>${notice('本机已保存 · 苹果健康未连接 · 小米未写入')}<button class="primary" id="edit-meal">编辑本餐</button><div class="row-actions"><button id="copy-meal" class="text-button">复制本餐记录</button><button id="delete-meal" class="danger">删除本餐</button></div>${meal.note?notice(escape(meal.note)):''}`;
}
function trendView() {
  const end = new Date(); end.setHours(23,59,59,999); const start = new Date(); start.setHours(0,0,0,0); start.setDate(start.getDate()-range+1);
  const entries = aggregate(meals,start,end), max = Math.max(1,...entries.map(e=>e.kcal));
  return `<h2>趋势</h2><div class="segmented">${[[7,'近7天'],[30,'近30天'],[365,'近365天']].map(([n,t])=>`<button data-range="${n}" class="${n===range?'selected':''}">${t}</button>`).join('')}</div><section class="card"><div class="card-top"><h3>已记录摄入</h3><span class="small orange">${round(entries.reduce((a,e)=>a+e.kcal,0))} kcal</span></div><p class="small">橙色：实际已保存餐食</p>${entries.length?`<div class="chart" role="img" aria-label="按日期统计已记录摄入">${entries.slice(-14).map(e=>`<div class="bar-column"><small>${round(e.kcal)}</small><div class="bar" style="height:${Math.max(e.kcal/max*130,3)}px"></div><span>${e.date.slice(5)}</span></div>`).join('')}</div>`:'<div class="empty">尚无记录，记录第一餐后查看趋势。</div>'}${entries.map(e=>`<div class="settings-row"><span>${e.date}</span><b class="orange">${round(e.kcal)} kcal</b></div>`).join('')}</section><section class="card"><h3>体重</h3><div class="empty">尚未读取 Apple 健康体重数据</div></section><section class="card"><h3>运动记录</h3><div class="empty">尚未读取，预览不生成虚假运动记录。</div></section>${notice('未记录日不显示为零摄入；历史消耗数据未接入。')}`;
}
function mineView() {
  return `<h2>我的</h2><section class="card"><div class="summary"><div class="avatar">${icon('user-round')}</div><div><b>我的记录</b><p class="small">本机交互预览 · 未登录第三方账号</p></div></div></section><section class="card"><button class="settings-row" id="edit-goal"><span>每日热量目标</span><small>${goal} kcal ${icon('chevron-right')}</small></button><button class="settings-row" data-page="sync"><span>数据同步</span><small>未连接 ${icon('chevron-right')}</small></button><div class="settings-row"><span>写入模块</span><small>小米减重 · 尚未接通</small></div></section><section class="card"><button class="settings-row" data-page="sync"><span>Apple 健康读取权限</span><small>需原生 iOS 授权</small></button><div class="settings-row"><span>iCloud 同步</span><small>待验证 · 未开启</small></div><p class="small">个人健康历史的云存储需要核实审核要求。</p><button class="settings-row" data-page="engine"><span>AI 识别引擎</span><small>预览为演示识别 ${icon('chevron-right')}</small></button><button class="settings-row" id="export"><span>导出本机记录</span><small>JSON ${icon('download')}</small></button><button data-demo class="settings-row"><span>加载示例餐食（演示）</span><small>仅用于预览</small></button><label class="settings-row">导入记录<input id="import" type="file" accept="application/json" style="max-width:130px;font-size:10px"></label></section>${notice('轻食记 V2 · 预览不是 iOS 安装包。照片仅保存在当前浏览器，导出内容包含个人饮食记录。')}${initialError?`<p class="error">${initialError}</p><button id="raw-export" class="text-button">导出损坏历史的原始备份</button>`:''}`;
}
function syncView() {
  return `${backTitle('数据同步')}<section class="card"><h3>数据来源</h3><div class="settings-row"><span>Apple 健康</span><small>浏览器不可访问</small></div><div class="settings-row"><span>小米运动健康</span><small>自动餐食写入未接通</small></div><p class="small">在原生应用主动授权后读取系统数据，不假定来源全部是小米。</p></section><section class="card"><h3>读取数据</h3>${['最近体重','活动能量消耗','基础能量消耗','训练记录','步数','最近心率'].map(t=>`<div class="settings-row"><span>${t}</span><small>— 未读取</small></div>`).join('')}</section><section class="card"><h3>写回小米运动健康</h3><div class="settings-row"><span>写入模块</span><small>减重 · 餐食记录</small></div><p class="small">未确认官方写接口，暂时不能启用自动写入。保存后在详情复制记录并手动填写。</p><button class="text-button" data-page="diary">去餐食日记复制</button></section>${notice('未连接能力不显示“已同步”。iCloud 完整历史和端侧视觉仍待验证。')}`;
}
function engineView() {
  return `${backTitle('AI 识别引擎')}<section class="card"><h3>原生 iOS 应用</h3><p class="small">支持配置完整 HTTPS 视觉 Chat Completions 服务。个人密钥保存在系统钥匙串，照片上传前单独确认。</p><p class="small">浏览器预览不收集密钥、不发送照片。真实服务请在原生应用“我的”页面配置。</p></section><section class="card"><h3>端侧视觉</h3><p class="small">尚未接入和验证；离线时可手动记录，不把演示结果当 AI 推理。</p><button class="primary" id="manual">开始手动记录</button></section>`;
}
function render() {
  const views = {today:todayView,diary:diaryView,capture:captureView,result:resultView,detail:detailView,trends:trendView,mine:mineView,sync:syncView,engine:engineView};
  app.innerHTML = (views[page] || todayView)();
  const active = ['capture','result','detail','sync','engine'].includes(page) ? '' : page;
  nav.innerHTML = [['today','house','今日'],['diary','images','日记'],['capture','camera',''],['trends','chart-no-axes-column','趋势'],['mine','user-round','我的']].map(([p,i,t])=>`<button data-page="${p}" class="${p===active?'active ':''}${p==='capture'?'capture':''}" aria-label="${t||'拍照记录'}">${icon(i)}${t?`<span>${t}</span>`:''}</button>`).join('');
  window.lucide?.createIcons();
}
function startCapture() {
  selectedMeal = null; draft = null; image = null; note = '';
  draftDate = dateTimeInput(page==='diary' ? new Date(`${selectedDay}T12:00:00`) : new Date());
  const hour = new Date().getHours(); draftKind = hour<11?'早餐':hour<15?'午餐':hour<22?'晚餐':'加餐';
  changePage('capture');
}
function buildDraft(foods, sample) {
  if (!draftDate || !Number.isFinite(new Date(draftDate).getTime())) throw new Error('请选择有效餐食时间');
  draft = {id:id(),date:new Date(draftDate).toISOString(),kind:draftKind,foods,photo:image,note,sample,version:1};
  changePage('result');
}
function newFood() { return {id:id(),name:'',grams:100,kcal:0,fraction:1,protein:null,fat:null,carbs:null}; }
function foodEditor(food) {
  dialog.innerHTML = `<form id="food-form"><h3>编辑食物</h3><p class="small">热量填写照片中的完整份量，实际摄入按比例计算。</p><input name="id" type="hidden" value="${escape(food.id)}"><label class="field">食物名称<input name="name" value="${escape(food.name)}" maxlength="80" required></label><label class="field">完整份量（克）<input name="grams" type="number" min="0.01" max="10000" step="any" value="${food.grams}" required></label><label class="field">完整份量热量（千卡）<input name="kcal" type="number" min="0" max="20000" step="any" value="${food.kcal}" required></label><label class="field">实际摄入比例 <b id="fraction-label">${round(food.fraction*100)}%</b><input name="fraction" type="range" min="0" max="1" step="0.05" value="${food.fraction}"></label><div class="fraction-buttons">${[.25,.5,.75,1].map(n=>`<button type="button" data-fraction="${n}">${n*100}%</button>`).join('')}</div>${[['protein','蛋白质'],['fat','脂肪'],['carbs','碳水']].map(([k,t])=>`<label class="field">${t}（克，未知留空）<input name="${k}" type="number" min="0" max="10000" step="any" value="${food[k]??''}"></label>`).join('')}<div id="form-error" class="error" hidden></div><div class="actions"><button type="button" id="cancel-editor" class="secondary">取消</button><button type="submit" class="primary">完成</button></div></form>`;
  dialog.showModal();
}
function download(text, name) {
  const url = URL.createObjectURL(new Blob([text],{type:'application/json'})); const link = document.createElement('a'); link.href=url; link.download=name; link.click(); setTimeout(()=>URL.revokeObjectURL(url),1000);
}
document.addEventListener('click', async event => {
  const button = event.target.closest('button'); if (!button || button.disabled) return;
  try {
    if (button.dataset.page) { if (button.dataset.page==='capture' && page!=='result') startCapture(); else changePage(button.dataset.page); }
    else if ('capture' in button.dataset) startCapture();
    else if (button.dataset.day) { selectedDay=button.dataset.day; render(); }
    else if (button.dataset.detail) { selectedMeal=button.dataset.detail; changePage('detail'); }
    else if (button.dataset.range) { range=Number(button.dataset.range); render(); }
    else if (button.dataset.edit) foodEditor(draft.foods.find(f=>f.id===button.dataset.edit));
    else if (button.dataset.remove) { draft.foods=draft.foods.filter(f=>f.id!==button.dataset.remove); render(); }
    else if (button.dataset.fraction) { dialog.querySelector('[name=fraction]').value=button.dataset.fraction; dialog.querySelector('#fraction-label').textContent=`${Number(button.dataset.fraction)*100}%`; }
    else switch(button.id || ('demo' in button.dataset ? 'load-demo' : '')) {
      case 'load-demo': {
        const times = ['08:12','12:32','18:45'];
        const items = [['早餐',[['燕麦',50,180],['牛奶',250,143],['鸡蛋',50,63]]],['午餐',[['米饭',150,232],['红烧鸡块',120,180],['西兰花',80,45]]],['晚餐',[['番茄牛腩',180,260],['青菜',100,68]]]];
        let next=meals;
        items.forEach(([kind,foods],i)=>{ next=upsert(next,{id:`demo-${i}`,date:new Date(`${localDay()}T${times[i]}:00`).toISOString(),kind,foods:foods.map(([name,grams,kcal],j)=>({id:`demofood-${i}-${j}`,name,grams,kcal,fraction:1,protein:null,fat:null,carbs:null})),sample:true,note:'用户主动加载的示例，不能视为真实识别'}); });
        persist(next); render(); toast('已加载明确标识的示例餐食'); break;
      }
      case 'analyze': {
        busy=true; render(); await new Promise(resolve=>setTimeout(resolve,400)); busy=false;
        if(failRecognition) { render(); toast('模拟：服务响应失败。照片与说明已保留，可重试或手动记录。'); break; }
        buildDraft([['米饭',150,232,4,.3,50],['红烧鸡块',120,180,22,9,4],['西兰花',80,45,2,.5,4]].map(([name,grams,kcal,protein,fat,carbs])=>({id:id(),name,grams,kcal,protein,fat,carbs,fraction:1})),true); break;
      }
      case 'manual': { if(page!=='capture') startCapture(); buildDraft([],false); foodEditor(newFood()); break; }
      case 'add-food': foodEditor(newFood()); break;
      case 'cancel-editor': dialog.close(); break;
      case 'save-meal': {
        busy=true; const next=upsert(meals,draft); persist(next); selectedMeal=draft.id; busy=false; changePage('detail'); toast('本机已保存；外部健康平台未连接'); break;
      }
      case 'edit-meal': draft=structuredClone(meals.find(m=>m.id===selectedMeal)); changePage('result'); break;
      case 'copy-meal': {
        const text=copyText(meals.find(m=>m.id===selectedMeal));
        try { await navigator.clipboard.writeText(text); toast('已复制，请在小米运动健康手动填写'); }
        catch { dialog.innerHTML=`<h3>复制本餐信息</h3><textarea readonly style="width:100%;height:200px">${escape(text)}</textarea><button id="cancel-editor" class="primary">完成</button>`; dialog.showModal(); }
        break;
      }
      case 'delete-meal': {
        dialog.innerHTML='<h3>删除本餐？</h3><p class="small">只删除当前预览的本机记录。外部平台未连接，不会删除其他应用数据。</p><div class="actions"><button id="cancel-editor" class="secondary">取消</button><button id="confirm-delete" class="primary">确认删除</button></div>';dialog.showModal();break;
      }
      case 'confirm-delete': persist(meals.filter(m=>m.id!==selectedMeal));dialog.close();changePage('diary');toast('已删除本餐');break;
      case 'edit-goal': {
        dialog.innerHTML=`<form id="goal-form"><h3>每日热量目标</h3><p class="small">仅用于记录进度，不是推荐摄入量。</p><label class="field">千卡<input name="goal" type="number" min="500" max="10000" value="${goal}" required></label><div class="actions"><button type="button" id="cancel-editor" class="secondary">取消</button><button class="primary">保存</button></div></form>`; dialog.showModal(); break;
      }
      case 'export': download(exportMeals(meals),'轻食记-预览记录.json'); toast('导出内容包含个人饮食记录，不含密钥'); break;
      case 'raw-export': download(localStorage.getItem(storageKey)||'','轻食记-原始备份.json'); break;
    }
  } catch(error) { busy=false; toast(`未完成：${error.message}`); }
});
document.addEventListener('input', event => {
  const el=event.target;
  if(el.id==='note') note=el.value;
  if(el.id==='meal-date') draftDate=el.value;
  if(el.name==='fraction') dialog.querySelector('#fraction-label').textContent=`${round(Number(el.value)*100)}%`;
});
document.addEventListener('change', async event => {
  const el=event.target;
  try {
    if(el.id==='date') { selectedDay=el.value; render(); }
    if(el.id==='kind') draftKind=el.value;
    if(el.id==='fail') failRecognition=el.checked;
    if(el.id==='photo') {
      const file=el.files?.[0]; if(!file)return;
      if(!/^image\/(jpeg|png|webp)$/.test(file.type)||file.size>3*1024*1024) throw new Error('请选择小于 3MB 的 JPEG、PNG 或 WebP 照片');
      image=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result);reader.onerror=reject;reader.readAsDataURL(file)}); render();
    }
    if(el.id==='import') {
      const file=el.files?.[0];if(!file)return;if(file.size>5*1024*1024)throw new Error('导入文件过大');
      const imported=restore(await file.text());let next=meals;for(const meal of imported)next=upsert(next,meal);persist(next);render();toast('已合并导入，重复餐食按 ID 更新');
    }
  } catch(error) { toast(error.message||'文件读取失败'); }
});
document.addEventListener('submit', event => {
  event.preventDefault();const form=event.target;const data=new FormData(form);const formId=form.getAttribute('id');
  try {
    if(formId==='food-form') {
      const food={id:data.get('id'),name:String(data.get('name')).trim(),grams:Number(data.get('grams')),kcal:Number(data.get('kcal')),fraction:Number(data.get('fraction'))};
      for(const key of ['protein','fat','carbs'])food[key]=data.get(key)===''?null:Number(data.get(key));
      totalKcal([food]);const index=draft.foods.findIndex(f=>f.id===food.id);if(index>=0)draft.foods[index]=food;else draft.foods.push(food);
      dialog.close();render();
    } else if(formId==='goal-form') {
      const value=Number(data.get('goal'));if(!Number.isFinite(value)||value<500||value>10000)throw new Error('目标范围 500–10000');
      localStorage.setItem('lightmeal-preview-goal',String(value));goal=value;dialog.close();render();
    }
  } catch(error) {const box=document.querySelector('#form-error');if(box){box.hidden=false;box.textContent=error.message}else toast(error.message);}
});
render();


