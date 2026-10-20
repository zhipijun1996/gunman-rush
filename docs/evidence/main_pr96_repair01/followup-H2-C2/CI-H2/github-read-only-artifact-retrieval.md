Use actual main commit M and repository zhipijun1996/gunman-rush. These are read-only callable tools; do not use expired GH_TOKEN.

1. Complete main-M push run collection (omit event=push when collecting every trigger/event, as done for all4 H2 runs; the dedicated fetch_commit_workflow_runs tool filters to pull_request):
   await tools.mcp__codex_apps__github_fetch({url: "https://api.github.com/repos/zhipijun1996/gunman-rush/actions/runs?head_sha=M&event=push&per_page=100"})
   JSON.parse(result.structuredContent.content) gives workflow_runs/total_count. Verify actual head_sha==M, event==push, run_attempt, status/conclusion. Paginate if total_count exceeds returned collection.
2. Actual full job timestamps and steps:
   await tools.mcp__codex_apps__github_fetch({url: "https://api.github.com/repos/zhipijun1996/gunman-rush/actions/runs/RUN_ID/jobs?per_page=100"})
   Alternative purpose-built: tools.mcp__codex_apps__github_fetch_workflow_run_jobs({repo_full_name:"zhipijun1996/gunman-rush",run_id:RUN_ID}); result.structuredContent.jobs omits some full API timestamp fields. Direct actions/jobs/JOB_ID was rejected by this generic connector; use the supported run/jobs route.
3. Artifact API original:
   await tools.mcp__codex_apps__github_fetch({url: "https://api.github.com/repos/zhipijun1996/gunman-rush/actions/runs/RUN_ID/artifacts?per_page=100"})
   JSON.parse(result.structuredContent.content).artifacts has id/name/digest/size_in_bytes/expired/workflow_run. Require correct run/head and select actual returned web name, not a guessed name. Purpose-built tools.mcp__codex_apps__github_fetch_workflow_run_artifacts({repo_full_name:"zhipijun1996/gunman-rush",run_id:RUN_ID}) returns .structuredContent.artifacts but only the first page.
4. Raw job log:
   await tools.mcp__codex_apps__github_fetch_workflow_job_logs({repo_full_name:"zhipijun1996/gunman-rush",job_id:JOB_ID})
   result.structuredContent.content is decoded UTF-8 log string. Save exact bytes, SHA256/CRC; live jobs can return404 BlobNotFound, which does not mean a test failed.
5. ZIP reusable reference:
   const result=await tools.mcp__codex_apps__github_download_workflow_artifact({repo_full_name:"zhipijun1996/gunman-rush",artifact_id:ARTIFACT_ID,file_name:"ACTUAL_WEB_ARTIFACT_NAME-M.zip"});
   const uri=result.structuredContent.file_uri;
   uri.download_url is a short-lived signed HTTP URL. uri.file_id/mime_type/file_name are metadata. Do not print the full result, URL or token, and do not persist signed URLs in evidence.

The original14MB H gameplay transport used this ZIP tool, returning a Sediment-hosted URL/reference (sdmnt...oaiusercontent.com), not base64. Because it was below32MiB, tools.download_file({file_id:SEDIMENT_FILE_ID}) returned a local attachments path, then bytes were copied unchanged to ignored evidence. Do not infer storage authority from a file_ prefix: FileService IDs must never be sent to the Sediment download_file tool.

For the approximately297MB web ZIP, download_file exceeds its32MiB limit. Instead use uri.download_url in an execution command to stream urllib.request.urlopen(url,timeout=60) into a fresh .part file in1MiB chunks while computing hashlib.sha256. Construct that command programmatically from the tool value; never text()/print the signed URL. Check downloaded byte count against API size_in_bytes and complete ZIP SHA256 against API digest sha256:...; only then rename to the final ZIP. Verify ZipFile.testzip() is None. Record metadata/elapsed/bytes/digests, not the URL. If the short-lived URL expires, repeat only the read-only ZIP-reference tool; do not rerun/cancel Actions. Do not claim these stream steps were executed by this guide.

Then provide the actual saved run API JSON, artifact API JSON and unmodified web ZIP to tools/verify_ci_artifact_browser.py using that original script CLI. Do not substitute the14MB gameplay ZIP, a locally rebuilt PCK or an older artifact. The old H actual web API name was gunman-rush-web-playtest (297589000bytes); choose the actual main API name even if an informal instruction calls it web-debug.

Small H2 mechanisms/provenance: ../all-workflow-runs-first.json, ../initial.json, ../api-metadata-before-final.json, ../PR-web-artifact-download-receipt.json, ../push-web-artifact-download-receipt.json. H2 selected final metadata will be separately bound at terminal; no H2 result signs future main M.
