import http from 'node:http';
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import os from 'node:os';
const lan=process.argv.includes('--lan');
const portArg=process.argv.find(arg=>arg.startsWith('--port='));
const port=portArg?Number(portArg.slice(7)):4173;
if(!Number.isInteger(port)||port<1024||port>65535)throw new Error('Port must be an integer from 1024 to 65535');
const host=lan?'0.0.0.0':'127.0.0.1';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const web=path.join(root,'preview');
const types={'.html':'text/html; charset=utf-8','.css':'text/css; charset=utf-8','.mjs':'text/javascript; charset=utf-8','.js':'text/javascript; charset=utf-8','.png':'image/png'};
const server=http.createServer(async(req,res)=>{
  try {
    const url=new URL(req.url,'http://127.0.0.1');
    const relative=decodeURIComponent(url.pathname);
    const file=relative==='/reference'?path.join(root,'design/用户设计-V2-主要页面.png'):path.resolve(web,relative==='/'?'index.html':'.'+relative);
    if(relative!=='/reference' && file!==web && !file.startsWith(web+path.sep)){res.writeHead(403);res.end('Forbidden');return;}
    const bytes=await fs.readFile(file);
    res.writeHead(200,{'Content-Type':types[path.extname(file)]||'application/octet-stream','Cache-Control':'no-store','X-Content-Type-Options':'nosniff','Content-Security-Policy':"default-src 'self'; img-src 'self' data:; script-src 'self'; style-src 'self' 'unsafe-inline'; connect-src 'none'; object-src 'none'; base-uri 'none'; frame-ancestors 'none'"});res.end(bytes);
  }catch {res.writeHead(404);res.end('Not found');}
});
server.listen(port,host,()=>{
  console.log(`LightMeal preview: http://127.0.0.1:${port} (${lan?'LAN preview':'local only'})`);
  if(lan){
    for(const entries of Object.values(os.networkInterfaces())){
      for(const entry of entries||[]){
        if(entry.family==='IPv4'&&!entry.internal)console.log(`Same Wi-Fi device: http://${entry.address}:${port}`);
      }
    }
    console.log('Static UI preview only; keep this computer running. Phone data stays in its browser. Stop with Ctrl+C.');
  }
});
server.on('error',error=>{console.error(error.message);process.exitCode=1});
