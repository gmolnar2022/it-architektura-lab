// Separate, read-only ITARCH submission inventory. Does not write to Azure.
// Usage: node itarch_readonly.mjs --local /path/to/submissions --week 1
//        node itarch_readonly.mjs --azure --week 1
// Azure mode: npm install @azure/storage-blob @azure/identity
// AZURE_STORAGE_ACCOUNT=itarchsubmissions; authenticate with DefaultAzureCredential
import fs from 'node:fs/promises';
import path from 'node:path';
const args=process.argv.slice(2);
const val=(name,def)=>{const i=args.indexOf(name);return i>=0?args[i+1]:def};
const week=Number(val('--week','1'));
if(!Number.isInteger(week)||week<1||week>53) throw Error('Invalid week');
const prefix=`week${String(week).padStart(2,'0')}/`;
const local=val('--local',null);
const entries=[];
if(local){
  async function walk(dir){for(const ent of await fs.readdir(dir,{withFileTypes:true})){const file=path.join(dir,ent.name);if(ent.isDirectory())await walk(file);else if(ent.name.endsWith('.json'))entries.push({name:file,json:JSON.parse(await fs.readFile(file,'utf8'))})}}
  await walk(local);
}else if(args.includes('--azure')){
  const {BlobServiceClient}=await import('@azure/storage-blob');
  const {DefaultAzureCredential}=await import('@azure/identity');
  const account=process.env.AZURE_STORAGE_ACCOUNT||'itarchsubmissions';
  const service=new BlobServiceClient(`https://${account}.blob.core.windows.net`,new DefaultAzureCredential());
  const container=service.getContainerClient('submissions');
  for await(const blob of container.listBlobsFlat({prefix})){
    if(!blob.name.endsWith('.json'))continue;
    const response=await container.getBlobClient(blob.name).download();
    const parts=[];for await(const chunk of response.readableStreamBody)parts.push(chunk);
    entries.push({name:blob.name,json:JSON.parse(Buffer.concat(parts).toString('utf8'))});
  }
}else throw Error('Specify --local DIRECTORY or --azure');
const groups=new Map(), warnings=[];
for(const e of entries){
 const j=e.json, id=String(j.student_id||'').trim().toUpperCase();
 if(j.course!=='ITARCH'||Number(j.week)!==week||!/^[A-Z0-9]{6}$/.test(id)){warnings.push({file:e.name,issue:'course/week/student_id mismatch'});continue}
 const folder=e.name.replaceAll('\\','/').split('/').at(-2)?.toUpperCase();
 if(!local&&folder!==id){warnings.push({file:e.name,issue:'Neptun folder differs from student_id'});continue}
 const t=Date.parse(j.submitted_at);
 if(!Number.isFinite(t)){warnings.push({file:e.name,issue:'Invalid submitted_at'});continue}
 if(!groups.has(id))groups.set(id,[]);
 groups.get(id).push({name:e.name,submitted_at:j.submitted_at,t,answers:j.answers||{}});
}
const selected=[];
for(const [student_id,items] of groups){
 items.sort((a,b)=>b.t-a.t||a.name.localeCompare(b.name));
 if(items.length>1&&items[0].t===items[1].t)warnings.push({student_id,issue:'Latest submissions tied: review manually'});
 selected.push({student_id,submissions:items.length,latest_file:items[0].name,submitted_at:items[0].submitted_at,answered_tasks:Array.from({length:15},(_,i)=>`Q${String(i+1).padStart(2,'0')}`).filter(q=>Object.keys(items[0].answers).some(k=>k.startsWith(q+'_'))).length});
}
selected.sort((a,b)=>a.student_id.localeCompare(b.student_id));
// No original answers, Subscription IDs or IP addresses are printed.
console.log(JSON.stringify({week,scanned_files:entries.length,students:selected.length,selected,warnings},null,2));
