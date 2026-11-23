const tg = window.Telegram?.WebApp;
export async function api(path, options = {}) {
  const response = await fetch(`/api/${path.replace(/^\//, '')}`, {
    method: options.method || 'GET',
    headers: { 'Content-Type': 'application/json', 'X-Telegram-Init-Data': tg?.initData || '', ...(options.headers || {}) },
    body: options.body === undefined ? undefined : JSON.stringify(options.body)
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) throw new Error(data.error || `Request failed (${response.status})`);
  return data;
}
export function telegramUser() { try { return JSON.parse(new URLSearchParams(tg?.initData || '').get('user') || 'null'); } catch { return null; } }
export function formatNumber(value, digits = 2) { return new Intl.NumberFormat('en-US', { maximumFractionDigits: digits }).format(Number(value || 0)); }
