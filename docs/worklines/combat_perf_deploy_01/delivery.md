# 本轮既有交付路径

以下为待执行步骤，不是成功收据。使用最终干净源F；`SOURCE_REF`是已推送且HEAD等于F的固定源分支／标签，不能运行中移动。完整流程既有 `environment.yml`，prepared工作流唯一必填input为 `prepared_ref`。不新增workflow，不重新导出替换已经验过的包。

```sh
# root填入最终值后执行；本记录不启动CI。
: "${F:?最终40位源码SHA}" "${SOURCE_REF:?固定源分支或标签}"
test "$(git rev-parse HEAD)" = "$F"
test -z "$(git status --porcelain)"
python3 tools/check_release_evidence.py --commit "$F"
gh workflow run environment.yml --repo zhipijun1996/gunman-rush --ref "$SOURCE_REF" -f deploy_playtest=false -f build_android=false
```

记录本次run ID/attempt/API head_sha，等待完整171、Windows、Web原jobs成功，再从同run选择唯一未过期 `gunman-rush-web-playtest`，保留原API JSON及原ZIP。不可仅凭artifact名字或浏览器coordinator的身份校验代替完整CI终态核验；失败／取消不能发布为通过。`deploy_playtest=false`跳过该workflow的Pages与verify_public。

```sh
: "${RUN_ID:?本次run}" "${ATTEMPT:?本次attempt}" "${RUN_API:?原run JSON路径}" "${ARTIFACT_API:?唯一artifact JSON路径}" "${WEB_ZIP:?实际下载ZIP路径}"
python3 tools/verify_ci_artifact_browser.py --run-api "$RUN_API" --artifact-api "$ARTIFACT_API" --artifact-zip "$WEB_ZIP" --commit "$F" --run-id "$RUN_ID" --attempt "$ATTEMPT" --output "$PWD/build/combat-perf-deploy-ci-browser"
```

此默认入口使用F树自身工具，保clean/实际源/ZIP/PCK前后守门及三项原300秒。只有明确分离工具版本时才使用现有双根三参数并满足其有限差异校验，不能跳过game source校验。保存实际PCK的空目录原探针结果，禁止仓库资源回退。以上通过后，将同一包准备为只含已验Web及原chunks的干净prepared提交P；如省去大PCK传输，必须用原重建器还原并与原ZIP的完整SHA/长度核一致。

```sh
: "${PREPARED_DIR:?已准备的同包目录}" "${PREPARED_SHA:?已推送的精确prepared提交}"
python3 tools/style_exploration_delivery.py reconstruct-pack --bundle "$PREPARED_DIR"
gh workflow run deploy-prepared-playtest.yml --repo zhipijun1996/gunman-rush --ref "$SOURCE_REF" -f prepared_ref="$PREPARED_SHA"
```

prepared流程的helper来自所选workflow提交、Web来自P，须分别记录。该流程严格重建完整PCK，但不自行证明之前CI通过或其source等于F；发布前必须以既有API验包收据、prepared文件清单与F绑定。Pages部署通过后：

```sh
: "${PUBLIC_URL:?实际部署URL}" "${BUILD_ID:?该包build ID}"
python3 tools/verify_published_build.py --url "$PUBLIC_URL" --build-id "$BUILD_ID" --commit "$F"
```

还须流式核公开完整PCK的64位SHA等于原ZIP记录（原公开工具比的是完整读取后的12位build ID）、HTTP与长度，并做真实Title／目标入口基本GUI。报告具体URL／F／build／run，手机帧率和玩家认可另列。部署不表示合main。

已批准非editor模板存在于 `/workspace/toolchains/user-data/godot-4.7.2-gunman-sd1/godot/export_templates/4.7.2.stable/linux_release.x86_64`，89583008字节／SHA `6a280c82dfaf94efc1a7e268c69cb536ecb841d303478068333df14ffb192493`，与当前工具链锁一致；仅用于root随后真实release路径验证，未执行不记通过。
