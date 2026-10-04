import importlib.util
from pathlib import Path
import tempfile
import unittest
import json
import sys
HERE=Path(__file__).parents[1]
sys.path.insert(0,str(HERE))
spec=importlib.util.spec_from_file_location('f',HERE/'sc_q2b_f.py')
f=importlib.util.module_from_spec(spec); spec.loader.exec_module(f)

class StageFContracts(unittest.TestCase):
    def record(self,**changes):
        r={'block':'F-N','arm':'neg_replay_no_manifest','suite':'neg_replay_no_manifest',
           'proc':{'spawned':True,'timed_out':False,'spawn_error':None,'post_exit_orphans':[],'exit_code':1},
           'facts':{'script_errors':[],'settle':[{'requested_ms':250,'elapsed_ms':256,'frames':39,'exit_code':1}],'leak_lines':[],'instances':[]},
           'q1_result':{'result':'PASS','reason_code':'ALL_REQUIRED_EVIDENCE_SATISFIED','exit_code':1,'negative':{'reported_reason':'MANIFEST_MISSING','reason_found':True}}}
        r.update(changes); return r
    def test_matrix_exact_counts_and_order(self):
        m=json.loads((HERE/'q2b_stage_f_matrix.json').read_text()); rr=m['attempts']
        self.assertEqual([r['ordinal'] for r in rr],list(range(1,121)))
        c=rr[6:66]; self.assertEqual(len(c),60)
        for j in range(30):
            expected=['LEGACY_IMMEDIATE_QUIT','FIXED_SETTLED_QUIT'] if j%2==0 else ['FIXED_SETTLED_QUIT','LEGACY_IMMEDIATE_QUIT']
            self.assertEqual([r['arm'] for r in c[2*j:2*j+2]],expected)
        self.assertEqual(sum(r['suite']=='virtual_rider' for r in rr),20)
        self.assertEqual(sum(r['suite']=='replay_session' for r in rr),10)
        self.assertEqual(sum(r['suite']=='neg_replay_no_manifest' for r in rr),3)
    def test_expected_negative_exit_one_accepted(self): f.validate(self.record())
    def test_wrong_negative_reason_stops(self):
        r=self.record(); r['q1_result']['negative']['reported_reason']='TIMEOUT'
        with self.assertRaisesRegex(RuntimeError,'negative semantics'): f.validate(r)
    def test_generic_pass_without_existing_reason_stops(self):
        r=self.record(); r['q1_result']['reason_code']='MANIFEST_MISSING'
        with self.assertRaisesRegex(RuntimeError,'Q1 verdict'): f.validate(r)
    def test_first_infra_stops(self):
        for field,value in [('spawned',False),('timed_out',True),('spawn_error','oops'),('post_exit_orphans',[1])]:
            r=self.record(); r['proc'][field]=value
            with self.subTest(field=field),self.assertRaisesRegex(RuntimeError,'STOP-INFRA'): f.validate(r)
    def test_q1_incomplete_stops(self):
        r=self.record();r['q1_result']['result']='INCOMPLETE'
        with self.assertRaisesRegex(RuntimeError,'STOP-INFRA'):f.validate(r)
    def test_fixed_bounds_inclusive(self):
        for elapsed in (250,500):
            r=self.record();r['facts']['settle'][0]['elapsed_ms']=elapsed; f.validate(r)
    def test_settle_violations_stop(self):
        for field,value in [('requested_ms',251),('elapsed_ms',249),('elapsed_ms',501),('exit_code',0),('frames',0)]:
            r=self.record();r['facts']['settle'][0][field]=value
            with self.subTest(field=field,value=value),self.assertRaisesRegex(RuntimeError,'STOP-SETTLE'):f.validate(r)
    def test_missing_duplicate_settle_stop(self):
        for n in (0,2):
            r=self.record();r['facts']['settle']*=n
            with self.assertRaisesRegex(RuntimeError,'STOP-SETTLE'):f.validate(r)
    def test_unrelated_objectdb_never_ignored(self):
        r=self.record();r['facts']['leak_lines']=['WARNING: 8 ObjectDB instances were leaked at exit']
        with self.assertRaisesRegex(RuntimeError,'STOP-RESIDUAL'):f.validate(r)
    def test_verbose_instance_without_warning_stops(self):
        r=self.record();r['facts']['instances']=[{'class':'Other'}]
        with self.assertRaisesRegex(RuntimeError,'STOP-RESIDUAL'):f.validate(r)
    def test_no_reduced_n_fisher(self):
        rr=[{'block':'F-C','arm':'LEGACY_IMMEDIATE_QUIT','facts':{'warning_counts':[6],'leak_lines':['warning']}}]*29
        self.assertIsNone(f.observations(rr)['fisher_one_sided'])
    def test_exact_fisher_threshold(self): self.assertLess(f.q.fisher(7,30,0,30),.01)
    def test_zero_interval_bounds(self):
        self.assertAlmostEqual(f.q.interval(0,30)[1],1-.025**(1/30),places=12)
        self.assertAlmostEqual(f.q.invert_tail(1,30,.99),1-.01**(1/30),places=12)
    def test_settle_stdout_parser(self):
        with tempfile.TemporaryDirectory() as d:
            p=Path(d); (p/'stdout.log').write_text('SC_TEARDOWN_SETTLE requested_ms=250 elapsed_ms=256 frames=39 exit_code=1\n')
            self.assertEqual(f.inspect(p)['settle'][0]['exit_code'],1)

if __name__=='__main__': unittest.main()
