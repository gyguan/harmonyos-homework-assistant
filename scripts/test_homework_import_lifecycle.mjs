// Actual lifecycle, HTTP client, organizer adapter and import Service with SDK/repository doubles.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const root=new URL('../entry/src/main/ets/',import.meta.url);
const files=['application/remote/BackendRequestControl.ets','application/import/HomeworkImportOperation.ets',
  'application/remote/BackendHttpClient.ets','application/remote/HomeworkOrganizerRemoteApi.ets',
  'application/import/HomeworkImportPipeline.ets','application/import/HomeworkImportService.ets'];
const subjects={CHINESE:'语文',MATH:'数学',ENGLISH:'英语',READING:'阅读',READ_ALOUD:'朗读',SPORTS:'体育',PRACTICE:'实践',INTEREST:'兴趣',OTHER:'其他'};
const task={subject:'数学',title:'口算20题',instruction:'口算20题',textbookRef:'待家长确认',taskDate:'2026-10-20',
  expectedMinutes:10,sourceExcerpt:'数学口算20题',confidence:.9,sourceBlockIds:['t1']};
function deferred(){let resolve,reject;const promise=new Promise((a,b)=>{resolve=a;reject=b;});return {promise,resolve,reject};}
function fixture({encodeGate,extractGate,networkError=false}={}){
  const calls=[],commits=[],phases=[],timers=new Map();let timerSeq=0,activeStudent='student-one',disconnected=0,localParses=0;
  const responses=[];
  const context=vm.createContext({console:{info(){}},Date,encodeURIComponent,
    setTimeout:fn=>{timers.set(++timerSeq,fn);return timerSeq;},clearTimeout:id=>timers.delete(id),
    http:{RequestMethod:{POST:'POST',GET:'GET'},createHttp:()=>{
      const pending=deferred();let destroyed=0;
      const call={pending,get destroyed(){return destroyed;}};calls.push(call);
      return {request:async(url,options)=>{call.url=url;call.options=options;
        if(networkError)throw Error('network');return pending.promise;},destroy:()=>{destroyed++;}};}},
    BackendSession:{instance:{isConnected:()=>true,getBaseUrl:()=> 'http://backend',getToken:()=> 'synthetic',disconnect:()=>disconnected++}},
    HomeworkImageEncoder:{encode:async()=>{if(encodeGate)await encodeGate.promise;
      return {imageBase64:'synthetic',contentType:'image/png',encodedBytes:8};}},
    AssignmentTaskDate:{today:()=> '2026-10-20',resolve:v=>v},Subject:subjects,
    HomeworkOrganizerMode:{AI:'AI',LOCAL:'LOCAL'},HomeworkImportSourceType:{SCREENSHOT:'SCREENSHOT',CLIPBOARD:'CLIPBOARD'},
    HomeworkImportSourceKind:{TEXT:'TEXT',IMAGE:'IMAGE'},
    DefaultHomeworkImportDraftRepository:{instance:{getActiveStudentId:()=>activeStudent}},
    HomeworkImportInboxService:{instance:{commitParsedImport:(...args)=>commits.push(args)}}
  });
  for(const file of files){let source=readFileSync(new URL(file,root),'utf8')
    .replace(/^import\s+[\s\S]*?\s+from\s+['"][^'"]+['"];\r?\n/gm,'')
    .replaceAll('export interface','interface').replaceAll('export enum','enum').replaceAll('export class','class');
    vm.runInContext(stripTypeScriptTypes(source,{mode:'transform'}),context);}
  const service=vm.runInContext('HomeworkImportService.instance',context);
  service.configure({}, {extract:async input=>{if(extractGate)await extractGate.promise;
    return {importId:input.id,studentId:input.studentId,text:input.rawText,sourceLabel:input.sourceLabel};}},
    {parse:async()=>{localParses++;return [{...task,studentId:'student-one',sourceEvidence:{}}];}});
  const operation=vm.runInContext('HomeworkImportOperation',context);
  return {service,calls,commits,timers,phases,context,
    operation:()=>new operation(phase=>phases.push(phase)),
    reply:(index=0,status=200)=>calls[index].pending.resolve({responseCode:status,result:JSON.stringify({mode:'AI',assignments:[task]})}),
    replyImage:(index=0)=>calls[index].pending.resolve({responseCode:200,result:JSON.stringify({mode:'AI_IMAGE',recognizedText:'数学口算20题',assignments:[task]})}),
    switchStudent:()=>activeStudent='student-two',get disconnected(){return disconnected;},get localParses(){return localParses;}};
}
async function tick(){for(let i=0;i<15;i++)await Promise.resolve();}
// A normal response follows genuine milestones and preserves student scope across the network.
{
 const f=fixture(),op=f.operation();const result=f.service.parseText('数学口算20题',null,'','','',op);
 await tick();assert.deepEqual(f.phases,['PREPARING_TEXT','WAITING_FOR_AI']);f.reply();await result;op.finish();
 assert.deepEqual(f.phases,['PREPARING_TEXT','WAITING_FOR_AI','VALIDATING_RESPONSE','SAVING_DRAFT','COMPLETE']);
 assert.equal(f.commits.length,1);assert.equal(f.commits[0][0].studentId,'student-one');
 assert.equal(f.calls[0].destroyed,1);assert.equal(f.timers.size,0);assert.equal(f.calls[0].options.readTimeout,300000);
}
// Stopping preparation never starts a provider request and never writes an import.
for(const kind of ['text','image']){
 const gate=deferred(),f=fixture(kind==='text'?{extractGate:gate}:{encodeGate:gate}),op=f.operation();
 const pending=kind==='text'?f.service.parseText('数学口算20题',null,'','','',op):f.service.parseImage('private-uri',null,'图片','','',op);
 op.cancel();gate.resolve();await assert.rejects(pending,/停止等待/);op.finish();
 assert.equal(f.calls.length,0);assert.equal(f.commits.length,0);assert.equal(f.localParses,0);assert.equal(f.timers.size,0);
}
// Even a late native response after destroy cannot become a fallback, a draft, or a session logout.
{
 const f=fixture(),op=f.operation();const pending=f.service.parseText('数学口算20题',null,'','','',op);
 await tick();op.cancel();assert.equal(f.calls[0].destroyed,1);f.reply(0,401);
 await assert.rejects(pending,/停止等待/);assert.equal(f.commits.length,0);assert.equal(f.localParses,0);
 assert.equal(f.disconnected,0);assert.equal(f.calls[0].destroyed,1);
}
// A deadline has its own explicit message; no 270-second sleeps, no fabricated progress.
{
 const f=fixture(),op=f.operation();const pending=f.service.parseImage('private-uri',null,'图片','','',op);
 await tick();for(const callback of [...f.timers.values()])callback();f.replyImage();
 await assert.rejects(pending,/等待超时/);op.finish();assert.equal(f.commits.length,0);assert.equal(f.calls[0].destroyed,1);
}
// A new request survives an older cancelled request's late completion.
{
 const f=fixture(),first=f.operation();const a=f.service.parseText('数学口算20题',null,'','','',first);
 await tick();first.cancel();const second=f.operation();const b=f.service.parseText('数学口算20题',null,'','','',second);
 await tick();f.reply(0);await assert.rejects(a,/停止等待/);assert.equal(f.calls[1].destroyed,0);
 f.reply(1);await b;second.finish();assert.equal(f.commits.length,1);assert.equal(f.calls[1].destroyed,1);
}
// Existing offline/network fallback and cross-student retention remain explicit and scoped.
{
 const f=fixture({networkError:true}),op=f.operation();const result=await f.service.parseText('数学口算20题',null,'','','',op);op.finish();
 assert.equal(result.aiFailed,true);assert.equal(f.localParses,1);assert.equal(f.commits.length,1);
}
{
 const f=fixture(),op=f.operation();const pending=f.service.parseImage('private-uri',null,'图片','补充文字','',op);
 await tick();f.switchStudent();f.replyImage();await assert.rejects(pending,/孩子已切换/);op.finish();
 assert.equal(f.commits[0][0].studentId,'student-one');assert.ok(f.calls[0].url.includes('/students/student-one/'));
 assert.equal(JSON.parse(f.calls[0].options.extraData).text,'补充文字');
}
console.log('HOMEWORK_IMPORT_LIFECYCLE_PASS: real phases, stop before/during HTTP, late responses, timeout, retry isolation, fallback, student scope');
