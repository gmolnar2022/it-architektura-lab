const base='https://itarch-backend-fpdsf6brfpanf5d8.northeurope-01.azurewebsites.net/api/itarchTeacherProjects';
let credentials=null;
export function login(key,secret){credentials={key,secret};}
export function logout(){credentials=null;}
export async function api(body){if(!credentials)throw Error('Jelentkezz be.');const r=await fetch(base,{method:'POST',headers:{'Content-Type':'application/json','x-functions-key':credentials.key,'x-itarch-teacher-secret':credentials.secret},body:JSON.stringify(body),cache:'no-store'});if(!r.ok){let msg;try{msg=(await r.json()).error}catch{}throw Error(msg||`HTTP ${r.status}`);}return r.json();}
