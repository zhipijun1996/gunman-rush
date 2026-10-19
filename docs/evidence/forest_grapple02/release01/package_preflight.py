"""Pending release evidence custody; no publisher/live checkpoint or validation execution."""
from pathlib import Path
import json,hashlib,zipfile,re
R=Path.cwd();O=R/'build/forest_grapple02/pending_release01';W=Path('/workspace/gunman-grapple-docs-check');S=lambda d:hashlib.sha256(d).hexdigest();data={};provenance=[]
def add(path,member):
 raw=path.read_bytes();assert not path.is_symlink()
 if re.search(rb'[?&](?:sig|X-Amz-Signature)=|gh[pousr]_[A-Za-z0-9]{20}|(?i:authorization)["\s:]+(?i:bearer)\s+[A-Za-z0-9]',raw):raise ValueError('Sensitive pattern; use explicit redacted derivative: '+member)
 data[member]=raw;provenance.append({'member':member,'actual_source_path':str(path),'sha256':S(raw),'bytes':len(raw),'kind':'exact original'})
folder=W/'build/verification/harness/20261019T032438.806423Z'
report=json.loads((folder/'report.json').read_text());assert report['commit']=='7ba2e92d2c3cb5449ac6648b820f79679548ee89' and report['status']=='passed' and report['git_status']=='' and len(report['checks'])==22
for p in sorted(folder.rglob('*')):
 if p.is_file() and p.suffix in {'.json','.log'}:add(p,'clean_worktree/docs22/'+str(p.relative_to(folder)))
release='20261019T032452.581744Z_8a8f420eb45b4c5981c5af47b358c265.json'
add(R/'build/verification/release-evidence'/release,'main_repo/G0-release-evidence/'+release)
for name in ['committed_native_binding01.json','duplicate_ci_cancel01.json','final_quality_content_check01.json','docs_wrong_cwd_interruption01.json']:
 add(R/'build/forest_grapple02'/name,'main_repo/forest_grapple02/'+name)
for name in ['ci_artifact_inventory_inprogress01.json','ci_serial_artifact_download01.json']:
 add(O/name,'pending_CI_metadata/'+name)
for name in ['commit_s1_review.json','commit_s1_review.md','commit_s1_probe.py']:
 add(R/'build/verification/verifier_migration_review'/name,'main_repo/verifier_migration_review/'+name)
notes={'scope':'Pre-CI terminal documentation and exact byte custody only; CI89/original80/publicGUI/whole quality not certified','source_commit':'7ba2e92d2c3cb5449ac6648b820f79679548ee89','selected_CI':39194694146,'G0_execution_location':'Main repository, not clean worktree. Requested clean-worktree path absent; actual same-named original main_repo path retained.','docs22_execution_location':str(folder),'wrong_cwd_interruption':'Original wrong-cwd command interrupted exit143 before report generation; retain original interruption JSON without inventing report.','serial_download_failure':'One accurate serial artifact attempt failed HTTP403; sanitized stderr receipt plus API metadata only, no downloaded serial report. In-progress API metadata is not terminal CI approval.', 'publisher_checkpoint':'Excluded entirely; no live checkpoint or temporary signed URLs copied.','future_append_only':'Future actual CI/preparedFoundry/export/API-digestZIP/browser/publicGUI receipts must have their own identity and failure scope; do not overwrite this preflight ZIP.','prior_existing_local_archive_sha256':S((O/'local_docs22_originals.zip').read_bytes())};data['derived/custody-notes.json']=json.dumps(notes,indent=2).encode();(O/'custody-notes.json').write_bytes(data['derived/custody-notes.json'])
rows=[{'member':p,'sha256':S(raw),'bytes':len(raw)} for p,raw in sorted(data.items())];inside=json.dumps({'scope':notes['scope'],'members':rows},indent=2).encode();zp=O/'s1-preflight-originals.zip'
with zipfile.ZipFile(zp,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
 for name,raw in sorted(data.items()):z.writestr(name,raw)
 z.writestr('ARCHIVE-INVENTORY.json',inside)
with zipfile.ZipFile(zp) as z:
 assert len(z.namelist())==len(set(z.namelist()))==len(rows)+1
 for row in rows:assert S(z.read(row['member']))==row['sha256']
inv={'scope':notes['scope'],'source_commit':notes['source_commit'],'archive_sha256':S(zp.read_bytes()),'archive_bytes':zp.stat().st_size,'archive_member_count':len(rows)+1,'members':rows,'original_provenance':provenance,'inside_inventory_sha256':S(inside),'full_readback_verified':True};(O/'s1-preflight-index.json').write_text(json.dumps(inv,indent=2)+'\n');print(json.dumps({k:v for k,v in inv.items() if k not in ['members','original_provenance']}))
