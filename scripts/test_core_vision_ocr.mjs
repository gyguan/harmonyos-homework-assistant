// Exercise the real adapter's control flow with SDK doubles. This is not an ArkTS/SDK build.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';

const source = readFileSync(new URL('../entry/src/main/ets/infrastructure/ai/CoreVisionHomeworkTextExtractor.ets', import.meta.url), 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replace('export class', 'class');
const javascript = stripTypeScriptTypes(source);
const input = { id: 'import', studentId: 'student', sourceLabel: 'image', resourceUri: 'private-uri', rawText: '' };

function fixture(failure = '', code = 401, text = ' 数学作业 ') {
  const events = [];
  const logs = [];
  const step = (name, value) => {
    events.push(name);
    if (failure === name || (Array.isArray(failure) && failure.includes(name))) {
      throw { code, message: 'private image content and uri' };
    }
    return value;
  };
  const pixelMap = { release: async () => step('pixel.release') };
  const imageSource = {
    createPixelMap: async options => {
      assert.equal(options?.desiredPixelFormat, 3, 'OCR must receive RGBA_8888');
      assert.equal(options?.desiredDynamicRange, 1, 'HDR photos must decode to SDR');
      return step('decode', pixelMap);
    },
    release: async () => step('source.release')
  };
  const context = vm.createContext({
    console: { warn: message => logs.push(message) },
    canIUse: () => true,
    fileIo: { OpenMode: { READ_ONLY: 0 }, open: async () => step('open', { fd: 1 }), close: async () => step('file.close') },
    image: { PixelMapFormat: { RGBA_8888: 3 }, DecodingDynamicRange: { SDR: 1 }, createImageSource: () => step('source', imageSource) },
    textRecognition: { init: async () => step('init', true), recognizeText: async () => step('recognize', { value: text }) }
  });
  vm.runInContext(javascript, context);
  return { adapter: vm.runInContext('new CoreVisionHomeworkTextExtractor()', context), events, logs, context };
}

let caseCount = 0;
async function check(name, fn) {
  await fn();
  caseCount++;
  console.log(`PASS ${name}`);
}

await check('text bypass preserves owner and does not access SDK', async () => {
  const f = fixture();
  const result = await f.adapter.extract({ ...input, rawText: ' 已有文字 ' });
  assert.equal(result.text, '已有文字');
  assert.equal(result.studentId, input.studentId);
  assert.deepEqual(f.events, []);
});
await check('success normalizes image and releases all native resources', async () => {
  const f = fixture();
  assert.equal((await f.adapter.extract(input)).text, '数学作业');
  assert.deepEqual(f.events.slice(-3), ['pixel.release', 'source.release', 'file.close']);
});
for (const [stage, hint, resources] of [
  ['init', '初始化失败', []], ['open', '无法读取', []],
  ['source', '图片解码失败', ['file.close']],
  ['decode', '图片解码失败', ['source.release', 'file.close']],
  ['recognize', '文字识别失败', ['pixel.release', 'source.release', 'file.close']]
]) {
  await check(`${stage} failure retains stage and code, releases acquired resources`, async () => {
    const f = fixture(stage);
    await assert.rejects(f.adapter.extract(input), error => error.message.includes(hint) && error.message.includes('401') && !error.message.includes('private'));
    assert.deepEqual(f.events.filter(event => event.endsWith('release') || event === 'file.close'), resources);
    assert.ok(f.logs.every(message => !message.includes('private')));
  });
}
await check('empty OCR retains its specific hint and releases resources', async () => {
  const f = fixture('', 0, '  ');
  await assert.rejects(f.adapter.extract(input), /没有识别到文字/);
  assert.deepEqual(f.events.slice(-3), ['pixel.release', 'source.release', 'file.close']);
});
for (const cleanup of ['pixel.release', 'source.release', 'file.close']) {
  await check(`${cleanup} failure preserves successful recognition and remaining cleanup`, async () => {
    const f = fixture(cleanup);
    assert.equal((await f.adapter.extract(input)).text, '数学作业');
    assert.deepEqual(f.events.slice(-3), ['pixel.release', 'source.release', 'file.close']);
  });
}
await check('service-abnormal failure allows initialization on retry', async () => {
  const f = fixture('recognize', 1001400002);
  await assert.rejects(f.adapter.extract(input));
  await assert.rejects(f.adapter.extract(input));
  assert.equal(f.events.filter(event => event === 'init').length, 2);
});
await check('unsupported devices and init=false give clear hints before reading the image', async () => {
  const unsupported = fixture();
  unsupported.context.canIUse = () => false;
  await assert.rejects(unsupported.adapter.extract(input), /当前设备不支持/);
  assert.deepEqual(unsupported.events, []);
  const unavailable = fixture();
  unavailable.context.textRecognition.init = async () => false;
  await assert.rejects(unavailable.adapter.extract(input), /初始化失败/);
  assert.deepEqual(unavailable.events, []);
});
await check('cleanup failures preserve the primary recognition error', async () => {
  const f = fixture(['recognize', 'pixel.release', 'source.release', 'file.close'], 1001400001);
  await assert.rejects(f.adapter.extract(input), /文字识别失败.*1001400001/);
  assert.deepEqual(f.events.slice(-3), ['pixel.release', 'source.release', 'file.close']);
});
await check('unknown native errors keep a safe stage hint', async () => {
  const f = fixture();
  f.context.textRecognition.recognizeText = async () => { throw null; };
  await assert.rejects(f.adapter.extract(input), /文字识别失败/);
  assert.ok(f.logs.every(message => !message.includes('private')));
});
console.log(`CORE_VISION_OCR_TEST_PASS cases=${caseCount}`);
