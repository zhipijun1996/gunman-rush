/* Bounded runtime cache handshake; update checks never interrupt an active run. */
window.PLAYTEST_CACHE_READY = (async () => {
    if (!('serviceWorker' in navigator) || !window.isSecureContext) return false;
    try {
        await navigator.serviceWorker.register('index.cache-sw.js', {updateViaCache: 'none'});
        // An already controlled page may still use the previous deployment's
        // worker. Wait for this build, not merely for any controller.
        const deadline = Date.now() + 3900;
        while (Date.now() < deadline) {
            const controller = navigator.serviceWorker.controller;
            if (controller) {
                const current = await new Promise(resolve => {
                    const channel = new MessageChannel();
                    const timer = setTimeout(() => { channel.port1.close(); resolve(false); }, 250);
                    channel.port1.onmessage = event => {
                        clearTimeout(timer); channel.port1.close();
                        resolve(event.data?.id === __WORKER_ID__ && event.data.packs.includes('index.' + __BUILD_ID__ + '.pck'));
                    };
                    controller.postMessage({type: 'playtest-cache-version'}, [channel.port2]);
                });
                if (current) return true;
            }
            await new Promise(resolve => setTimeout(resolve, 100));
        }
        return false;
    } catch (_) { return false; }
})();
window.PLAYTEST_CACHE_READY = Promise.race([
    window.PLAYTEST_CACHE_READY,
    new Promise(resolve => setTimeout(() => resolve(false), 4000))
]);
window.addEventListener('DOMContentLoaded', () => {
    const panel = document.createElement('div');
    panel.id = 'playtest-download';
    panel.style.cssText = 'position:fixed;bottom:25px;left:50%;transform:translateX(-50%);z-index:20;width:min(90vw,480px);padding:12px;background:#19251eee;color:#edf1dc;font:14px sans-serif;border-radius:8px;text-align:center';
    const label = document.createElement('div');
    label.textContent = '正在准备试玩 · 首次加载较慢，后续使用本机缓存';
    const retry = document.createElement('button');
    retry.textContent = '连接中断？继续加载';
    retry.style.cssText = 'margin-top:10px;padding:8px 14px;background:#44654c;color:white;border:1px solid #8ca779;border-radius:5px';
    retry.onclick = () => location.reload();
    panel.append(label, retry); document.body.appendChild(panel);
    const totals = new Map();
    navigator.serviceWorker?.addEventListener('message', event => {
        const data = event.data;
        if (data?.type !== 'playtest-download' || window.PLAYTEST_LOADING_DONE) return;
        totals.set(data.mime, data);
        const loaded = [...totals.values()].reduce((sum, value) => sum + value.loaded, 0);
        label.textContent = '已准备 ' + (loaded / 1048576).toFixed(1) + ' MB · 中断后可继续，已完成分块会保留';
    });
});
let playtestUpdateChecking = false;
async function checkPlaytestUpdate() {
    if (playtestUpdateChecking || document.visibilityState === 'hidden') return;
    playtestUpdateChecking = true;
    try {
        const manifest = new URL('build-info.json', location.href);
        manifest.searchParams.set('check', Date.now().toString());
        const response = await fetch(manifest, {cache: 'no-store'});
        if (!response.ok) return;
        const live = await response.json();
        if (!live || live.build_id === __BUILD_ID__ || !/^[a-f0-9]{12}$/.test(live.build_id)) return;
        if (document.getElementById('playtest-update')) return;
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
        if (document.body) document.body.appendChild(button);
        else window.addEventListener('DOMContentLoaded', () => document.body.appendChild(button), {once: true});
    } catch (_) { /* Offline play continues with the current immutable pack. */ }
    finally { playtestUpdateChecking = false; }
}
checkPlaytestUpdate();
setInterval(checkPlaytestUpdate, 60000);
document.addEventListener('visibilitychange', checkPlaytestUpdate);
