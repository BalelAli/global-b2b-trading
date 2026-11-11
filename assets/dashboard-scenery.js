(()=>{"use strict";
const canvas=document.getElementById("dashboardScenery");if(!canvas)return;
const ctx=canvas.getContext("2d",{alpha:false});if(!ctx)return;
document.body.classList.add("dashboard-scenic");
const scenes=[
{name:"Container ship crossing the ocean",type:"ship"},
{name:"An aircraft crossing the open sky",type:"plane"},
{name:"A train through green mountain valleys",type:"train"},
{name:"A busy international cargo port",type:"port"},
{name:"Freight trucks on a mountain highway",type:"truck"},
{name:"A global city at golden hour",type:"city"}
];
let sceneIndex=Math.floor(Math.random()*scenes.length);
try{
 const previous=Number(localStorage.getItem("globalB2BLastScenery"));
 if(Number.isInteger(previous)&&previous>=0&&previous<scenes.length&&scenes.length>1&&sceneIndex===previous){
  sceneIndex=(previous+1+Math.floor(Math.random()*(scenes.length-1)))%scenes.length;
 }
 localStorage.setItem("globalB2BLastScenery",String(sceneIndex));
}catch(_){}
const scene=scenes[sceneIndex];
let w=0,h=0,dpr=1,t=0,last=0,raf=0;
const reduced=window.matchMedia&&window.matchMedia("(prefers-reduced-motion: reduce)").matches;
function resize(){dpr=Math.min(window.devicePixelRatio||1,1.7);w=innerWidth;h=innerHeight;canvas.width=Math.round(w*dpr);canvas.height=Math.round(h*dpr);canvas.style.width=w+"px";canvas.style.height=h+"px";ctx.setTransform(dpr,0,0,dpr,0,0);draw(0)}
function gradient(top,bottom){const g=ctx.createLinearGradient(0,0,0,h);g.addColorStop(0,top);g.addColorStop(1,bottom);ctx.fillStyle=g;ctx.fillRect(0,0,w,h)}
function cloud(x,y,s,a=1){ctx.save();ctx.globalAlpha=a;ctx.fillStyle="#fff";ctx.beginPath();ctx.ellipse(x,y,34*s,12*s,0,0,Math.PI*2);ctx.ellipse(x-22*s,y+2*s,19*s,10*s,0,0,Math.PI*2);ctx.ellipse(x+19*s,y-5*s,23*s,14*s,0,0,Math.PI*2);ctx.fill();ctx.restore()}
function mountain(x,y,ww,hh,color){ctx.fillStyle=color;ctx.beginPath();ctx.moveTo(x-ww/2,y);ctx.lineTo(x,y-hh);ctx.lineTo(x+ww/2,y);ctx.closePath();ctx.fill();ctx.fillStyle="rgba(255,255,255,.58)";ctx.beginPath();ctx.moveTo(x-hh*.16,y-hh*.68);ctx.lineTo(x,y-hh);ctx.lineTo(x+hh*.17,y-hh*.67);ctx.lineTo(x+hh*.07,y-hh*.72);ctx.lineTo(x,y-hh*.82);ctx.closePath();ctx.fill()}
function ship(x,y,s){ctx.save();ctx.translate(x,y);ctx.scale(s,s);
ctx.fillStyle="#102e46";ctx.beginPath();ctx.moveTo(-145,0);ctx.lineTo(140,0);ctx.lineTo(112,35);ctx.lineTo(-112,35);ctx.closePath();ctx.fill();
ctx.fillStyle="#e9f0f4";ctx.fillRect(-28,-30,52,30);ctx.fillStyle="#f6a23b";ctx.fillRect(-118,-54,43,52);ctx.fillStyle="#e45d42";ctx.fillRect(-72,-54,43,52);ctx.fillStyle="#2e91ba";ctx.fillRect(-26,-54,43,52);ctx.fillStyle="#f2c14e";ctx.fillRect(20,-54,43,52);ctx.fillStyle="#d5e2e8";ctx.fillRect(65,-34,43,32);ctx.fillStyle="#f8fbfd";ctx.fillRect(-5,-24,7,8);ctx.fillRect(8,-24,7,8);ctx.restore()}
function plane(x,y,s){ctx.save();ctx.translate(x,y);ctx.scale(s,s);ctx.fillStyle="#f8fbff";ctx.shadowColor="rgba(8,38,60,.3)";ctx.shadowBlur=12;ctx.beginPath();ctx.moveTo(-78,0);ctx.lineTo(-12,-9);ctx.lineTo(18,-45);ctx.lineTo(31,-44);ctx.lineTo(21,-8);ctx.lineTo(75,0);ctx.lineTo(21,9);ctx.lineTo(31,44);ctx.lineTo(18,45);ctx.lineTo(-12,9);ctx.closePath();ctx.fill();ctx.restore()}
function train(x,y,s){ctx.save();ctx.translate(x,y);ctx.scale(s,s);ctx.fillStyle="#1b536b";ctx.fillRect(-110,-40,215,42);ctx.fillStyle="#e5f2f6";ctx.fillRect(-90,-28,34,17);ctx.fillRect(-42,-28,34,17);ctx.fillRect(7,-28,34,17);ctx.fillStyle="#ef9d38";ctx.fillRect(105,-34,28,36);ctx.fillStyle="#f8fbfc";ctx.fillRect(111,-25,12,12);ctx.fillStyle="#253d4b";for(let i=-75;i<125;i+=52){ctx.beginPath();ctx.arc(i,8,10,0,Math.PI*2);ctx.fill()}ctx.restore()}
function draw(ms){const dt=Math.min(.04,(ms-last)/1000||0);last=ms;if(!reduced)t+=dt;
const drift=t*16% (w+260);
if(scene.type==="ship"||scene.type==="port"){
gradient("#78c8e8","#e5f3f8");cloud(w*.2-(drift*.18),h*.2,.9,.7);cloud(w*.72-(drift*.12),h*.28,1.1,.6);
ctx.fillStyle="#b9d9df";ctx.fillRect(0,h*.54,w,h*.46);ctx.fillStyle="#2b91b5";ctx.fillRect(0,h*.61,w,h*.39);
for(let i=0;i<10;i++){const yy=h*.66+i*h*.035;ctx.strokeStyle="rgba(220,249,255,.23)";ctx.lineWidth=2;ctx.beginPath();ctx.moveTo((i*137-drift*1.5)%(w+100),yy);ctx.lineTo((i*137-drift*1.5)%(w+100)+100,yy);ctx.stroke()}
if(scene.type==="ship")ship(w*.5+Math.sin(t*.35)*w*.06,h*.68,Math.min(1.15,w/1050));else{ctx.fillStyle="#315a65";ctx.fillRect(0,h*.5,w,h*.13);for(let i=0;i<7;i++){const x=(i*190-drift*1.7)%(w+180);ctx.fillStyle="#263f4e";ctx.fillRect(x,h*.32,8,h*.3);ctx.strokeStyle="#263f4e";ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(x+4,h*.34);ctx.lineTo(x+70,h*.49);ctx.lineTo(x+70,h*.53);ctx.stroke();ctx.fillStyle=["#e35f45","#eeb13d","#3187a8"][i%3];ctx.fillRect(x+12,h*.46,52,28)}ship(w*.68,h*.69,.62)}
}else if(scene.type==="plane"){
gradient("#4da9df","#d9f1fb");cloud(w*.18-drift*.35,h*.25,1.2,.85);cloud(w*.65-drift*.22,h*.42,1.6,.65);cloud(w*.9-drift*.3,h*.18,.8,.6);plane((w*.18+drift*1.4)%(w+200)-100,h*.38+Math.sin(t*.7)*h*.025,Math.min(1.15,w/1100));
}else if(scene.type==="train"){
gradient("#8bd0e9","#e8f5e8");mountain(w*.15,h*.7,w*.55,h*.56,"#548b78");mountain(w*.48,h*.72,w*.7,h*.67,"#39765f");mountain(w*.82,h*.7,w*.58,h*.54,"#6da18a");ctx.fillStyle="#5a9b62";ctx.fillRect(0,h*.7,w,h*.3);ctx.fillStyle="#b6a987";ctx.beginPath();ctx.moveTo(0,h*.83);ctx.lineTo(w,h*.72);ctx.lineTo(w,h*.79);ctx.lineTo(0,h*.9);ctx.fill();ctx.strokeStyle="#364e4c";ctx.lineWidth=5;ctx.beginPath();ctx.moveTo(0,h*.86);ctx.lineTo(w,h*.75);ctx.stroke();train((w*.1+drift*1.5)%(w+300)-150,h*.75,.88);
}else if(scene.type==="truck"){
gradient("#79c8e9","#eff2e5");mountain(w*.2,h*.78,w*.75,h*.64,"#527e68");mountain(w*.72,h*.77,w*.8,h*.7,"#3d705b");ctx.fillStyle="#b9b39b";ctx.beginPath();ctx.moveTo(0,h*.84);ctx.lineTo(w,h*.69);ctx.lineTo(w,h*.82);ctx.lineTo(0,h*.98);ctx.fill();ctx.fillStyle="#59646a";ctx.fillRect(0,h*.9,w,7);const x=(w*.08+drift*1.2)%(w+250)-130;ctx.fillStyle="#d95f3c";ctx.fillRect(x,h*.69,145,43);ctx.fillStyle="#e8f0f2";ctx.fillRect(x+108,h*.67,47,37);ctx.fillStyle="#263d4a";for(let i=0;i<3;i++){ctx.beginPath();ctx.arc(x+28+i*90,h*.75,13,0,Math.PI*2);ctx.fill()}
}else{
gradient("#f3b56d","#f6e2bf");ctx.fillStyle="#f9d98d";ctx.beginPath();ctx.arc(w*.78,h*.22,52,0,Math.PI*2);ctx.fill();for(let i=0;i<9;i++){const bw=45+(i%3)*25,bh=h*(.2+(i%4)*.1),x=i*w/8;ctx.fillStyle=["#365a70","#47758a","#284b63"][i%3];ctx.fillRect(x,h*.76-bh,bw,bh);ctx.fillStyle="rgba(255,220,153,.65)";for(let yy=h*.76-bh+14;yy<h*.75;yy+=22)for(let xx=x+10;xx<x+bw-5;xx+=17)ctx.fillRect(xx,yy,5,7)}ctx.fillStyle="#263f50";ctx.fillRect(0,h*.76,w,h*.24)
}
const shade=ctx.createLinearGradient(0,0,0,h);shade.addColorStop(0,"rgba(13,42,60,.02)");shade.addColorStop(1,"rgba(10,38,54,.25)");ctx.fillStyle=shade;ctx.fillRect(0,0,w,h);
if(!reduced)raf=requestAnimationFrame(draw)}
const tag=document.createElement("div");tag.id="sceneryCaption";tag.textContent="✦ "+scene.name;tag.setAttribute("aria-hidden","true");tag.style.cssText="position:fixed;right:18px;bottom:14px;z-index:1;padding:7px 12px;border:1px solid rgba(255,255,255,.48);border-radius:30px;background:rgba(9,39,59,.38);backdrop-filter:blur(8px);color:white;font:600 12px/1.3 system-ui,sans-serif;letter-spacing:.2px;pointer-events:none;box-shadow:0 4px 18px rgba(0,0,0,.12)";
document.body.appendChild(tag);
window.addEventListener("resize",resize,{passive:true});resize();if(!reduced)raf=requestAnimationFrame(draw);
window.addEventListener("pagehide",()=>cancelAnimationFrame(raf),{once:true});
})();