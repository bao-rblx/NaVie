import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { DriveSession, distance, ease, routeMetrics, pointAt, projectPosition, shortestArc, sortOptions, tripQuery } from '../navigation.mjs';
import { locales } from '../locales.mjs';

const geometry = [[10.77,106.7],[10.78,106.7],[10.78,106.71]];
const route = { geometry, duration_s:200,distance_m:2200,maneuvers:[{at_index:1,type:'turn_right',text_en:'Turn right',text_vi:'Rẽ phải'}] };
test('geocoder places are converted to the TripQuery API contract',()=>{
  const query=tripQuery({name:'A',latlon:geometry[0]},{name:'B',latlon:geometry[2]},'all');
  assert.deepEqual(query.origin,{text:'A',latlon:geometry[0]});assert.deepEqual(query.destination,{text:'B',latlon:geometry[2]});assert.deepEqual(query.modes_allowed,[]);
  assert.deepEqual(tripQuery({name:'A',latlon:geometry[0]},{name:'B',latlon:geometry[2]},'walk').modes_allowed,['walk']);
});
test('route distance, interpolation and heading follow geometry, including duplicates',()=>{
  const metrics=routeMetrics(geometry);
  assert.ok(Math.abs(metrics.total-distance(geometry[0],geometry[1])-distance(geometry[1],geometry[2]))<.001);
  const midpoint=pointAt(metrics,metrics.cumulative[1]/2);
  assert.ok(Math.abs(midpoint.point[0]-10.775)<.000001);
  assert.ok(Math.abs(midpoint.heading)<.001);
  assert.deepEqual(pointAt(metrics,metrics.total+100).point,geometry.at(-1));
  assert.ok(Number.isFinite(pointAt(routeMetrics([geometry[0],geometry[0],geometry[1]]),0).point[0]));
});
test('projection uses road segments rather than nearest vertices',()=>{
  const result=projectPosition(routeMetrics(geometry),[10.775,106.7]);
  assert.ok(result.distance<.01);assert.ok(result.progress>500 && result.progress<600);
});
test('three consecutive accurate off-route fixes trigger rerouting and an on-route fix resets them',()=>{
  const drive=new DriveSession(route,'car');
  assert.equal(drive.update([10.775,106.702]).reroute,false);
  assert.equal(drive.update([10.775,106.702]).reroute,false);
  assert.equal(drive.update([10.775,106.702],80).reliable,false);
  assert.equal(drive.offRouteFixes,2);
  assert.equal(drive.update([10.775,106.7]).reroute,false);
  assert.equal(drive.offRouteFixes,0);
  drive.update([10.775,106.702]);drive.update([10.775,106.702]);
  assert.equal(drive.update([10.775,106.702]).reroute,true);
});
test('simulation uses API duration and arrives exactly without overshooting',()=>{
  const drive=new DriveSession(route,'car');drive.advance(100);
  assert.ok(Math.abs(drive.remainingFraction-.5)<.00001);
  assert.deepEqual(drive.advance(500).point,geometry.at(-1));
  assert.equal(drive.remainingFraction,0);
  assert.equal(drive.update(geometry.at(-1)).arrived,true);
});
test('voice thresholds are deduplicated and skipped fixes do not produce a queue of stale prompts',()=>{
  const drive=new DriveSession(route,'motorbike');
  drive.progress=drive.metrics.cumulative[1]-400;assert.ok(drive.announcement());assert.equal(drive.announcement(),null);
  drive.progress=drive.metrics.cumulative[1]-100;assert.ok(drive.announcement());assert.equal(drive.announcement(),null);
  drive.progress=drive.metrics.cumulative[1]-30;assert.ok(drive.announcement());assert.equal(drive.announcement(),null);
  const walk=new DriveSession(route,'walk');walk.progress=walk.metrics.cumulative[1]-100;assert.equal(walk.announcement(),null);
  walk.progress=walk.metrics.cumulative[1]-30;assert.ok(walk.announcement());
});
test('unknown zero prices are not ranked cheaper than verified costs',()=>{
  const unknown={id:'car',duration_s:200,distance_m:1000,cost_vnd:0,legs:[{estimate:true}]};
  const known={id:'taxi',duration_s:300,distance_m:1100,cost_vnd:10000,legs:[{estimate:false}]};
  const options=[unknown,known];assert.equal(sortOptions(options,'cheapest')[0],known);assert.equal(sortOptions(options,'fastest')[0],unknown);assert.equal(options[0],unknown);
});
test('a single-point route can arrive and does not divide by zero',()=>{
  const drive=new DriveSession({...route,geometry:[geometry[0]],duration_s:0,maneuvers:[]},'walk');
  assert.equal(drive.remainingFraction,0);assert.deepEqual(drive.advance(5).point,geometry[0]);assert.equal(drive.update(geometry[0]).arrived,true);
});
test('camera rotation eases along the shortest arc instead of unwinding the long way',()=>{
  // Heading-up flips between 350deg and 10deg: the 20deg path, never the 340deg one.
  assert.equal(shortestArc(350,10),370);assert.ok(Math.abs(shortestArc(350,10)-350)<=20);
  assert.equal(shortestArc(10,350),-10);assert.ok(Math.abs(shortestArc(10,350)-10)<=20);
  assert.equal(shortestArc(0,90),90);assert.equal(shortestArc(0,-90),-90);
  assert.equal(shortestArc(0,180),180);assert.equal(shortestArc(0,-180),-180);
  assert.equal(shortestArc(720,0),720);assert.equal(shortestArc(45,45),45);
  // Repeated heading-up churn must never accumulate a full turn.
  let angle=0;for(const heading of [350,10,350,10])angle=shortestArc(angle,heading);
  assert.ok(Math.abs(angle)<=30);
});
test('ease is a frame-rate independent approach that clamps to the target',()=>{
  assert.equal(ease(0,100,90,0),0);
  assert.ok(Math.abs(ease(0,100,90,90)-63.21)<.01);      // one time constant
  const halfstep=ease(0,100,90,45),fullstep=ease(0,100,90,90);
  assert.ok(fullstep>halfstep);                           // advances toward the target
  assert.ok(Math.abs(ease(0,100,90,1e6)-100)<.001);       // arrives and does not overshoot
  assert.ok(Math.abs(ease(100,0,90,1e6))<.001);
  assert.equal(ease(5,5,90,16),5);
});
test('browser locales match ARB sources and all visible UI translation keys exist',()=>{
  const html=readFileSync(new URL('../index.html',import.meta.url),'utf8');
  const js=readFileSync(new URL('../app.js',import.meta.url),'utf8');
  const keys=[...html.matchAll(/data-(?:i18n|label|placeholder)="([^"]+)"/g),...js.matchAll(/\bt\('([^']+)'\)/g)].map(match=>match[1]);
  for(const locale of ['vi','en']){
    const arb=JSON.parse(readFileSync(new URL(`../../lib/l10n/app_${locale}.arb`,import.meta.url),'utf8'));
    for(const key of keys)assert.ok(locales[locale][key],`${locale}: missing ${key}`);
    for(const [key,value] of Object.entries(arb))if(!key.startsWith('@'))assert.equal(locales[locale][key],value);
  }
});
