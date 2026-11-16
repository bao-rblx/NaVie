// Route progress uses API geometry only; no invented speeds or map data.
const R = 6371000;
const rad = degrees => degrees * Math.PI / 180;
export function tripQuery(origin, destination, mode) {
  return { origin: { text: origin.name, latlon: origin.latlon }, destination: { text: destination.name, latlon: destination.latlon }, modes_allowed: mode === 'all' ? [] : [mode], optimize: 'balanced' };
}
export function distance(a, b) {
  const dlat = rad(b[0] - a[0]), dlon = rad(b[1] - a[1]);
  const h = Math.sin(dlat / 2) ** 2 + Math.cos(rad(a[0])) * Math.cos(rad(b[0])) * Math.sin(dlon / 2) ** 2;
  return 2 * R * Math.asin(Math.sqrt(Math.min(1, h)));
}
export function bearing(a, b) {
  const y = Math.sin(rad(b[1] - a[1])) * Math.cos(rad(b[0]));
  const x = Math.cos(rad(a[0])) * Math.sin(rad(b[0])) - Math.sin(rad(a[0])) * Math.cos(rad(b[0])) * Math.cos(rad(b[1] - a[1]));
  return (Math.atan2(y, x) * 180 / Math.PI + 360) % 360;
}
// Smoothing helpers for the camera/compass. `shortestArc` returns the target angle
// nearest to `from` so a heading-up camera never spins the long way round, and
// `ease` is a frame-rate independent exponential approach (1 - e^(-dt/tau)).
export function shortestArc(from, to) {
  let delta = (to - from) % 360;
  if (delta > 180) delta -= 360;
  if (delta < -180) delta += 360;
  return from + delta;
}
export function ease(from, to, tau, dt) {
  return from + (to - from) * (1 - Math.exp(-dt / tau));
}
export function routeMetrics(geometry) {
  const cumulative = [0];
  for (let i = 1; i < geometry.length; i++) cumulative.push(cumulative[i - 1] + distance(geometry[i - 1], geometry[i]));
  return { geometry, cumulative, total: cumulative.at(-1) || 0 };
}
export function pointAt(metrics, meters) {
  const { geometry, cumulative, total } = metrics;
  if (!geometry.length) return null;
  if (geometry.length === 1) return { point: geometry[0], heading: 0, index: 0 };
  const progress = Math.max(0, Math.min(total, meters));
  let index = 1;
  while (index < cumulative.length - 1 && cumulative[index] < progress) index++;
  const length = cumulative[index] - cumulative[index - 1];
  const ratio = length > 0 ? (progress - cumulative[index - 1]) / length : 0;
  const a = geometry[index - 1], b = geometry[index];
  return { point: [a[0] + (b[0] - a[0]) * ratio, a[1] + (b[1] - a[1]) * ratio], heading: bearing(a, b), index };
}
export function projectPosition(metrics, position, previous = 0) {
  // Project onto segments rather than vertices: long road edges must not
  // trigger false off-route events. Resolve crossing ties toward prior progress.
  const { geometry, cumulative } = metrics;
  if (geometry.length === 1) return { progress: 0, distance: distance(position, geometry[0]) };
  let best = { progress: 0, distance: Infinity };
  const cos = Math.cos(rad(position[0]));
  for (let i = 1; i < geometry.length; i++) {
    const a = geometry[i - 1], b = geometry[i];
    const ax = rad(a[1] - position[1]) * R * cos, ay = rad(a[0] - position[0]) * R;
    const bx = rad(b[1] - position[1]) * R * cos, by = rad(b[0] - position[0]) * R;
    const dx = bx - ax, dy = by - ay, length2 = dx * dx + dy * dy;
    const t = length2 ? Math.max(0, Math.min(1, -(ax * dx + ay * dy) / length2)) : 0;
    const gap = Math.hypot(ax + t * dx, ay + t * dy);
    const progress = cumulative[i - 1] + t * (cumulative[i] - cumulative[i - 1]);
    if (gap < best.distance - .5 || (Math.abs(gap - best.distance) <= .5 && Math.abs(progress - previous) < Math.abs(best.progress - previous))) best = { progress, distance: gap };
  }
  return best;
}
export function nextManeuver(route, metrics, progress) {
  return route.maneuvers.find(m => metrics.cumulative[m.at_index] > progress + 8) || null;
}
export function voiceThreshold(distanceToTurn, mode, spoken = new Set()) {
  // If a GPS fix skips a threshold, announce only the nearest applicable one.
  return (mode === 'walk' ? [50] : [50, 200, 500]).find(value => distanceToTurn <= value && !spoken.has(value)) ?? null;
}
export function sortOptions(options, preference) {
  const knownPrice = option => option.legs.every(leg => !leg.estimate);
  const byTime = (a, b) => a.duration_s - b.duration_s;
  return [...options].sort((a, b) => preference === 'cheapest'
    ? Number(knownPrice(b)) - Number(knownPrice(a)) || (knownPrice(a) && knownPrice(b) ? a.cost_vnd - b.cost_vnd : 0) || byTime(a, b)
    : preference === 'balanced' ? a.duration_s + a.distance_m / 10 - b.duration_s - b.distance_m / 10 : byTime(a, b));
}
export class DriveSession {
  constructor(route, mode) {
    this.route = route; this.mode = mode; this.metrics = routeMetrics(route.geometry);
    this.progress = 0; this.offRouteFixes = 0; this.spoken = new Map();
  }
  update(position, accuracy = 0) {
    if (accuracy > 40) return { reliable: false, reroute: false, arrived: false };
    const projection = projectPosition(this.metrics, position, this.progress);
    this.offRouteFixes = projection.distance > 40 ? this.offRouteFixes + 1 : 0;
    if (projection.distance <= 40) this.progress = projection.progress;
    return { reliable: true, reroute: this.offRouteFixes >= 3, arrived: this.metrics.total - this.progress < 20 && distance(position, this.route.geometry.at(-1)) < 25 };
  }
  advance(seconds) {
    const perSecond = this.route.duration_s > 0 ? this.metrics.total / this.route.duration_s : this.metrics.total;
    this.progress = Math.min(this.metrics.total, this.progress + Math.max(0, seconds) * perSecond);
    return pointAt(this.metrics, this.progress);
  }
  get remainingFraction() { return this.metrics.total > 0 ? Math.max(0, 1 - this.progress / this.metrics.total) : 0; }
  get maneuver() { return nextManeuver(this.route, this.metrics, this.progress); }
  announcement() {
    const maneuver = this.maneuver;
    if (!maneuver) return null;
    const remaining = this.metrics.cumulative[maneuver.at_index] - this.progress;
    const spoken = this.spoken.get(maneuver.at_index) || new Set();
    const threshold = voiceThreshold(remaining, this.mode, spoken);
    if (threshold === null) return null;
    for (const value of [500, 200, 50]) if (value >= threshold) spoken.add(value);
    this.spoken.set(maneuver.at_index, spoken);
    return { maneuver, distance: Math.round(remaining) };
  }
}
