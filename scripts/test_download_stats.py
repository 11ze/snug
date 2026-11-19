# scripts/download_stats.py 的单测：scripts/snug check 会跑
#   python3 -B -m unittest discover -s scripts -p 'test_*.py'
# 日志行照腾讯云 CDN 的真实格式造，IP 用文档专用网段（203.0.113.0/24、198.51.100.0/24）
import hashlib
import unittest
from datetime import datetime, timezone

import download_stats as ds

USER_A = "203.0.113.10"
USER_B = "203.0.113.20"
SHIP = "198.51.100.7"
CURL = "curl/8.7.1"
BROWSER = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)"
APP = "Snug/2.6.2 CFNetwork/3896.100.1 Darwin/25.0.0"

DMG_200 = "/snug/v2.0.0/Snug-2.0.0.dmg"
DMG_210 = "/snug/v2.1.0/Snug-2.1.0.dmg"


def line(time, ip, path, size, status=200, ua=BROWSER, method="GET"):
    return f'{time} {ip} dl.zephyrxiang.com {path} {size} 669 -1 {status} NULL 12 "{ua}" "(null)" {method} HTTPS hit 1'


def rows(*lines):
    return [ds.parse_line(text) for text in lines]


def release(tag, published, dmg_size, counts=None, draft=False):
    version = tag.removeprefix("v")
    counts = counts or {}
    names = [f"Snug-{version}.dmg", f"Snug-{version}.dmg.sha256", f"Snug-{version}.pack", "update.json"]
    return {
        "tag_name": tag,
        "published_at": None if draft else published,
        "assets": [
            {"name": name, "size": dmg_size if name.endswith(".dmg") else 100, "download_count": counts.get(name, 0)}
            for name in names
        ],
    }


# 2.0.0 发于北京时间 11-13 19:27，2.1.0 发于 11-14 22:42
RELEASES = ds.parse_releases([
    release("v2.0.0", "2026-11-13T11:27:10Z", 1000, {"Snug-2.0.0.dmg": 78, "Snug-2.0.0.dmg.sha256": 30}),
    release("v2.1.0", "2026-11-14T14:42:12Z", 2000, {"Snug-2.1.0.dmg": 36, "Snug-2.1.0.pack": 9, "update.json": 40}),
    release("v2.2.0", None, 3000, draft=True),
])


class ParseLineTest(unittest.TestCase):
    def test_fields(self):
        row = ds.parse_line(line("20261114120000", USER_A, DMG_200 + "?from=readme", 1000, ua=CURL))
        self.assertEqual(row.ip, USER_A)
        self.assertEqual(row.path, DMG_200)  # 查询串去掉
        self.assertEqual(row.bytes, 1000)
        self.assertEqual(row.status, 200)
        self.assertEqual(row.ua, CURL)
        self.assertEqual(row.method, "GET")
        self.assertEqual(row.day, "2026-11-14")
        self.assertEqual(row.when, datetime(2026, 11, 14, 4, 0, tzinfo=timezone.utc))  # 日志是北京时间

    def test_malformed_is_none(self):
        self.assertIsNone(ds.parse_line(""))
        self.assertIsNone(ds.parse_line("#Fields: time ip host"))


class ReleasesTest(unittest.TestCase):
    def test_drafts_skipped(self):
        self.assertEqual([r.tag for r in RELEASES], ["v2.0.0", "v2.1.0"])

    def test_versioned_dmg_size(self):
        at = datetime(2026, 11, 20, tzinfo=timezone.utc)
        self.assertEqual(ds.dmg_size(DMG_200, at, RELEASES), 1000)
        self.assertEqual(ds.dmg_size(DMG_210, at, RELEASES), 2000)
        self.assertIsNone(ds.dmg_size("/snug/v9.9.9/Snug-9.9.9.dmg", at, RELEASES))

    def test_latest_follows_newest_published(self):
        before_210 = datetime(2026, 11, 14, 14, 0, tzinfo=timezone.utc)
        after_210 = datetime(2026, 11, 14, 15, 0, tzinfo=timezone.utc)
        before_any = datetime(2026, 11, 13, 0, 0, tzinfo=timezone.utc)
        self.assertEqual(ds.dmg_size(ds.LATEST_DMG, before_210, RELEASES), 1000)
        self.assertEqual(ds.dmg_size(ds.LATEST_DMG, after_210, RELEASES), 2000)
        self.assertIsNone(ds.dmg_size(ds.LATEST_DMG, before_any, RELEASES))


class FindSelfTest(unittest.TestCase):
    def test_ship_checks_are_self(self):
        found = ds.find_self(rows(
            line("20261114224500", SHIP, "/snug/v2.1.0/update.json", 100, ua=CURL),
            line("20261114224501", USER_A, "/snug/v2.1.0/Snug-2.1.0.pack", 100, ua=CURL),
        ), known=set())
        self.assertEqual(found, {SHIP, USER_A})

    def test_known_egress_is_self(self):
        known = {hashlib.sha256(USER_B.encode()).hexdigest()}
        found = ds.find_self(rows(line("20261114120000", USER_B, DMG_200, 1000)), known=known)
        self.assertEqual(found, {USER_B})

    def test_users_are_not_self(self):
        # curl 拉 README 图片、拉最新版和它的校验值：用户自己或者用户的 AI 助手也会这样；App 下更新包的 UA 是 Snug/…
        found = ds.find_self(rows(
            line("20261114120000", USER_A, "/snug/media/hero.0ee41447.png", 100, ua=CURL),
            line("20261114120001", USER_A, ds.LATEST_DMG, 1000, ua=CURL),
            line("20261114120002", USER_A, "/snug/latest/Snug.dmg.sha256", 100, ua=CURL),
            line("20261114120003", USER_B, "/snug/v2.1.0/Snug-2.1.0.pack", 100, ua=APP),
            line("20261114120004", USER_B, "/snug/latest/update.json", 100, ua=APP),
        ), known=set())
        self.assertEqual(found, set())


class CountMirrorTest(unittest.TestCase):
    def count(self, *lines, self_ips=frozenset()):
        return ds.count_mirror(rows(*lines), RELEASES, set(self_ips))

    def test_partial_transfers_add_up(self):
        got = self.count(
            line("20261114120000", USER_A, DMG_200, 400),
            line("20261114120100", USER_A, DMG_200, 600),
        )
        self.assertAlmostEqual(got.real, 1.0)
        self.assertEqual(got.real_ips, 1)

    def test_one_per_ip_per_day(self):
        got = self.count(
            line("20261114120000", USER_A, DMG_200, 1000),
            line("20261114130000", USER_A, DMG_200, 1000),
            line("20261114140000", USER_A, ds.LATEST_DMG, 1000),
            line("20261115090000", USER_A, DMG_200, 1000),
        )
        self.assertAlmostEqual(got.real, 2.0)
        self.assertEqual(got.by_day, {"2026-11-14": 1.0, "2026-11-15": 1.0})

    def test_failed_and_head_requests_ignored(self):
        got = self.count(
            line("20261114120000", USER_A, DMG_200, 1000, status=404),
            line("20261114120000", USER_A, DMG_200, 1000, status=304),
            line("20261114120000", USER_B, DMG_200, 1000, method="HEAD"),
            line("20261114120000", USER_B, "/snug/v2.0.0/Snug-2.0.0.dmg.sha256", 100),
        )
        self.assertEqual(got.real, 0)
        self.assertEqual(got.rows, 0)

    def test_latest_sized_by_release_at_that_time(self):
        # 2.1.0 发出前 latest 是 1000 字节的 2.0.0，之后是 2000 字节的 2.1.0
        got = self.count(
            line("20261114200000", USER_A, ds.LATEST_DMG, 1000),
            line("20261115090000", USER_B, ds.LATEST_DMG, 1000),
        )
        self.assertAlmostEqual(got.real, 1.5)
        self.assertAlmostEqual(got.via_latest, 1.5)
        self.assertEqual(got.real_ips, 2)

    def test_self_and_curl_split_out(self):
        got = self.count(
            line("20261114230000", SHIP, DMG_210, 2000, ua=CURL),
            line("20261114230000", USER_A, DMG_210, 2000, ua=CURL),
            line("20261114230000", USER_B, DMG_210, 600),
            self_ips={SHIP},
        )
        self.assertAlmostEqual(got.self, 1.0)
        self.assertAlmostEqual(got.real, 1.3)
        self.assertAlmostEqual(got.curl, 1.0)
        self.assertEqual(got.real_ips, 1)  # 下了不到半个包的不算来源
        self.assertEqual(got.last, datetime(2026, 11, 14, 15, 0, tzinfo=timezone.utc))


class CountGithubTest(unittest.TestCase):
    def test_only_dmg_counts_minus_release_checks(self):
        got = ds.count_github(RELEASES)
        self.assertEqual(got.dmg, 78 + 36)
        self.assertEqual(got.release_checks, 2)
        self.assertEqual(got.real, 78 + 36 - 2)
        self.assertEqual(got.others, {".sha256": 30, ".pack": 9, "update.json": 40})


class ReportTest(unittest.TestCase):
    def test_report_and_stale_warning(self):
        mirror = ds.count_mirror(rows(line("20261114120000", USER_A, DMG_200, 1000)), RELEASES, set())
        github = ds.count_github(RELEASES)
        # 最后一次有人下 Snug 是一天前，但缓存是新的（别的路径一直有请求）：不算旧
        logs_until = datetime(2026, 11, 15, 5, 0, tzinfo=timezone.utc)
        fresh = ds.render(github, mirror, logs_until, now=datetime(2026, 11, 15, 6, 0, tzinfo=timezone.utc))
        self.assertRegex(fresh, r"合计\s+真实 113\.0")
        self.assertNotIn("⚠️", fresh)
        stale = ds.render(github, mirror, logs_until, now=datetime(2026, 11, 15, 12, 0, tzinfo=timezone.utc))
        self.assertIn("⚠️", stale)
        empty = ds.render(github, ds.MirrorCount(), None, now=datetime(2026, 11, 15, 6, 0, tzinfo=timezone.utc))
        self.assertIn("⚠️", empty)


if __name__ == "__main__":
    unittest.main()
