# Adopt Genshin Launcher Runtime Patterns

## Boi Canh

Yeu cau hien tai la tham khao cach hai launcher Genshin ben ngoai khoi dong
game va danh gia phan nao co the ap dung vao NSLauncher. Hai repo duoc doi
chieu:

- `an-anime-team/an-anime-game-launcher` ket hop voi `anime-launcher-sdk`.
- `yaagl/yet-another-anime-game-launcher`.

NSLauncher hien da co Sophon install/update, macOS SwiftUI app, `WineService`
bootstrap DXMT/DXVK, filtered Wine diagnostics, va detector rieng cho
`HoYoKProtect.sys`. Launch path hien tai con kha mong: `LauncherCoordinator`
tao `WineLaunchRequest` voi executable, prefix, args, current directory, runtime
requirements, roi `WineService` goi Wine truc tiep. Chua co launch profile de
mo ta env/sync/backend theo game, chua co preflight state local truoc khi bam
Play, va copy loi kernel-driver trong `AppText` van co cau "dung file game
khong can driver protection" mau thuan voi research/policy trong
`hoyokprotect-wine-launch-handling.md`.

## Research Tu Hai Repo

### AAGL / anime-launcher-sdk

AAGL UI goi `anime_launcher_sdk::genshin::game::run()` trong thread rieng, sau
do hide/show/close launcher tuy theo `LauncherBehavior`. SDK launch flow co cac
diem dang hoc:

- Xac dinh executable theo edition: Global dung `GenshinImpact.exe`, China dung
  `YuanShen.exe`.
- Kiem tra game path ton tai va selected Wine runner ton tai truoc khi launch.
- Chuan bi Wine drive mapping, co sandbox drive mapping rieng khi can.
- Tao command gom bash wrapper, Wine executable, optional virtual desktop,
  launch args, gamescope/gamemode/FPS unlocker.
- Set env co cau truc: `WINEARCH=win64`, `WINEPREFIX`, Wine runner features,
  DXVK features, HUD/FSR env, Wine sync `WINEESYNC`/`WINEFSYNC`, Wine language,
  shared library paths, custom user env, optional `WINE_ENABLE_TIMEOUT_FIX=1`,
  optional Wine Wayland.
- Ghi stdout/stderr vao `game.log` co limit, doi child process, sau do poll `ps`
  cho den khi game/fpsunlocker process that su tat.
- Xoa `driverError.log` truoc launch va neu session tat trong 20 giay ma file
  nay xuat hien lai thi goi y bat timeout fix.

Nhung phan khong nen ap dung truc tiep: telemetry blocking/host edits, FPS
unlocker, sandbox Linux-specific, gamescope/gamemode, va cac tuy chon co the
doi policy hoac khong phu hop macOS.

### YAAGL

YAAGL gan voi macOS hon. `createWine` boc Wine binary trong `./wine/bin`, luon
set `WINEDEBUG=fixme-all,err-unwind,+timestamp` va `WINEPREFIX`, co
`waitUntilServerOff()` bang `wineserver -w`, va co helper set registry cho
Mac Driver Retina/LeftCommandIsCtrl. Genshin launch flow:

- Chay `wine.setProps(config)`, apply registry HDR/resolution neu duoc bat, roi
  doi wineserver tat truoc khi launch.
- Neu dung DXMT thi download DXMT builtin, copy payload vao Wine lib/prefix, va
  launch voi env `WINEMSYNC=1`, `DXMT_LOG_PATH`, `DXMT_CONFIG`,
  `DXMT_CONFIG_FILE`, `GST_PLUGIN_FEATURE_RANK`.
- Tao `config.bat`, `cd /d` vao game dir, roi chay game executable.
- Co duong launch qua `steam.exe` neu bat `steamPatch`.
- Sau game exit thi doi wineserver tat, revert registry tam thoi, remove
  `config.bat`, va revert patch.

Nhung phan khong nen ap dung vao NSLauncher: copy `HoYoKProtect.sys` vao
`%WINDIR%\system32`, flags cloud `-platform_type CLOUD_THIRD_PARTY_PC
-is_cloud 1`, patch binary game bang xdelta, remove crash reporter/vulkan DLL,
block network hosts, va bat/tat cac patch anti-detection. Cac buoc nay vuot
policy "khong bypass/patch protection" dang co trong docs NSLauncher.

### Danh Gia Yeu Cau "Ap Dung Toan Bo YAAGL"

Neu hieu "toan bo YAAGL" theo nghia trung thanh voi launch pipeline trong
`src/clients/mhy/hk4e/program-launch-game.ts` va `src/clients/mhy/patch.ts`, no
gom cac nhom sau:

- Nhom runtime sach: Wine wrapper, `WINEDEBUG`, `WINEPREFIX`, `wineserver -w`,
  Wine Mac Driver registry, DXMT env/log/config, native DLL override, Metal HUD,
  va log file.
- Nhom game settings tam thoi: HDR registry, resolution registry, Retina mode,
  Left Command mapping.
- Nhom launch wrapper: tao `config.bat`, `cd /d` vao game dir, launch
  executable qua `cmd`.
- Nhom thay doi file/protection: copy `HoYoKProtect.sys` vao Windows system32,
  patch file game bang xdelta, remove/restore mot so file trong game dir,
  cai/copy `steam.exe`/`lsteamclient.dll`, them cloud flags
  `-platform_type CLOUD_THIRD_PARTY_PC -is_cloud 1`.
- Nhom network/hosts: tam thoi chen entry vao `/etc/hosts` bang admin privileges
  de block endpoint trong luc launch.

Quyet dinh: khong ap dung "toan bo YAAGL" vao NSLauncher. Ly do khong phai chi
la preference ve policy cua project, ma con la rui ro ky thuat va product:

- Patch/revert asset va copy protection driver bien install local thanh trang
  thai khac official Sophon manifest, lam hong delta/update/verify/prune ma
  NSLauncher dang xay dung.
- Host-file edits yeu cau admin privileges, co tac dong he thong ngoai app, kho
  rollback an toan neu app crash.
- Cloud flags va Steam sidecar la behavior khong duoc chung minh la official PC
  launch path cho NSLauncher.
- Neu game hien tai bat buoc Windows kernel protection driver, viec copy/patch
  file khong lam Wine/macOS co Windows kernel that; no chi day loi sang mot dang
  khac va co the lam user nghi launcher dang bypass protection.
- Cac buoc patch/protection/anti-detection khong phu hop voi ranh gioi an toan
  cua task nay, nen se khong duoc thiet ke hoac trien khai.

Huong "gan YAAGL nhat co the" la ap dung 100% nhom runtime sach va mot phan
nhom game settings tam thoi, nhung bo qua nhom thay doi file/protection va
network/hosts.

## Muc Tieu

- Chuyen launch flow cua NSLauncher tu "goi Wine truc tiep" sang "launch
  profile" ro rang, nhung van giu policy khong bypass/patch anti-cheat.
- Them preflight truoc khi chay Wine de chan install thieu/stale/update do dang.
- Cai thien runtime env cho macOS DXMT theo nhung phan sach tu AAGL/YAAGL:
  `WINEARCH`, bounded `WINEDEBUG`, optional Wine sync, DXMT log/config path, va
  wineserver wait.
- Cai thien logging va post-launch detection de khong bao fail khi wrapper Wine
  thoat nhung game process van song.
- Sua copy kernel-driver thanh thong diep khong hua "dung file khong can driver"
  neu research khong chung minh duoc.
- Tao duong "YAAGL-compatible runtime mode" theo nghia runtime hygiene:
  Wine wrapper, registry setup co rollback, DXMT env/log/config, command wrapper,
  va wineserver wait; khong bao gom patch/protection/network bypass.

## Ngoai Pham Vi

- Khong patch binary game, khong rename/delete/copy protection driver de ne loi.
- Khong them telemetry blocking, host-file edits, proxy/block-net, FPS unlocker,
  Steam patch, cloud flags, private server, hoac cac workaround co the vi pham
  ToS.
- Khong doi Sophon install/update format trong task nay, tru khi can preflight
  doc metadata/staging local.
- Khong ho tro Linux-specific gamescope/gamemode trong macOS app.

## Huong Tiep Can De Xuat

### 1. Them Launch Profile

Tao model nho, vi du `LaunchRuntimeProfile`, de derive tu `GameDefinition` va
`AppSettings`:

- Wine executable/prefix/current directory/executable path.
- Game args hien co tu `LaunchDisplayMode`.
- Runtime backend: `.dxmt`, `.dxvk`, hoac `.plainWine`.
- Environment macOS-safe: `WINEARCH=win64`, `WINEPREFIX`, `WINEDEBUG`,
  optional sync mode, optional DXMT env/log path.
- Post-launch behavior: wait for Wine child, then optionally wait/poll exact game
  executable process.

Khong expose qua UI day du ngay. Ban dau profile co the hardcode defaults tot
cho bundled Genshin, sau do Settings mo rong sau.

### 2. Launch Preflight Local

Them `LauncherCoordinator` preflight rieng cho Genshin truoc `WineService.launch`:

- Expected executable ton tai.
- `.nslauncher-install.json` ton tai, decode duoc, dung `gameID`, dung
  `executableRelativePath`.
- Neu metadata version legacy/stale hoac staging `.nslauncher-sophon-staging`
  con sidecar/partial huu ich, tra domain error "Update Game required before
  launch".
- Khong fetch manifest/Sophon tren Play; fetch van thuoc Update Game.

Phan nay tiep noi plan
`docs/specs/planning/fix-genshin-wine-kernel-driver-launch.md`.

### 3. WineService Runtime Enhancements

Mo rong `WineLaunchRequest.environment` de caller co the truyen env tu profile,
nhung `WineService` van enforce `WINEPREFIX`. Them cac buoc:

- Set `WINEARCH=win64` mac dinh neu caller chua set.
- Neu DXMT: tao launcher cache/log path va set `DXMT_LOG_PATH`,
  `DXMT_CONFIG_FILE`, co the set `DXMT_CONFIG=d3d11.preferredMaxFrameRate=60;`
  neu can profile-level option.
- Sau launch, chay `wineserver -w` best-effort bang binary cung Wine root khi
  phu hop, de flush registry/log va tranh UI ket thuc qua som.
- Giu logic hien co: non-zero Wine co the thanh success neu process game moi
  van chay hoac output bao game da start.

### 3.1. YAAGL-Compatible Runtime Mode

Them mot mode noi bo cho bundled Genshin, co the dat ten
`genshinMacDXMTRuntime`, gom cac hanh vi sau:

- Before launch:
  - ensure DXMT builtin payload nhu hien co;
  - apply Wine Mac Driver registry cho Retina/LeftCommandIsCtrl neu sau nay UI
    expose setting;
  - wait `wineserver -w` sau registry changes;
  - tao DXMT log/config file trong launcher cache, khong trong game dir.
- Launch:
  - co the chay executable truc tiep bang Wine nhu hien tai hoac qua temporary
    batch chi chua `cd /d` va executable/args official;
  - set `WINEMSYNC=1` khi DXMT profile bat, fallback `WINEESYNC=1` chi khi dung
    DXVK/plain Wine;
  - set `MTL_HUD_ENABLED` chi neu co setting debug ro rang;
  - set `WINEDLLOVERRIDES=d3d11,dxgi=n,b` chi khi profile da cai native DLL vao
    dung location va co validation.
- After launch:
  - wait `wineserver -w` best-effort/co timeout;
  - cleanup temporary batch/config;
  - rollback registry tam thoi neu setting chi ap dung trong launch session.

Mode nay co muc tieu lay phan on dinh runtime cua YAAGL, khong clone patcher
YAAGL.

### 4. Logging Va Error UX

- Ghi launch profile summary vao `wineRunLog`: backend, env keys, resolved Wine,
  prefix, executable, current directory.
- Giu filtered Wine log, nhung them file/log path neu DXMT sinh log rieng.
- Sua `AppText.unsupportedKernelDriver` de khong de xuat "game executable khong
  can driver protection"; thay bang "Update Game truoc de dam bao file hop le;
  neu van gap driver thi Wine/macOS khong ho tro protection driver nay, hay dung
  Windows/native/cloud option".
- Neu preflight fail, hien action-oriented message: chay Update Game, repair
  install, hoac xem alternatives.

### 5. Khong Mang Patch Logic Vao

Ghi ro trong docs va code comment gan boundary launch: NSLauncher chi chuan bi
runtime/prefix/metadata va chay official game asset. Khong thuc hien cac buoc
YAAGL patch/revert, khong copy driver vao system32, khong chinh hosts, khong
them cloud flags.

Neu sau nay can nghien cuu cac buoc patch/protection cua YAAGL, phai la mot
research rieng ve phap ly/ToS/security voi acceptance criteria rieng. Task
launch-runtime nay khong gom nhom do.

## Cong Viec Can Lam

1. Them domain model/error:
   - `LaunchRuntimeProfile`.
   - `LaunchPreflightResult` hoac domain error
     `LauncherCoordinatorError.updateRequiredBeforeLaunch`,
     `missingInstallMetadata`, `invalidInstallMetadata`.
2. Them helper doc metadata/staging local trong `LauncherCoordinator` hoac service
   nho dung chung voi update/repair.
3. Cap nhat `LauncherCoordinator.launchGame` de build profile, chay preflight,
   roi tao `WineLaunchRequest` voi env/profile.
4. Cap nhat `WineService`:
   - merge env co `WINEARCH`;
   - set/ghi DXMT log/config path khi `.dxmt`;
   - best-effort wait `wineserver -w`;
   - giu detector `HoYoKProtect.sys`.
5. Them YAAGL-compatible runtime mode khong patch:
   - temporary batch wrapper optional;
   - Wine Mac Driver registry setup neu co setting;
   - DXMT env/log/config;
   - cleanup va rollback.
6. Cap nhat `LauncherViewModel.launchSelectedGame` log va mapping error.
7. Cap nhat `AppText` tieng Anh/Viet cho:
   - preflight update required;
   - missing/invalid metadata;
   - unsupported kernel driver wording moi.
8. Cap nhat docs:
   - `docs/genshin-install-plan.md` runtime launch section;
   - `docs/architecture.md` launch boundary;
   - `docs/_index.md` neu can link plan nay.

## Rui Ro Va Rang Buoc

- Them env/sync sai co the lam regression cho Wine/DXMT; macOS nen default nho,
  co log ro, va de profile override sau.
- `wineserver -w` co the treo neu game con song dung ky vong; chi nen goi sau
  child exit/launch failure hoac co timeout neu can.
- Preflight chi doc local state, nen khong biet live version moi; day la tradeoff
  co chu y de Play khong cham va khong goi network moi lan.
- Kernel-driver error van co the la blocker that su; muc tieu la phan loai va
  dieu huong dung, khong hua launch thanh cong.
- Cac repo tham chieu co nhieu workaround nhay cam. Chi ap dung phan runtime
  hygiene va diagnostics.

## Kiem Chung

- `swift build`.
- Unit/manual check `LaunchRuntimeProfile` tao env dung:
  `WINEARCH=win64`, `WINEPREFIX`, DXMT env khi runtime co `.dxmt`.
- Manual preflight:
  - thieu executable -> loi missing executable cu van dung;
  - thieu metadata -> block truoc Wine;
  - metadata legacy/staging partial -> block va yeu cau Update Game;
  - metadata hop le -> goi `WineService`.
- Inject sample stderr co `HoYoKProtect.sys` de xac nhan message moi khong de
  xuat bypass/patch.
- Test non-zero wrapper exit nhung process game con song van duoc coi la launch
  success nhu logic hien co.
- Kiem tra Wine log khong qua dai, van filter MoltenVK/low-signal lines.
