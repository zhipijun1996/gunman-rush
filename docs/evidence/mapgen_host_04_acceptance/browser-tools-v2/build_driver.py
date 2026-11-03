"""Build/audit the finite authorized gears checkpoint migration; never runs live."""
import ast
from collections import Counter
import hashlib
import json
from pathlib import Path

BASE = Path(__file__).resolve().parent
SHA = '112c62449312246ac3a600a1dd3b690ce8a1cf32ef5517ce0be014b8c8b036f0'
OLD_CHECKPOINT_START = '        async def checkpoint(label,pic,row,action):\n'
OLD_CHECKPOINT_END = '        async with async_playwright() as p:\n'
AUTO_CHECKPOINT = '''        async def checkpoint(label,pic,row,action):
            nonlocal sequence
            sequence+=1
            plan=[('view-real04-gears-entry-and-cropped-frame','observe'),('view04-gears-motion-images-and-hazard-band','escape'),('view-real-returned-title','confirm-title')]
            assert 1<=sequence<=len(plan) and (label,action)==plan[sequence-1]
            files=[item['file'] for item in row['screenshots']]
            assert files and pic.name==files[-1] and len(files)==[1,6,7][sequence-1]
            record=dict(seq=sequence,label=label,expected_action=action,screenshot=pic.name,capture_files=files,disposition='DEFERRED_ACTUAL_VISUAL_REVIEW_REQUIRED')
            row.setdefault('deferred_visual_checkpoints',[]).append(record)
            report['visual_review_state']='PENDING_INDEPENDENT_OFFLINE_REVIEW'
            report['checkpoint_policy']='Automatic declared actions; saved captures are unreviewed until independent offline strict join. No human ACK is generated or consumed.'
            save();print('CAPTURE_DEFERRED',sequence,label,pic.name,flush=True)
'''
REPLACEMENTS = [
    ("row['operator_visual_review'][-1]['reviewed_files']", "row['deferred_visual_checkpoints'][-1]['capture_files']"),
    ("row['status']='PASSED_ACTUAL_04_GEARS_INITIAL_SPAWN_MECHANISM_MOTION_AND_ESCAPE'", "row['status']='AUTOMATED_GEARS_ACTIONS_COMPLETE_VISUAL_PENDING'"),
    ("report['status']='PASSED_04_GEARS_INITIAL_SPAWN_MECHANISM_MOTION_AND_ESCAPE'", "report['status']='AUTOMATED_COMPLETE_VISUAL_PENDING'"),
    ("if report['status'].startswith('PASSED'):", "if report['status']=='AUTOMATED_COMPLETE_VISUAL_PENDING':"),
]

def ast_dump(text): return ast.dump(ast.parse(text),include_attributes=False)
def assertions(text): return Counter(ast.dump(n,include_attributes=False) for n in ast.walk(ast.parse(text)) if isinstance(n,ast.Assert))

def main():
    old=(BASE/'original_driver.py').read_text()
    assert hashlib.sha256(old.encode()).hexdigest()==SHA
    start=old.index(OLD_CHECKPOINT_START);end=old.index(OLD_CHECKPOINT_END,start)
    old_checkpoint=old[start:end]
    new=old[:start]+AUTO_CHECKPOINT+old[end:]
    for before,after in REPLACEMENTS:
        assert new.count(before)==1
        new=new.replace(before,after)
    compile(new,'automated_driver.py','exec')
    restored=new
    for before,after in reversed(REPLACEMENTS):
        assert restored.count(after)==1;restored=restored.replace(after,before)
    assert restored.count(AUTO_CHECKPOINT)==1
    restored=restored.replace(AUTO_CHECKPOINT,old_checkpoint)
    assert restored==old and ast_dump(restored)==ast_dump(old)
    old_assert=assertions(old)
    ack_text="assert value['action']==action and value.get('passed') is True"
    capture_text="assert set(row['operator_visual_review'][-1]['reviewed_files'])==set(screenshots)"
    changed=[ast_dump(ack_text).removeprefix('Module(body=[').removesuffix('], type_ignores=[])'),ast_dump(capture_text).removeprefix('Module(body=[').removesuffix('], type_ignores=[])')]
    old_non_manual=old_assert.copy()
    for item in changed: assert old_non_manual[item]==1;old_non_manual.subtract([item])
    new_assert=assertions(new)
    assert not (old_non_manual-new_assert)
    (BASE/'automated_driver.py').write_text(new)
    audit=dict(original_sha256=SHA,new_sha256=hashlib.sha256(new.encode()).hexdigest(),original_assertions=sum(old_assert.values()),old_manual_ack_assertions=1,old_review_batch_assertions=1,other_76_assertions_preserved=not bool(old_non_manual-new_assert),new_assertions=sum(new_assert.values()),inverse_entire_source_exact=True,inverse_entire_AST_exact=True,original_actions_and_guards='Entire source restores exact under this finite checkpoint/status/key inverse; all key/screenshot/observation/browser/source/PCK/producer/HTTP actions outside checkpoint unchanged',manual_change_scope=[ack_text+' -> declared seq/action and capture count assertions; no operator ACK',capture_text+" -> assert set(row['deferred_visual_checkpoints'][-1]['capture_files'])==set(screenshots); strict offline full7-image review is mandatory"],budget_seconds=300,fresh_contexts=1,required_PNGs=7,automatic_complete_status='AUTOMATED_COMPLETE_VISUAL_PENDING',guard_status_predicate="report['status']=='AUTOMATED_COMPLETE_VISUAL_PENDING'",final_visual_acceptance='Separate independent offline_review.py strict join only')
    (BASE/'equivalence-audit.json').write_text(json.dumps(audit,indent=2)+'\n')
    print(json.dumps(audit,indent=2))

if __name__=='__main__': main()
