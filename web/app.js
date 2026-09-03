// ═══════════════════════════════════════════════════════════
//  GODDESS — NUI DASHBOARD LOGIC
// ═══════════════════════════════════════════════════════════

const resourceName = (window.GetParentResourceName && window.GetParentResourceName()) || 'Goddess';

const app = document.getElementById('app');
let latestData = { players: [], detections: [], bans: [] };

function post(endpoint, body) {
  return fetch(`https://${resourceName}/${endpoint}`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json; charset=UTF-8' },
    body: JSON.stringify(body || {}),
  }).catch(() => {});
}

window.addEventListener('message', (event) => {
  const { action, payload } = event.data;
  if (action === 'open') {
    app.classList.remove('hidden');
  } else if (action === 'close') {
    app.classList.add('hidden');
  } else if (action === 'data') {
    latestData = payload;
    render(payload);
  }
});

document.getElementById('closeBtn').addEventListener('click', () => {
  app.classList.add('hidden');
  post('close');
});

document.getElementById('refreshBtn').addEventListener('click', () => {
  post('refresh');
});

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    app.classList.add('hidden');
    post('close');
  }
});

document.querySelectorAll('.tab').forEach((tab) => {
  tab.addEventListener('click', () => {
    document.querySelectorAll('.tab').forEach((t) => t.classList.remove('active'));
    document.querySelectorAll('.tab-panel').forEach((p) => p.classList.remove('active'));
    tab.classList.add('active');
    document.getElementById(`tab-${tab.dataset.tab}`).classList.add('active');
  });
});

function severityBadge(score) {
  if (score >= 60) return `<span class="badge high">${score}</span>`;
  if (score >= 25) return `<span class="badge med">${score}</span>`;
  return `<span class="badge low">${score}</span>`;
}

function render(data) {
  document.getElementById('version').textContent = `v${data.version || '1.0.0'}`;
  document.getElementById('dbStatus').textContent = `DB: ${data.dbReady ? 'Connected' : 'In-memory'}`;

  const players = data.players || [];
  const detections = data.detections || [];
  const bans = data.bans || [];

  document.getElementById('statOnline').textContent = players.length;
  document.getElementById('statSuspicious').textContent = players.filter((p) => p.score >= 25).length;
  document.getElementById('statDetections').textContent = detections.length;
  document.getElementById('statBans').textContent = bans.length;

  const playersBody = document.querySelector('#playersTable tbody');
  playersBody.innerHTML = players.length ? players.map((p) => `
    <tr>
      <td>${p.id}</td>
      <td>${escapeHtml(p.name)}</td>
      <td>${severityBadge(p.score)}</td>
      <td>${p.elevated ? '🔺 Elevated Monitoring' : 'Normal'}</td>
      <td>
        <button class="row-btn" data-action="clear" data-id="${p.id}">Clear</button>
        <button class="row-btn" data-action="kick" data-id="${p.id}">Kick</button>
        <button class="row-btn danger" data-action="ban" data-id="${p.id}">Ban</button>
      </td>
    </tr>`).join('') : `<tr><td colspan="5" class="empty-state">No players online.</td></tr>`;

  const detectionsBody = document.querySelector('#detectionsTable tbody');
  detectionsBody.innerHTML = detections.length ? detections.map((d) => `
    <tr>
      <td>${d.created_at ? new Date(d.created_at).toLocaleString() : '—'}</td>
      <td>${escapeHtml(d.player_name || '?')}</td>
      <td>${escapeHtml(d.detection || '?')}</td>
      <td>${d.severity ?? '—'}</td>
      <td>${d.score_after ?? '—'}</td>
    </tr>`).join('') : `<tr><td colspan="5" class="empty-state">No recent detections.</td></tr>`;

  const bansBody = document.querySelector('#bansTable tbody');
  bansBody.innerHTML = bans.length ? bans.map((b) => `
    <tr>
      <td>${escapeHtml(b.player_name || '?')}</td>
      <td>${escapeHtml((b.license || '').slice(0, 18))}…</td>
      <td>${escapeHtml(b.reason || '—')}</td>
      <td>${b.banned_at ? new Date(b.banned_at).toLocaleDateString() : '—'}</td>
      <td><button class="row-btn" data-action="unban" data-license="${b.license}">Unban</button></td>
    </tr>`).join('') : `<tr><td colspan="5" class="empty-state">No active bans.</td></tr>`;

  document.querySelectorAll('[data-action]').forEach((btn) => {
    btn.addEventListener('click', () => {
      const action = btn.dataset.action;
      const payload = { action };
      if (btn.dataset.id) payload.id = btn.dataset.id;
      if (btn.dataset.license) payload.license = btn.dataset.license;
      if (action === 'ban') {
        payload.minutes = prompt('Ban duration in minutes (0 = permanent):', '0') || '0';
        payload.reason = prompt('Ban reason:', 'Security violation detected by Goddess') || '';
      }
      if (action === 'kick') {
        payload.reason = prompt('Kick reason:', 'Kicked by administrator') || '';
      }
      post('action', payload);
      setTimeout(() => post('refresh'), 400);
    });
  });
}

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}
