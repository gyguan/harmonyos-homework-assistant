// Runs the actual ArkTS encoder with SDK doubles; does not replace a Harmony HAP build.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {stripTypeScriptTypes} from 'node:module';
import vm from 'node:vm';
const source = readFileSync(new URL('../entry/src/main/ets/infrastructure/ai/HomeworkImageEncoder.ets',import.meta.url),'utf8')
  .replace(/^import .*;\r?\n/gm,'').replaceAll('export interface','interface').replace('export class','class');
function fixture({bytes=Buffer.from([0xff,0xd8,0xff,0xe1,1,2,3]), size=bytes.length, width=3000, height=2000,
  fail='', partial=false, cleanupFail=false, output=Buffer.from([1,2,3])}={}) {
  const events=[];
  const context=vm.createContext({Uint8Array,ArrayBuffer,
    console:{warn(){}},
    fileIo:{OpenMode:{READ_ONLY:0},
      open:async()=>{events.push('open'); if(fail==='open') throw Error('private'); return {fd:1};},
      statSync:()=>({size}),
      read:async(fd,buffer,options)=>{events.push('read'); if(fail==='read') return 0;
        const count=Math.min(buffer.byteLength,partial?2:buffer.byteLength,bytes.length-options.offset);
        new Uint8Array(buffer).set(bytes.subarray(options.offset,options.offset+count)); return count;},
      close:async()=>{events.push('close'); if(cleanupFail) throw Error('private');}},
    image:{createImageSource:()=>{events.push('source'); return {
      getImageInfo:async()=>({size:{width,height}}),
      createPixelMap:async(...args)=>{events.push(['decode',args]); if(fail==='decode') throw Error('private');
        return {release:async()=>{events.push('pixel.release'); if(cleanupFail) throw Error('private');}};},
      release:async()=>{events.push('source.release'); if(cleanupFail) throw Error('private');}};},
      createImagePacker:()=>({packToData:async(pixel,options)=>{events.push(['pack',options]);
        if(fail==='pack') throw Error('private'); return Uint8Array.from(output).buffer;},
        release:async()=>{events.push('packer.release'); if(cleanupFail) throw Error('private');}})},
    util:{Base64Helper:class {async encodeToString(bytes){return Buffer.from(bytes).toString('base64');}}}
  });
  vm.runInContext(stripTypeScriptTypes(source),context);
  return {encoder:vm.runInContext('HomeworkImageEncoder',context),events,bytes};
}
for (const bytes of [Buffer.from([0xff,0xd8,0xff,0xe1,1,2,3]), Buffer.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,9])]) {
  const f=fixture({bytes,partial:true}); const encoded=await f.encoder.encode('private-uri');
  assert.equal(encoded.imageBase64,bytes.toString('base64'));
  assert.equal(encoded.encodedBytes,bytes.length);
  assert.ok(!f.events.some(e=>Array.isArray(e)&&e[0]==='decode'));
  assert.deepEqual(f.events.slice(-2),['source.release','close']);
}
const other=fixture({bytes:Buffer.from('other-format')});
assert.equal((await other.encoder.encode('private-uri')).contentType,'image/png');
assert.equal(other.events.find(e=>Array.isArray(e)&&e[0]==='decode')[1].length,0); // original dimensions
assert.equal(other.events.find(e=>Array.isArray(e)&&e[0]==='pack')[1].format,'image/png');
assert.deepEqual(other.events.slice(-4),['packer.release','pixel.release','source.release','close']);
for (const opts of [{size:4*1024*1024+1},{width:40001,height:1000},{fail:'read'},
  {bytes:Buffer.from('other'),fail:'decode'},{bytes:Buffer.from('other'),fail:'pack'},
  {bytes:Buffer.from('other'),output:Buffer.alloc(4*1024*1024+1)}]) {
  const f=fixture(opts); await assert.rejects(f.encoder.encode('private-uri'));
  assert.deepEqual(f.events.slice(-2),['source.release','close']);
}
const cleanup=fixture({cleanupFail:true}); assert.ok((await cleanup.encoder.encode('private-uri')).encodedBytes>0);
assert.deepEqual(cleanup.events.slice(-2),['source.release','close']);
console.log('HOMEWORK_IMAGE_ENCODER_PASS: exact JPEG/PNG, partial reads, no downscale, lossless conversion, limits, resource cleanup');
