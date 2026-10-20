"""Synthetic VERIFIED cases test the tool only; no production fixture is promoted to gold."""
import copy
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0,str(Path(__file__).resolve().parents[1]))
from benchmark_homework_organizer import benchmark
from organizer_eval_inputs import case_fingerprint, digest
from organizer_metrics import configured_cost, summarize


class BenchmarkTest(unittest.TestCase):
    def setUp(self):
        self.root=Path('.')
        self.fixtures={'cases':[dict(id='math',sourceType='TEXT',sourceText='数学口算20题',reviewStatus='VERIFIED',
            expected=[dict(subject='数学',keywords=['口算20题'],fields={'taskDate':'2026-10-20'},sourceEvidenceTexts=['数学口算20题'])]),
            dict(id='chinese',sourceType='TEXT',sourceText='语文朗读13页',reviewStatus='VERIFIED',
            expected=[dict(subject='语文',keywords=['朗读13页'],fields={'taskDate':'2026-10-20'},sourceEvidenceTexts=['语文朗读13页'])])]}
        self.context=dict(studentScopeHash='a'*64,teacherStateHash='b'*64,textbookStateHash='c'*64,
                          businessDate='2026-10-20',networkProfile='same-lab')
        self.prices={'A':dict(inputPerMillion=1,outputPerMillion=1,cachedInputPerMillion=.1,currency='CNY'),
                     'B':dict(inputPerMillion=.5,outputPerMillion=.5,cachedInputPerMillion=.05,currency='CNY')}
    def run_data(self,model='A',elapsed=100):
        rows=[]
        for case in self.fixtures['cases']:
            exp=case['expected'][0] if case['expected'] else dict(subject='其他',keywords=['通知'])
            item=dict(subject=exp['subject'],title=exp['keywords'][0],instruction=exp['keywords'][0],taskDate='2026-10-20',sourceBlockIds=['b1'])
            rows.append(dict(caseId=case['id'],inputType=case.get('sourceType','TEXT'),inputFingerprint=case_fingerprint(case,self.root),
                             success=True,assignments=[item] if case['expected'] else [],sourceDocument={'blocks':[dict(id='b1',text=case['sourceText'])]},
                             model=model,promptVersion='prompt-1',ruleVersion='rule-1',experienceVersion='experience-1',provider='TEST',
                             elapsedMs=elapsed,cacheHit=False,callCount=1,tokensIn=100,tokensOut=50,
                             aiCalls=[dict(stage='PRIMARY',model=model,provider='TEST',promptVersion='actual-call-prompt-1',usage=dict(tokensIn=100,tokensOut=50,cachedTokens=0,imageTokens=0))]))
        return dict(fixtureHash=digest(self.fixtures),benchmarkContext=copy.deepcopy(self.context),results=rows)
    def compare(self,base=None,candidate=None,kind='MODEL'):
        return benchmark(self.fixtures,{'base':[base or self.run_data()], 'candidate':[candidate or self.run_data('B',80)]},
                         'base',self.prices,self.root,kind)['variants']['candidate']
    def test_complete_proxy_comparison_passes_without_claiming_semantic_accuracy(self):
        result=self.compare()
        self.assertEqual('PROXY_NONREGRESSION_PASS',result['decision'])
        self.assertEqual(1,result['quality']['recallProxy'])
        self.assertEqual(-20,result['deltas']['p95Ms'])
        self.assertEqual({'TEXT':['B']},result['models'])
        self.assertNotIn('数学口算20题',json.dumps(result,ensure_ascii=False))
    def test_draft_gold_never_produces_accuracy_or_model_selection(self):
        for case in self.fixtures['cases']:case['reviewStatus']='DRAFT'
        result=self.compare()
        self.assertEqual('NO_VERIFIED_GOLD',result['qualityStatus'])
        self.assertEqual('UNAVAILABLE',result['decision'])
        self.assertIsNone(result['quality']['recallProxy'])
    def test_partial_gold_cannot_bless_unverified_image_or_text_quality(self):
        self.fixtures['cases'][1]['reviewStatus']='DRAFT'
        result=self.compare()
        self.assertEqual(1,result['quality']['recallProxy'])
        self.assertEqual('UNAVAILABLE',result['qualityGate'])
        self.assertEqual('UNAVAILABLE',result['decision'])
        self.assertEqual(['chinese'],result['goldCoverage']['unverifiedCaseIds'])

    def test_faster_cheaper_candidate_cannot_hide_task_or_field_loss(self):
        for loss in ('task','field'):
            candidate=self.run_data('B',1)
            if loss=='task':candidate['results'][0]['assignments']=[]
            else:candidate['results'][0]['assignments'][0]['taskDate']='wrong-date'
            result=self.compare(candidate=candidate)
            self.assertEqual('REGRESSED',result['decision'])
            self.assertEqual('math',result['qualityRegressions'][0]['caseId'])
    def test_gains_in_one_case_cannot_cancel_loss_in_another(self):
        base=self.run_data();base['results'][1]['assignments']=[]
        candidate=self.run_data('B',1);candidate['results'][0]['assignments']=[]
        result=self.compare(base,candidate)
        self.assertEqual(.5,result['quality']['recallProxy'])
        self.assertEqual('REGRESSED',result['qualityGate'])
    def test_negative_sample_fabrication_is_a_quality_regression(self):
        self.fixtures['cases'][0]['expected']=[]
        base=self.run_data();candidate=self.run_data('B',1)
        candidate['results'][0]['assignments']=[dict(subject='其他',title='捏造作业')]
        self.assertEqual('REGRESSED',self.compare(base,candidate)['qualityGate'])
    def test_changed_scope_missing_usage_and_unknown_currency_cannot_pass(self):
        for change in ('scope','usage','currency','input_type','latency','calls'):
            candidate=self.run_data('B',1)
            if change=='scope':candidate['benchmarkContext']['studentScopeHash']='d'*64
            if change=='usage':candidate['results'][0]['aiCalls'][0]['usage']['tokensIn']=None
            if change=='currency':self.prices['B']['currency']='USD'
            if change=='input_type':candidate['results'][0].pop('inputType')
            if change=='latency':candidate['results'][0].pop('elapsedMs')
            if change=='calls':candidate['results'][0]['callCount']=3
            self.assertEqual('UNAVAILABLE',self.compare(candidate=candidate)['decision'],change)
            self.prices['B']['currency']='CNY'
    def test_model_and_pipeline_comparisons_freeze_different_variables(self):
        candidate=self.run_data('A',80);candidate['results'][0]['promptVersion']='prompt-2'
        self.assertEqual('UNAVAILABLE',self.compare(candidate=candidate)['decision'])
        self.assertEqual('PROXY_NONREGRESSION_PASS',self.compare(candidate=candidate,kind='PIPELINE')['decision'])
        self.assertEqual('UNAVAILABLE',self.compare(kind='PIPELINE')['decision'])
    def test_primary_and_review_prompt_changes_cannot_hide_under_an_unchanged_primary_version(self):
        candidate=self.run_data('B',80);candidate['results'][0]['aiCalls'][0]['promptVersion']='changed-actual-prompt'
        result=self.compare(candidate=candidate)
        self.assertEqual('UNAVAILABLE',result['decision'])
        self.assertIn('PER_CALL_COMPARISON_VARIABLES_CHANGED',result['contextIssues'])
        candidate['results'][0]['aiCalls'][0].pop('promptVersion')
        self.assertEqual('UNAVAILABLE',self.compare(candidate=candidate)['decision'])
    def test_repeated_runs_must_preserve_context_and_provenance(self):
        a,b=self.run_data(),self.run_data('B',80)
        second=copy.deepcopy(b);second['results'][0]['experienceVersion']='changed'
        report=benchmark(self.fixtures,{'base':[a,a],'candidate':[b,second]},'base',self.prices,self.root)
        self.assertIn('PROVENANCE_DRIFT_ACROSS_REPEATS',report['variants']['candidate']['contextIssues'])
        with self.assertRaisesRegex(ValueError,'same nonzero'):
            benchmark(self.fixtures,{'base':[a],'candidate':[b,b]},'base')
    def test_missing_duplicate_and_extra_cases_are_rejected(self):
        for rows in (self.run_data()['results'][:1],[self.run_data()['results'][0]]*2,
                     self.run_data()['results']+[dict(caseId='extra')]):
            candidate=self.run_data('B');candidate['results']=rows
            with self.assertRaisesRegex(ValueError,'exactly'):
                self.compare(candidate=candidate)
    def test_warm_hits_cannot_hide_cold_latency_regression(self):
        self.fixtures['cases']=[dict(copy.deepcopy(self.fixtures['cases'][0]),id='case-'+str(i)) for i in range(20)]
        base=self.run_data();candidate=self.run_data('B',1)
        for row in candidate['results']:
            row.update(cacheHit=True,callCount=0,tokensIn=0,tokensOut=0,aiCalls=[])
        candidate['results'][0]=self.run_data('B',150)['results'][0]
        result=self.compare(base,candidate)
        self.assertEqual(1,result['performance']['p95Ms'])
        self.assertEqual('REGRESSED',result['latencyGate'])
    def test_warm_hits_cannot_hide_more_expensive_cold_model(self):
        self.fixtures['cases']=[dict(copy.deepcopy(self.fixtures['cases'][0]),id='case-'+str(i)) for i in range(20)]
        self.prices['B']['inputPerMillion']=2;self.prices['B']['outputPerMillion']=2
        base=self.run_data();candidate=self.run_data('B',80)
        for row in candidate['results'][1:]:row.update(cacheHit=True,callCount=0,tokensIn=0,tokensOut=0,aiCalls=[])
        result=self.compare(base,candidate)
        self.assertLess(result['performance']['averageConfiguredCost'],summarize(base['results'],self.prices)['averageConfiguredCost'])
        self.assertEqual('REGRESSED',result['costGate'])

    def test_same_image_path_with_changed_bytes_invalidates_comparison(self):
        with tempfile.TemporaryDirectory() as folder:
            self.root=Path(folder);image=self.root/'case.png';image.write_bytes(b'actual fixture image bytes')
            self.fixtures['cases'][0].update(sourceType='IMAGE',imagePath='case.png')
            base=self.run_data();candidate=self.run_data('B',80);image.write_bytes(b'changed bytes')
            result=self.compare(base,candidate)
            self.assertEqual('UNAVAILABLE',result['decision'])
            self.assertIn('INPUT_FINGERPRINT_UNAVAILABLE_OR_CHANGED',result['contextIssues'])
    def test_text_and_image_can_use_different_models_without_mixing_quality_scores(self):
        with tempfile.TemporaryDirectory() as folder:
            self.root=Path(folder);(self.root/'case.png').write_bytes(b'fixture image')
            self.fixtures['cases'][0].update(sourceType='IMAGE',imagePath='case.png')
            base=self.run_data();candidate=self.run_data('B',80)
            base['results'][0]['model']='B';base['results'][0]['aiCalls'][0]['model']='B'
            result=self.compare(base,candidate)
            self.assertEqual('PROXY_NONREGRESSION_PASS',result['decision'])
            self.assertEqual({'IMAGE','TEXT'},set(result['buckets']))
    def test_context_date_and_non_private_hash_fields_are_validated(self):
        for key,value in [('businessDate','2026-99-99'),('studentScopeHash','private-child-name')]:
            candidate=self.run_data('B');candidate['benchmarkContext'][key]=value
            self.assertEqual('UNAVAILABLE',self.compare(candidate=candidate)['decision'])
    def test_replay_enrichment_preserves_context_and_input_identity(self):
        from run_homework_organizer_eval import main
        with tempfile.TemporaryDirectory() as folder:
            source=Path(folder)/'predictions.json';out=Path(folder)/'enriched.json';source.write_text(json.dumps(self.run_data()))
            with patch('sys.argv',['eval','--predictions',str(source),'--output',str(out)]), patch('builtins.print'):main()
            result=json.loads(out.read_text())
            self.assertEqual(self.context,result['benchmarkContext']);self.assertEqual(digest(self.fixtures),result['fixtureHash'])
            self.assertEqual(self.run_data()['results'][0]['inputFingerprint'],result['results'][0]['inputFingerprint'])

    def test_cli_writes_reviewable_reports_and_returns_pass_regression_or_unavailable(self):
        from benchmark_homework_organizer import main
        for status in ('pass','regressed','draft'):
            if status=='draft':
                for case in self.fixtures['cases']:case['reviewStatus']='DRAFT'
            with tempfile.TemporaryDirectory() as directory:
                folder=Path(directory);base=self.run_data();candidate=self.run_data('B',80)
                if status=='regressed':candidate['results'][0]['assignments']=[]
                files={'fixtures.json':self.fixtures,'base.json':base,'candidate.json':candidate,'prices.json':self.prices,
                       'manifest.json':dict(baseline='base',comparisonKind='MODEL',variants={'base':['base.json'],'candidate':['candidate.json']})}
                for name,data in files.items():(folder/name).write_text(json.dumps(data))
                arguments=['benchmark','--fixtures',str(folder/'fixtures.json'),'--manifest',str(folder/'manifest.json'),
                           '--prices',str(folder/'prices.json'),'--report',str(folder/'report.json')]
                with patch('sys.argv',arguments),patch('builtins.print'),self.assertRaises(SystemExit) as exited:main()
                self.assertEqual({'pass':0,'regressed':1,'draft':2}[status],exited.exception.code)
                report=json.loads((folder/'report.json').read_text())
                self.assertEqual('base',report['baseline'])
                self.assertNotIn('数学口算20题',json.dumps(report,ensure_ascii=False))


class ActualUsageCostTest(unittest.TestCase):
    def test_actual_per_call_review_model_and_provider_rate_override(self):
        row=dict(model='large',callCount=2,tokensIn=1100,tokensOut=110,aiCalls=[
            dict(model='large',provider='P',usage=dict(tokensIn=100,tokensOut=10,cachedTokens=0)),
            dict(model='small',provider='P',usage=dict(tokensIn=1000,tokensOut=100,cachedTokens=0))])
        prices={'large':dict(inputPerMillion=2,outputPerMillion=2,currency='CNY'),
                'small':dict(inputPerMillion=999,outputPerMillion=999,currency='CNY'),
                'P/small':dict(inputPerMillion=.1,outputPerMillion=.1,currency='CNY')}
        cost,currency=configured_cost(row,prices)
        self.assertAlmostEqual(.00033,cost);self.assertEqual('CNY',currency)
    def test_cached_discount_needs_actual_counter_and_image_tokens_are_not_double_charged(self):
        prices={'model':dict(inputPerMillion=2,outputPerMillion=4,cachedInputPerMillion=.2,currency='CNY')}
        row=dict(model='model',callCount=1,aiCalls=[dict(model='model',usage=dict(tokensIn=100,tokensOut=10,cachedTokens=30,imageTokens=80))])
        self.assertAlmostEqual(.000186,configured_cost(row,prices)[0])
        for value in (None,-1,101):
            row['aiCalls'][0]['usage']['cachedTokens']=value
            self.assertIsNone(configured_cost(row,prices)[0])
    def test_mixed_currencies_partial_usage_and_invalid_prices_never_become_complete_cost(self):
        rows=[dict(model='a',tokensIn=100,tokensOut=20),dict(model='b',tokensIn=100,tokensOut=20)]
        prices={'a':dict(inputPerMillion=1,outputPerMillion=1,currency='CNY'),'b':dict(inputPerMillion=1,outputPerMillion=1,currency='USD')}
        report=summarize(rows,prices);self.assertIsNone(report['averageConfiguredCost']);self.assertEqual(2,report['costUnavailableRequests'])
        for value in (-1, float('nan'),True):
            prices['a']['inputPerMillion']=value;self.assertIsNone(configured_cost(rows[0],prices)[0])
        self.assertEqual((0.0,None),configured_cost(dict(cacheHit=True,callCount=0),{}))


if __name__=='__main__':unittest.main()
