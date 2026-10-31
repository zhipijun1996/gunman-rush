#!/usr/bin/env python3
"""Promote one reviewed artifact through runner credentials; never rebuild an engine."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import sys
import urllib.parse
import urllib.request
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parent))
import package as pack


def distribution_names():
    return {'SHA256SUMS.json', 'build-logs.zip', 'build-provenance.json', 'engine-identity.json',
            'godot-lock-candidate.json', 'version.txt', pack.RECIPE['id']+'-linux-x86_64.zip',
            pack.RECIPE['id']+'-export-templates.tpz'}


def extract_exact(archive, destination, expected):
    if destination.exists():
        raise ValueError('Extraction destination must be fresh')
    with zipfile.ZipFile(archive) as source:
        entries = source.infolist()
        if len(entries) != len(expected) or {row.filename for row in entries} != set(expected):
            raise ValueError('Archive members differ from the exact contract')
        for row in entries:
            path = PurePosixPath(row.filename)
            mode = stat.S_IFMT(row.external_attr >> 16)
            if (path.is_absolute() or '..' in path.parts or '\\' in row.filename
                    or row.is_dir() or mode not in (0, stat.S_IFREG)):
                raise ValueError('Unsafe or non-regular archive member')
        destination.mkdir(parents=True)
        for row in entries:
            target = destination / row.filename
            target.parent.mkdir(parents=True, exist_ok=True)
            with source.open(row) as incoming, target.open('xb') as outgoing:
                shutil.copyfileobj(incoming, outgoing, 1024 * 1024)


def verify_metadata(run, artifact, pins):
    expected_run = {'id': pins.run, 'head_sha': pins.source, 'status': 'completed', 'conclusion': 'success'}
    if any(run.get(key) != value for key, value in expected_run.items()):
        raise ValueError('Build run is not the reviewed successful source')
    expected_artifact = {'id': pins.artifact, 'name': 'engine-distribution-candidate',
                         'size_in_bytes': pins.size, 'digest': 'sha256:'+pins.digest, 'expired': False}
    if any(artifact.get(key) != value for key, value in expected_artifact.items()):
        raise ValueError('Artifact metadata differs from the reviewed bytes')
    owner = artifact.get('workflow_run', {})
    if owner.get('id') != pins.run or owner.get('head_sha') != pins.source:
        raise ValueError('Artifact belongs to a different run/source')


def verify_distribution(archive, work, pins):
    if archive.stat().st_size != pins.size or pack.sha(archive) != pins.digest:
        raise ValueError('Artifact ZIP digest/size mismatch')
    distribution = work/'distribution'
    extract_exact(archive, distribution, distribution_names())
    if pack.sha(distribution/'godot-lock-candidate.json') != pins.lock_digest:
        raise ValueError('Reviewed installation lock SHA mismatch')
    proof = json.loads((distribution/'build-provenance.json').read_text())
    if proof.get('recipe_commit') != pins.source or proof.get('workflow_run') != str(pins.run):
        raise ValueError('Distribution source/run mismatch')
    if set(proof['lanes']) != set(pack.RECIPE['jobs']):
        raise ValueError('Distribution must contain all ten build lanes')
    editor_names = {'godot-linux-x86_64', 'LICENSE.txt', 'COPYRIGHT.txt', 'engine-identity.json'}
    output_names = {name for job in pack.RECIPE['jobs'].values() for name in job['outputs']}
    template_names = (output_names-editor_names) | {'version.txt', 'engine-identity.json'}
    extract_exact(distribution/(pack.RECIPE['id']+'-linux-x86_64.zip'), work/'editor', editor_names)
    extract_exact(distribution/(pack.RECIPE['id']+'-export-templates.tpz'), work/'templates',
                  {'templates/'+name for name in template_names})
    logs = set()
    for lane, receipt in proof['lanes'].items():
        for command in receipt['commands']:
            name = command.get('log', '')
            if not name or Path(name).name != name:
                raise ValueError('Unsafe build log name')
            logs.add(lane+'/'+name)
    extract_exact(distribution/'build-logs.zip', work/'logs', logs)
    for lane, job in pack.RECIPE['jobs'].items():
        target = work/'lanes'/('engine-built-'+lane)
        target.mkdir(parents=True)
        pack.write(target/'provenance.json', proof['lanes'][lane])
        for name in job['outputs']:
            origin = work/'editor'/name if name in editor_names else work/'templates/templates'/name
            os.link(origin, target/name)
        for command in proof['lanes'][lane]['commands']:
            os.link(work/'logs'/lane/command['log'], target/command['log'])
    # The existing packager is the sole source/command/log/payload authority.
    pack.package(work/'lanes', work/'repacked', pins.base_url, pins.source, str(pins.run))
    observed = {}
    for name in sorted(distribution_names()):
        actual = pack.sha(distribution/name)
        if actual != pack.sha(work/'repacked'/name):
            raise ValueError('Repack differs from reviewed distribution: '+name)
        observed[name] = {'sha256': actual, 'bytes': (distribution/name).stat().st_size}
    return distribution, observed


class SafeRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, fp, code, msg, headers, new_url):
        result = super().redirect_request(request, fp, code, msg, headers, new_url)
        if result is not None and urllib.parse.urlsplit(new_url).netloc != urllib.parse.urlsplit(request.full_url).netloc:
            result.remove_header('Authorization')
        return result


class GitHub:
    def __init__(self, repository, token):
        self.prefix = 'https://api.github.com/repos/'+repository
        self.token = token
        self.opener = urllib.request.build_opener(SafeRedirect())

    def request(self, method, path, body=None, accept='application/vnd.github+json', file=None):
        url = path if path.startswith('https://') else self.prefix+path
        if urllib.parse.urlsplit(url).netloc not in ('api.github.com', 'uploads.github.com'):
            raise ValueError('Refusing credentials outside GitHub API/upload hosts')
        headers = {'Authorization': 'Bearer '+self.token, 'Accept': accept,
                   'X-GitHub-Api-Version': '2022-11-28', 'User-Agent': 'gunman-fixed-engine-promotion'}
        payload = json.dumps(body).encode() if body is not None else None
        if payload is not None:
            headers['Content-Type'] = 'application/json'
        if file is not None:
            headers.update({'Content-Type': 'application/octet-stream', 'Content-Length': str(file.stat().st_size)})
            with file.open('rb') as stream:
                request = urllib.request.Request(url, data=stream, headers=headers, method=method)
                with self.opener.open(request, timeout=180) as response:
                    return json.load(response)
        request = urllib.request.Request(url, data=payload, headers=headers, method=method)
        return self.opener.open(request, timeout=180)

    def json(self, method, path, body=None):
        with self.request(method, path, body) as response:
            return json.load(response)

    def download(self, path, destination):
        destination.parent.mkdir(parents=True, exist_ok=True)
        with self.request('GET', path, accept='application/octet-stream') as response, destination.open('xb') as output:
            shutil.copyfileobj(response, output, 1024*1024)

    def upload(self, url, path):
        return self.request('POST', url, file=path)


def release_state(api, pins):
    release = api.json('GET', '/releases/'+str(pins.release))
    if (release.get('id') != pins.release or release.get('tag_name') != pins.tag
            or release.get('target_commitish') != pins.source or release.get('prerelease') is not True
            or type(release.get('draft')) is not bool):
        raise ValueError('Existing release metadata differs from the reviewed target')
    obj = api.json('GET', '/git/ref/tags/'+urllib.parse.quote(pins.tag, safe=''))['object']
    seen = set()
    while obj.get('type') == 'tag':
        if obj['sha'] in seen or len(seen) >= 5:
            raise ValueError('Invalid annotated tag chain')
        seen.add(obj['sha'])
        obj = api.json('GET', '/git/tags/'+obj['sha'])['object']
    if obj.get('type') != 'commit' or obj.get('sha') != pins.source:
        raise ValueError('Release tag does not resolve to the reviewed source commit')
    expected_url = 'https://uploads.github.com/repos/'+pins.repository+'/releases/'+str(pins.release)+'/assets'
    if release.get('upload_url', '').split('{', 1)[0] != expected_url:
        raise ValueError('Unexpected GitHub upload endpoint')
    return release, expected_url


def verify_assets(api, pins, expected, work, phase, complete=False):
    assets = api.json('GET', '/releases/'+str(pins.release)+'/assets?per_page=100')
    names = [row['name'] for row in assets]
    if len(names) != len(set(names)) or not set(names).issubset(expected):
        raise ValueError('Unexpected or duplicate release assets; never clobber')
    if complete and set(names) != set(expected):
        raise ValueError('Release does not contain exactly the eight reviewed files')
    for row in assets:
        wanted = expected[row['name']]
        if (type(row.get('id')) is not int or row['id'] <= 0
                or row.get('state') != 'uploaded' or row.get('size') != wanted['bytes']):
            raise ValueError('Existing asset differs; refusing replacement: '+row['name'])
        target = work/'asset-checks'/phase/row['name']
        api.download('/releases/assets/'+str(row['id']), target)
        if pack.sha(target) != wanted['sha256']:
            raise ValueError('Existing asset bytes differ; refusing replacement: '+row['name'])
    return set(names)


def promote(api, pins, distribution, expected, work, publish=False):
    release, upload = release_state(api, pins)
    present = verify_assets(api, pins, expected, work, 'before')
    missing = sorted(set(expected)-present)
    if release.get('draft') is not True:
        if missing:
            raise ValueError('Published release is incomplete; refusing mutation')
        return {'status': 'already_published_verified', 'files': expected}
    if not publish:
        return {'status': 'validated_only', 'missing_assets': missing, 'files': expected}
    for name in missing:
        api.upload(upload+'?'+urllib.parse.urlencode({'name': name}), distribution/name)
    # Refresh metadata/tag and read every uploaded byte before publishing.
    release_state(api, pins)
    verify_assets(api, pins, expected, work, 'after', complete=True)
    published = api.json('PATCH', '/releases/'+str(pins.release), {'draft': False})
    if published.get('id') != pins.release or published.get('draft') is not False:
        raise ValueError('GitHub did not confirm publication')
    return {'status': 'published_verified', 'files': expected}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('repository', 'source', 'digest', 'lock-digest', 'tag'):
        parser.add_argument('--'+name, required=True)
    for name in ('run', 'artifact', 'size', 'release'):
        parser.add_argument('--'+name, required=True, type=int)
    parser.add_argument('--work', required=True, type=Path)
    parser.add_argument('--publish', action='store_true')
    pins = parser.parse_args()
    if pins.repository != 'zhipijun1996/gunman-rush' or not re.fullmatch('[0-9a-f]{40}', pins.source):
        raise ValueError('Exact repository/source required')
    if any(not re.fullmatch('[0-9a-f]{64}', value) for value in (pins.digest, pins.lock_digest)):
        raise ValueError('Exact artifact and reviewed lock hashes required')
    if pins.tag != 'toolchain-'+pack.RECIPE['id']:
        raise ValueError('Release tag differs from the fixed recipe')
    pins.base_url = 'https://github.com/'+pins.repository+'/releases/download/'+pins.tag+'/'
    if pins.work.exists():
        raise ValueError('Promotion work directory must be fresh; preserve previous failures')
    pins.work.mkdir(parents=True)
    report = {'status': 'failed', 'source': pins.source, 'run': pins.run, 'artifact': pins.artifact,
              'artifact_sha256': pins.digest, 'artifact_bytes': pins.size,
              'reviewed_lock_sha256': pins.lock_digest, 'recipe_sha256': pack.sha(pack.RECIPE_PATH),
              'publisher_commit': os.environ.get('GITHUB_SHA', 'local'),
              'release': pins.release, 'tag': pins.tag, 'publish_requested': pins.publish,
              'stage': 'run_and_artifact_metadata'}
    try:
        api = GitHub(pins.repository, os.environ['GITHUB_TOKEN'])
        run = api.json('GET', '/actions/runs/'+str(pins.run))
        artifact = api.json('GET', '/actions/artifacts/'+str(pins.artifact))
        verify_metadata(run, artifact, pins)
        report['stage'] = 'artifact_download'
        archive = pins.work/'artifact.zip'
        api.download('/actions/artifacts/'+str(pins.artifact)+'/zip', archive)
        report['stage'] = 'complete_distribution_validation'
        distribution, expected = verify_distribution(archive, pins.work, pins)
        report.update(stage='release_assets_and_publication', distribution_files=expected)
        report.update(promote(api, pins, distribution, expected, pins.work, pins.publish))
        report['stage'] = 'complete'
    except Exception as error:
        report['error'] = type(error).__name__+': '+str(error)
        raise
    finally:
        pack.write(pins.work/'promotion-report.json', report)


if __name__ == '__main__':
    main()
