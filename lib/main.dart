import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================
//  فوضى الجيتباك - لعبة أكشن 2D مع بوتات ولعب مع صديق (هوت سبوت)
// ============================================================

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const JetpackChaosApp());
}

class JetpackChaosApp extends StatelessWidget {
  const JetpackChaosApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'فوضى الجيتباك',
      theme: ThemeData.dark().copyWith(scaffoldBackgroundColor: const Color(0xFF0D1117)),
      builder: (c, child) => Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const MenuScreen(),
    );
  }
}

// ======================== أدوات صغيرة ========================
const double kViewH = 620;
final Random _rng = Random();
double _cl(double v, double lo, double hi) {
  if (hi < lo) hi = lo;
  return v < lo ? lo : (v > hi ? hi : v);
}

double _r1(double v) => (v * 10).round() / 10;
double _r2(double v) => (v * 100).round() / 100;
double _d(dynamic v) => (v as num).toDouble();

const List<String> botNames = ['بوت أبو العريف', 'بوت حمو', 'بوت نونة', 'بوت كزبرة', 'بوت شطة', 'بوت زقزوق'];

// ======================== الأسلحة ========================
class WeaponDef {
  final String name, emoji;
  final double dmg, interval, speed, spread, grav, life, radius, size, reload, knock;
  final int count, mag, bounces;
  final Color color;
  const WeaponDef(this.name, this.emoji,
      {required this.dmg,
      required this.interval,
      required this.speed,
      required this.color,
      this.spread = 0.02,
      this.count = 1,
      this.grav = 0,
      this.life = 1.5,
      this.radius = 0,
      this.size = 5,
      this.reload = 1.4,
      this.mag = 12,
      this.bounces = 0,
      this.knock = 60});
}

const List<WeaponDef> weapons = [
  WeaponDef('مسدس الطماطم', '🍅', dmg: 14, interval: 0.32, speed: 900, mag: 12, reload: 1.0, color: Color(0xFFFF4D4D), size: 5),
  WeaponDef('رشاش البطاطس', '🥔', dmg: 7, interval: 0.09, speed: 950, spread: 0.07, mag: 35, reload: 1.6, color: Color(0xFFE0B060), size: 4),
  WeaponDef('الجزمة الطايرة', '👢', dmg: 9, interval: 0.85, speed: 800, spread: 0.28, count: 6, mag: 6, reload: 1.8, life: 0.55, color: Color(0xFF8B5A2B), size: 5, knock: 140),
  WeaponDef('قناصة الجزرة', '🥕', dmg: 70, interval: 1.15, speed: 2000, spread: 0.0, mag: 5, reload: 2.2, life: 1.2, color: Color(0xFFFF9800), size: 4, knock: 120),
  WeaponDef('مدفع الفشار', '🍿', dmg: 6, interval: 0.4, speed: 800, spread: 0.18, count: 3, mag: 15, reload: 1.5, bounces: 4, life: 2.2, color: Color(0xFFFFF8DC), size: 5),
  WeaponDef('صاروخ البطيخ', '🍉', dmg: 50, interval: 1.1, speed: 520, mag: 3, reload: 2.4, radius: 95, grav: 60, life: 3, color: Color(0xFF2ECC71), size: 9, knock: 260),
  WeaponDef('خرطوم المية', '💦', dmg: 3, interval: 0.04, speed: 700, spread: 0.1, mag: 90, reload: 2.0, life: 0.7, color: Color(0xFF4FC3F7), size: 4, knock: 30),
  WeaponDef('قنبلة الكفتة', '🍢', dmg: 55, interval: 0.9, speed: 620, mag: 3, reload: 2.0, radius: 105, grav: 900, bounces: 3, life: 1.7, color: Color(0xFFB5502D), size: 9, knock: 300),
  WeaponDef('الشبشب الطاير', '🩴', dmg: 42, interval: 0.55, speed: 650, mag: 8, reload: 1.2, life: 0.16, color: Color(0xFFFFEB3B), size: 14, knock: 260),
  WeaponDef('ليزر القطة', '😺', dmg: 11, interval: 0.14, speed: 2400, spread: 0.02, mag: 20, reload: 1.4, life: 0.8, color: Color(0xFFE040FB), size: 3),
];

// ======================== المودات ========================
class ModeDef {
  final String name, emoji, desc;
  final double grav, size, hp, speed, fireRate, crateEvery;
  final int bounceAdd, killLimit;
  final bool randomWeapon;
  const ModeDef(this.name, this.emoji, this.desc,
      {this.grav = 1,
      this.size = 1,
      this.hp = 100,
      this.speed = 1,
      this.fireRate = 1,
      this.bounceAdd = 0,
      this.killLimit = 10,
      this.randomWeapon = false,
      this.crateEvery = 14});
}

const List<ModeDef> modes = [
  ModeDef('كلاسيك', '⚔️', 'قتال عادي لحد 10 ضربات قاتلة', killLimit: 10),
  ModeDef('جاذبية القمر', '🌙', 'الجاذبية خفيفة وكله بيطير', grav: 0.35),
  ModeDef('الجبابرة', '🦍', 'كل اللاعبين ضخمين ودمهم 200', size: 1.6, hp: 200, killLimit: 8),
  ModeDef('رصاص نطاط', '🏀', 'كل الرصاص بينط على الحيطان', bounceAdd: 3),
  ModeDef('سرعة البرق', '⚡', 'حركة وضرب أسرع بكتير', speed: 1.5, fireRate: 1.6),
  ModeDef('فوضى الأسلحة', '🎲', 'سلاح عشوائي كل ما ترجع وصناديق كتير', randomWeapon: true, crateEvery: 5, killLimit: 12),
  ModeDef('الهشّين', '🥚', 'دمك قليل وأي طلقة خطر', hp: 30, killLimit: 15),
];

// ======================== الشخصيات ========================
class CharDef {
  final String name;
  final Color body, accent;
  final int type;
  final double hpMul, speedMul;
  const CharDef(this.name, this.body, this.accent, this.type, {this.hpMul = 1, this.speedMul = 1});
}

const List<CharDef> chars = [
  CharDef('الفرخة الغاضبة', Color(0xFFFFF3E0), Color(0xFFE53935), 0, speedMul: 1.1),
  CharDef('البطيخة القاتلة', Color(0xFF43A047), Color(0xFF1B5E20), 1, hpMul: 1.15),
  CharDef('الفرعون توت', Color(0xFFFFCA28), Color(0xFF1E88E5), 2),
  CharDef('الروبوت الكحيان', Color(0xFF90A4AE), Color(0xFFE53935), 3, hpMul: 1.2, speedMul: 0.92),
  CharDef('الديناصور نونو', Color(0xFF7CB342), Color(0xFFFB8C00), 4, speedMul: 1.05),
  CharDef('الشيف أبو كرش', Color(0xFFFFAB91), Color(0xFFFFFFFF), 5, hpMul: 1.3, speedMul: 0.9),
];

// ======================== الخرايط ========================
List<Rect> _r(List<List<double>> l) => [for (final e in l) Rect.fromLTWH(e[0], e[1], e[2], e[3])];
List<Offset> _o(List<List<double>> l) => [for (final e in l) Offset(e[0], e[1])];

class MapDef {
  final String name, emoji;
  final List<Color> sky;
  final Color plat, top;
  final double grav;
  final int deco;
  final List<Rect> plats;
  final List<Offset> spawns;
  final double w = 2000, h = 1000;
  late final List<Rect> all;
  MapDef(this.name, this.emoji, this.sky, this.plat, this.top, this.grav, this.deco, this.plats, this.spawns) {
    all = [
      Rect.fromLTWH(-200, 940, 2400, 300),
      Rect.fromLTWH(-200, -300, 240, 1600),
      Rect.fromLTWH(1960, -300, 240, 1600),
      Rect.fromLTWH(-200, -300, 2400, 340),
      ...plats,
    ];
  }
}

final List<MapDef> maps = [
  MapDef(
    'مزرعة الفراخ', '🐔',
    const [Color(0xFF64B5F6), Color(0xFFE3F2FD)], const Color(0xFF6D4C41), const Color(0xFF7CB342), 1.0, 0,
    _r([
      [200, 760, 320, 26], [840, 740, 320, 26], [1480, 760, 320, 26], [480, 560, 300, 26], [1220, 560, 300, 26],
      [840, 380, 320, 26], [100, 380, 220, 26], [1680, 380, 220, 26],
    ]),
    _o([
      [300, 700], [1000, 680], [1600, 700], [600, 500], [1350, 500], [1000, 320], [200, 320], [1780, 320], [500, 880], [1500, 880],
    ]),
  ),
  MapDef(
    'الهرم', '🏜️',
    const [Color(0xFFFFB74D), Color(0xFFFFF3E0)], const Color(0xFFC9A66B), const Color(0xFFE6C98A), 1.0, 1,
    _r([
      [700, 860, 600, 80], [800, 780, 400, 80], [900, 700, 200, 80], [150, 720, 300, 26], [1550, 720, 300, 26],
      [300, 480, 300, 26], [1400, 480, 300, 26], [850, 460, 300, 26], [100, 260, 260, 26], [1640, 260, 260, 26], [870, 240, 260, 26],
    ]),
    _o([
      [250, 660], [1700, 660], [450, 420], [1550, 420], [1000, 400], [230, 200], [1770, 200], [1000, 180], [300, 880], [1700, 880],
    ]),
  ),
  MapDef(
    'المحطة الفضائية', '🛰️',
    const [Color(0xFF0B0F2A), Color(0xFF2B1B5A)], const Color(0xFF455A64), const Color(0xFF80DEEA), 0.6, 2,
    _r([
      [150, 800, 200, 22], [500, 700, 200, 22], [850, 800, 200, 22], [1200, 700, 200, 22], [1550, 800, 200, 22],
      [1750, 600, 200, 22], [100, 560, 200, 22], [400, 440, 220, 22], [780, 540, 440, 22], [1300, 430, 220, 22],
      [150, 300, 200, 22], [600, 260, 200, 22], [1000, 330, 200, 22], [1400, 230, 200, 22], [1700, 330, 200, 22],
    ]),
    _o([
      [250, 740], [600, 640], [950, 740], [1300, 640], [1650, 740], [1850, 540], [200, 500], [500, 380], [1000, 480], [1400, 370], [250, 240], [700, 200],
    ]),
  ),
  MapDef(
    'برج البيتزا', '🍕',
    const [Color(0xFFFFCC80), Color(0xFFFFF8E1)], const Color(0xFFBF360C), const Color(0xFFFFC107), 1.0, 0,
    _r([
      [480, 500, 40, 440], [1480, 500, 40, 440], [60, 780, 380, 26], [1560, 780, 380, 26], [560, 700, 880, 26],
      [100, 560, 300, 26], [1600, 560, 300, 26], [560, 480, 300, 26], [1140, 480, 300, 26], [840, 300, 320, 26],
      [100, 340, 260, 26], [1640, 340, 260, 26], [840, 860, 320, 26],
    ]),
    _o([
      [200, 720], [1800, 720], [1000, 640], [200, 500], [1800, 500], [700, 420], [1300, 420], [1000, 240], [230, 280], [1770, 280], [1000, 800],
    ]),
  ),
  MapDef(
    'شاطئ البطيخ', '🏖️',
    const [Color(0xFF4DD0E1), Color(0xFFE0F7FA)], const Color(0xFF2E7D32), const Color(0xFFEF5350), 1.0, 1,
    _r([
      [300, 820, 500, 30], [1200, 820, 500, 30], [700, 640, 600, 30], [100, 600, 260, 30], [1640, 600, 260, 30],
      [450, 420, 300, 30], [1250, 420, 300, 30], [800, 230, 400, 30],
    ]),
    _o([
      [500, 760], [1450, 760], [1000, 580], [220, 540], [1780, 540], [600, 360], [1400, 360], [1000, 170], [200, 880], [1800, 880],
    ]),
  ),
];

// ======================== كيانات اللعبة ========================
class Body {
  double x = 0, y = 0, vx = 0, vy = 0, w = 20, h = 20;
  bool onGround = false;
}

class Inp {
  double mx = 0, up = 0, aim = 0;
  bool shoot = false, swap = false;
}

class P extends Body {
  final int id;
  String name;
  int ch;
  bool isBot;
  int primary = 0;
  double hp = 100, maxHp = 100, aim = 0, cool = 0, reload = 0, fuel = 100, respawn = 0, shield = 0;
  int face = 1, slot = 0, kills = 0, deaths = 0;
  bool alive = false, thrust = false;
  List<int> slots = [0, 0];
  List<int> ammo = [0, 0];
  final Inp inp = Inp();
  double botT = 0, botMx = 0, botUp = 0, botAim = 0;
  bool botShoot = false;
  P(this.id, this.name, this.ch, this.isBot);
}

class B {
  double x, y, vx, vy, life;
  int wi, owner, bounces;
  B(this.x, this.y, this.vx, this.vy, this.life, this.wi, this.owner, this.bounces);
}

class Crate extends Body {
  int wp;
  double life = 25;
  Crate(this.wp) {
    w = 26;
    h = 26;
  }
}

// ======================== عالم اللعبة (المحاكاة) ========================
class World {
  final MapDef map;
  final ModeDef mode;
  final List<P> ps = [];
  final List<B> bs = [];
  final List<Crate> cs = [];
  final List<List<dynamic>> ev = [];
  final List<List<dynamic>> feed = [];
  double time = 0, crateT = 6, timeLeft = 240;
  bool over = false;
  int winner = -1;
  World(this.map, this.mode);

  P addPlayer(String name, int ch, int wp, bool bot) {
    final p = P(ps.length, name, ch, bot);
    p.primary = wp;
    ps.add(p);
    _spawn(p);
    return p;
  }

  void _spawn(P p) {
    final ch = chars[p.ch];
    p.maxHp = mode.hp * ch.hpMul;
    p.hp = p.maxHp;
    p.w = 26 * mode.size;
    p.h = 46 * mode.size;
    Offset best = map.spawns[0];
    double bestD = -1;
    for (int i = 0; i < 4; i++) {
      final c = map.spawns[_rng.nextInt(map.spawns.length)];
      double d = 1e9;
      for (final o in ps) {
        if (o != p && o.alive) {
          final dd = (o.x - c.dx).abs() + (o.y - c.dy).abs();
          if (dd < d) d = dd;
        }
      }
      if (d > bestD) {
        bestD = d;
        best = c;
      }
    }
    p.x = best.dx;
    p.y = best.dy;
    p.vx = 0;
    p.vy = 0;
    p.slots[0] = mode.randomWeapon ? _rng.nextInt(weapons.length) : p.primary;
    p.slots[1] = 0;
    p.slot = 0;
    p.ammo[0] = weapons[p.slots[0]].mag;
    p.ammo[1] = weapons[0].mag;
    p.cool = 0;
    p.reload = 0;
    p.fuel = 100;
    p.shield = 2.2;
    p.alive = true;
    p.respawn = 0;
    p.thrust = false;
  }

  void update(double dt) {
    if (over) return;
    time += dt;
    timeLeft -= dt;
    if (timeLeft <= 0) {
      _finish(-1);
      return;
    }
    for (final p in ps) {
      _updatePlayer(p, dt);
    }
    _updateBullets(dt);
    _updateCrates(dt);
    crateT -= dt;
    if (crateT <= 0) {
      crateT = mode.crateEvery;
      if (cs.length < 4) {
        final sp = map.spawns[_rng.nextInt(map.spawns.length)];
        final c = Crate(_rng.nextInt(weapons.length));
        c.x = sp.dx;
        c.y = sp.dy - 20;
        cs.add(c);
      }
    }
    feed.removeWhere((f) => time - (f[1] as double) > 8);
  }

  void _finish(int win) {
    over = true;
    if (win >= 0) {
      winner = win;
      return;
    }
    int best = -1;
    for (final p in ps) {
      if (p.kills > best) {
        best = p.kills;
        winner = p.id;
      }
    }
  }

  void _physics(Body b, double dt, double g) {
    b.vy += g * dt;
    if (b.vy > 1100) b.vy = 1100;
    final hw = b.w / 2, hh = b.h / 2;
    b.x += b.vx * dt;
    for (final r in map.all) {
      if (Rect.fromLTWH(b.x - hw, b.y - hh, b.w, b.h).overlaps(r)) {
        if (b.vx > 0) {
          b.x = r.left - hw;
        } else if (b.vx < 0) {
          b.x = r.right + hw;
        }
        b.vx = 0;
      }
    }
    b.y += b.vy * dt;
    b.onGround = false;
    for (final r in map.all) {
      if (Rect.fromLTWH(b.x - hw, b.y - hh, b.w, b.h).overlaps(r)) {
        if (b.vy > 0) {
          b.y = r.top - hh;
          b.onGround = true;
        } else if (b.vy < 0) {
          b.y = r.bottom + hh;
        }
        b.vy = 0;
      }
    }
  }

  void _updatePlayer(P p, double dt) {
    if (!p.alive) {
      p.respawn -= dt;
      if (p.respawn <= 0) _spawn(p);
      return;
    }
    if (p.shield > 0) p.shield -= dt;
    if (p.isBot) _bot(p, dt);
    final inp = p.inp;
    final ch = chars[p.ch];
    final spd = 330 * ch.speedMul * mode.speed;
    final double target = inp.mx.clamp(-1.0, 1.0).toDouble() * spd;
    p.vx += (target - p.vx) * min(1.0, dt * (p.onGround ? 14.0 : 5.0));
    p.thrust = false;
    if (inp.up > 0.5) {
      if (p.onGround) {
        p.vy = -620;
      } else if (p.fuel > 0) {
        if (p.vy > -480) {
          p.vy -= 2900 * dt;
          if (p.vy < -480) p.vy = -480;
        }
        p.thrust = true;
        p.fuel -= 45 * dt;
      }
    }
    if (!p.thrust) {
      p.fuel += (p.onGround ? 50 : 8) * dt;
    }
    p.fuel = _cl(p.fuel, 0, 100);
    p.aim = inp.aim;
    p.face = cos(p.aim) >= 0 ? 1 : -1;
    _physics(p, dt, 1500 * map.grav * mode.grav);

    if (inp.swap) {
      inp.swap = false;
      p.slot = 1 - p.slot;
      p.reload = 0;
      p.cool = 0.2;
    }
    final wd = weapons[p.slots[p.slot]];
    p.cool -= dt;
    if (p.reload > 0) {
      p.reload -= dt;
      if (p.reload <= 0) p.ammo[p.slot] = wd.mag;
    } else if (p.ammo[p.slot] <= 0) {
      p.reload = wd.reload;
    } else if (inp.shoot && p.cool <= 0) {
      _fire(p, wd);
    }
    // التقاط الصناديق
    final pr = Rect.fromCenter(center: Offset(p.x, p.y), width: p.w, height: p.h);
    for (int i = cs.length - 1; i >= 0; i--) {
      final c = cs[i];
      if (Rect.fromCenter(center: Offset(c.x, c.y), width: c.w, height: c.h).overlaps(pr)) {
        p.slots[p.slot] = c.wp;
        p.ammo[p.slot] = weapons[c.wp].mag;
        p.reload = 0;
        ev.add([3, c.x, c.y, c.wp]);
        cs.removeAt(i);
      }
    }
  }

  void _fire(P p, WeaponDef wd) {
    p.cool = wd.interval / mode.fireRate;
    p.ammo[p.slot]--;
    for (int i = 0; i < wd.count; i++) {
      final a = p.aim + (_rng.nextDouble() - 0.5) * 2 * wd.spread;
      final sp = wd.count > 1 ? wd.speed * (0.9 + _rng.nextDouble() * 0.2) : wd.speed;
      final off = p.w / 2 + 14;
      bs.add(B(p.x + cos(a) * off, p.y + 2 + sin(a) * off, cos(a) * sp, sin(a) * sp, wd.life, p.slots[p.slot], p.id, wd.bounces + mode.bounceAdd));
    }
    p.vx -= cos(p.aim) * wd.knock * 0.1;
    if (p.ammo[p.slot] <= 0) p.reload = wd.reload;
  }

  bool _solidAt(double x, double y) {
    final o = Offset(x, y);
    for (final r in map.all) {
      if (r.contains(o)) return true;
    }
    return false;
  }

  void _updateBullets(double dt) {
    for (int i = bs.length - 1; i >= 0; i--) {
      final b = bs[i];
      final wd = weapons[b.wi];
      b.life -= dt;
      b.vy += wd.grav * mode.grav * dt;
      bool dead = false;
      final dist = sqrt(b.vx * b.vx + b.vy * b.vy) * dt;
      final steps = max(1, (dist / 8).ceil());
      final sdt = dt / steps;
      for (int s = 0; s < steps && !dead; s++) {
        final nx = b.x + b.vx * sdt;
        if (_solidAt(nx, b.y)) {
          if (b.bounces > 0) {
            b.vx = -b.vx * 0.85;
            b.bounces--;
          } else {
            dead = true;
            _burst(b, wd);
            break;
          }
        } else {
          b.x = nx;
        }
        final ny = b.y + b.vy * sdt;
        if (_solidAt(b.x, ny)) {
          if (b.bounces > 0) {
            b.vy = -b.vy * 0.85;
            b.bounces--;
          } else {
            dead = true;
            _burst(b, wd);
            break;
          }
        } else {
          b.y = ny;
        }
        for (final p in ps) {
          if (!p.alive || p.id == b.owner || p.shield > 0) continue;
          final hit = Rect.fromCenter(center: Offset(p.x, p.y), width: p.w + wd.size * 2, height: p.h + wd.size * 2).contains(Offset(b.x, b.y));
          if (hit) {
            if (wd.radius > 0) {
              _explode(b.x, b.y, wd, b.owner);
            } else {
              final l = max(1.0, sqrt(b.vx * b.vx + b.vy * b.vy));
              p.vx += b.vx / l * wd.knock;
              p.vy += b.vy / l * wd.knock * 0.5;
              _damage(p, wd.dmg, b.owner, wd);
            }
            dead = true;
            break;
          }
        }
      }
      if (!dead && b.life <= 0) {
        dead = true;
        if (wd.radius > 0) _explode(b.x, b.y, wd, b.owner);
      }
      if (dead) bs.removeAt(i);
    }
  }

  void _burst(B b, WeaponDef wd) {
    if (wd.radius > 0) {
      _explode(b.x, b.y, wd, b.owner);
    } else {
      ev.add([0, b.x, b.y, b.wi]);
    }
  }

  void _explode(double x, double y, WeaponDef wd, int owner) {
    final wi = weapons.indexOf(wd);
    ev.add([1, x, y, wi]);
    for (final p in ps) {
      if (!p.alive || p.shield > 0) continue;
      final dx = p.x - x, dy = p.y - y;
      final d = sqrt(dx * dx + dy * dy);
      if (d < wd.radius + p.w / 2) {
        final f = max(0.25, 1 - d / (wd.radius * 1.2));
        double dmg = wd.dmg * f;
        if (p.id == owner) dmg *= 0.5;
        final l = max(1.0, d);
        p.vx += dx / l * wd.knock * f;
        p.vy += dy / l * wd.knock * f - 120 * f;
        _damage(p, dmg, owner, wd);
      }
    }
  }

  void _damage(P p, double amount, int owner, WeaponDef wd) {
    if (!p.alive) return;
    p.hp -= amount;
    ev.add([0, p.x, p.y, weapons.indexOf(wd)]);
    if (p.hp <= 0) _kill(p, owner, wd);
  }

  void _kill(P p, int owner, WeaponDef wd) {
    p.alive = false;
    p.deaths++;
    p.respawn = 3;
    ev.add([2, p.x, p.y, 0]);
    if (owner >= 0 && owner < ps.length && owner != p.id) {
      final k = ps[owner];
      k.kills++;
      feed.add(['${k.name} ${wd.emoji} ${p.name}', time]);
      if (k.kills >= mode.killLimit) _finish(k.id);
    } else {
      feed.add(['${p.name} انتحر 💥', time]);
    }
  }

  void _updateCrates(double dt) {
    for (int i = cs.length - 1; i >= 0; i--) {
      final c = cs[i];
      c.life -= dt;
      _physics(c, dt, 1500 * map.grav);
      c.vx = 0;
      if (c.life <= 0) cs.removeAt(i);
    }
  }

  void _bot(P p, double dt) {
    p.botT -= dt;
    if (p.botT <= 0) {
      p.botT = 0.2 + _rng.nextDouble() * 0.3;
      P? t;
      double bd = 1e9;
      for (final o in ps) {
        if (o == p || !o.alive) continue;
        final d = (o.x - p.x).abs() + (o.y - p.y).abs() * 1.5;
        if (d < bd) {
          bd = d;
          t = o;
        }
      }
      if (t == null) {
        p.botShoot = false;
        p.botMx = 0;
        p.botUp = 0;
      } else {
        final dx = t.x - p.x, dy = t.y - p.y;
        final dist = sqrt(dx * dx + dy * dy);
        p.botAim = atan2(dy, dx) + (_rng.nextDouble() - 0.5) * 0.25;
        if (dist > 450) {
          p.botMx = dx > 0 ? 1 : -1;
        } else if (dist < 180) {
          p.botMx = dx > 0 ? -1 : 1;
        } else {
          p.botMx = (_rng.nextInt(3) - 1).toDouble();
        }
        p.botUp = (dy < -50 || _rng.nextDouble() < 0.12) ? 1 : 0;
        p.botShoot = dist < 800 && _rng.nextDouble() < 0.8;
      }
    }
    final stuck = p.botMx != 0 && p.vx.abs() < 25;
    p.inp.mx = p.botMx;
    p.inp.up = (p.botUp > 0 || stuck) ? 1 : 0;
    p.inp.aim = p.botAim;
    p.inp.shoot = p.botShoot;
  }

  Map<String, dynamic> snap() {
    final recent = <String>[];
    for (final f in feed) {
      if (time - (f[1] as double) < 5) recent.add(f[0] as String);
    }
    final m = <String, dynamic>{
      't': 's',
      'p': [
        for (final p in ps)
          [
            p.id, _r1(p.x), _r1(p.y), p.face, _r1(p.hp), _r1(p.maxHp), _r2(p.aim), p.ch, p.slots[p.slot],
            p.alive ? 1 : 0, p.kills, p.deaths, _r1(p.fuel), _r1(p.shield), p.ammo[p.slot], p.reload > 0 ? 1 : 0,
            p.name, p.thrust ? 1 : 0, _r1(p.respawn),
          ]
      ],
      'b': [
        for (final b in bs) [_r1(b.x), _r1(b.y), b.wi, _r2(atan2(b.vy, b.vx))]
      ],
      'c': [
        for (final c in cs) [_r1(c.x), _r1(c.y), c.wp]
      ],
      'tl': _r1(timeLeft),
      'o': over ? 1 : 0,
      'wn': winner,
      'ev': List<List<dynamic>>.from(ev),
      'f': recent.length > 4 ? recent.sublist(recent.length - 4) : recent,
    };
    ev.clear();
    return m;
  }
}

// ======================== نموذج العرض (من الشبكة أو محلي) ========================
class PV {
  int id = 0, ch = 0, wi = 0, kills = 0, deaths = 0, ammo = 0, face = 1;
  double x = 0, y = 0, hp = 0, maxHp = 1, aim = 0, fuel = 0, shield = 0, respawn = 0;
  bool alive = false, reload = false, thrust = false;
  String name = '';
}

class BV {
  double x, y, ang;
  int w;
  BV(this.x, this.y, this.w, this.ang);
}

class CV {
  double x, y;
  int w;
  CV(this.x, this.y, this.w);
}

class Snap {
  final List<PV> ps = [];
  final List<BV> bs = [];
  final List<CV> cs = [];
  final List<String> feed = [];
  final List<List<dynamic>> ev = [];
  double timeLeft = 0;
  bool over = false;
  int winner = -1;
}

Snap parseSnap(Map<String, dynamic> m) {
  final s = Snap();
  for (final a in (m['p'] as List)) {
    final l = a as List;
    final p = PV();
    p.id = l[0] as int;
    p.x = _d(l[1]);
    p.y = _d(l[2]);
    p.face = l[3] as int;
    p.hp = _d(l[4]);
    p.maxHp = _d(l[5]);
    p.aim = _d(l[6]);
    p.ch = l[7] as int;
    p.wi = l[8] as int;
    p.alive = (l[9] as int) == 1;
    p.kills = l[10] as int;
    p.deaths = l[11] as int;
    p.fuel = _d(l[12]);
    p.shield = _d(l[13]);
    p.ammo = l[14] as int;
    p.reload = (l[15] as int) == 1;
    p.name = l[16] as String;
    p.thrust = (l[17] as int) == 1;
    p.respawn = _d(l[18]);
    s.ps.add(p);
  }
  for (final a in (m['b'] as List)) {
    final l = a as List;
    s.bs.add(BV(_d(l[0]), _d(l[1]), l[2] as int, _d(l[3])));
  }
  for (final a in (m['c'] as List)) {
    final l = a as List;
    s.cs.add(CV(_d(l[0]), _d(l[1]), l[2] as int));
  }
  for (final f in (m['f'] as List)) {
    s.feed.add(f as String);
  }
  for (final e in (m['ev'] as List)) {
    s.ev.add(List<dynamic>.from(e as List));
  }
  s.timeLeft = _d(m['tl']);
  s.over = (m['o'] as int) == 1;
  s.winner = m['wn'] as int;
  return s;
}

// ======================== الشبكة ========================
class Net {
  final Socket sock;
  void Function(Map<String, dynamic>)? onMsg;
  void Function()? onClose;
  bool closed = false;
  Net(this.sock) {
    try {
      sock.setOption(SocketOption.tcpNoDelay, true);
    } catch (_) {}
    sock.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      try {
        final m = jsonDecode(line);
        if (m is Map) onMsg?.call(Map<String, dynamic>.from(m));
      } catch (_) {}
    }, onDone: _done, onError: (_) => _done(), cancelOnError: true);
  }
  void _done() {
    if (closed) return;
    closed = true;
    onClose?.call();
  }

  void send(Map<String, dynamic> m) {
    if (closed) return;
    try {
      sock.write('${jsonEncode(m)}\n');
    } catch (_) {
      _done();
    }
  }

  void close() {
    closed = true;
    try {
      sock.destroy();
    } catch (_) {}
  }
}

class GameConfig {
  final int role, map, mode, bots, ch, wp;
  final String name;
  String rName = 'صديقك';
  int rCh = 1, rWp = 0;
  GameConfig({required this.role, required this.map, required this.mode, required this.bots, required this.ch, required this.wp, required this.name});
}

// ======================== الرسم ========================
void drawText(Canvas c, String s, Offset center, double size, Color color, {bool bold = false}) {
  final tp = TextPainter(
    text: TextSpan(
      text: s,
      style: TextStyle(fontSize: size, color: color, fontWeight: bold ? FontWeight.bold : FontWeight.normal, shadows: const [Shadow(blurRadius: 3, color: Colors.black)]),
    ),
    textDirection: TextDirection.rtl,
  )..layout();
  tp.paint(c, center - Offset(tp.width / 2, tp.height / 2));
}

void drawFighter(Canvas c, int chi, int face, double aim, int wi, bool thrust, double t) {
  final ch = chars[chi];
  final body = Paint()..color = ch.body;
  final acc = Paint()..color = ch.accent;
  final dark = Paint()..color = const Color(0xFF263238);
  final white = Paint()..color = Colors.white;
  final black = Paint()..color = Colors.black;
  c.save();
  c.scale(face.toDouble(), 1);
  // الجيتباك
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-19, -6, 9, 24), const Radius.circular(3)), Paint()..color = const Color(0xFF78909C));
  if (thrust) {
    final fl = Path()
      ..moveTo(-18, 18)
      ..lineTo(-14.5, 30 + sin(t * 40) * 4)
      ..lineTo(-11, 18)
      ..close();
    c.drawPath(fl, Paint()..color = const Color(0xFFFFB300));
  }
  // الجسم والرجلين
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-11, -4, 22, 26), const Radius.circular(8)), body);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-9, 20, 7, 7), const Radius.circular(3)), dark);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(2, 20, 7, 7), const Radius.circular(3)), dark);
  // الرأس
  if (ch.type == 3) {
    c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-13, -28, 26, 24), const Radius.circular(6)), body);
  } else {
    c.drawCircle(const Offset(0, -14), 13, body);
  }
  // العيون
  c.drawCircle(const Offset(3, -16), 4.5, white);
  c.drawCircle(const Offset(10, -16), 3.8, white);
  c.drawCircle(const Offset(4.4, -16), 2, black);
  c.drawCircle(const Offset(11, -16), 1.8, black);
  // الإكسسوارات
  switch (ch.type) {
    case 0:
      c.drawPath(
          Path()
            ..moveTo(12, -13)
            ..lineTo(22, -9)
            ..lineTo(12, -5)
            ..close(),
          Paint()..color = const Color(0xFFFFA000));
      for (final dx in [-5.0, 1.0, 7.0]) {
        c.drawCircle(Offset(dx, dx == 1.0 ? -30 : -27), 4.5, acc);
      }
      c.drawCircle(const Offset(10, -3), 3, acc);
      break;
    case 1:
      final sp = Paint()
        ..color = ch.accent
        ..strokeWidth = 3
        ..style = PaintingStyle.stroke;
      for (final dx in [-6.0, 0.0, 6.0]) {
        c.drawLine(Offset(dx, -3), Offset(dx, 21), sp);
      }
      c.drawCircle(const Offset(-3, 8), 1.6, black);
      c.drawCircle(const Offset(3, 13), 1.6, black);
      c.drawOval(Rect.fromLTWH(-3, -33, 12, 7), Paint()..color = const Color(0xFF2E7D32));
      break;
    case 2:
      c.drawRect(Rect.fromLTWH(-13, -27, 26, 6), acc);
      c.drawRect(Rect.fromLTWH(-13, -22, 26, 2), dark);
      c.drawPath(
          Path()
            ..moveTo(-6, -27)
            ..lineTo(0, -39)
            ..lineTo(6, -27)
            ..close(),
          acc);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(6, -4, 5, 9), const Radius.circular(2)), acc);
      break;
    case 3:
      c.drawLine(
          const Offset(0, -28),
          const Offset(0, -37),
          Paint()
            ..color = const Color(0xFF546E7A)
            ..strokeWidth = 2);
      c.drawCircle(const Offset(0, -38), 3.5, acc);
      c.drawRect(Rect.fromLTWH(-5, -8, 14, 3), dark);
      c.drawCircle(const Offset(-9, 18), 1.5, dark);
      c.drawCircle(const Offset(9, 18), 1.5, dark);
      break;
    case 4:
      for (int i = 0; i < 3; i++) {
        final y0 = -2.0 + i * 9;
        c.drawPath(
            Path()
              ..moveTo(-11, y0)
              ..lineTo(-19, y0 + 5)
              ..lineTo(-11, y0 + 10)
              ..close(),
            acc);
      }
      c.drawPath(
          Path()
            ..moveTo(-11, 14)
            ..lineTo(-26, 24)
            ..lineTo(-11, 22)
            ..close(),
          body);
      c.drawCircle(const Offset(10, -8), 1.6, dark);
      break;
    case 5:
      c.drawRect(Rect.fromLTWH(-9, -36, 18, 10), white);
      for (final dx in [-8.0, 0.0, 8.0]) {
        c.drawCircle(Offset(dx, dx == 0.0 ? -41 : -37), 6, white);
      }
      c.drawRect(Rect.fromLTWH(-9, -29, 18, 3), Paint()..color = const Color(0xFFB0BEC5));
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(1, -9, 13, 3), const Radius.circular(2)), dark);
      break;
  }
  // السلاح
  c.save();
  c.translate(4, 6);
  c.rotate(face == 1 ? aim : pi - aim);
  c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(-2, -4, 28, 8), const Radius.circular(2)), Paint()..color = const Color(0xFF455A64));
  c.drawRect(Rect.fromLTWH(22, -4, 6, 8), Paint()..color = weapons[wi].color);
  c.restore();
  c.restore();
}

class AvatarPainter extends CustomPainter {
  final int ch;
  AvatarPainter(this.ch);
  @override
  void paint(Canvas canvas, Size size) {
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(1.7);
    drawFighter(canvas, ch, 1, 0, 0, false, 0);
  }

  @override
  bool shouldRepaint(covariant AvatarPainter old) => old.ch != ch;
}

class Part {
  double x, y, vx, vy, life, max, size;
  Color color;
  bool ring;
  Part(this.x, this.y, this.vx, this.vy, this.life, this.size, this.color, {this.ring = false}) : max = life;
}

class GamePainter extends CustomPainter {
  final Snap snap;
  final MapDef map;
  final ModeDef mode;
  final double camX, camY, scale, time;
  final int myId;
  final List<Part> parts;
  GamePainter(this.snap, this.map, this.mode, this.camX, this.camY, this.scale, this.time, this.myId, this.parts);

  @override
  void paint(Canvas canvas, Size size) {
    final m = map;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..shader = LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: m.sky).createShader(rect));
    // الديكور
    final dr = Random(m.deco * 7 + 3);
    if (m.deco == 2) {
      for (int i = 0; i < 60; i++) {
        final bx = dr.nextDouble() * 3000, by = dr.nextDouble() * size.height;
        final px = ((bx - camX * scale * 0.15) % (size.width + 100));
        canvas.drawCircle(Offset(px, by), 0.8 + dr.nextDouble() * 1.8, Paint()..color = const Color(0xCCFFFFFF));
      }
      canvas.drawCircle(Offset(size.width * 0.75, size.height * 0.25), 46, Paint()..color = const Color(0xFF7E57C2));
      canvas.drawCircle(Offset(size.width * 0.75 - 14, size.height * 0.25 - 10), 10, Paint()..color = const Color(0xFF9575CD));
    } else {
      if (m.deco == 1) {
        canvas.drawCircle(Offset(size.width * 0.8, 80), 50, Paint()..color = const Color(0xBBFFEB3B));
      }
      for (int i = 0; i < 9; i++) {
        final bx = dr.nextDouble() * 3000, by = 30 + dr.nextDouble() * size.height * 0.5;
        final px = ((bx - camX * scale * 0.25) % (size.width + 400)) - 200;
        final cp = Paint()..color = const Color(0x59FFFFFF);
        canvas.drawOval(Rect.fromCenter(center: Offset(px, by), width: 130, height: 36), cp);
        canvas.drawOval(Rect.fromCenter(center: Offset(px + 28, by - 14), width: 80, height: 34), cp);
      }
    }

    canvas.save();
    canvas.scale(scale);
    canvas.translate(-camX, -camY);
    final view = Rect.fromLTWH(camX - 50, camY - 50, size.width / scale + 100, size.height / scale + 100);

    // المنصات
    final pp = Paint()..color = m.plat;
    final tp = Paint()..color = m.top;
    for (final r in m.all) {
      if (!r.overlaps(view)) continue;
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)), pp);
      canvas.drawRect(Rect.fromLTWH(r.left, r.top, r.width, 7), tp);
    }

    // الصناديق
    for (final c in snap.cs) {
      final r = Rect.fromCenter(center: Offset(c.x, c.y), width: 26, height: 26);
      canvas.drawRRect(RRect.fromRectAndRadius(r, const Radius.circular(4)), Paint()..color = const Color(0xFF8D6E63));
      canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()
            ..color = const Color(0xFFFFCA28)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5);
      drawText(canvas, '?', Offset(c.x, c.y), 16, Colors.white, bold: true);
      drawText(canvas, weapons[c.w].emoji, Offset(c.x, c.y - 28 + sin(time * 4) * 3), 20, Colors.white);
    }

    // الرصاص
    for (final b in snap.bs) {
      final wd = weapons[b.w];
      if (wd.size >= 8) {
        drawText(canvas, wd.emoji, Offset(b.x, b.y), 24, Colors.white);
      } else {
        canvas.drawLine(
            Offset(b.x, b.y),
            Offset(b.x - cos(b.ang) * 14, b.y - sin(b.ang) * 14),
            Paint()
              ..color = wd.color.withAlpha(150)
              ..strokeWidth = wd.size * 1.2
              ..strokeCap = StrokeCap.round);
        canvas.drawCircle(Offset(b.x, b.y), wd.size / 1.5, Paint()..color = wd.color);
      }
    }

    // اللاعبين
    final s = mode.size;
    for (final p in snap.ps) {
      if (!p.alive) continue;
      if (p.shield > 0 && (time * 12).floor() % 2 == 0) continue;
      canvas.save();
      canvas.translate(p.x, p.y);
      canvas.scale(s);
      drawFighter(canvas, p.ch, p.face, p.aim, p.wi, p.thrust, time);
      canvas.restore();
      final top = p.y - 44 * s;
      const bw = 40.0;
      final bx = p.x - bw / 2;
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, top, bw, 5), const Radius.circular(2)), Paint()..color = const Color(0x99000000));
      final ratio = _cl(p.hp / p.maxHp, 0, 1);
      canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(bx, top, bw * ratio, 5), const Radius.circular(2)), Paint()..color = Color.lerp(Colors.red, Colors.greenAccent, ratio)!);
      drawText(canvas, p.name, Offset(p.x, top - 9), 11, p.id == myId ? const Color(0xFFFFEB3B) : Colors.white, bold: true);
      if (p.id == myId) {
        final cx = p.x + cos(p.aim) * 110, cy = p.y + sin(p.aim) * 110;
        canvas.drawCircle(
            Offset(cx, cy),
            7,
            Paint()
              ..color = const Color(0x99FFFFFF)
              ..style = PaintingStyle.stroke
              ..strokeWidth = 2);
        canvas.drawCircle(Offset(cx, cy), 1.5, Paint()..color = Colors.white);
      }
    }

    // الجزيئات
    for (final pt in parts) {
      final a = _cl(pt.life / pt.max, 0, 1);
      if (pt.ring) {
        canvas.drawCircle(
            Offset(pt.x, pt.y),
            pt.size * (1 - a) + 10,
            Paint()
              ..color = pt.color.withAlpha((a * 200).toInt())
              ..style = PaintingStyle.stroke
              ..strokeWidth = 6 * a + 1);
      } else {
        canvas.drawCircle(Offset(pt.x, pt.y), pt.size * (0.4 + 0.6 * a), Paint()..color = pt.color.withAlpha((a * 255).toInt()));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant GamePainter old) => true;
}

// ======================== عصا التحكم ========================
class StickPainter extends CustomPainter {
  final Offset knob;
  final Color color;
  StickPainter(this.knob, this.color);
  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(c, size.width / 2 - 4, Paint()..color = color.withAlpha(45));
    canvas.drawCircle(
        c,
        size.width / 2 - 4,
        Paint()
          ..color = color.withAlpha(120)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3);
    canvas.drawCircle(c + knob, 28, Paint()..color = color.withAlpha(150));
  }

  @override
  bool shouldRepaint(covariant StickPainter old) => old.knob != knob;
}

class Stick extends StatefulWidget {
  final void Function(Offset v, bool active) onChanged;
  final Color color;
  final double size;
  const Stick({Key? key, required this.onChanged, required this.color, this.size = 150}) : super(key: key);
  @override
  State<Stick> createState() => _StickState();
}

class _StickState extends State<Stick> {
  Offset knob = Offset.zero;
  void _upd(Offset p) {
    final r = widget.size / 2;
    var v = p - Offset(r, r);
    final maxR = r - 22;
    if (v.distance > maxR) v = v / v.distance * maxR;
    setState(() => knob = v);
    widget.onChanged(v / maxR, true);
  }

  void _end() {
    if (mounted) setState(() => knob = Offset.zero);
    widget.onChanged(Offset.zero, false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onPanDown: (d) => _upd(d.localPosition),
      onPanUpdate: (d) => _upd(d.localPosition),
      onPanEnd: (_) => _end(),
      onPanCancel: _end,
      child: SizedBox(width: widget.size, height: widget.size, child: CustomPaint(painter: StickPainter(knob, widget.color))),
    );
  }
}

// ======================== شاشة اللعب ========================
class GameScreen extends StatefulWidget {
  final GameConfig cfg;
  final Net? net;
  const GameScreen({Key? key, required this.cfg, this.net}) : super(key: key);
  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _last = Duration.zero;
  World? world;
  Snap? snap;
  int myId = 0;
  final List<Part> parts = [];
  double camX = 0, camY = 0, t = 0;
  bool camInit = false;
  Offset mv = Offset.zero, aimv = Offset.zero;
  bool aimActive = false, swapPending = false, saved = false;
  double lastAim = 0;
  String? msg;
  late MapDef map;
  late ModeDef mode;

  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    final cfg = widget.cfg;
    map = maps[cfg.map];
    mode = modes[cfg.mode];
    if (cfg.role != 2) {
      final w = World(map, mode);
      w.addPlayer(cfg.name, cfg.ch, cfg.wp, false);
      if (cfg.role == 1) w.addPlayer(cfg.rName, cfg.rCh, cfg.rWp, false);
      for (int i = 0; i < cfg.bots; i++) {
        w.addPlayer(botNames[i % botNames.length], _rng.nextInt(chars.length), _rng.nextInt(weapons.length), true);
      }
      world = w;
    } else {
      myId = 1;
    }
    final net = widget.net;
    if (net != null) {
      net.onMsg = (m) {
        final type = m['t'];
        if (cfg.role == 1) {
          if (type == 'i' && world != null && world!.ps.length > 1) {
            final inp = world!.ps[1].inp;
            inp.mx = _d(m['mx']);
            inp.up = _d(m['up']);
            inp.aim = _d(m['a']);
            inp.shoot = m['s'] == 1;
            if (m['w'] == 1) inp.swap = true;
          }
        } else {
          if (type == 's') {
            _applySnap(parseSnap(m));
          } else if (type == 'bye') {
            if (mounted) setState(() => msg = 'الهوست خرج من اللعبة');
          }
        }
      };
      net.onClose = () {
        if (cfg.role == 1) {
          if (world != null && world!.ps.length > 1) world!.ps[1].isBot = true;
        } else {
          if (mounted) setState(() => msg = 'الاتصال اتقطع');
        }
      };
    }
    _ticker = createTicker(_tick)..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    final net = widget.net;
    if (net != null) {
      if (widget.cfg.role == 1) net.send({'t': 'bye'});
      net.onMsg = null;
      net.onClose = null;
      net.close();
    }
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _applySnap(Snap s) {
    snap = s;
    for (final e in s.ev) {
      _addEffect(e);
    }
    if (s.over && !saved) {
      saved = true;
      _saveStats(s);
    }
  }

  Future<void> _saveStats(Snap s) async {
    try {
      final sp = await SharedPreferences.getInstance();
      PV? me;
      for (final p in s.ps) {
        if (p.id == myId) me = p;
      }
      if (me != null) sp.setInt('kills', (sp.getInt('kills') ?? 0) + me.kills);
      if (s.winner == myId) sp.setInt('wins', (sp.getInt('wins') ?? 0) + 1);
    } catch (_) {}
  }

  void _addEffect(List<dynamic> e) {
    if (parts.length > 350) return;
    final type = e[0] as int;
    final x = _d(e[1]), y = _d(e[2]);
    final wi = e[3] as int;
    final col = weapons[wi].color;
    if (type == 0) {
      for (int i = 0; i < 7; i++) {
        final a = _rng.nextDouble() * 2 * pi, sp = 80 + _rng.nextDouble() * 140;
        parts.add(Part(x, y, cos(a) * sp, sin(a) * sp, 0.4 + _rng.nextDouble() * 0.3, 2 + _rng.nextDouble() * 2, col));
      }
    } else if (type == 1) {
      parts.add(Part(x, y, 0, 0, 0.4, weapons[wi].radius, const Color(0xFFFFA726), ring: true));
      const cols = [Color(0xFFFF7043), Color(0xFFFFCA28), Colors.white, Color(0xFFFF5722)];
      for (int i = 0; i < 26; i++) {
        final a = _rng.nextDouble() * 2 * pi, sp = 100 + _rng.nextDouble() * 350;
        parts.add(Part(x, y, cos(a) * sp, sin(a) * sp, 0.5 + _rng.nextDouble() * 0.5, 3 + _rng.nextDouble() * 4, cols[_rng.nextInt(cols.length)]));
      }
      HapticFeedback.mediumImpact();
    } else if (type == 2) {
      const cols = [Colors.red, Colors.yellow, Colors.cyan, Colors.pinkAccent, Colors.lightGreenAccent, Colors.orange];
      for (int i = 0; i < 28; i++) {
        final a = _rng.nextDouble() * 2 * pi, sp = 100 + _rng.nextDouble() * 280;
        parts.add(Part(x, y, cos(a) * sp, sin(a) * sp - 120, 0.8 + _rng.nextDouble() * 0.6, 3 + _rng.nextDouble() * 3, cols[_rng.nextInt(cols.length)]));
      }
    } else {
      for (int i = 0; i < 10; i++) {
        final a = _rng.nextDouble() * 2 * pi, sp = 60 + _rng.nextDouble() * 120;
        parts.add(Part(x, y, cos(a) * sp, sin(a) * sp - 80, 0.5, 3, const Color(0xFFFFEB3B)));
      }
    }
  }

  void _tick(Duration d) {
    var dt = (d - _last).inMicroseconds / 1e6;
    _last = d;
    if (dt > 0.033) dt = 0.033;
    if (dt <= 0 || !mounted) return;
    t += dt;
    final size = MediaQuery.of(context).size;

    // المدخلات
    final mx = mv.dx.abs() > 0.15 ? mv.dx : 0.0;
    final up = (-mv.dy) > 0.5 ? 1.0 : 0.0;
    if (aimActive && aimv.distance > 0.2) {
      lastAim = atan2(aimv.dy, aimv.dx);
    } else if (!aimActive && mx.abs() > 0.2) {
      lastAim = mx > 0 ? 0 : pi;
    }
    final shoot = aimActive && aimv.distance > 0.35;

    if (world != null) {
      final me = world!.ps[0];
      me.inp.mx = mx;
      me.inp.up = up;
      me.inp.aim = lastAim;
      me.inp.shoot = shoot;
      if (swapPending) {
        me.inp.swap = true;
        swapPending = false;
      }
      world!.update(dt);
      final sm = world!.snap();
      widget.net?.send(sm);
      _applySnap(parseSnap(sm));
    } else {
      widget.net?.send({'t': 'i', 'mx': _r2(mx), 'up': up, 'a': _r2(lastAim), 's': shoot ? 1 : 0, 'w': swapPending ? 1 : 0});
      swapPending = false;
    }

    // الجزيئات
    for (int i = parts.length - 1; i >= 0; i--) {
      final p = parts[i];
      p.life -= dt;
      if (p.life <= 0) {
        parts.removeAt(i);
        continue;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      if (!p.ring) p.vy += 500 * dt;
    }

    // الكاميرا
    final s = snap;
    if (s != null) {
      PV? me;
      for (final p in s.ps) {
        if (p.id == myId) me = p;
      }
      if (me != null) {
        final sc = size.height / kViewH;
        final vw = size.width / sc;
        final tx = _cl(me.x - vw / 2, -40, map.w + 40 - vw);
        final ty = _cl(me.y - kViewH / 2 - 30, -40, map.h + 40 - kViewH);
        if (!camInit) {
          camX = tx;
          camY = ty;
          camInit = true;
        } else {
          final k = min(1.0, dt * 8);
          camX += (tx - camX) * k;
          camY += (ty - camY) * k;
        }
      }
    }
    setState(() {});
  }

  Widget _bar(double v, Color c, double w) {
    return Container(
      width: w,
      height: 8,
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: _cl(v, 0, 1),
        child: Container(decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(4))),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = snap;
    final size = MediaQuery.of(context).size;
    final sc = size.height / kViewH;
    PV? me;
    if (s != null) {
      for (final p in s.ps) {
        if (p.id == myId) me = p;
      }
    }
    final children = <Widget>[];
    if (s != null) {
      children.add(Positioned.fill(child: CustomPaint(painter: GamePainter(s, map, mode, camX, camY, sc, t, myId, parts))));
    }

    // الأزرار
    children.add(Positioned(
      left: 20,
      bottom: 16,
      child: Stick(color: Colors.white, onChanged: (v, a) => mv = a ? v : Offset.zero),
    ));
    children.add(Positioned(
      right: 20,
      bottom: 16,
      child: Stick(
          color: const Color(0xFFFF7043),
          onChanged: (v, a) {
            aimActive = a;
            aimv = v;
          }),
    ));
    children.add(Positioned(
      right: 190,
      bottom: 40,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => swapPending = true,
        child: Container(
          width: 58,
          height: 58,
          decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
          child: const Center(child: Text('🔄', style: TextStyle(fontSize: 26))),
        ),
      ),
    ));

    if (s != null) {
      // الشريط العلوي
      final sorted = List<PV>.from(s.ps)..sort((a, b) => b.kills.compareTo(a.kills));
      final tl = max(0, s.timeLeft).ceil();
      children.add(Positioned(
        top: 6,
        left: 8,
        right: 8,
        child: Row(children: [
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(color: Color(0x66000000), shape: BoxShape.circle),
              child: const Icon(Icons.close, size: 20),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Wrap(spacing: 4, runSpacing: 4, children: [
              for (final p in sorted.take(6))
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
                  child: Text('${p.name} ${p.kills}', style: TextStyle(fontSize: 12, color: p.id == myId ? const Color(0xFFFFEB3B) : Colors.white)),
                ),
            ]),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
            child: Text('⏱ ${tl ~/ 60}:${(tl % 60).toString().padLeft(2, '0')}  |  🎯 ${mode.killLimit}', style: const TextStyle(fontSize: 12)),
          ),
        ]),
      ));

      // حالتي
      if (me != null) {
        final wd = weapons[me.wi];
        children.add(Positioned(
          top: 48,
          left: 10,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _bar(me.hp / me.maxHp, Colors.greenAccent, 140),
            const SizedBox(height: 4),
            _bar(me.fuel / 100, Colors.lightBlueAccent, 140),
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text('${wd.emoji} ${wd.name}  ${me.reload ? 'تعبئة...' : '${me.ammo}'}', style: const TextStyle(fontSize: 12)),
            ),
          ]),
        ));
        if (!me.alive && !s.over) {
          children.add(Center(child: Text('هترجع بعد ${me.respawn.ceil()} 💀', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 6, color: Colors.black)]))));
        }
      }

      // سجل القتل
      children.add(Positioned(
        top: 48,
        right: 10,
        child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          for (final f in s.feed)
            Container(
              margin: const EdgeInsets.only(bottom: 3),
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(6)),
              child: Text(f, style: const TextStyle(fontSize: 11)),
            ),
        ]),
      ));

      // نهاية اللعبة
      if (s.over) {
        String wn = '';
        for (final p in s.ps) {
          if (p.id == s.winner) wn = p.name;
        }
        children.add(Positioned.fill(
          child: Container(
            color: Colors.black87,
            child: Center(
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('🏆 $wn فاز!', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  for (int i = 0; i < sorted.length; i++)
                    Text('${i + 1}. ${sorted[i].name}  —  ${sorted[i].kills} قتل  /  ${sorted[i].deaths} موت', style: const TextStyle(fontSize: 15)),
                  const SizedBox(height: 14),
                  ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع للقايمة')),
                ]),
              ),
            ),
          ),
        ));
      }
    }

    if (msg != null) {
      children.add(Positioned.fill(
        child: Container(
          color: Colors.black87,
          child: Center(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(msg!, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 12),
              ElevatedButton(onPressed: () => Navigator.of(context).pop(), child: const Text('رجوع')),
            ]),
          ),
        ),
      ));
    }

    return Scaffold(backgroundColor: Colors.black, body: Stack(children: children));
  }
}

// ======================== القايمة الرئيسية ========================
class MenuScreen extends StatefulWidget {
  const MenuScreen({Key? key}) : super(key: key);
  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  SharedPreferences? sp;
  final nameC = TextEditingController(text: 'لاعب');
  int ch = 0, wp = 0, map = 0, mode = 0, bots = 3, totalKills = 0, wins = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    nameC.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    sp = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      nameC.text = sp!.getString('name') ?? 'لاعب';
      ch = (sp!.getInt('ch') ?? 0).clamp(0, chars.length - 1).toInt();
      wp = (sp!.getInt('wp') ?? 0).clamp(0, weapons.length - 1).toInt();
      map = (sp!.getInt('map') ?? 0).clamp(0, maps.length - 1).toInt();
      mode = (sp!.getInt('mode') ?? 0).clamp(0, modes.length - 1).toInt();
      bots = (sp!.getInt('bots') ?? 3).clamp(0, 5).toInt();
      totalKills = sp!.getInt('kills') ?? 0;
      wins = sp!.getInt('wins') ?? 0;
    });
  }

  void _save() {
    final s = sp;
    if (s == null) return;
    s.setString('name', nameC.text);
    s.setInt('ch', ch);
    s.setInt('wp', wp);
    s.setInt('map', map);
    s.setInt('mode', mode);
    s.setInt('bots', bots);
  }

  GameConfig _cfg(int role) {
    final n = nameC.text.trim().isEmpty ? 'لاعب' : nameC.text.trim();
    return GameConfig(role: role, map: map, mode: mode, bots: role == 2 ? 0 : bots, ch: ch, wp: wp, name: n);
  }

  Widget _chips(List<String> labels, int sel, void Function(int) on) {
    return Wrap(spacing: 6, runSpacing: 6, children: [
      for (int i = 0; i < labels.length; i++)
        ChoiceChip(
          label: Text(labels[i]),
          selected: sel == i,
          onSelected: (_) {
            setState(() => on(i));
            _save();
          },
        ),
    ]);
  }

  Widget _title(String s) => Padding(padding: const EdgeInsets.only(top: 14, bottom: 6), child: Text(s, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF58A6FF))));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(padding: const EdgeInsets.all(16), children: [
          const Center(child: Text('🚀 فوضى الجيتباك', style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold))),
          Center(child: Text('إجمالي القتلى: $totalKills   |   الفوز: $wins', style: const TextStyle(color: Colors.white60))),
          const SizedBox(height: 10),
          TextField(
            controller: nameC,
            maxLength: 12,
            onChanged: (_) => _save(),
            decoration: const InputDecoration(labelText: 'اسمك', border: OutlineInputBorder()),
          ),
          _title('الشخصية'),
          Row(children: [
            SizedBox(width: 90, height: 120, child: CustomPaint(painter: AvatarPainter(ch))),
            const SizedBox(width: 8),
            Expanded(child: _chips([for (final c in chars) c.name], ch, (i) => ch = i)),
          ]),
          _title('السلاح الأساسي'),
          _chips([for (final w in weapons) '${w.emoji} ${w.name}'], wp, (i) => wp = i),
          _title('الماب'),
          _chips([for (final m in maps) '${m.emoji} ${m.name}'], map, (i) => map = i),
          _title('المود'),
          _chips([for (final m in modes) '${m.emoji} ${m.name}'], mode, (i) => mode = i),
          Padding(padding: const EdgeInsets.only(top: 6), child: Text(modes[mode].desc, style: const TextStyle(color: Colors.white60))),
          _title('عدد البوتات: $bots'),
          Slider(
            value: bots.toDouble(),
            min: 0,
            max: 5,
            divisions: 5,
            onChanged: (v) => setState(() => bots = v.round()),
            onChangeEnd: (_) => _save(),
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.play_arrow),
            label: const Text('العب ضد البوتات', style: TextStyle(fontSize: 16)),
            onPressed: () {
              _save();
              Navigator.push(context, MaterialPageRoute(builder: (_) => GameScreen(cfg: _cfg(0)))).then((_) => _load());
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.wifi_tethering),
            label: const Text('استضافة لعبة (هوت سبوت)', style: TextStyle(fontSize: 16)),
            onPressed: () {
              _save();
              Navigator.push(context, MaterialPageRoute(builder: (_) => HostScreen(cfg: _cfg(1)))).then((_) => _load());
            },
          ),
          const SizedBox(height: 8),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(14)),
            icon: const Icon(Icons.group_add),
            label: const Text('انضم لصديق', style: TextStyle(fontSize: 16)),
            onPressed: () {
              _save();
              Navigator.push(context, MaterialPageRoute(builder: (_) => JoinScreen(cfg: _cfg(2)))).then((_) => _load());
            },
          ),
        ]),
      ),
    );
  }
}

// ======================== استضافة ========================
class HostScreen extends StatefulWidget {
  final GameConfig cfg;
  const HostScreen({Key? key, required this.cfg}) : super(key: key);
  @override
  State<HostScreen> createState() => _HostScreenState();
}

class _HostScreenState extends State<HostScreen> {
  ServerSocket? server;
  Net? net;
  List<String> ips = [];
  String status = 'في انتظار صديقك...';
  bool joined = false, started = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4);
      ips = [
        for (final i in ifs)
          for (final a in i.addresses)
            if (!a.isLoopback) '${a.address}   (${i.name})'
      ];
      server = await ServerSocket.bind(InternetAddress.anyIPv4, 4567);
      server!.listen((sock) {
        if (net != null) {
          sock.destroy();
          return;
        }
        final n = Net(sock);
        net = n;
        n.onMsg = (m) {
          if (m['t'] == 'hello') {
            widget.cfg.rName = (m['name'] ?? 'صديقك').toString();
            widget.cfg.rCh = (m['ch'] as int).clamp(0, chars.length - 1).toInt();
            widget.cfg.rWp = (m['wp'] as int).clamp(0, weapons.length - 1).toInt();
            if (mounted) {
              setState(() {
                joined = true;
                status = '✅ ${widget.cfg.rName} دخل! اضغط ابدأ';
              });
            }
          }
        };
        n.onClose = () {
          net = null;
          if (mounted && !started) {
            setState(() {
              joined = false;
              status = 'صديقك خرج. في انتظار حد تاني...';
            });
          }
        };
      });
      if (mounted) setState(() {});
    } catch (e) {
      if (mounted) setState(() => status = 'حصل خطأ: $e');
    }
  }

  @override
  void dispose() {
    if (!started) {
      net?.onClose = null;
      net?.close();
    }
    server?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('استضافة لعبة')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('1) شغّل الهوت سبوت من موبايلك\n2) خلّي صديقك يتوصل بيه\n3) هو يختار "انضم لصديق" ويكتب الـ IP اللي تحت', style: TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),
          const Text('الـ IP بتاعك:', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          if (ips.isEmpty) const Text('مفيش شبكة ظاهرة، شغّل الهوت سبوت وارجع'),
          for (final ip in ips) SelectableText(ip, style: const TextStyle(fontSize: 20, color: Color(0xFF58A6FF), fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          Text(status, style: const TextStyle(fontSize: 18)),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: joined
                  ? () {
                      started = true;
                      final n = net!;
                      n.send({'t': 'start', 'map': widget.cfg.map, 'mode': widget.cfg.mode});
                      server?.close();
                      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(cfg: widget.cfg, net: n)));
                    }
                  : null,
              child: const Text('ابدأ اللعبة', style: TextStyle(fontSize: 18)),
            ),
          ),
        ]),
      ),
    );
  }
}

// ======================== الانضمام ========================
class JoinScreen extends StatefulWidget {
  final GameConfig cfg;
  const JoinScreen({Key? key, required this.cfg}) : super(key: key);
  @override
  State<JoinScreen> createState() => _JoinScreenState();
}

class _JoinScreenState extends State<JoinScreen> {
  final ipC = TextEditingController(text: '192.168.43.1');
  String status = '';
  bool busy = false, started = false;
  Net? net;

  @override
  void initState() {
    super.initState();
    SharedPreferences.getInstance().then((sp) {
      final ip = sp.getString('ip');
      if (ip != null && mounted) setState(() => ipC.text = ip);
    });
  }

  @override
  void dispose() {
    ipC.dispose();
    if (!started) {
      net?.onClose = null;
      net?.close();
    }
    super.dispose();
  }

  Future<void> _connect() async {
    final ip = ipC.text.trim();
    if (ip.isEmpty) return;
    setState(() {
      busy = true;
      status = 'بتوصل...';
    });
    try {
      final sp = await SharedPreferences.getInstance();
      sp.setString('ip', ip);
      final sock = await Socket.connect(ip, 4567, timeout: const Duration(seconds: 6));
      final n = Net(sock);
      net = n;
      n.onMsg = (m) {
        if (m['t'] == 'start' && mounted && !started) {
          started = true;
          final c = GameConfig(role: 2, map: m['map'] as int, mode: m['mode'] as int, bots: 0, ch: widget.cfg.ch, wp: widget.cfg.wp, name: widget.cfg.name);
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GameScreen(cfg: c, net: n)));
        }
      };
      n.onClose = () {
        if (mounted && !started) {
          setState(() {
            busy = false;
            status = 'الاتصال اتقطع';
          });
        }
      };
      n.send({'t': 'hello', 'name': widget.cfg.name, 'ch': widget.cfg.ch, 'wp': widget.cfg.wp});
      if (mounted) setState(() => status = '✅ اتوصلت! مستني الهوست يبدأ اللعبة...');
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          status = 'مقدرتش أوصل: $e\nتأكد إنك متوصل بالهوت سبوت والـ IP صح';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('انضم لصديق')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('اتوصل بالهوت سبوت بتاع صديقك، وبعدين اكتب الـ IP اللي ظاهر عنده.', style: TextStyle(fontSize: 15, height: 1.6)),
          const SizedBox(height: 16),
          TextField(
            controller: ipC,
            keyboardType: TextInputType.number,
            textDirection: TextDirection.ltr,
            decoration: const InputDecoration(labelText: 'IP الهوست', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(padding: const EdgeInsets.all(16)),
              onPressed: busy ? null : _connect,
              child: const Text('اتصل', style: TextStyle(fontSize: 18)),
            ),
          ),
          const SizedBox(height: 16),
          Text(status, style: const TextStyle(fontSize: 16)),
        ]),
      ),
    );
  }
}
