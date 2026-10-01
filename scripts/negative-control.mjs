import {mkdtemp,readFile,writeFile,rm} from 'node:fs/promises';
import {tmpdir} from 'node:os';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const temporary=await mkdtemp(join(tmpdir(),'lightmeal-negative-'));
try {
  const original=await readFile(join(root,'preview/core.mjs'),'utf8');
  const changed=original.replace('return food.kcal * food.fraction;', 'return food.kcal;');
  if(changed===original)throw new Error('Mutation target missing');
  const file=join(temporary,'core.mjs');await writeFile(file,changed);
  const result=spawnSync(process.execPath,['--test',join(root,'tests/core.test.mjs')],{env:{...process.env,MEAL_CORE_MODULE:file},encoding:'utf8'});
  if(result.status!==0){console.log(result.stdout);console.log(`RED observed: consumed fraction disabled; exit: ${result.status}`);process.exitCode=1;}
  else {console.error('Negative control unexpectedly passed');process.exitCode=2;}
}finally{await rm(temporary,{recursive:true,force:true});}
