export function validateFood(food) {
  if (!food || typeof food.name !== 'string' || !food.name.trim() || food.name.length > 80) throw new Error('请填写食物名称');
  if (!Number.isFinite(food.grams) || food.grams <= 0 || food.grams > 10000) throw new Error('份量必须在 0–10000 克之间');
  if (!Number.isFinite(food.kcal) || food.kcal < 0 || food.kcal > 20000) throw new Error('热量不合法');
  if (!Number.isFinite(food.fraction) || food.fraction < 0 || food.fraction > 1) throw new Error('摄入比例不合法');
  for (const key of ['protein', 'fat', 'carbs']) {
    if (food[key] != null && (!Number.isFinite(food[key]) || food[key] < 0 || food[key] > 10000)) throw new Error('营养素不合法');
  }
  return food;
}
export function effectiveKcal(food) { return food.kcal * food.fraction; }
export function totalKcal(foods) { return foods.reduce((sum, food) => sum + effectiveKcal(validateFood(food)), 0); }
export function totalNutrient(foods, key) {
  if (!foods.length || foods.some(food => food[key] == null)) return null;
  return foods.reduce((sum, food) => sum + food[key] * food.fraction, 0);
}
export function localDay(date = new Date()) {
  const parsed = new Date(date);
  if (!Number.isFinite(parsed.getTime())) throw new Error('日期无效');
  return `${parsed.getFullYear()}-${String(parsed.getMonth() + 1).padStart(2, '0')}-${String(parsed.getDate()).padStart(2, '0')}`;
}
export function validateMeal(meal) {
  if (!meal || typeof meal.id !== 'string' || !meal.id || !Array.isArray(meal.foods) || !meal.foods.length || meal.foods.length > 30) throw new Error('至少添加一种食物，最多 30 项');
  if (!['早餐', '午餐', '晚餐', '加餐'].includes(meal.kind)) throw new Error('餐次无效');
  if (typeof meal.date !== 'string' || !Number.isFinite(new Date(meal.date).getTime())) throw new Error('日期无效');
  localDay(meal.date); meal.foods.forEach(validateFood);
  if (new Set(meal.foods.map(f => f.id)).size !== meal.foods.length || meal.foods.some(f => typeof f.id !== 'string' || !f.id)) throw new Error('食物标识重复或缺失');
  return meal;
}
export function upsert(meals, meal) {
  validateMeal(meal);
  const old = meals.find(item => item.id === meal.id);
  const value = { ...meal, version: old ? old.version + 1 : 1, healthStatus: 'unavailable' };
  return [...meals.filter(item => item.id !== meal.id), value].sort((a, b) => new Date(b.date) - new Date(a.date));
}
export function mealsOn(meals, date) { return meals.filter(meal => localDay(meal.date) === localDay(date)).sort((a, b) => new Date(a.date) - new Date(b.date)); }
export function aggregate(meals, start, end) {
  const totals = new Map();
  for (const meal of meals) {
    if (new Date(meal.date) < new Date(start) || new Date(meal.date) > new Date(end)) continue;
    const day = localDay(meal.date); totals.set(day, (totals.get(day) ?? 0) + totalKcal(meal.foods));
  }
  return [...totals].sort(([a], [b]) => a.localeCompare(b)).map(([date, kcal]) => ({ date, kcal }));
}
export function parseRecognition(text) {
  const clean = text.trim().replace(/^```(?:json)?\s*\n([\s\S]*?)\n```$/, '$1');
  const payload = JSON.parse(clean);
  if (!Array.isArray(payload.foods) || !payload.foods.length || payload.foods.length > 30) throw new Error('模型未返回有效食物');
  return payload.foods.map((food, index) => validateFood({ ...food, id: `parsed-${index}`, fraction: 1 }));
}
export function exportMeals(meals) { meals.forEach(validateMeal); return JSON.stringify({ schemaVersion: 1, exportedAt: new Date().toISOString(), meals }, null, 2); }
export function restore(text) {
  const data = JSON.parse(text);
  if (data.schemaVersion !== 1 || !Array.isArray(data.meals)) throw new Error('历史数据格式不支持');
  data.meals.forEach(validateMeal);
  if (new Set(data.meals.map(meal => meal.id)).size !== data.meals.length) throw new Error('历史餐食标识重复');
  return data.meals;
}
export function copyText(meal) {
  validateMeal(meal);
  return `${localDay(meal.date)} · ${meal.kind}\n${meal.foods.map(f => `${f.name}：约${Math.round(f.grams * f.fraction)}克，${Math.round(effectiveKcal(f))}千卡`).join('\n')}\n合计约 ${Math.round(totalKcal(meal.foods))} 千卡（估算）`;
}
