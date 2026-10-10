/* A bounded cache handshake, without a reload loop or changes to user saves. */
window.PLAYTEST_CACHE_READY = (async () => {
    if (!('serviceWorker' in navigator) || !window.isSecureContext) return false;
    try {
        await navigator.serviceWorker.register('index.cache-sw.js', {updateViaCache: 'none'});
        await navigator.serviceWorker.ready;
        if (!navigator.serviceWorker.controller) {
            await new Promise(resolve => navigator.serviceWorker.addEventListener('controllerchange', resolve, {once: true}));
        }
        return true;
    } catch (_) { return false; }
})();
window.PLAYTEST_CACHE_READY = Promise.race([
    window.PLAYTEST_CACHE_READY,
    new Promise(resolve => setTimeout(() => resolve(false), 4000))
]);
// Check only a tiny manifest. A running session is never automatically interrupted.
fetch('build-info.json', {cache: 'no-store'}).then(r => r.ok ? r.json() : null).then(live => {
    if (!live || live.build_id === __BUILD_ID__) return;
    const button = document.createElement('button');
    button.id = 'playtest-update';
    button.textContent = '新版本可用 · 返回家园后点击更新';
    button.style.cssText = 'position:fixed;right:8px;top:8px;z-index:100;font:12px sans-serif;padding:8px;background:#292f3e;color:#eee;border:1px solid #727d8f;border-radius:5px';
    button.onclick = () => {
        if (!confirm('更新将结束当前试玩；已保存的音符与永久升级保留。继续？')) return;
        const next = new URL(location.href);
        next.searchParams.set('v', live.build_id);
        location.replace(next.href);
    };
    document.body ? document.body.appendChild(button) : window.addEventListener('DOMContentLoaded', () => document.body.appendChild(button), {once: true});
}).catch(() => {});
