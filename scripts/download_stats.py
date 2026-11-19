# Snug 安装包的下载量（只读，只由 scripts/snug stats 调；只用标准库）。
#
# 两个下载地址分开算，最后相加：
# - GitHub Release：API 的 download_count 按文件计，update.json（App 查更新）、.sha256、.pack 都在里面，
#   只有 .dmg 是安装。ship 发版时会从 GitHub 的下载地址把每个包拉一次核对，每版扣一次；
#   自己从 GitHub 下的认不出来，扣不干净
# - 国内源：读 CDN 访问日志。dl.zephyrxiang.com 和 SpeakMore 共用，日志由 SpeakMore 的 stats 拉下来缓存，
#   这里只读那份缓存。每个安装包按「传出去的字节 ÷ 包的大小」折算成完整下载次数（分段下、断点续传、
#   下到一半断掉都不会把数撑大）；同一个 IP 同一天最多算一次（多线程下载器会分段重复拉），
#   代价是公司、学校这类共用出口的同一天只算一次
#
# 认自己的来源 IP（整段时间都算自测）：
# - SpeakMore 记下的本机出口（self-ips.json 里存的是 IP 的 sha256）
# - curl 拉某个版本目录下的 update.json 或 .pack：只有 ship / mirror 从下载地址核对时这么拉。
#   App 查更新走 latest/update.json，下 .pack 的 UA 是 Snug/…
# 不能当自测的：curl 拉 media/ 下的 README 图片（各版本 Linux curl、AI 工具读 README 都会拉）；
# curl 拉安装包和校验值（宣传片发出后十几个不同来源这样下，多半是用户让 AI 助手装的）
from __future__ import annotations  # macOS 自带的 python3 是 3.9，不认 X | None 的写法

import argparse
import hashlib
import json
import re
import sys
from collections import defaultdict
from dataclasses import dataclass, field
from datetime import datetime, timedelta, timezone
from gzip import BadGzipFile, GzipFile
from pathlib import Path

BEIJING = timezone(timedelta(hours=8))
LATEST_DMG = "/snug/latest/Snug.dmg"
# 日志比这更旧就提醒先刷新 SpeakMore 的缓存
STALE_AFTER = timedelta(hours=6)

# 腾讯云 CDN 访问日志一行：时间 IP 域名 路径 字节 省份 运营商 状态码 来源 耗时 "UA" "Range" 方法 ……
LINE = re.compile(r'^(\d{14}) (\S+) (\S+) (\S+) (\d+) (\S+) (\S+) (\d{3}) (\S+) (\S+) "([^"]*)" "([^"]*)" (\S+)')
VERSIONED_DMG = re.compile(r"^/snug/(v[^/]+)/(Snug-[^/]+\.dmg)$")
SHIP_CHECK = re.compile(r"^/snug/v[^/]+/(update\.json|Snug-[^/]+\.pack)$")


@dataclass(frozen=True)
class Row:
    time: str  # 北京时间 yyyymmddHHMMSS，和日志一致
    ip: str
    path: str
    bytes: int
    status: int
    ua: str
    method: str

    @property
    def when(self) -> datetime:
        return datetime.strptime(self.time, "%Y%m%d%H%M%S").replace(tzinfo=BEIJING).astimezone(timezone.utc)

    @property
    def day(self) -> str:
        return f"{self.time[:4]}-{self.time[4:6]}-{self.time[6:8]}"


def parse_line(text: str) -> Row | None:
    """拆一行访问日志；格式不对的行（空行、表头）返回 None"""
    m = LINE.match(text)
    if not m:
        return None
    time, ip, _, path, size, _, _, status, _, _, ua, _, method = m.groups()
    return Row(time, ip, path.split("?")[0], int(size), int(status), ua, method)


@dataclass(frozen=True)
class Release:
    tag: str
    published: datetime
    dmg_name: str | None
    dmg_size: int | None
    downloads: dict[str, int]  # 文件名 → GitHub 的 download_count


def parse_releases(items: list[dict]) -> list[Release]:
    """GitHub API 的 Release 列表 → 按公开时间排好的 Release；草稿（还没有 published_at）跳过"""
    releases = []
    for item in items:
        if not item.get("published_at"):
            continue
        dmg = next((a for a in item["assets"] if a["name"].endswith(".dmg")), None)
        releases.append(Release(
            tag=item["tag_name"],
            published=datetime.fromisoformat(item["published_at"].replace("Z", "+00:00")),
            dmg_name=dmg["name"] if dmg else None,
            dmg_size=dmg["size"] if dmg else None,
            downloads={a["name"]: a["download_count"] for a in item["assets"]},
        ))
    return sorted(releases, key=lambda r: r.published)


def dmg_size(path: str, at: datetime, releases: list[Release]) -> int | None:
    """日志里这个安装包地址在 at 时刻是多大。latest/ 指向当时最新公开的版本（CDN 最多晚 5 分钟换上，忽略）"""
    if path == LATEST_DMG:
        current = [r for r in releases if r.published <= at and r.dmg_size]
        return current[-1].dmg_size if current else None
    m = VERSIONED_DMG.match(path)
    if not m:
        return None
    tag, name = m.groups()
    return next((r.dmg_size for r in releases if r.tag == tag and r.dmg_name == name), None)


def find_self(rows: list[Row], known: set[str]) -> set[str]:
    """认出自己的来源 IP；known 是记下来的本机出口的 sha256"""
    found = set()
    for row in rows:
        if hashlib.sha256(row.ip.encode()).hexdigest() in known:
            found.add(row.ip)
        elif row.ua.startswith("curl/") and SHIP_CHECK.match(row.path):
            found.add(row.ip)
    return found


@dataclass
class MirrorCount:
    real: float = 0.0
    self: float = 0.0
    curl: float = 0.0  # 真实下载里 curl 拉的（多半是用户让 AI 助手装的）
    via_latest: float = 0.0
    real_ips: int = 0  # 至少下完半个包的真实来源 IP：比次数更接近人数
    rows: int = 0  # 算进来的安装包请求行数
    by_day: dict[str, float] = field(default_factory=dict)
    first: datetime | None = None
    last: datetime | None = None


def count_mirror(rows: list[Row], releases: list[Release], self_ips: set[str]) -> MirrorCount:
    out = MirrorCount()
    counted: dict[tuple[str, str], float] = defaultdict(float)  # (IP, 日期) → 已经算了多少次，到 1 封顶
    per_ip: dict[str, float] = defaultdict(float)
    by_day: dict[str, float] = defaultdict(float)
    dmgs = sorted(
        (r for r in rows if r.path.startswith("/snug/") and r.path.endswith(".dmg")
         and r.method == "GET" and 200 <= r.status < 300),
        key=lambda r: r.time,
    )
    for row in dmgs:
        size = dmg_size(row.path, row.when, releases)
        if not size:
            continue
        out.rows += 1
        out.first = out.first or row.when
        out.last = row.when
        key = (row.ip, row.day)
        share = min(row.bytes / size, 1 - counted[key])
        if share <= 0:
            continue
        counted[key] += share
        if row.ip in self_ips:
            out.self += share
            continue
        out.real += share
        per_ip[row.ip] += share
        by_day[row.day] += share
        if row.ua.startswith("curl/"):
            out.curl += share
        if row.path == LATEST_DMG:
            out.via_latest += share
    out.real_ips = sum(1 for n in per_ip.values() if n >= 0.5)
    out.by_day = {day: round(n, 2) for day, n in sorted(by_day.items())}
    return out


@dataclass(frozen=True)
class GithubCount:
    dmg: int
    release_checks: int  # ship 从 GitHub 下载地址核对：每版拉一次安装包
    others: dict[str, int]  # 不算下载的文件：.sha256、.pack、update.json

    @property
    def real(self) -> int:
        return max(0, self.dmg - self.release_checks)


def count_github(releases: list[Release]) -> GithubCount:
    others: dict[str, int] = defaultdict(int)
    dmg = checks = 0
    for release in releases:
        for name, n in release.downloads.items():
            if name.endswith(".dmg"):
                dmg += n
            elif name == "update.json":
                others[name] += n
            else:
                others[Path(name).suffix] += n
        if release.dmg_name:
            checks += 1
    return GithubCount(dmg, checks, dict(others))


def _beijing(at: datetime) -> str:
    return at.astimezone(BEIJING).strftime("%m-%d %H:%M")


def render(github: GithubCount, mirror: MirrorCount, logs_until: datetime | None, now: datetime) -> str:
    """logs_until 是整份日志缓存的最后一行（任何路径），看缓存新不新用它：几个小时没人下 Snug 不算缓存旧"""
    lines = [
        f"Snug 下载量 · {_beijing(now)}（北京时间）",
        "",
        "安装包（.dmg，按完整下载次数算）",
        f"  GitHub Release   真实 {github.real:<8} 共 {github.dmg}，每版扣一次发版核对（{github.release_checks} 次）",
        f"  国内源           真实 {mirror.real:<8.1f} 自测 {mirror.self:.1f}；同一个 IP 同一天最多算一次",
        f"  合计             真实 {github.real + mirror.real:.1f}",
        f"  国内源真实来源 IP {mirror.real_ips} 个（至少下完半个包）；其中 curl 拉的 {mirror.curl:.1f} 次，"
        f"走 latest/ 的 {mirror.via_latest:.1f} 次",
    ]
    if mirror.by_day:
        lines.append("  国内源按天（真实）：" + " · ".join(f"{d[5:]} {n:.1f}" for d, n in mirror.by_day.items()))
    if mirror.last:
        lines.append(f"  国内源安装包请求：{_beijing(mirror.first)} → {_beijing(mirror.last)}")
    if logs_until:
        lines.append(f"  日志缓存截至：{_beijing(logs_until)}")
    others = " · ".join(f"{name} {n}" for name, n in sorted(github.others.items()))
    lines += ["", f"不算下载（GitHub 上的其他文件）：{others or '无'}"]
    if logs_until is None or now - logs_until > STALE_AFTER:
        lines += ["", "⚠️  日志缓存不新：先在 SpeakMore 仓库跑一次 scripts/release/with-cos-key.sh npm run stats 刷新"]
    return "\n".join(lines)


def read_logs(directory: Path) -> list[Row]:
    rows = []
    for path in sorted(directory.iterdir()):
        try:
            with GzipFile(path) as f:
                text = f.read().decode("utf-8", errors="replace")
        except BadGzipFile as e:
            raise SystemExit(f"❌ 日志缓存里有一份不是 gzip：{path}（{e}）")
        rows.extend(row for row in map(parse_line, text.splitlines()) if row)
    return rows


def read_known(path: Path) -> set[str]:
    if not path.exists():
        print(f"⚠️  没有 {path}：认不出本机出口，自己的下载会算进真实", file=sys.stderr)
        return set()
    return set(json.loads(path.read_text()))


def main(argv: list[str]) -> None:
    parser = argparse.ArgumentParser(description="Snug 安装包下载量（只读）")
    parser.add_argument("--releases", type=Path, required=True, help="gh api 取的 Release，一行一个 JSON")
    parser.add_argument("--logs", type=Path, required=True, help="SpeakMore 缓存的 CDN 访问日志目录")
    parser.add_argument("--self-ips", type=Path, required=True, help="SpeakMore 记下的本机出口（sha256）")
    args = parser.parse_args(argv)
    releases = parse_releases([json.loads(text) for text in args.releases.read_text().splitlines() if text.strip()])
    rows = read_logs(args.logs)
    mirror = count_mirror(rows, releases, find_self(rows, read_known(args.self_ips)))
    logs_until = max((row.when for row in rows), default=None)
    print(render(count_github(releases), mirror, logs_until, now=datetime.now(timezone.utc)))


if __name__ == "__main__":
    main(sys.argv[1:])
