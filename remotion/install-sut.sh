#!/bin/bash
# T3 成片基准 -- 单机执行部分
#
# T3 模板:4 段混合规格素材(不同分辨率/帧率/编码)-> 20 秒竖屏成片
#          片头 + 片尾 + 转场 + 水印 + 中文字幕 + BGM
# 输出规格:1080x1920 / 30fps / H.264 / AAC
#
# 支持 Ubuntu/Debian(apt)与 Amazon Linux(dnf),自动识别。
#
# !! 重要 !! x86_64 上必须用 Ubuntu/Debian,不能用 Amazon Linux 2023:
#    Remotion 的 x64 Rust 合成器要求 GLIBC_2.35,AL2023 只有 2.34。
#    arm64 的合成器只要求 GLIBC_2.25,所以 Graviton 上 AL2023 可用。
#    脚本在安装后会做预检,不满足时直接给出明确报错(否则表现为
#    难以定位的 "write EPIPE")。
#
# 自包含:素材由 Remotion 自己合成,不依赖任何外部下载。
# 结果写到 ~/t3-result.json。
#
#   bash run_t3_benchmark.sh                # 完整流程
#   bash run_t3_benchmark.sh --runs 5
#   bash run_t3_benchmark.sh --skip-setup   # 复用已建项目,只重跑基准
set -uo pipefail

PROJ="${PROJ:-$HOME/t3-bench}"
RUNS="${RUNS:-3}"
SKIP_SETUP=false
RESULT_JSON="${RESULT_JSON:-$HOME/t3-result.json}"
LOG="${LOG:-$HOME/t3-run.log}"

while [ $# -gt 0 ]; do
  case "$1" in
    --runs)       RUNS="$2"; shift 2;;
    --skip-setup) SKIP_SETUP=true; shift;;
    --proj)       PROJ="$2"; shift 2;;
    *) echo "unknown arg: $1" >&2; exit 2;;
  esac
done

: > "$LOG"
log(){ echo "[$(date +%H:%M:%S)] $*" | tee -a "$LOG"; }
die(){ log "FATAL: $*"; exit 1; }

[ -f /etc/os-release ] && . /etc/os-release
VCPU=$(nproc)
ARCH=$(uname -m)
GLIBC=$(ldd --version 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+$')
if command -v apt-get >/dev/null 2>&1; then PM=apt
elif command -v dnf >/dev/null 2>&1; then PM=dnf
else PM=unknown; fi
# 在最外层声明,避免 set -u 下在 dnf 分支里引用到未定义数组
APT_OPTS=(-y -qq -o DPkg::Lock::Timeout=600)

log "=== T3 成片基准 ==="
log "OS=${PRETTY_NAME:-?}  arch=$ARCH  vCPU=$VCPU  glibc=$GLIBC  pkg=$PM"

detect_env(){
  ZH_FONTS=$(fc-list :lang=zh 2>/dev/null | wc -l | tr -d ' ')
  REMOTION_VER=$(cd "$PROJ" 2>/dev/null \
    && node -e 'console.log(require("remotion/package.json").version)' 2>/dev/null || echo unknown)
}

# 预检:直接 exec 合成器二进制。失败多半是 glibc 太旧,
# 这里一次性说清楚,避免后面渲染时抛出语焉不详的 write EPIPE。
preflight_compositor(){
  local dir bin
  dir=$(ls -d "$PROJ"/node_modules/@remotion/compositor-* 2>/dev/null | head -1)
  [ -n "$dir" ] || die "找不到 @remotion/compositor-* 包"
  bin="$dir/remotion"
  [ -x "$bin" ] || die "合成器二进制不存在: $bin"
  log "    合成器: $(basename "$dir")"
  # 这个二进制从 stdin 读 JSON 指令,没有 --help。所以"退出码非 0"不等于
  # "跑不起来" —— 它会正常启动然后吐一个 JSON 解析错误,那说明一切正常。
  # 真正的失败是动态链接阶段就挂掉(glibc 版本不够),错误形态完全不同。
  local out; out=$("$bin" </dev/null 2>&1 | head -3 | tr '\n' ' ')
  case "$out" in
    *GLIBC*|*"cannot open shared object"*|*"cannot execute"*|*"Exec format error"*)
      log "    !! 合成器无法装载: $out"
      die "合成器无法装载(当前 glibc $GLIBC)。x86_64 的合成器要求 GLIBC_2.35,Amazon Linux 2023 只有 2.34 —— 请改用 Ubuntu 22.04/24.04。arm64 合成器只要求 2.25,不受影响。" ;;
  esac
  # 补一道静态检查:有未解析的依赖同样算失败
  if ldd "$bin" 2>&1 | grep -q 'not found'; then
    log "    !! 未解析的动态依赖:"; ldd "$bin" 2>&1 | grep 'not found' | sed 's/^/      /' | tee -a "$LOG"
    die "合成器存在未解析的动态依赖(glibc $GLIBC 过旧?)"
  fi
  log "    合成器可装载 ✓(glibc $GLIBC)"
}

if [ "$SKIP_SETUP" = false ]; then
# ---------------------------------------------------------------- 1. 系统依赖
# 共享库清单取自 Remotion 官方 Linux Dependencies 文档对应发行版小节:
# https://www.remotion.dev/docs/miscellaneous/linux-dependencies
# git 不在该清单内,但 create-video 缺 git 会硬失败。
log "--- [1/7] 系统依赖 ---"
if [ "$PM" = apt ]; then
  export DEBIAN_FRONTEND=noninteractive
  # Ubuntu 云镜像刚启动时,cloud-init / unattended-upgrades 会持有 dpkg 锁,
  # 直接 apt 会在几秒内失败("Could not get lock ... held by process N (python3)")。
  # 先等 cloud-init 收尾,再给 apt 一个锁等待超时,双重保险。
  log "    等待 cloud-init 结束"
  sudo cloud-init status --wait >>"$LOG" 2>&1 || true
  APT_OPTS=(-y -qq -o DPkg::Lock::Timeout=600)
  sudo apt-get update -qq -o DPkg::Lock::Timeout=600 >>"$LOG" 2>&1
  sudo apt-get "${APT_OPTS[@]}" install \
    git curl ca-certificates \
    libnss3 libdbus-1-3 libatk1.0-0t64 libasound2t64 libxrandr2 \
    libxkbcommon0 libxfixes3 libxcomposite1 libxdamage1 libgbm1 \
    libcups2t64 libcairo2 libpango-1.0-0 libatk-bridge2.0-0t64 \
    fontconfig >>"$LOG" 2>&1 \
  || sudo apt-get "${APT_OPTS[@]}" install \
    git curl ca-certificates \
    libnss3 libdbus-1-3 libatk1.0-0 libasound2 libxrandr2 \
    libxkbcommon0 libxfixes3 libxcomposite1 libxdamage1 libgbm1 \
    libcups2 libcairo2 libpango-1.0-0 libatk-bridge2.0-0 \
    fontconfig >>"$LOG" 2>&1 \
  || die "apt 依赖安装失败(见 $LOG)"
else
  sudo dnf install -y -q git tar \
    mesa-libgbm libX11 libXrandr libdrm libXdamage libXfixes libxkbcommon \
    dbus-libs libXcomposite alsa-lib nss dbus pango cups-libs \
    at-spi2-core atk at-spi2-atk fontconfig >>"$LOG" 2>&1 \
    || die "dnf 依赖安装失败"
fi
log "    ok"

# ------------------------------------------------------------------ 2. 字体
# 中文字幕是 DOM 文本,由 Chrome 渲染。缺 CJK 字体时渲染照常成功、退出码 0,
# 但字幕是豆腐块,而且渲染空白字形更快 -> 基准数字偏乐观。必须单独校验。
log "--- [2/7] 字体(含 CJK) ---"
if [ "$PM" = apt ]; then
  sudo apt-get "${APT_OPTS[@]}" install fonts-noto-cjk fonts-noto-color-emoji \
    fonts-dejavu fonts-liberation >>"$LOG" 2>&1 || log "    WARN: 字体安装有报错"
else
  # 注意 AL2023 包名与 Debian 词序不同:
  #   fonts-noto-cjk         -> google-noto-sans-cjk-ttc-fonts
  #   fonts-noto-color-emoji -> google-noto-emoji-color-fonts
  sudo dnf install -y -q dejavu-sans-fonts liberation-fonts \
    google-noto-sans-fonts google-noto-sans-cjk-ttc-fonts \
    google-noto-emoji-color-fonts >>"$LOG" 2>&1 || log "    WARN: 字体安装有报错"
fi
sudo fc-cache -f >>"$LOG" 2>&1 || true
log "    中文字体数: $(fc-list :lang=zh 2>/dev/null | wc -l | tr -d ' ')"

# ---------------------------------------------------------------- 3. Node.js
# 直接用官方二进制包,不走发行版仓库也不走 NodeSource:
#  - 两个架构同一来源同一版本,基准可比(发行版仓库的版本会随架构/时间漂移)
#  - 不依赖第三方 apt 仓库(NodeSource 的 arm64 Packages 拉取会偶发失败)
#  - 版本钉死,基准可复现
NODE_VER="${NODE_VER:-24.22.0}"
log "--- [3/7] Node.js v$NODE_VER(官方二进制包) ---"
if ! command -v node >/dev/null 2>&1 || [ "$(node -v 2>/dev/null)" != "v$NODE_VER" ]; then
  case "$ARCH" in
    x86_64)  NARCH=x64;;
    aarch64) NARCH=arm64;;
    *) die "不支持的架构: $ARCH";;
  esac
  URL="https://nodejs.org/dist/v$NODE_VER/node-v$NODE_VER-linux-$NARCH.tar.xz"
  log "    下载 $URL"
  curl -fsSL "$URL" -o /tmp/node.tar.xz >>"$LOG" 2>&1 || die "下载 Node 失败: $URL"
  sudo tar -xJf /tmp/node.tar.xz -C /usr/local --strip-components=1 \
       --exclude='*/README.md' --exclude='*/LICENSE' --exclude='*/CHANGELOG.md' \
       >>"$LOG" 2>&1 || die "解包 Node 失败"
  hash -r
fi
command -v node >/dev/null 2>&1 || die "node 不在 PATH 上"
log "    node $(node -v)  npm $(npm -v)"

# ------------------------------------------------------------- 4. 项目脚手架
log "--- [4/7] 脚手架 + @remotion/transitions ---"
if [ ! -f "$PROJ/package.json" ]; then
  mkdir -p "$(dirname "$PROJ")"
  ( cd "$(dirname "$PROJ")" \
    && npx --yes create-video@latest --yes --blank "$(basename "$PROJ")" ) \
    >>"$LOG" 2>&1 || die "create-video 失败(见 $LOG)"
fi
cd "$PROJ" || die "cd $PROJ 失败"
[ -d node_modules ] || npm i >>"$LOG" 2>&1 || die "npm i 失败"
node -e 'require.resolve("@remotion/transitions")' >/dev/null 2>&1 \
  || npm i --silent @remotion/transitions >>"$LOG" 2>&1 \
  || die "安装 @remotion/transitions 失败"
log "    remotion $(node -e 'console.log(require("remotion/package.json").version)')"

# 关键预检:现在就确认合成器能跑,而不是等到渲染时报 EPIPE
preflight_compositor

# --------------------------------------------------------------- 5. 写入源码
log "--- [5/7] 写入 T3 组合源码 ---"
mkdir -p src public

cat > src/SourceClip.tsx <<'TSX'
// 用于合成"拍摄素材"的组件。故意加入高频运动与渐变,
// 让解码与缩放有真实开销,避免测出一个不具代表性的轻负载。
import React from 'react';
import {AbsoluteFill, useCurrentFrame, useVideoConfig} from 'remotion';

export const SourceClip: React.FC<{label: string; hue: number}> = ({label, hue}) => {
  const frame = useCurrentFrame();
  const {width, height, fps, durationInFrames} = useVideoConfig();
  const t = frame / fps;
  const bars = Array.from({length: 18});
  return (
    <AbsoluteFill style={{backgroundColor: `hsl(${(hue + frame * 1.5) % 360}, 65%, 18%)`}}>
      {bars.map((_, i) => {
        const p = (i / bars.length + t * 0.25) % 1;
        return (
          <div key={i} style={{
            position: 'absolute', left: p * width - width * 0.1, top: 0,
            width: width * 0.06, height,
            background: `hsl(${(hue + i * 20 + frame * 2) % 360}, 80%, ${45 + 20 * Math.sin(t * 2 + i)}%)`,
            opacity: 0.55, transform: `skewX(${12 * Math.sin(t + i)}deg)`,
          }} />
        );
      })}
      <div style={{
        position: 'absolute',
        left: width / 2 - width * 0.14, top: height / 2 - width * 0.14,
        width: width * 0.28, height: width * 0.28,
        background: `hsl(${(hue + 180) % 360}, 90%, 60%)`,
        transform: `rotate(${frame * 3}deg) scale(${1 + 0.18 * Math.sin(t * 3)})`,
        borderRadius: width * 0.03,
      }} />
      <AbsoluteFill style={{justifyContent: 'center', alignItems: 'center'}}>
        <div style={{
          fontFamily: 'DejaVu Sans, Liberation Sans, sans-serif',
          fontSize: Math.round(Math.min(width, height) * 0.1),
          fontWeight: 800, color: '#fff',
          textShadow: '0 4px 24px rgba(0,0,0,.7)', letterSpacing: 2,
        }}>{label}</div>
        <div style={{
          fontFamily: 'DejaVu Sans, Liberation Sans, sans-serif',
          fontSize: Math.round(Math.min(width, height) * 0.045),
          color: 'rgba(255,255,255,.85)', marginTop: 12,
        }}>{width}x{height} @ {fps}fps · {durationInFrames}f</div>
      </AbsoluteFill>
    </AbsoluteFill>
  );
};
TSX

cat > src/T3Final.tsx <<'TSX'
// T3 成片:片头 -> 4 段混合规格素材(带转场)-> 片尾
//          叠加:水印(全程)、中文字幕(分段)、BGM(全程)
// 时长核算(@30fps):60 + 145*4 + 60 - 5*20 = 600 帧 = 20 秒
// TransitionSeries 总时长 = 各 Sequence 之和 - 各 Transition 之和
import React from 'react';
import {
  AbsoluteFill, Audio, OffthreadVideo, Sequence,
  staticFile, useCurrentFrame, useVideoConfig, interpolate,
} from 'remotion';
import {TransitionSeries, linearTiming, springTiming} from '@remotion/transitions';
import {fade} from '@remotion/transitions/fade';
import {slide} from '@remotion/transitions/slide';
import {wipe} from '@remotion/transitions/wipe';

const CJK = '"Noto Sans CJK SC","Noto Sans CJK JP","Noto Sans CJK",sans-serif';
const CLIP_LEN = 145;
const TRANS = 20;

const SOURCES = [
  'clip1.mp4',   // 1920x1080 @30 h264
  'clip2.mp4',   // 1280x720  @24 h265
  'clip3.webm',  // 1080x1920 @60 vp8
  'clip4.mp4',   // 640x480   @25 h264
];

const Intro: React.FC = () => {
  const frame = useCurrentFrame();
  const {width, height} = useVideoConfig();
  const s = interpolate(frame, [0, 24], [0.75, 1], {extrapolateRight: 'clamp'});
  const o = interpolate(frame, [0, 14], [0, 1], {extrapolateRight: 'clamp'});
  return (
    <AbsoluteFill style={{
      background: 'linear-gradient(145deg,#0f172a 0%,#1e3a8a 55%,#312e81 100%)',
      justifyContent: 'center', alignItems: 'center',
    }}>
      <div style={{transform: `scale(${s})`, opacity: o, textAlign: 'center'}}>
        <div style={{fontFamily: CJK, fontSize: Math.round(width * 0.12), fontWeight: 900, color: '#fff'}}>
          成片流水线
        </div>
        <div style={{
          fontFamily: CJK, fontSize: Math.round(width * 0.045),
          color: '#93c5fd', marginTop: height * 0.012, letterSpacing: 4,
        }}>T3 · 混合规格素材合成</div>
      </div>
    </AbsoluteFill>
  );
};

const Outro: React.FC = () => {
  const frame = useCurrentFrame();
  const {width} = useVideoConfig();
  const o = interpolate(frame, [0, 18], [0, 1], {extrapolateRight: 'clamp'});
  return (
    <AbsoluteFill style={{
      background: 'linear-gradient(200deg,#111827 0%,#4c1d95 100%)',
      justifyContent: 'center', alignItems: 'center',
    }}>
      <div style={{opacity: o, textAlign: 'center'}}>
        <div style={{fontFamily: CJK, fontSize: Math.round(width * 0.085), fontWeight: 800, color: '#fff'}}>
          感谢观看
        </div>
        <div style={{fontFamily: CJK, fontSize: Math.round(width * 0.038), color: '#c4b5fd', marginTop: 16}}>
          1080×1920 · 30fps · H.264 / AAC
        </div>
      </div>
    </AbsoluteFill>
  );
};

// 混合分辨率/宽高比由 CSS 统一成竖屏填充 —— 这层归一化在 Remotion 里是免费的,
// 不需要像 FFmpeg 那样为每路输入手写 scale/pad/setsar/fps/settb。
const Clip: React.FC<{src: string}> = ({src}) => (
  <AbsoluteFill style={{backgroundColor: '#000'}}>
    <OffthreadVideo
      src={staticFile(src)}
      style={{width: '100%', height: '100%', objectFit: 'cover'}}
      muted
    />
  </AbsoluteFill>
);

const Watermark: React.FC = () => {
  const {width, height} = useVideoConfig();
  const frame = useCurrentFrame();
  return (
    <AbsoluteFill style={{pointerEvents: 'none'}}>
      <div style={{
        position: 'absolute', right: width * 0.045, top: height * 0.035,
        padding: `${Math.round(height * 0.009)}px ${Math.round(width * 0.03)}px`,
        borderRadius: 999, background: 'rgba(0,0,0,.42)',
        border: '1px solid rgba(255,255,255,.32)',
        fontFamily: CJK, fontSize: Math.round(width * 0.032),
        color: 'rgba(255,255,255,.93)', letterSpacing: 1,
        opacity: 0.82 + 0.18 * Math.sin(frame / 18),
      }}>@ 基准测试</div>
    </AbsoluteFill>
  );
};

const SUBS: {from: number; dur: number; text: string}[] = [
  {from: 30,  dur: 70, text: '四段不同规格的素材'},
  {from: 110, dur: 80, text: '分辨率、帧率、编码各不相同'},
  {from: 200, dur: 80, text: '统一转码为竖屏 1080×1920'},
  {from: 290, dur: 80, text: '加入转场、水印与字幕'},
  {from: 380, dur: 80, text: '混入背景音乐并封装'},
  {from: 470, dur: 70, text: '输出 H.264 / AAC 成片'},
];

const Subtitles: React.FC = () => {
  const {width, height} = useVideoConfig();
  return (
    <>
      {SUBS.map((s, i) => (
        <Sequence key={i} from={s.from} durationInFrames={s.dur}>
          <AbsoluteFill style={{justifyContent: 'flex-end', alignItems: 'center', pointerEvents: 'none'}}>
            <div style={{
              marginBottom: height * 0.11, maxWidth: width * 0.86,
              padding: `${Math.round(height * 0.011)}px ${Math.round(width * 0.045)}px`,
              background: 'rgba(0,0,0,.6)', borderRadius: Math.round(width * 0.02),
              fontFamily: CJK, fontSize: Math.round(width * 0.052),
              fontWeight: 700, color: '#fff', textAlign: 'center',
              lineHeight: 1.35, textShadow: '0 2px 10px rgba(0,0,0,.85)',
            }}>{s.text}</div>
          </AbsoluteFill>
        </Sequence>
      ))}
    </>
  );
};

export const T3Final: React.FC = () => (
  <AbsoluteFill style={{backgroundColor: '#000'}}>
    <TransitionSeries>
      <TransitionSeries.Sequence durationInFrames={60}>
        <Intro />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        timing={linearTiming({durationInFrames: TRANS})} presentation={fade()} />
      <TransitionSeries.Sequence durationInFrames={CLIP_LEN}>
        <Clip src={SOURCES[0]} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        timing={linearTiming({durationInFrames: TRANS})} presentation={slide()} />
      <TransitionSeries.Sequence durationInFrames={CLIP_LEN}>
        <Clip src={SOURCES[1]} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        timing={linearTiming({durationInFrames: TRANS})} presentation={wipe()} />
      <TransitionSeries.Sequence durationInFrames={CLIP_LEN}>
        <Clip src={SOURCES[2]} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        timing={springTiming({config: {damping: 200}, durationInFrames: TRANS})}
        presentation={slide()} />
      <TransitionSeries.Sequence durationInFrames={CLIP_LEN}>
        <Clip src={SOURCES[3]} />
      </TransitionSeries.Sequence>
      <TransitionSeries.Transition
        timing={linearTiming({durationInFrames: TRANS})} presentation={fade()} />
      <TransitionSeries.Sequence durationInFrames={60}>
        <Outro />
      </TransitionSeries.Sequence>
    </TransitionSeries>
    <Watermark />
    <Subtitles />
    <Audio src={staticFile('bgm.wav')} volume={0.22} />
  </AbsoluteFill>
);
TSX

cat > src/Root.tsx <<'TSX'
import React from 'react';
import {Composition} from 'remotion';
import {SourceClip} from './SourceClip';
import {T3Final} from './T3Final';

// GenClip* 仅用于合成"混合规格素材",不参与基准计时。
// 不同的 width/height/fps 再配不同 codec 渲出,得到分辨率/帧率/编码
// 三个维度都不同的异构输入。
export const RemotionRoot: React.FC = () => (
  <>
    <Composition id="GenClip1" component={SourceClip}
      durationInFrames={150} fps={30} width={1920} height={1080}
      defaultProps={{label: 'CLIP 1', hue: 0}} />
    <Composition id="GenClip2" component={SourceClip}
      durationInFrames={120} fps={24} width={1280} height={720}
      defaultProps={{label: 'CLIP 2', hue: 95}} />
    <Composition id="GenClip3" component={SourceClip}
      durationInFrames={300} fps={60} width={1080} height={1920}
      defaultProps={{label: 'CLIP 3', hue: 185}} />
    <Composition id="GenClip4" component={SourceClip}
      durationInFrames={125} fps={25} width={640} height={480}
      defaultProps={{label: 'CLIP 4', hue: 275}} />

    {/* 被测目标:20 秒竖屏成片 */}
    <Composition id="T3Final" component={T3Final}
      durationInFrames={600} fps={30} width={1080} height={1920} />
  </>
);
TSX

cat > src/index.ts <<'TSX'
import {registerRoot} from 'remotion';
import {RemotionRoot} from './Root';
registerRoot(RemotionRoot);
TSX

# BGM:用 Node 直接生成 WAV,零依赖、确定性、免下载
cat > /tmp/gen_bgm.mjs <<'MJS'
import {writeFileSync} from 'node:fs';
const sr = 44100, secs = 21, ch = 2;
const n = sr * secs;
const data = Buffer.alloc(n * ch * 2);
const prog = [[220, 277.18, 329.63], [196, 246.94, 293.66],
              [174.61, 220, 261.63], [164.81, 207.65, 246.94]];
for (let i = 0; i < n; i++) {
  const t = i / sr;
  const chord = prog[Math.floor(t / 4) % prog.length];
  let v = 0;
  for (const f of chord) v += Math.sin(2 * Math.PI * f * t);
  v = (v / chord.length) * 0.28;
  v *= 0.55 + 0.45 * Math.sin(2 * Math.PI * 0.25 * t);
  const fade = Math.min(1, t / 1.5, Math.max(0, (secs - t) / 1.5));
  v *= fade;
  const q = (Math.max(-1, Math.min(1, v)) * 32767) | 0;
  data.writeInt16LE(q, (i * ch) * 2);
  data.writeInt16LE(q, (i * ch + 1) * 2);
}
const hdr = Buffer.alloc(44);
hdr.write('RIFF', 0); hdr.writeUInt32LE(36 + data.length, 4); hdr.write('WAVE', 8);
hdr.write('fmt ', 12); hdr.writeUInt32LE(16, 16); hdr.writeUInt16LE(1, 20);
hdr.writeUInt16LE(ch, 22); hdr.writeUInt32LE(sr, 24);
hdr.writeUInt32LE(sr * ch * 2, 28); hdr.writeUInt16LE(ch * 2, 32);
hdr.writeUInt16LE(16, 34);
hdr.write('data', 36); hdr.writeUInt32LE(data.length, 40);
writeFileSync(process.argv[2], Buffer.concat([hdr, data]));
MJS
node /tmp/gen_bgm.mjs public/bgm.wav || die "生成 BGM 失败"
log "    bgm.wav $(du -h public/bgm.wav | cut -f1)"

# ------------------------------------------------------- 6. 合成混合规格素材
log "--- [6/7] 合成 4 段混合规格素材(不计入基准计时) ---"
npx remotion browser ensure >>"$LOG" 2>&1 || die "browser ensure 失败"

GEN_PORT=${GEN_PORT:-3100}
gen(){ # comp outfile codec
  # 每次换端口并重试:实测偶发
  #   Error: Visited "http://localhost:3000/index.html" but got no response.
  # 即 bundler 本地服务未就绪/端口竞争。最重的那段(1080x1920@60fps vp8)
  # 命中概率最高。重试 3 次,每次换端口。
  local i
  for i in 1 2 3; do
    GEN_PORT=$((GEN_PORT + 1))
    log "    渲染 $1 -> $2 ($3) 第 $i 次, port=$GEN_PORT"
    if npx remotion render src/index.ts "$1" "public/$2" \
         --codec="$3" --log=error --concurrency="$VCPU" --port="$GEN_PORT" >>"$LOG" 2>&1; then
      [ -s "public/$2" ] && return 0
      log "      产物为空,重试"
    else
      log "      渲染失败,重试"
    fi
    rm -f "public/$2"; sleep 5
  done
  die "合成素材 $1 连续 3 次失败(见 $LOG)"
}
[ -f public/clip1.mp4 ]  || gen GenClip1 clip1.mp4  h264
[ -f public/clip2.mp4 ]  || gen GenClip2 clip2.mp4  h265
[ -f public/clip3.webm ] || gen GenClip3 clip3.webm vp8
[ -f public/clip4.mp4 ]  || gen GenClip4 clip4.mp4  h264

for f in clip1.mp4 clip2.mp4 clip3.webm clip4.mp4 bgm.wav; do
  [ -s "public/$f" ] || die "素材缺失: public/$f"
done
log "    素材就绪: $(cd public && du -ch clip*.* bgm.wav | tail -1 | cut -f1)"

else
  log "--skip-setup:跳过安装与素材合成"
  cd "$PROJ" || die "cd $PROJ 失败"
  preflight_compositor
fi

detect_env
log "环境:remotion=$REMOTION_VER  中文字体数=$ZH_FONTS"
[ "${ZH_FONTS:-0}" -gt 0 ] || die "没有中文字体,字幕会是豆腐块(静默失败),中止"

# --------------------------------------------------------------- 7. 正式基准
# 并发固定为 vCPU 数:四个被测机型都是 16 vCPU,保证横向可比。
log "--- [7/7] 基准:T3Final / runs=$RUNS / concurrency=$VCPU ---"
RAW="$HOME/t3-benchmark-raw.txt"
# 注意:这里不能加 --log=error。benchmark 的统计结果("Time (mean ± σ)")
# 走普通 verbosity,设成 error 会把它一起吞掉,raw 文件变成 0 字节。
npx remotion benchmark src/index.ts T3Final \
  --runs="$RUNS" --concurrencies="$VCPU" --codec=h264 \
  2>&1 | tee "$RAW" | grep -aE 'Benchmark #|Time \(mean|Range' | tee -a "$LOG"
RC=${PIPESTATUS[0]}

MEAN=$(grep -a 'Time (mean' "$RAW" | head -1 | awk '{gsub(/s$/,"",$5); print $5}')
SD=$(grep -a 'Time (mean' "$RAW"  | head -1 | awk '{gsub(/s$/,"",$7); print $7}')

# 产物自检:确认真的能出一条成片(防"渲染成功但内容为空")
log "--- 产物自检 ---"
mkdir -p out
if npx remotion render src/index.ts T3Final out/t3-verify.mp4 \
     --codec=h264 --log=error --concurrency="$VCPU" >>"$LOG" 2>&1; then
  OUTSZ=$(stat -c %s out/t3-verify.mp4 2>/dev/null || echo 0)
else
  OUTSZ=0
fi
log "    成片字节数: $OUTSZ"

if [ -z "$MEAN" ] || [ "$RC" -ne 0 ] || [ "$OUTSZ" -lt 100000 ]; then
  log "基准未取得有效数据 (rc=$RC, mean=${MEAN:-none}, bytes=$OUTSZ)"
  cat > "$RESULT_JSON" <<JSON
{"ok":false,"arch":"$ARCH","vcpu":$VCPU,"glibc":"$GLIBC","os":"${PRETTY_NAME:-unknown}","remotion":"${REMOTION_VER:-unknown}","rc":$RC,"output_bytes":$OUTSZ}
JSON
  exit 1
fi

THRU=$(awk -v m="$MEAN" 'BEGIN{printf "%.2f", 3600/m}')
cat > "$RESULT_JSON" <<JSON
{
  "ok": true,
  "arch": "$ARCH",
  "vcpu": $VCPU,
  "glibc": "$GLIBC",
  "os": "${PRETTY_NAME:-unknown}",
  "remotion": "${REMOTION_VER:-unknown}",
  "node": "$(node -v)",
  "runs": $RUNS,
  "concurrency": $VCPU,
  "zh_fonts": ${ZH_FONTS:-0},
  "mean_seconds_per_video": $MEAN,
  "stddev_seconds": ${SD:-0},
  "videos_per_hour": $THRU,
  "output_bytes": $OUTSZ
}
JSON

log ""
log "=== 完成 ==="
log "单条成片耗时 : ${MEAN}s (σ ${SD:-?})"
log "吞吐         : ${THRU} 条/小时"
cat "$RESULT_JSON"
