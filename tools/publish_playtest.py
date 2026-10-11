"""Publish a verified Git ref to the existing Pages URL without merging PRs.
Invoke after local tests/build/browser validation. CI rechecks before deployment;
a successful deployment is also checked against the live source commit.
"""
import argparse,json,subprocess,time,urllib.request

def gh(*args):
    return subprocess.check_output(['gh',*args],text=True).strip()
def live_info(url):
    request=urllib.request.Request(url.rstrip('/')+'/build-info.json?check='+str(time.time_ns()),headers={'Cache-Control':'no-cache'})
    with urllib.request.urlopen(request,timeout=20) as response:return json.load(response)
def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ref',required=True)
    parser.add_argument('--timeout',type=int,default=3600)
    args=parser.parse_args()
    repo=json.loads(gh('repo','view','--json','nameWithOwner'))['nameWithOwner']
    commit=gh('api',f'repos/{repo}/commits/{args.ref}','--jq','.sha')
    url=gh('api',f'repos/{repo}/pages','--jq','.html_url')
    prior={r['databaseId'] for r in json.loads(gh('run','list','--workflow','environment.yml','--branch',args.ref,'--event','workflow_dispatch','--limit','20','--json','databaseId'))}
    gh('workflow','run','environment.yml','--ref',args.ref,'-f','deploy_playtest=true')
    deadline=time.monotonic()+args.timeout
    run=None;last_status=''
    while time.monotonic()<deadline:
        runs=json.loads(gh('run','list','--workflow','environment.yml','--branch',args.ref,'--event','workflow_dispatch','--limit','10','--json','databaseId,headSha,status,conclusion,url'))
        selected=[r for r in runs if r['databaseId'] not in prior and r['headSha']==commit]
        if selected:
            run=selected[0]
            state=f"{run['status']} {run['conclusion']} {run['url']}"
            if state!=last_status:print(state,flush=True);last_status=state
            if run['status']=='completed':
                if run['conclusion']!='success':raise RuntimeError('CI/deployment failed: '+state)
                info=live_info(url)
                if info.get('source_commit')==commit:
                    print(json.dumps({'url':url+'?v='+info['build_id'],'commit':commit,'build_id':info['build_id'],'run_url':run['url'],'live_verified':True}),flush=True)
                    return
        time.sleep(20)
    raise RuntimeError('Timed out waiting for deployment and live commit verification')
if __name__=='__main__':main()
