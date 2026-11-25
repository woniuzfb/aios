# AIOS (All In One Script)

纯 Bash（兼容 Bash 3.2+）+ `jq` 驱动的多服务运维与媒体流管理面板，支持 Linux 与 macOS，内置多语言国际化（`zh_CN` / `en` 等），通过模块化源码静态打包为单文件 `aios.sh`，运行时按命令软链自动分发至各管理模块。

<details>
<summary><strong>目录</strong></summary>

- [快速开始](#快速开始)
- [命令入口一览](#命令入口一览)
- [Xray](#xray)
- [V2Ray](#v2ray)
- [Nginx / OpenResty](#nginx--openresty)
- [FFmpeg / IPTV](#ffmpeg--iptv)
  - [自动解析直播源](#自动解析直播源)
  - [快捷键](#快捷键)
  - [参数详解](#参数详解)
  - [举例](#举例)
- [Armbian / Proxmox VE](#armbian--proxmox-ve)
- [Docker / HAProxy / Rclone / OpenList / Calibre / LianHuanHua](#docker--haproxy--rclone--openlist--calibre--lianhuanhua)
- [已失效 / 归档模块](#已失效--归档模块)
- [测试与开发](#测试与开发)

</details>

## 快速开始

一键下载运行（首次运行按指引安装软链，之后直接输入对应短命令）：

```bash
wget https://woniuzfb.github.io/aios/aios.sh && bash aios.sh
```

## 命令入口一览

| 命令  | 模块          | 说明                                                                 |
| :---- | :------------ | :------------------------------------------------------------------- |
| `tv`  | FFmpeg / IPTV | HLS / FLV 推流、多码率转码、监控、防盗链、计划任务、节目表、VIP      |
| `x`   | Xray          | Xray-core 多版本隔离管理、出入站/路由/DNS/策略/统计/预设/URI 导入    |
| `v2`  | V2Ray         | V2Ray 5.x（`jsonv4`/`jsonv5`）多版本隔离管理、出入站/路由/统计/导入  |
| `nx`  | Nginx         | 编译/包安装、crossplane 五级配置管理、SNI/SSL/ALPN 分流              |
| `or`  | OpenResty     | 编译/包安装、Nginx + Lua 扩展配置管理                                |
| `cx`  | Xtream Codes  | Xtream Codes / Stalker 账号与频道管理                                |
| `dr`  | Docker        | Docker / Compose 与常用服务编排                                      |
| `ha`  | HAProxy       | 动/静态链接 PCRE / zlib / Lua / OpenSSL / QuicTLS 编译与管理         |
| `rc`  | Rclone        | Remote / Mount / Serve / Sync 管理                                   |
| `ali` | OpenList      | OpenList 服务与账号管理                                              |
| `cw`  | Calibre       | Calibre-Web 与 KCC 电子书转换                                        |
| `lhh` | LianHuanHua   | 连环画资源抓取与整理                                                 |
| `arm` | Armbian       | 旁路由 OpenWrt、透明代理、DNSCrypt、Docker、NAT 检测                 |
| `pve` | Proxmox VE    | NBFC、DNSCrypt、OpenWrt 透明代理与源管理                             |
| `cf`  | Cloudflare    | 多账号 CFP / Workers 管理与自动切换监控（已失效，仅归档）            |
| `ibm` | IBM CF        | IBM Cloud Foundry 应用管理（已失效，仅归档）                         |

---

## Xray

```bash
wget https://woniuzfb.github.io/aios/x.sh && bash x.sh
```

输入 `x` 打开 Xray 管理面板（支持 Xray-core **`25.9.11` – `26.11.9`**）：

- **完全命名空间隔离与多版本管理**：配置、多版本内核槽位、共享 GeoData（`Loyalsoldier/v2ray-rules-dat`）、备份、日志与事务状态统一收敛在 `$AIOS_ROOT/proxy`，对外仅暴露固定软链 `aios-xray` 与独立服务 `aios-xray.service`（不触碰宿主机公共 `xray`）；支持在线安装/本地导入多版本、原子切换与失败自动回滚（含 `last-known-good` 槽位保护）。
- **Feature 级版本感知与事务写盘**：自动按当前内核版本适配 `flatOutbounds`、`inboundUsersKey`、`dnsRewriteKeys`、`streamMethodKey`、`freedom.finalRules`、`ssUot` 升级拦截与公网明文 VLESS/Trojan 拦截；所有配置修改均走统一事务（排他锁 → 同身份 `-test` 校验 → 动态 Capabilities 与 `/dev/net/tun` 预检 → 原子写盘 → 就绪检查与失败回滚）。
- **全协议与高级能力**：完整支持 VLESS（含内联 `reverse`）/ VMess / Trojan / Shadowsocks（含 2022 多用户）/ Hysteria / WireGuard / TUN / MASQUE 入站与出站，支持 `raw` / `ws` / `grpc` / `xhttp` / `httpupgrade` / `kcp` / `finalmask` 及 TLS / REALITY（自动派生 `pbk`/`pqv`、多用户按账号选打二维码，绝不泄露服务端私钥）。
- **运维与便捷工具**：内置路由、DNS、Policy、顶层高级配置（`log`/`api`/`metrics`/`observatory`/`burstObservatory`/`version`/`env`）、API 流量统计/重置、Nginx/ACME 证书联动、一键预设模板（动态生成 X25519 密钥对）及多协议 URI 批量导入（含脱敏 Diff 预览）。

---

## V2Ray

```bash
wget https://woniuzfb.github.io/aios/v2.sh && bash v2.sh
```

输入 `v2` 打开 V2Ray 管理面板（支持 V2Ray 5.x **`5.18.0` – `5.56.0`**，不再支持 V2Ray 4.x 与 `v2ctl`）：

- **完全隔离与双配置格式**：使用独立 `aios-v2ray` 与 `aios-v2ray.service`，隔离 `XDG_DATA_HOME`/`XDG_DATA_DIRS` 防止宿主机 GeoData 劫持；原生支持 **`jsonv4`（`-format json`）与 `jsonv5`（`-format jsonv5`）**双格式生成与一键事务切换（自动回滚与崩溃恢复）。
- **全协议与 v5 能力**：支持 VMess / VLESS / Trojan / Shadowsocks / Shadowsocks 2022（`jsonv5`）/ Hysteria2（`hy2Settings` 与 `transportSettings` 分离生成）/ Loopback、传输层 `packetEncoding` / `bindToDevice` / `mptcp`、`services.tun` / `services.burstObservatory` / `browserForwarder`。
- **统计、证书与导入**：统一使用 `aios-v2ray api stats`（支持单用户与全量流量查询）与 `aios-v2ray tls cert`，支持 Nginx/ACME 证书权限联动、一键预设模板与多协议 URI 批量导入。

---

## Nginx / OpenResty

```bash
# Nginx
wget https://woniuzfb.github.io/aios/nx.sh && bash nx.sh

# OpenResty
wget https://woniuzfb.github.io/aios/or.sh && bash or.sh
```

<details>
<summary>功能说明</summary>

- `nx` 打开 Nginx 管理面板，`or` 打开 OpenResty 管理面板。
- 基于官方 `crossplane` 解析配置，支持修改最多五级指令。
- 支持 SNI / SSL / ALPN 分流、HTTP-FLV 模块及 OpenSSL 3 / QuicTLS 编译。
- 集成 Node.js、MongoDB、Postfix、mmproxy、DNSCrypt-Proxy、iperf3 等组件管理。

</details>

---

## FFmpeg / IPTV

```bash
wget https://woniuzfb.github.io/aios/aios.sh && bash aios.sh
```

<details>
<summary>展开查看 IPTV 管理面板、快捷键、参数详解与示例</summary>

输入 `tv` 打开 IPTV 管理面板（`tv f` 打开 FLV 面板）：

- **多版本 FFmpeg 与运行时能力自适应**：
  - 支持 FFmpeg 6.x / 7.x / 8.x / 9.x（macOS 自动扫描/切换 Homebrew `ffmpeg-full`、`ffmpeg`、`ffmpeg@8`/`@7`/`@6`；Linux 支持 BtbN 静态包、John Van Sickle 与包管理器）。
  - 运行时自动探测二进制能力并透明适配参数（FFmpeg 5.1+ 自动使用 `-fps_mode passthrough`、FFmpeg 9 自动屏蔽 `-qphist` 并转换 `-/filter_complex`、FFmpeg 6.1+ 原生支持 Enhanced FLV HEVC、启动水印前预检 `drawtext` 滤镜）。
- **配置隔离与平滑升级**：全局默认配置独立存放于 `$IPTV_ROOT/config.json`（`$IPTV_CONFIG`），频道列表存放于 `$IPTV_ROOT/channels.json`，旧版（含 `1.87.x`）自动原子迁移。
- 支持计划任务（定时启停）、后台监控守护进程、防盗链与 Anti-DDoS 防护、多数据源节目表及 VIP 分发。

### 自动解析直播源

- `cx`：打开 Xtream Codes 账号/频道管理面板
- `tv 4g`：打开 4gtv 频道管理面板
- `tv d`：添加演示频道
- 支持自动解析：TVB、Fengshows、Lotus Macau、YouTube、Twitch、HBO Asia、4gtv 等

### 快捷键

完整快捷键见 `tv -h`：

- `tv c <en|zh_CN|...>`：切换界面语言
- `tv color`：自定义文字与背景颜色
- `tv s`：节目表抓取与定时任务管理
- `tv m`：监控管理面板

### 参数详解

用法：`tv -i [直播源] [-s 分片时长(秒)] [-o 输出目录名称] [-c m3u8包含的分片数目] [-b 码率] [-r 分辨率] [-p m3u8文件名称] [-C] [-R] [-l] [-P http代理]`

```bash
-i  直播源（支持 mpegts / hls / flv / youtube ...），可为本地路径或空格分隔的多条备源
-s  分片时长（秒，默认：6）
-o  输出目录名称（默认：随机名称）

-l  非无限时长点播源，不设切割分片数且不纳入直播监控（默认：关闭）
-P  FFmpeg HTTP 代理，仅输入源为 http(s) 链接时生效

-p  m3u8 名称前缀（默认：随机）
-c  m3u8 包含的分片数目（默认：5）
-S  分片子目录名称（默认：不使用子目录）
-t  分片文件名前缀（默认：同 m3u8 名称）
-a  音频编码（默认：aac；不转码填 copy）
-v  视频编码（默认：libx264；不转码填 copy）
-f  音画延迟校准（如 v_3 画面延迟 3 秒，a_2 声音延迟 2 秒）
-q  CRF 固定质量因子，多档用逗号分隔（与码率同时设置时启用 capped CRF）
    x264/x265 范围 [0,51]（默认 23/28），VP9 范围 [0,63]（建议 15-35）
-b  输出视频码率（k），多档用逗号分隔（如 800,1000,1500；默认 900；填 omit 省略）
-r  输出视频分辨率，多档用逗号分隔（如 960x540,1280x720；默认 1280x720）
-C  限制性编码 VBV（需设置码率，默认：否）
-R  固定码率 CBR（需同时设置 -C，默认：否）
-e  AES 加密分片（默认：不加密）
-K  Key 名称（默认：随机）
-z  频道名称（默认：同 m3u8 名称）

# FLV 推流模式
-k  设置输出类型，如 -k flv
-H  开启 FLV H.265（HEVC）推流（FFmpeg 6.1+ 原生 Enhanced FLV）
-T  推流地址，如 rtmp://127.0.0.1/flv/xxx
-L  拉流（播放）地址（可省略），如 http://domain.com/flv?app=flv&stream=xxx

-m  FFmpeg 额外输入参数（非 HTTP 协议会自动剥离 -reconnect* 等 HTTP 专用项）
    默认：-copy_unknown -reconnect 1 -reconnect_at_eof 1 -reconnect_streamed 1 -reconnect_delay_max 2000 -rw_timeout 10000000 -y -nostats -nostdin -hide_banner -loglevel fatal
-n  FFmpeg 额外输出参数（不转码时请填 omit）
    默认：-g 60 -sc_threshold 0 -sn -preset superfast -pix_fmt yuv420p -profile:v main
```

### 举例

- 使用 CRF 固定质量因子控制视频质量：
  ```bash
  tv -i http://xxx/xxx.ts -s 6 -o hbo1 -p hbo1 -q 15 -b 1500 -r 1280x720 -z 'hbo直播1'
  ```
- 使用码率控制视频质量（默认）：
  ```bash
  tv -i http://xxx/xxx.ts -s 6 -o hbo2 -p hbo2 -b 900 -r 1280x720 -z 'hbo直播2'
  ```
- 不转码直接封装：追加 `-a copy -v copy -n omit`
- FLV 推流：
  ```bash
  tv -i http://xxx/xxx.ts -a aac -v libx264 -b 3000 -k flv -T rtmp://127.0.0.1/flv/xxx
  ```

</details>

---

## Armbian / Proxmox VE

```bash
# Armbian
wget https://woniuzfb.github.io/aios/arm.sh && bash arm.sh

# Proxmox VE
wget https://woniuzfb.github.io/aios/pve.sh && bash pve.sh
```

<details>
<summary>功能说明</summary>

- `arm`（Armbian）：Docker、DNSCrypt-Proxy、OpenWrt 旁路由、openwrt-v2ray、Xray/V2Ray 核心切换、一键透明代理（国内直连/国外代理）与配置保存切换、NAT 类型检测。
- `pve`（Proxmox VE）：软件源切换、NBFC 风扇控制、DNSCrypt-Proxy、OpenWrt 透明代理与核心切换。

</details>

---

## Docker / HAProxy / Rclone / OpenList / Calibre / LianHuanHua

本地开发调试或安装软链后可直接运行对应命令：

```bash
./debug dr    # Docker（traefik / authelia / postgresql / yq 等）
./debug ha    # HAProxy（支持 pcre / zlib / lua / openssl / quictls 动静态链接）
./debug rc    # Rclone（remote / mount / serve / sync）
./debug ali   # OpenList
./debug cw    # Calibre（calibre-web / kcc）
./debug lhh   # LianHuanHua
```

---

## 已失效 / 归档模块

<details>
<summary>展开查看已失效模块（Cloudflare Partner / Workers、IBM Cloud Foundry）</summary>

> 以下模块依赖的第三方服务已下线或失效，代码仅作历史归档保留。

### Cloudflare Partner / Workers

```bash
wget https://woniuzfb.github.io/aios/cf.sh && bash cf.sh
```

- `cf` 打开 Cloudflare Partner / Workers 管理面板，`cf w` 直达 Workers 管理。
- 支持多 CFP 账号管理、Workers 请求量监控（超阈值自动跨账号迁移 Worker 与 CNAME）以及 IBM CF 中转配置。

### IBM Cloud Foundry

```bash
wget https://woniuzfb.github.io/aios/ibm.sh && bash ibm.sh
```

- `ibm`：IBM CF 管理面板；`ibm v2`：V2Ray App 管理；`ibm x`：Xray App 管理。

</details>

---

## 测试与开发

```bash
# 本地动态调试指定模块
./debug [tv|v2|x|nx|or|cf|rc|dr|ha|...] [args]

# 静态打包生成单文件 aios.sh（或同时安装软链）
./make [install]

# 拉取锁定版本的多版本 Xray/V2Ray 测试内核与 GeoData（支持 SHA256 校验）
bash scripts/fetch_test_cores.sh

# 运行非交互式全量自动化测试（9 大套件：core / nginx / xray / v2ray / matrix / types / iptv / core_matrix / e2e）
bash test/run

# 严格核心矩阵模式（缺失任一测试内核或 GeoData 直接失败，CI 同款门禁）
AIOS_REQUIRE_CORE_MATRIX=1 bash test/run

# 查看指定套件的真实渲染与 JSON 输出
bash test/run --show-output [all|core|nginx|xray|v2ray|matrix|types|iptv|core_matrix|e2e]

# 多语言模板同步与校验（要求 zh_CN.pot 与 aios.sh.pot 严格 1:1 一致）
./i18n/make-pot.sh zh_CN en
./i18n/make-pot.sh b

# 交互式开发调试入口
./debug tt
```
