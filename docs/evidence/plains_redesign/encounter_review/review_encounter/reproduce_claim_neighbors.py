"""Verifier-only mutations of a retained ACTUAL capture; no native physics claim.
To replay the reviewed validator later, extract reviewed_original_source.tar.gz to
an isolated source root and set REVIEWED_SOURCE_ROOT to that root before running.
"""
import copy,gzip,json,os,sys
from pathlib import Path
folder=Path(__file__).resolve().parent
source=Path(os.environ.get('REVIEWED_SOURCE_ROOT',folder.parents[2]))
sys.path.insert(0,str(source/'tools'))
import level_experience as experience
capture=json.loads(gzip.open(folder/'reviewed_growth_capture.json.gz','rt').read())
experience.validate_capture(capture)
results=[]
for name in ['missing_wallet_receipt','missing_wallet_effect','forged_reward_amount','forged_resource_type']:
    changed=copy.deepcopy(capture)
    claim=next(o for o in changed['policy_observations'] if o.get('kind')=='actual_cache_claim')
    if name=='missing_wallet_receipt':claim['wallet_receipts']={}
    elif name=='missing_wallet_effect':claim['after']['coins']=claim['before']['coins']
    elif name=='forged_reward_amount':claim['claim_output']['amount']=999999
    else:claim['claim_output']['resource']='imaginary_resource'
    try:experience.validate_capture(changed);rejected=False;reason='accepted'
    except (ValueError,KeyError,TypeError) as error:rejected=True;reason=str(error)
    results.append(dict(case=name,rejected=rejected,reason=reason))
print(json.dumps(results,indent=2))
raise SystemExit(1 if any(not r['rejected'] for r in results) else 0)
