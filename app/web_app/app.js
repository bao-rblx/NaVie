import { DriveSession, ease, pointAt, shortestArc, sortOptions, tripQuery } from './navigation.mjs';
import { icon } from './icons.mjs';
import { locales } from './locales.mjs';

const $ = selector => document.querySelector(selector);
const $$ = selector => [...document.querySelectorAll(selector)];
const API = `${location.protocol}//${location.hostname}:8000`;
const CENTER = [10.7769, 106.7009];
const fields = ['origin', 'destination'];
const read = (key, fallback) => { try { return JSON.parse(localStorage.getItem(`navie.${key}`)) ?? fallback; } catch { return fallback; } };
const write = (key, value) => { try { localStorage.setItem(`navie.${key}`, JSON.stringify(value)); } catch { toast(t('storageUnavailable')); } };
const settings = { language: 'vi', theme: 'light', voice: true, reduceMotion: matchMedia('(prefers-reduced-motion: reduce)').matches, ...read('settings', {}) };
let strings = {}, toastTimer, driveTimer, watchId = null, drive = null, driveGeneration = 0, rerouteController, routingController;
const state = { page: 'explore', origin: null, destination: null, picking: null, mode: 'motorbike', options: [], selected: null, busy: false, revision: 0, saved: read('saved', []), recent: read('recent', []), explored: [], preview: false, paused: false, following: true, rerouting: false };
const search = { origin: { serial: 0 }, destination: { serial: 0 } };
// `camera` is what is on screen; `cameraTarget` is where a programmatic move is
// heading. Only the rAF loop copies target -> camera, so a drag that writes both
// stays 1:1 under the finger.
const camera = { center: CENTER, zoom: 14, rotation: 0 };
const cameraTarget = { center: CENTER, zoom: 14, rotation: 0 };
const map = $('#map'), tiles = $('#tiles');
const TILE_CAP = 220;                    // LRU budget for decoded 256px tiles and their DOM nodes
const tileCache = new Map();             // key -> <img>, insertion order is recency order
const routeLayer = { geometry: null, drawn: null, zoom: 0, points: '', transform: '', group: $('#route-group'), shadow: $('#route-shadow'), line: $('#route-line') };
const exploredLayer = { drawn: [], zoom: 0, transform: '', group: $('#explored-group') };
const pinRotation = { current: 0, target: 0 };
const prefersReducedMotion = matchMedia('(prefers-reduced-motion: reduce)');
let mapFrame, cameraFrame, cameraLast, sceneTransform, explorationTimer;
function t(key) { return strings[key] || key; }
const esc = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const markupIcon = name => `<i>${icon(name)}</i>`;
function translate() {
  document.documentElement.lang = settings.language;
  document.title = `NaVie · ${t('footerTagline')}`;
  $$('[data-i18n]').forEach(el => el.textContent = t(el.dataset.i18n));
  $$('[data-label]').forEach(el => { el.setAttribute('aria-label', t(el.dataset.label)); el.title = t(el.dataset.label); });
  $$('[data-placeholder]').forEach(el => el.placeholder = t(el.dataset.placeholder));
  $$('[data-icon]').forEach(el => el.innerHTML = icon(el.dataset.icon));
}
async function setLanguage(language) {
  strings = locales[language]; settings.language = language; write('settings', settings); translate(); renderOptions(); renderSaved(); renderRecent(); update();
}
function applySettings() {
  const dark = settings.theme === 'dark' || settings.theme === 'auto' && matchMedia('(prefers-color-scheme: dark)').matches;
  document.body.classList.toggle('dark', dark);
  document.body.classList.toggle('reduce-motion', settings.reduceMotion);
  $('#language').value = settings.language; $('#theme').value = settings.theme;
  $('#voice').checked = settings.voice; $('#reduce-motion').checked = settings.reduceMotion;
  $('#mute-drive').innerHTML = markupIcon(settings.voice ? 'volume' : 'muted');
  $('#mute-drive').setAttribute('aria-pressed', String(settings.voice));
}
function toast(text) { clearTimeout(toastTimer); $('#toast').textContent = text; $('#toast').classList.remove('hidden'); toastTimer = setTimeout(() => $('#toast').classList.add('hidden'), 4500); }
function modeName(mode) { return t({ walk: 'modeWalk', motorbike: 'modeMotorbike', car: 'modeCar', taxi: 'modeTaxi' }[mode] || 'compareAll'); }
function duration(seconds) { const minutes = Math.max(1, Math.ceil(seconds / 60)); return minutes < 60 ? `${minutes} ${t('minutesShort')}` : `${Math.floor(minutes / 60)} ${t('hoursShort')} ${minutes % 60} ${t('minutesShort')}`; }
function meters(value) { return value < 1000 ? `${Math.round(value / 10) * 10} m` : `${(value / 1000).toFixed(1)} km`; }
async function request(path, body, signal) {
  const timeout = AbortSignal.timeout(45000);
  const response = await fetch(API + path, { method: body ? 'POST' : 'GET', headers: body ? { 'Content-Type': 'application/json' } : {}, body: body ? JSON.stringify(body) : undefined, signal: signal ? AbortSignal.any([signal, timeout]) : timeout });
  const data = await response.json();
  if (!response.ok) { const error = data.error || data.detail?.error; throw new Error(error?.[`message_${settings.language}`] || t('serverUnavailable')); }
  return data;
}
function errorText(error) { return error instanceof TypeError || error.name === 'TimeoutError' ? t('serverUnavailable') : error.message; }

// Square 256px Web Mercator tiles retain their geographic aspect ratio at every size.
function world(point, zoom = camera.zoom) {
  const scale = 256 * 2 ** zoom, lat = Math.max(-85, Math.min(85, point[0])) * Math.PI / 180;
  return [(point[1] + 180) / 360 * scale, (1 - Math.log(Math.tan(lat) + 1 / Math.cos(lat)) / Math.PI) / 2 * scale];
}
function fromWorld(point, zoom = camera.zoom) {
  const scale = 256 * 2 ** zoom;
  return [Math.atan(Math.sinh(Math.PI * (1 - 2 * point[1] / scale))) * 180 / Math.PI, point[0] / scale * 360 - 180];
}
function pixel(point) { const p = world(point), c = world(camera.center); return [p[0] - c[0] + map.clientWidth / 2, p[1] - c[1] + map.clientHeight / 2]; }
function geo(x, y) {
  const angle = -camera.rotation * Math.PI / 180, dx = x - map.clientWidth / 2, dy = y - map.clientHeight / 2, c = world(camera.center);
  return fromWorld([c[0] + dx * Math.cos(angle) - dy * Math.sin(angle), c[1] + dx * Math.sin(angle) + dy * Math.cos(angle)]);
}
function scheduleMap() { if (!mapFrame) mapFrame = requestAnimationFrame(() => { mapFrame = null; renderMap(); }); }
// --- motion ---------------------------------------------------------------
// Every programmatic move eases toward `cameraTarget`; direct manipulation writes
// both objects instead, so pan and pinch never lag behind the pointer.
const reducedMotion = () => settings.reduceMotion || prefersReducedMotion.matches;
function stopCamera() { if (cameraFrame) cancelAnimationFrame(cameraFrame); cameraFrame = null; }
function snapCamera() {
  stopCamera();
  camera.center = cameraTarget.center; camera.zoom = cameraTarget.zoom;
  camera.rotation = cameraTarget.rotation; pinRotation.current = pinRotation.target;
  scheduleMap();
}
function animateCamera() {
  if (reducedMotion()) snapCamera();
  else if (!cameraFrame) cameraFrame = requestAnimationFrame(cameraStep);
}
function cameraStep(now) {
  cameraFrame = null;
  const dt = Math.min(64, now - (cameraLast || now)); cameraLast = now;
  const from = world(camera.center, 0), to = world(cameraTarget.center, 0);
  camera.center = fromWorld([ease(from[0], to[0], 90, dt), ease(from[1], to[1], 90, dt)], 0);
  camera.zoom = ease(camera.zoom, cameraTarget.zoom, 90, dt);
  const rotation = shortestArc(camera.rotation, cameraTarget.rotation);
  camera.rotation = ease(camera.rotation, rotation, 90, dt);
  const heading = shortestArc(pinRotation.current, pinRotation.target);
  pinRotation.current = ease(pinRotation.current, heading, 60, dt);   // the compass settles a touch faster
  const resting = world(cameraTarget.center, 0), current = world(camera.center, 0);
  const gap = Math.hypot(resting[0] - current[0], resting[1] - current[1]) * 256 * 2 ** camera.zoom;
  scheduleMap();
  const settled = gap < .5 && Math.abs(cameraTarget.zoom - camera.zoom) < .002
    && Math.abs(rotation - camera.rotation) < .05 && Math.abs(heading - pinRotation.current) < .05;
  if (settled) snapCamera(); else cameraFrame = requestAnimationFrame(cameraStep);
}
function moveCamera(center, rotation = camera.rotation) {
  cameraTarget.center = center; cameraTarget.rotation = rotation;
  animateCamera();
}
// The two polylines live in index.html and are mutated in place. Points are held in
// world pixels at the layer's own zoom; one group transform places them on screen,
// so easing and panning translate the group instead of re-projecting geometry.
const worldPoints = (geometry, zoom) => {
  let points = '';
  for (const point of geometry) { const p = world(point, zoom); points += `${p[0].toFixed(1)},${p[1].toFixed(1)} `; }
  return points.trimEnd();
};
// Points are projected once at an integer zoom; panning and a zoom that is still
// easing are absorbed by one group transform, so neither re-projects the geometry.
function placeLayer(layer, width, height) {
  const scale = 2 ** (camera.zoom - layer.zoom);
  const center = world(camera.center, layer.zoom);
  const transform = `translate(${(width / 2 - center[0] * scale).toFixed(2)} ${(height / 2 - center[1] * scale).toFixed(2)}) scale(${scale.toFixed(4)})`;
  if (transform === layer.transform) return;
  layer.transform = transform; layer.group.setAttribute('transform', transform);
}
function drawRoute(geometry, width, height) {
  const zoom = Math.round(camera.zoom);
  const points = geometry?.length ? worldPoints(geometry, zoom) : '';
  if (points !== routeLayer.points) {
    routeLayer.points = points;
    routeLayer.shadow.setAttribute('points', points); routeLayer.line.setAttribute('points', points);
  }
  routeLayer.geometry = geometry; routeLayer.zoom = zoom; routeLayer.drawn = geometry;
  routeLayer.group.classList.toggle('hidden', !points);
  placeLayer(routeLayer, width, height);
}
// The circle nodes are reused too: create or drop only when the explored array changes.
// Circles are projected at exploredLayer.zoom; placeLayer's scale carries any later zoom
// change, so panning and pinching never touch the up-to-5 000 nodes.
function drawExplored(points, width, height) {
  const circles = exploredLayer.group.childNodes;
  while (circles.length > points.length) circles[circles.length - 1].remove();
  while (circles.length < points.length) {
    const circle = document.createElementNS('http://www.w3.org/2000/svg', 'circle');
    circle.setAttribute('r', '2.5'); circle.setAttribute('fill', '#5c66c7'); circle.setAttribute('opacity', '.45');
    exploredLayer.group.append(circle);
  }
  // The lab animation only ever appends to the previous array, so re-coordinate the
  // tail; any other change (a new selection, a big zoom jump) reprojects everything.
  const grew = exploredLayer.drawn.length <= points.length && points[0] === exploredLayer.drawn[0];
  const jumped = Math.abs(Math.round(camera.zoom) - exploredLayer.zoom) > 1;
  if (jumped) exploredLayer.zoom = Math.round(camera.zoom);
  const drawn = exploredLayer.group.childNodes;
  for (let index = grew && !jumped ? exploredLayer.drawn.length : 0; index < points.length; index++) {
    const p = world(points[index], exploredLayer.zoom);
    drawn[index].setAttribute('cx', p[0].toFixed(1)); drawn[index].setAttribute('cy', p[1].toFixed(1));
  }
  exploredLayer.drawn = points;
  placeLayer(exploredLayer, width, height);
}
function renderMap() {
  const width = map.clientWidth, height = map.clientHeight, zoom = camera.zoom;
  const angle = camera.rotation * Math.PI / 180;
  // Tiles only exist at integer zooms, so a zoom that is easing between two levels
  // draws the nearest level scaled to fit: no invalid tile URLs, no pop to blank.
  const tileZoom = Math.round(zoom), scale = 2 ** (zoom - tileZoom);
  const center = world(camera.center, tileZoom);
  const left = center[0] - width / 2 / scale, top = center[1] - height / 2 / scale;
  const marginX = (Math.max(0, (Math.abs(width * Math.cos(angle)) + Math.abs(height * Math.sin(angle)) - width) / 2) + 64) / scale;
  const marginY = (Math.max(0, (Math.abs(width * Math.sin(angle)) + Math.abs(height * Math.cos(angle)) - height) / 2) + 64) / scale;
  const limit = 2 ** tileZoom, keys = new Set();
  for (let y = Math.floor((top - marginY) / 256); y <= Math.floor((top + height / scale + marginY) / 256); y++) {
    for (let x = Math.floor((left - marginX) / 256); x <= Math.floor((left + width / scale + marginX) / 256); x++) {
      if (x < 0 || y < 0 || x >= limit || y >= limit) continue;
      const key = `${tileZoom}/${x}/${y}`; keys.add(key);
      let image = tileCache.get(key);
      if (image) { tileCache.delete(key); tileCache.set(key, image); }        // refresh LRU position
      else {
        image = new Image(); image.className = 'tile'; image.alt = ''; image.draggable = false;
        image.src = `https://tile.openstreetmap.org/${key}.png`; tileCache.set(key, image);
      }
      // A visible tile is already parented: move it with a transform, never re-append it.
      image.style.transform = `translate(${x * 256 - left}px,${y * 256 - top}px) scale(${scale})`;
      if (image.parentNode !== tiles) tiles.append(image);
    }
  }
  // Tiles that left the viewport stay cached so panning back does not re-download,
  // but they are detached so they cost nothing to composite. The Map is in recency
  // order (visible keys were re-inserted above), so dropping from the front is LRU.
  for (const [key, image] of tileCache) if (!keys.has(key) && image.parentNode) image.remove();
  for (const [key, image] of tileCache) {
    if (tileCache.size <= TILE_CAP) break;
    if (keys.has(key)) continue;
    image.remove(); tileCache.delete(key);
  }
  const rotation = Math.round(camera.rotation * 1000) / 1000;
  if (rotation !== sceneTransform) { sceneTransform = rotation; $('#map-scene').style.transform = `rotate(${rotation}deg)`; }
  for (const field of fields) {
    const pin = $(`#${field}-pin`), place = state[field]; pin.classList.toggle('hidden', !place || !!drive);
    if (place) { const p = pixel(place.latlon); pin.style.left = `${p[0]}px`; pin.style.top = `${p[1]}px`; }
  }
  const geometry = drive?.route.geometry || state.selected?.legs[0]?.geometry || null;
  if (geometry !== routeLayer.drawn || Math.abs(zoom - routeLayer.zoom) > 1) drawRoute(geometry, width, height);
  else placeLayer(routeLayer, width, height);
  if (state.explored !== exploredLayer.drawn || Math.abs(zoom - exploredLayer.zoom) > 1) drawExplored(state.explored, width, height);
  else placeLayer(exploredLayer, width, height);
  if (drive?.position) {
    const p = pixel(drive.position);
    $('#driver-pin').style.left = `${p[0]}px`; $('#driver-pin').style.top = `${p[1]}px`;
    pinRotation.target = drive.heading || 0;
    $('#driver-pin span').style.transform = `rotate(${pinRotation.current.toFixed(2)}deg)`;
  }
}
function fitRoute(geometry) {
  if (!geometry?.length) return;
  const lats = geometry.map(p => p[0]), lons = geometry.map(p => p[1]);
  const min = [Math.min(...lats), Math.min(...lons)], max = [Math.max(...lats), Math.max(...lons)];
  let zoom = 10, center = [(min[0] + max[0]) / 2, (min[1] + max[1]) / 2];
  const mobile = innerWidth <= 600 && !drive;
  for (let z = 17; z >= 10; z--) { const a = world(min, z), b = world(max, z); if (Math.abs(a[0] - b[0]) < map.clientWidth - 100 && Math.abs(a[1] - b[1]) < (mobile ? map.clientHeight * .3 : map.clientHeight - (drive ? 360 : 170))) { zoom = z; break; } zoom = z; }
  if (mobile) { const p = world(center, zoom); center = fromWorld([p[0], p[1] + map.clientHeight * .25], zoom); }
  cameraTarget.center = center; cameraTarget.zoom = zoom; cameraTarget.rotation = 0;
  animateCamera();
}
function changeZoom(delta, anchor = [map.clientWidth / 2, map.clientHeight / 2]) {
  if (drive) state.following = false;
  const zoom = Math.max(10, Math.min(19, cameraTarget.zoom + delta));
  const point = geo(...anchor), p = world(point, zoom);           // keep the point under the cursor fixed
  cameraTarget.zoom = zoom; cameraTarget.rotation = 0;
  cameraTarget.center = fromWorld([p[0] - anchor[0] + map.clientWidth / 2, p[1] - anchor[1] + map.clientHeight / 2], zoom);
  animateCamera();
}
let drag = null, moved = false;
const pointers = new Map(); let pinch = null;
map.addEventListener('pointerdown', event => {
  if (event.target.closest('a')) return;
  pointers.set(event.pointerId, [event.clientX, event.clientY]); map.setPointerCapture(event.pointerId);
  if (pointers.size === 2) { const [a,b] = [...pointers.values()]; pinch = Math.hypot(a[0]-b[0],a[1]-b[1]); moved = true; drag = null; return; }
  stopCamera(); drag = { x: event.clientX, y: event.clientY, center: world(camera.center) }; moved = false;
});
map.addEventListener('pointermove', event => {
  if (!pointers.has(event.pointerId)) return; pointers.set(event.pointerId, [event.clientX,event.clientY]);
  if (pointers.size === 2 && pinch) { const [a,b] = [...pointers.values()], gap = Math.hypot(a[0]-b[0],a[1]-b[1]); if (gap / pinch > 1.5 || gap / pinch < .66) { const rect = map.getBoundingClientRect(); changeZoom(gap > pinch ? 1 : -1, [(a[0]+b[0])/2-rect.left,(a[1]+b[1])/2-rect.top]); pinch = gap; } return; }
  if (!drag) return;
  const dx = event.clientX - drag.x, dy = event.clientY - drag.y;
  if (Math.hypot(dx, dy) > 4) moved = true;
  if (!moved) return;
  state.following = false; cameraTarget.rotation = 0;
  camera.center = cameraTarget.center = fromWorld([drag.center[0] - dx, drag.center[1] - dy]); scheduleMap();
});
map.addEventListener('pointerup', event => {
  const wasPinch = pinch !== null; pointers.delete(event.pointerId); if (!pointers.size) pinch = null;
  if (!moved && !wasPinch && drag && !drive && state.picking) { const rect = map.getBoundingClientRect(); selectPlace(state.picking, { name: t('mapPin'), latlon: geo(event.clientX - rect.left, event.clientY - rect.top) }); }
  drag = null;
});
map.addEventListener('pointercancel', () => { pointers.clear(); drag = null; pinch = null; });
map.addEventListener('wheel', event => { event.preventDefault(); const rect = map.getBoundingClientRect(); changeZoom(event.deltaY < 0 ? 1 : -1, [event.clientX - rect.left,event.clientY - rect.top]); }, { passive: false });
map.addEventListener('keydown', event => {
  if (['+', '=', '-'].includes(event.key)) { event.preventDefault(); changeZoom(event.key === '-' ? -1 : 1); }
  const direction = { ArrowLeft: [-100,0], ArrowRight: [100,0], ArrowUp: [0,-100], ArrowDown: [0,100] }[event.key];
  if (direction) { event.preventDefault(); const p = world(cameraTarget.center); cameraTarget.center = fromWorld([p[0]+direction[0],p[1]+direction[1]]); animateCamera(); }
  if (event.key === 'Enter' && state.picking && !drive) selectPlace(state.picking, { name:t('mapPin'),latlon:camera.center });
});

function invalidate() {
  clearInterval(explorationTimer);
  labSerial++; labController?.abort(); $('#lab-results').replaceChildren(); $('#run-lab').disabled=false;
  state.revision++; routingController?.abort(); state.busy = false; state.options = []; state.selected = null; state.explored = []; $('#message').textContent = ''; renderOptions();
}
function update() {
  $('#find-route').disabled = !state.origin || !state.destination || state.busy;
  $('#find-route').classList.toggle('loading', state.busy); $('#find-label').textContent = t(state.busy ? 'findingRoute' : 'findRoute');
  fields.forEach(field => { $(`#${field}-row`).classList.toggle('active', state.picking === field); });
  $$('[data-mode]').forEach(button => { const selected = button.dataset.mode === state.mode; button.classList.toggle('selected',selected); button.setAttribute('aria-pressed',String(selected)); });
  $('#map-hint span').textContent = t(state.picking === 'origin' ? 'chooseOrigin' : state.picking === 'destination' ? 'chooseDestination' : 'mapHint');
  $('#save-destination').disabled = !state.destination;
  scheduleMap();
}
function setPage(page) {
  clearInterval(explorationTimer);
  state.page = page; closeSuggestions(); state.explored = []; document.body.classList.remove('panel-collapsed');
  $$('.page').forEach(el => el.classList.toggle('hidden', el.id !== `page-${page}`));
  $$('[data-page]').forEach(el => { el.classList.toggle('active', el.dataset.page === page); if (el.dataset.page === page) el.setAttribute('aria-current','page'); else el.removeAttribute('aria-current'); });
  $('#workspace').scrollTop = 0; renderSaved(); scheduleMap();
}
function cancelSearch(field) { search[field].serial++; clearTimeout(search[field].timer); search[field].controller?.abort(); }
function closeSuggestions(field) { for (const key of field ? [field] : fields) { cancelSearch(key); $(`#${key}-suggestions`).classList.add('hidden'); $(`#${key}-search`).setAttribute('aria-expanded','false'); } }
function showSearchStatus(field, key) { const panel = $(`#${field}-suggestions`); panel.innerHTML = `<p class="suggestion-status">${esc(t(key))}</p>`; panel.classList.remove('hidden'); $(`#${field}-search`).setAttribute('aria-expanded','true'); }
function scheduleSearch(field) {
  cancelSearch(field); const query = $(`#${field}-search`).value.trim();
  if (query.length < 2) { closeSuggestions(field); return; }
  const serial = search[field].serial; showSearchStatus(field, 'searchingPlaces');
  search[field].timer = setTimeout(async () => {
    const controller = new AbortController(); search[field].controller = controller;
    try {
      const near = state[field === 'origin' ? 'destination' : 'origin']?.latlon || CENTER;
      const places = await request(`/v1/geocode?${new URLSearchParams({q:query,near:near.join(',')})}`, null, controller.signal);
      if (serial !== search[field].serial) return;
      const panel = $(`#${field}-suggestions`); panel.replaceChildren();
      if (!places.length) { showSearchStatus(field,'noPlaces'); return; }
      places.forEach(place => {
        const button = document.createElement('button'); button.className = 'suggestion'; button.setAttribute('role','option');
        button.innerHTML = `${markupIcon('pin')}<span><strong>${esc(place.name)}</strong><small>${esc(place.address || t('place'))}</small></span>`;
        button.onclick = () => selectPlace(field,place);
        button.onkeydown = event => { if (event.key === 'ArrowDown') { event.preventDefault(); button.nextElementSibling?.focus(); } if (event.key === 'ArrowUp') { event.preventDefault(); (button.previousElementSibling || $(`#${field}-search`)).focus(); } if (event.key === 'Escape') { closeSuggestions(field); $(`#${field}-search`).focus(); } };
        panel.append(button);
      });
    } catch (error) { if (serial === search[field].serial && error.name !== 'AbortError') showSearchStatus(field,'serverUnavailable'); }
  },300);
}
function selectPlace(field, place) {
  invalidate(); state[field] = place; $(`#${field}-search`).value = place.name; closeSuggestions();
  state.picking = field === 'origin' && !state.destination ? 'destination' : null;
  state.recent = [place,...state.recent.filter(p => p.name !== place.name)].slice(0,4); write('recent',state.recent);
  moveCamera(place.latlon, 0); renderRecent(); update();
  if (field === 'origin' && !state.destination) $(`#destination-search`).focus();
}
function resetTrip() { invalidate(); for (const field of fields) { state[field] = null; $(`#${field}-search`).value = ''; } state.picking = null; closeSuggestions(); cameraTarget.center = CENTER; cameraTarget.zoom = 14; cameraTarget.rotation = 0; animateCamera(); update(); }
async function locate() {
  if (!navigator.geolocation) return toast(t('locationUnavailable'));
  toast(t('findingLocation'));
  navigator.geolocation.getCurrentPosition(position => { selectPlace('origin',{name:t('myLocation'),latlon:[position.coords.latitude,position.coords.longitude]}); }, () => toast(t('locationDenied')), {enableHighAccuracy:true,timeout:15000,maximumAge:10000});
}
async function findRoutes() {
  if (!state.origin || !state.destination || state.busy) return;
  const revision = state.revision, controller = new AbortController(); routingController?.abort(); routingController = controller;
  state.busy = true; $('#message').textContent = ''; update();
  try {
    const body = await request('/v1/plan', tripQuery(state.origin,state.destination,state.mode),controller.signal);
    if (revision !== state.revision) return;
    state.options = body.options.filter(option => option.legs[0]?.geometry.length > 0);
    if (!state.options.length) throw new Error(t('errorNoPath'));
    state.selected = sortOptions(state.options,$('#sort').value)[0]; renderOptions(); fitRoute(state.selected.legs[0].geometry);
    $('#route-results').scrollIntoView({behavior:settings.reduceMotion ? 'instant' : 'smooth',block:'nearest'});
  } catch (error) { if (revision === state.revision && error.name !== 'AbortError') $('#message').textContent = errorText(error); }
  finally { if (revision === state.revision) {state.busy = false; update();} }
}
function price(option) { return option.legs.some(leg => leg.estimate) ? t('priceUnavailable') : new Intl.NumberFormat(settings.language === 'vi' ? 'vi-VN' : 'en-US',{style:'currency',currency:'VND',maximumFractionDigits:0}).format(option.cost_vnd); }
function renderOptions() {
  $('#welcome').classList.toggle('hidden',state.options.length > 0); $('#route-results').classList.toggle('hidden',!state.options.length);
  const list = $('#results'); list.replaceChildren();
  const fastest = Math.min(...state.options.map(o => o.duration_s));
  for (const option of sortOptions(state.options,$('#sort').value)) {
    const button = document.createElement('button'); button.className = `route-card${state.selected === option ? ' selected' : ''}`; button.setAttribute('aria-pressed',String(state.selected === option));
    button.innerHTML = `${markupIcon(option.modes[0])}<span><strong>${esc(modeName(option.modes[0]))}</strong><small>${meters(option.distance_m)} · ${esc(price(option))}</small>${state.options.length > 1 && option.duration_s === fastest ? `<span class="badge">${esc(t('fastest'))}</span>` : ''}</span><span class="time">${duration(option.duration_s)}</span>`;
    button.onclick = () => { state.selected = option; renderOptions(); fitRoute(option.legs[0].geometry); }; list.append(button);
  }
  if (!state.selected) return;
  const route = state.selected.legs[0], locale = settings.language;
  $('#trip-detail').innerHTML = `<div class="detail-card"><p>${esc(t('routeEstimateNote'))}</p><p>${esc(t('pricingUpdated'))}: ${esc(route.data_version.pricing === 'TODO-verify' ? t('notVerified') : route.data_version.pricing)}</p><details><summary><strong>${esc(t('directions'))} · ${route.maneuvers.length}</strong>↓</summary><ol class="maneuver-list">${route.maneuvers.map(m => `<li>${esc(m[`text_${locale}`])} <small>· ${meters(m.distance_m)}</small></li>`).join('')}<li>${esc(t('youArrived'))}</li></ol></details><button class="text-button" id="save-route-place">${markupIcon('bookmark')}${esc(t('saveDestination'))}</button></div>`;
  $('#save-route-place').onclick = saveDestination;
}
function saveDestination() {
  const place = state.destination; if (!place) return toast(t('chooseDestination'));
  if (!state.saved.some(p => p.latlon.join(',') === place.latlon.join(','))) { state.saved.push(place); write('saved',state.saved); }
  renderSaved(); toast(t('placeSaved'));
}
function renderSaved() {
  $('#saved-list').replaceChildren();
  if (!state.saved.length) { $('#saved-list').innerHTML = `<div class="empty-state">${markupIcon('bookmark')}<p>${esc(t('noSavedPlaces'))}</p></div>`; return; }
  state.saved.forEach((place,index) => {
    const item = document.createElement('article'); item.className='saved-item';
    item.innerHTML = `<button class="place-button">${markupIcon('pin')}<span><strong>${esc(place.name)}</strong><small>${esc(place.address || t('savedOnDevice'))}</small></span></button><button class="icon-button" aria-label="${esc(t('removePlace'))}">${markupIcon('trash')}</button>`;
    item.firstElementChild.onclick = () => { selectPlace('destination',place); setPage('explore'); };
    item.lastElementChild.onclick = () => { state.saved.splice(index,1); write('saved',state.saved); renderSaved(); };
    $('#saved-list').append(item);
  });
}
function renderRecent() {
  $('#recent').replaceChildren();
  if (!state.recent.length) return;
  const heading = document.createElement('div'); heading.className='section-heading'; heading.innerHTML=`<h2>${esc(t('recentPlaces'))}</h2>`; $('#recent').append(heading);
  state.recent.slice(0,2).forEach(place => { const button=document.createElement('button'); button.className='suggestion'; button.innerHTML=`${markupIcon('clock')}<span><strong>${esc(place.name)}</strong><small>${esc(t('useAsDestination'))}</small></span>`; button.onclick=()=>selectPlace('destination',place); $('#recent').append(button); });
}

// Never cancel an in-flight prompt: a second call while speaking is dropped rather
// than cutting the first one off mid-word. The flag clears on end/error.
let isSpeaking = false;
function stopSpeaking() { isSpeaking = false; if ('speechSynthesis' in window) speechSynthesis.cancel(); }
function speak(text) {
  if (!settings.voice || isSpeaking || !('speechSynthesis' in window)) return;
  const utterance = new SpeechSynthesisUtterance(text);
  utterance.lang = settings.language === 'vi' ? 'vi-VN' : 'en-US';
  isSpeaking = true;
  utterance.onend = utterance.onerror = () => { isSpeaking = false; };
  speechSynthesis.speak(utterance);
}
function startDrive(preview) {
  if (!state.selected) return;
  if (!preview && !navigator.geolocation) return toast(t('locationUnavailable'));
  stopResources(); driveGeneration++;
  drive = new DriveSession(state.selected.legs[0],state.selected.modes[0]); state.preview=preview; state.paused=false; state.following=true; state.rerouting=false;
  drive.position=drive.route.geometry[0]; drive.heading=pointAt(drive.metrics,0)?.heading || 0; drive.speed=null;
  closeSuggestions(); state.picking=null; document.body.classList.add('driving'); $('#driver').classList.remove('hidden'); $('#driver-pin').classList.remove('hidden'); $('#simulation-controls').classList.toggle('hidden',!preview); $('#pause-drive').innerHTML=markupIcon('pause');
  // Start the drive camera already settled and heading-up: easing it in from the
  // planner view would fight the CSS inset transition on #map.
  stopCamera();
  camera.center = cameraTarget.center = drive.position;
  camera.zoom = cameraTarget.zoom = 17;
  camera.rotation = cameraTarget.rotation = -(drive.heading || 0);
  pinRotation.current = pinRotation.target = drive.heading || 0;
  applySettings(); renderDrive();
  if (preview) {
    speak(t('previewStarted')); let last=performance.now();
    driveTimer=setInterval(()=>{const now=performance.now(),delta=Math.min(2,(now-last)/1000);last=now;if(!drive || state.paused)return;const p=drive.advance(delta*Number($('#simulation-speed').value));drive.position=p.point;drive.heading=p.heading;renderDrive();if(drive.progress>=drive.metrics.total)arrive();},250);
  } else {
    const generation=driveGeneration;
    toast(t('waitingGps'));
    watchId=navigator.geolocation.watchPosition(position=>{
      if(!drive || generation!==driveGeneration)return;
      drive.position=[position.coords.latitude,position.coords.longitude]; drive.speed=position.coords.speed;
      const status=drive.update(drive.position,position.coords.accuracy);
      drive.heading=position.coords.heading ?? pointAt(drive.metrics,drive.progress)?.heading ?? 0;
      drive.gpsStatus=status.reliable ? 'gpsActive' : 'gpsWeak';
      if(status.reroute)reroute();
      renderDrive(); if(status.arrived)arrive();
    },()=>{ if(generation!==driveGeneration)return; endDrive();toast(t('locationDenied')); },{enableHighAccuracy:true,timeout:15000,maximumAge:0});
  }
}
function renderDrive() {
  if(!drive)return;
  const next=drive.maneuver, remaining=drive.metrics.total-drive.progress;
  const toTurn=next ? drive.metrics.cumulative[next.at_index]-drive.progress : remaining;
  const arrows={turn_left:'↰',turn_right:'↱',slight_left:'↖',slight_right:'↗',sharp_left:'↰',sharp_right:'↱',u_turn:'↶'};
  $('#turn-icon').textContent=next ? arrows[next.type] || '↑' : '⚑';
  $('#turn-distance').textContent=meters(toTurn); $('#turn-text').textContent=next?.[`text_${settings.language}`] || t('continueToDestination');
  $('#drive-status').textContent=t(state.rerouting?'rerouting':state.preview ? state.paused?'simulationPaused':'simulation' : drive.gpsStatus || 'waitingGps');
  $('#remaining-time').textContent=duration(drive.route.duration_s*drive.remainingFraction);
  $('#remaining-distance').textContent=meters(drive.route.distance_m*drive.remainingFraction);
  $('#arrival-time').textContent=new Date(Date.now()+drive.route.duration_s*drive.remainingFraction*1000).toLocaleTimeString(settings.language==='vi'?'vi-VN':'en-GB',{hour:'2-digit',minute:'2-digit',timeZone:'Asia/Ho_Chi_Minh'});
  $('#speed').textContent=!state.preview && Number.isFinite(drive.speed) && drive.speed>=0 ? Math.round(drive.speed*3.6) : '—';
  if(state.following){cameraTarget.center=drive.position;cameraTarget.rotation=-(drive.heading||0);animateCamera();}
  if(settings.voice){const announcement=drive.announcement();if(announcement)speak(`${announcement.distance} ${t('metersWord')}. ${announcement.maneuver[`text_${settings.language}`]}`);}
  scheduleMap();
}
async function reroute() {
  if(!drive || state.rerouting || Date.now()-(drive.lastReroute || 0)<10000)return;
  state.rerouting=true;drive.lastReroute=Date.now();const generation=driveGeneration,position=drive.position,mode=drive.mode;
  rerouteController=new AbortController();
  try{
    const route=await request('/v1/route',{origin:position,destination:state.destination.latlon,mode,algorithm:'astar',weight:'time'},rerouteController.signal);
    if(!drive || generation!==driveGeneration)return;
    if(!route.geometry.length)throw new Error(t('errorNoPath'));
    drive=new DriveSession(route,mode);drive.position=position;drive.lastReroute=Date.now();drive.gpsStatus='gpsActive';speak(t('routeUpdated'));toast(t('routeUpdated'));
  }catch(error){if(generation===driveGeneration && error.name!=='AbortError')toast(t('rerouteFailed'));}
  finally{if(generation===driveGeneration){state.rerouting=false;renderDrive();}}
}
function stopResources(){clearInterval(driveTimer);if(watchId!==null){navigator.geolocation.clearWatch(watchId);watchId=null;}rerouteController?.abort();stopSpeaking();}
function endDrive(){stopResources();driveGeneration++;drive=null;state.rerouting=false;document.body.classList.remove('driving');$('#driver').classList.add('hidden');$('#driver-pin').classList.add('hidden');pinRotation.current=pinRotation.target=0;if(state.selected?.legs[0])fitRoute(state.selected.legs[0].geometry);else{cameraTarget.rotation=0;animateCamera();}$('#start-drive').focus();}
function arrive(){const place=state.destination?.name;endDrive();speak(t('youArrived'));$('#arrival-place').textContent=place;$('#arrival-dialog').showModal();}

let labController, labSerial=0;
async function runLab(){
  if(!state.origin || !state.destination)return toast(t('chooseBothPoints'));
  const serial=++labSerial,revision=state.revision;labController?.abort();labController=new AbortController();$('#run-lab').disabled=true;$('#lab-results').textContent=t('runningComparison');state.explored=[];
  const algorithms=[$('#algorithm-a').value,$('#algorithm-b').value];
  try{
    // The server's memory profiler is process-wide. Run comparisons sequentially
    // so concurrent tracemalloc sessions cannot corrupt the displayed statistics.
    const responses=[];
    for(const algorithm of algorithms){
      if(serial!==labSerial || revision!==state.revision)return;
      try{responses.push({status:'fulfilled',value:await request('/v1/route',{origin:state.origin.latlon,destination:state.destination.latlon,mode:state.mode==='all'?'motorbike':state.mode,algorithm,debug:{return_explored:true,max_points:5000}},labController.signal)});}
      catch(reason){responses.push({status:'rejected',reason});}
    }
    if(serial!==labSerial || revision!==state.revision)return;
    $('#lab-results').replaceChildren();
    responses.forEach((response,index)=>{
      const card=document.createElement('article');card.className='lab-result';
      if(response.status==='rejected'){card.textContent=`${algorithms[index]}: ${errorText(response.reason)}`;}else{
        const data=response.value;card.innerHTML=`<h3>${esc(algorithms[index])}</h3><dl><dt>${esc(t('nodesExpanded'))}</dt><dd>${data.stats.nodes_expanded.toLocaleString()}</dd><dt>${esc(t('runtime'))}</dt><dd>${data.stats.runtime_ms.toFixed(1)} ms</dd><dt>${esc(t('distance'))}</dt><dd>${meters(data.distance_m)}</dd><dt>${esc(t('memory'))}</dt><dd>${data.stats.peak_memory_kb.toFixed(0)} KB</dd></dl><button class="secondary">${esc(t('showExploration'))}</button>`;
        card.querySelector('button').onclick=()=>{
          clearInterval(explorationTimer);fitRoute([...data.geometry,...data.explored]);
          state.explored=settings.reduceMotion ? data.explored : [];let count=0;
          if(!settings.reduceMotion)explorationTimer=setInterval(()=>{count+=250;state.explored=data.explored.slice(0,count);scheduleMap();if(count>=data.explored.length)clearInterval(explorationTimer);},80);
        };
      }$('#lab-results').append(card);
    });
  }catch(error){if(serial===labSerial)$('#lab-results').textContent=errorText(error);}finally{if(serial===labSerial)$('#run-lab').disabled=false;}
}

fields.forEach(field=>{
  const input=$(`#${field}-search`);
  input.oninput=()=>{invalidate();state[field]=null;state.picking=field;scheduleSearch(field);update();};
  input.onfocus=()=>{state.picking=field;update();};
  input.onkeydown=event=>{if(event.key==='ArrowDown'){event.preventDefault();$(`#${field}-suggestions .suggestion`)?.focus();}if(event.key==='Escape')closeSuggestions(field);};
});
$$('[data-pick]').forEach(button=>button.onclick=()=>{state.picking=button.dataset.pick;closeSuggestions();update();toast(t(state.picking==='origin'?'chooseOrigin':'chooseDestination'));map.focus();});
$$('[data-mode]').forEach(button=>button.onclick=()=>{if(state.mode===button.dataset.mode)return;invalidate();state.mode=button.dataset.mode;update();});
$$('[data-page]').forEach(button=>button.onclick=()=>setPage(button.dataset.page));
$('#swap').onclick=()=>{invalidate();[state.origin,state.destination]=[state.destination,state.origin];fields.forEach(field=>$(`#${field}-search`).value=state[field]?.name || '');closeSuggestions();update();};
$('#use-location').onclick=locate;$('#reset').onclick=resetTrip;$('#find-route').onclick=findRoutes;$('#sort').onchange=renderOptions;
$('#save-destination').onclick=saveDestination;$('#clear-saved').onclick=()=>{state.saved=[];state.recent=[];write('saved',[]);write('recent',[]);renderSaved();renderRecent();toast(t('savedCleared'));};
$('#language').onchange=async event=>{try{await setLanguage(event.target.value);}catch{toast(t('serverUnavailable'));}};
$('#theme').onchange=event=>{settings.theme=event.target.value;write('settings',settings);applySettings();};
$('#voice').onchange=event=>{settings.voice=event.target.checked;write('settings',settings);applySettings();};
$('#reduce-motion').onchange=event=>{settings.reduceMotion=event.target.checked;write('settings',settings);applySettings();if(settings.reduceMotion)snapCamera();};
$('#map-theme').onclick=()=>{settings.theme=document.body.classList.contains('dark')?'light':'dark';write('settings',settings);applySettings();};
$('#collapse-panel').onclick=()=>{document.body.classList.toggle('panel-collapsed');scheduleMap();};
$('#zoom-in').onclick=()=>changeZoom(1);$('#zoom-out').onclick=()=>changeZoom(-1);
$('#recenter').onclick=()=>{if(drive){state.following=true;cameraTarget.zoom=17;renderDrive();}else if(state.selected)fitRoute(state.selected.legs[0].geometry);else moveCamera(state.origin?.latlon || CENTER, 0);};
$('#north').onclick=()=>{cameraTarget.rotation=0;state.following=false;animateCamera();};
$('#start-drive').onclick=()=>startDrive(false);$('#preview-drive').onclick=()=>startDrive(true);$('#end-drive').onclick=endDrive;
$('#drive-overview').onclick=()=>{state.following=false;fitRoute(drive?.route.geometry);};
$('#pause-drive').onclick=()=>{state.paused=!state.paused;$('#pause-drive').innerHTML=markupIcon(state.paused?'play':'pause');renderDrive();};
$('#mute-drive').onclick=()=>{settings.voice=!settings.voice;write('settings',settings);if(!settings.voice)stopSpeaking();applySettings();};
$('#arrival-done').onclick=()=>$('#arrival-dialog').close();$('#run-lab').onclick=runLab;
document.addEventListener('click',event=>{if(!event.target.closest('.point-row'))closeSuggestions();});
document.addEventListener('keydown',event=>{if(event.key==='Escape' && !drive){closeSuggestions();state.picking=null;update();}});
addEventListener('resize',scheduleMap);addEventListener('pagehide',()=>{stopResources();clearInterval(explorationTimer);stopCamera();});
// #map now animates its inset when a drive starts, which changes its size without a
// window resize event; observe the element so tiles and layers stay registered.
if ('ResizeObserver' in window) new ResizeObserver(scheduleMap).observe(map);
matchMedia('(prefers-color-scheme: dark)').addEventListener('change',applySettings);
prefersReducedMotion.addEventListener('change',()=>{if(reducedMotion())snapCamera();});
await setLanguage(['vi','en'].includes(settings.language)?settings.language:'vi');applySettings();renderMap();
