// Exercise actual remote adapter with HTTP doubles; does not replace HAP/ArkTS SDK compilation.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { stripTypeScriptTypes } from 'node:module';
import vm from 'node:vm';
const source = readFileSync(new URL('../entry/src/main/ets/application/remote/HomeworkOrganizerRemoteApi.ets', import.meta.url), 'utf8')
  .replace(/^import .*;\r?\n/gm, '').replaceAll('export interface', 'interface').replace('export class', 'class');
let response;
const calls = [];
const context = vm.createContext({
  console: { info() {} },
  http: { RequestMethod: { POST: 'POST', GET: 'GET' } },
  BackendSession: { instance: { isConnected: () => true } },
  BackendHttpClient: { instance: { requestFor: async (...args) => { calls.push(args); return { statusCode: 200, body: JSON.stringify(response) }; } } },
  AssignmentTaskDate: { today: () => '2026-10-19', resolve: value => value },
  HomeworkImageEncoder: { encode: async () => ({ imageBase64: 'synthetic', contentType: 'image/png', encodedBytes: 8 }) },
  Subject: { CHINESE: '语文', MATH: '数学', ENGLISH: '英语', READING: '阅读', READ_ALOUD: '朗读', SPORTS: '体育', PRACTICE: '实践', INTEREST: '兴趣', OTHER: '其他' }
});
vm.runInContext(stripTypeScriptTypes(source), context);
const api = vm.runInContext('HomeworkOrganizerRemoteApi.instance', context);
const input = { importId: 'batch', studentId: 'student-one', sourceLabel: '来源', text: '老师原文' };
const candidate = { subject: '数学', title: '口算20题', instruction: '口算20题', textbookRef: '待家长确认', taskDate: '2026-10-19', expectedMinutes: 10, sourceExcerpt: '口算20题', confidence: .99, sourceBlockIds: ['t1'] };
response = { mode: 'AI', assignments: [candidate], needsReview: true,
  sourceDocument: { blocks: [{ id: 't2', text: '语文：朗读13页' }] },
  qualityFlags: [{ code: 'POSSIBLE_OMISSION', sourceBlockIds: ['t2'], assignmentIndexes: [] }, { code: 'REVIEW_FAILED', sourceBlockIds: [], assignmentIndexes: [] }] };
const flagged = await api.organize(input);
assert.equal(flagged.length, 1);
assert.equal(flagged[0].confidence, .99);
assert.ok(flagged[0].sourceEvidence.reviewNotice.includes('语文：朗读13页'));
assert.ok(flagged[0].sourceEvidence.reviewNotice.includes('复核未能确认'));
assert.equal(flagged[0].studentId, 'student-one');
assert.equal(flagged[0].sourceEvidence.sourceBlockIds[0], 't1');
response = { mode: 'AI', assignments: [candidate] }; // older backend fields remain usable
const legacy = await api.organize(input);
assert.equal(legacy[0].sourceEvidence.reviewNotice, '');
response = { mode: 'AI_IMAGE', recognizedText: '', assignments: [candidate], needsReview: true,
  qualityFlags: [{ code: 'SOURCE_EVIDENCE_UNAVAILABLE', sourceBlockIds: [], assignmentIndexes: [] }] };
const image = await api.organizeImage(input, 'private-local-image');
assert.equal(image.candidates.length, 1);
assert.ok(image.candidates[0].sourceEvidence.reviewNotice.length > 0);
assert.equal(image.recognizedText, ''); // no fabricated full transcription from candidate excerpt
assert.ok(calls.every(call => call[1].includes('/students/student-one/')));
console.log('ORGANIZER_QUALITY_CONTRACT_PASS: warnings, source location, legacy fields, image evidence gap, student scope');
