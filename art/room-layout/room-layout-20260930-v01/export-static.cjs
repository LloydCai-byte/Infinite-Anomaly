// Export the authored vector diagram without browser access or image generation.
const fs=require('node:fs');
const path=require('node:path');
const vm=require('node:vm');
const sharp=require('sharp');
const folder=__dirname;
const source=fs.readFileSync(path.join(folder,'source.html'),'utf8');
const script=source.match(/<script>([\s\S]*?)<\/script>/)[1];
const host={innerHTML:'',getBoundingClientRect:()=>({width:736})};
const state={textContent:''};
const buttons=['closed','open'].map(door=>({dataset:{door},setAttribute(){},addEventListener(event,cb){this.click=cb;}}));
const root={querySelector:selector=>selector==='.room-plan'?host:state,querySelectorAll:()=>buttons};
vm.runInNewContext(script,{document:{getElementById:()=>root},window:{addEventListener(){}},ResizeObserver:class{observe(){}}});
const palette={'--foreground':'#252b2c','--muted':'#edf0ee','--border':'#9ba9a1','--viz-series-1':'#25695d','--viz-series-2':'#4c678b'};
const styles='<style>text{font-family:"Microsoft YaHei","Noto Sans CJK SC",sans-serif;font-size:14px;fill:#252b2c;font-weight:400}.structure{fill:none;stroke:#252b2c;stroke-width:2}.furniture{fill:#edf0ee;stroke:#9ba9a1;stroke-width:1.5}.door{fill:none;stroke:#25695d;stroke-width:2.5}.route{fill:none;stroke:#4c678b;stroke-width:2;stroke-dasharray:6 5}</style>';
(async()=>{
  for(const mode of ['closed','open']){
    buttons.find(b=>b.dataset.door===mode).click();
    let svg=host.innerHTML.replace(/var\((--[\w-]+)\)/g,(_,k)=>palette[k]||'#252b2c');
    svg=svg.replace(/(<svg[^>]*>)/,`$1${styles}<rect width="100%" height="100%" fill="#ffffff"/><text x="368" y="27" text-anchor="middle">房间布局草案 · 待确认</text><text x="368" y="49" text-anchor="middle">${mode==='open'?'出口向室内打开':'出口关闭'} · 尺寸暂按 6.4 × 4.8 米</text>`);
    fs.writeFileSync(path.join(folder,`plan-${mode}.svg`),svg);
    await sharp(Buffer.from(svg),{density:192}).png().toFile(path.join(folder,`plan-${mode}.png`));
  }
  const files=['source.html','index.html','plan-closed.svg','plan-open.svg','plan-closed.png','plan-open.png'];
  const crypto=require('node:crypto');
  const manifest={status:'待用户确认；非最终布局',version:'room-layout-20260930-v01',method:'同一矢量空间示意的开门／关门两状态；没有生成新分镜',files:files.filter(f=>fs.existsSync(path.join(folder,f))).map(f=>({path:f,sha256:crypto.createHash('sha256').update(fs.readFileSync(path.join(folder,f))).digest('hex')}))};
  fs.writeFileSync(path.join(folder,'manifest.json'),JSON.stringify(manifest,null,2)+'\n');
  console.log('Exported the two door states from one vector source.');
})().catch(e=>{console.error(e);process.exitCode=1;});
