import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import qs.Commons
import qs.Ui
import "Sprites.js" as Sprites
import "PetBus.js" as PetBus

// Bar Buddies — Dash and his dog Biscuit live on your Omarchy bar.
//   * They wander, hop over widgets and stand on them. Now and then Dash pushes
//     a row of widgets along, or ties a rope to one and drags it while Biscuit
//     tugs; moved widgets glide home after about a minute.
//   * Dash throws a ball, bone or frisbee and Biscuit fetches it.
//   * Bring the mouse near and Dash runs; corner him and he vaults or vanishes.
//     Catching him is 1 in 1000. Click Biscuit to pet him.
//   * Dances when music plays, sleeps late at night.
// The widget itself is invisible. Every bar publishes where its widgets are;
// the first screen's instance runs the simulation and draws every monitor.
//   omarchy-shell bar-buddies toggle | poof | dance | fetch | push | pull | home | play | next
//   omarchy-shell bar-buddies cheer "Build" | alert "CI" | hide | show | stats
BarWidget {
  id: root
  moduleName: "bar-buddies"
  implicitWidth: 0
  implicitHeight: barSize

  readonly property var spr: Sprites.build()
  readonly property string home: Quickshell.env("HOME")
  property bool leader: false
  property bool enabled: true
  property int caughtCount: 0
  property int petCount: 0

  // ---- obstacle map (every bar instance) ------------------------------------
  function publish() {
    var win = root.QsWindow ? root.QsWindow.window : null
    if (!win || !win.screen || !win.contentItem) return
    var scr = win.screen
    var obs = [], ground = 0
    // Positions are stored without the runner's offset (bx1/bx2) so a widget
    // he moved keeps its home; x1/x2 = home + current offset.
    function add(o, key) {
      var off = PetBus.offsets[key] || 0
      o.key = key; o.bx1 = o.x1 - off; o.bx2 = o.x2 - off
      obs.push(o)
    }
    function pills(it, key) {
      var kids = it.children
      for (var i = 0; i < kids.length; i++) {
        var c = kids[i]
        if (!c || !c.visible) continue
        if (c.wsId !== undefined && c.width > 4) {
          var p = c.mapToItem(null, 0, 0)
          add({ x1: scr.x + p.x, x2: scr.x + p.x + c.width, top: p.y, h: c.height, ws: c.wsId }, key)
        } else pills(c, key)
      }
    }
    function walk(it) {
      var kids = it.children
      for (var i = 0; i < kids.length; i++) {
        var c = kids[i]
        if (!c || !c.visible || c.opacity <= 0.01) continue
        if (typeof c.moduleName === "string" && c.moduleName !== "" && c !== root) {
          if (c.width < 4 || c.height < 4) continue
          var key = scr.name + "|" + c.moduleName
          PetBus.items[key] = c
          var p = c.mapToItem(null, 0, 0)
          ground = Math.max(ground, p.y + c.height)
          if (c.moduleName.indexOf("workspaces") >= 0) { pills(c, key); continue }
          var h = Math.min(c.height, Style.space(24))
          add({ x1: scr.x + p.x + 3, x2: scr.x + p.x + c.width - 3,
                top: p.y + Math.max(0, (c.height - h) / 2), h: h, id: c.moduleName }, key)
          continue
        }
        walk(c)
      }
    }
    walk(win.contentItem)
    PetBus.setScreen(scr.name, { name: scr.name, x0: scr.x, w: scr.width, h: scr.height,
                                 ground: ground > 0 ? ground : scr.height, obstacles: obs, at: Date.now() })
    var first = Quickshell.screens.length ? Quickshell.screens[0].name : scr.name
    leader = scr.name === first
  }
  Timer { interval: 2500; running: true; repeat: true; triggeredOnStart: true; onTriggered: root.publish() }

  // ---- persistent state ---------------------------------------------------
  FileView {
    id: stateFile
    path: root.home + "/.local/state/bar-buddies/state.json"
    printErrors: false
    atomicWrites: true
    onLoaded: {
      try {
        var j = JSON.parse(text())
        root.enabled = j.enabled !== false
        root.caughtCount = j.caught || 0
        root.petCount = j.pets || 0
      } catch (e) {}
    }
  }
  function save() {
    if (!leader) return
    stateFile.setText(JSON.stringify({ enabled: enabled, caught: caughtCount, pets: petCount }))
  }
  Process { id: notifier }

  // ---- inputs: cursor, music, agents, focus --------------------------------
  property var cur: ({ x: -9999, y: -9999, moved: Date.now() })
  property string curBuf: ""
  Socket {
    id: hypr
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/hypr/" + Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") + "/.socket.sock"
    onConnectedChanged: {
      if (connected) { write("j/cursorpos"); flush() }
      else {
        var mx = /"x":\s*(-?\d+)/.exec(root.curBuf), my = /"y":\s*(-?\d+)/.exec(root.curBuf)
        root.curBuf = ""
        if (mx && my) {
          var nx = Number(mx[1]), ny = Number(my[1])
          if (nx !== root.cur.x || ny !== root.cur.y) root.cur = { x: nx, y: ny, moved: Date.now() }
        }
      }
    }
    parser: SplitParser { onRead: function(line) { root.curBuf += line } }
  }
  readonly property bool cursorClose: cur.y > groundY - 220
  Timer {
    interval: root.cursorClose ? 40 : 220
    running: root.leader && root.enabled
    repeat: true
    onTriggered: if (!hypr.connected) hypr.connected = true
  }

  readonly property bool musicOn: {
    var ps = Mpris.players ? Mpris.players.values : []
    for (var i = 0; i < ps.length; i++) if (ps[i].isPlaying) return true
    return false
  }

  // Hidden while something else wants the bar quiet (see `hide`/`show` IPC).
  property bool focusActive: false
  onFocusActiveChanged: if (leader) { if (focusActive) hideAll(); else showAll() }
  onEnabledChanged: if (leader) { if (!enabled) hideAll(); else if (!focusActive) showAll() }

  // ---- world --------------------------------------------------------------
  readonly property real grav: 0.55          // gravity, px/frame² at 60 fps
  property var scrs: []
  property real worldMin: 0
  property real worldMax: 1920
  property real groundY: 1080
  function refreshWorld() {
    var all = PetBus.allScreens(), list = []
    for (var k in all) if (Date.now() - all[k].at < 15000) list.push(all[k])
    list.sort(function(a, b) { return a.x0 - b.x0 })
    if (!list.length) return
    for (var i = 0; i < list.length; i++)
      for (var j = 0; j < list[i].obstacles.length; j++) {
        var o = list[i].obstacles[j], off = PetBus.offsets[o.key] || 0
        o.x1 = o.bx1 + off; o.x2 = o.bx2 + off
      }
    scrs = list
    worldMin = list[0].x0
    worldMax = list[list.length - 1].x0 + list[list.length - 1].w
    groundY = list[0].ground
  }
  function scrAt(x) {
    for (var i = 0; i < scrs.length; i++) if (x >= scrs[i].x0 && x < scrs[i].x0 + scrs[i].w) return scrs[i]
    return scrs.length ? (x < worldMin ? scrs[0] : scrs[scrs.length - 1]) : null
  }
  // the obstacle under a body of half-width hw at x, or null
  function obsAt(x, hw) {
    var s = scrAt(x), best = null
    if (!s) return null
    for (var i = 0; i < s.obstacles.length; i++) {
      var o = s.obstacles[i]
      if (x + hw > o.x1 && x - hw < o.x2 && (!best || o.top < best.top)) best = o
    }
    return best
  }
  function surface(x, hw) {
    var s = scrAt(x)
    if (!s) return groundY - 2
    var o = obsAt(x, hw)
    return o ? o.top : s.ground - 2
  }

  // ---- moving widgets ---------------------------------------------------------
  // He slides real bar widgets along with a Translate (layout is untouched, so
  // nothing reflows); after a while they glide back home.
  readonly property real rope: 30            // rope length, widget edge -> hands
  property var trs: ({})                     // key -> { item, tr }
  property var homeAt: ({})                  // key -> when it slides back
  function setOff(key, v) {
    PetBus.offsets[key] = v
    var it = PetBus.items[key]
    if (it) {
      var e = trs[key]
      if (!e || e.item !== it) {
        var tr = Qt.createQmlObject("import QtQuick; Translate {}", it)
        var list = []
        for (var i = 0; i < it.transform.length; i++) list.push(it.transform[i])
        list.push(tr)
        it.transform = list
        e = trs[key] = { item: it, tr: tr }
      }
      e.tr.x = v
    }
    for (var s = 0; s < scrs.length; s++) {
      var obs = scrs[s].obstacles
      for (var j = 0; j < obs.length; j++)
        if (obs[j].key === key) { obs[j].x1 = obs[j].bx1 + v; obs[j].x2 = obs[j].bx2 + v }
    }
  }
  // whole widgets on a screen (workspace pills merged), with the free floor
  // to each side
  function widgetsOn(s) {
    var m = {}, out = []
    for (var i = 0; i < s.obstacles.length; i++) {
      var o = s.obstacles[i], w = m[o.key]
      if (!w) { w = m[o.key] = { key: o.key, x1: o.x1, x2: o.x2, top: o.top, h: o.h || 24 }; out.push(w) }
      else { w.x1 = Math.min(w.x1, o.x1); w.x2 = Math.max(w.x2, o.x2); w.top = Math.min(w.top, o.top) }
    }
    out.sort(function(a, b) { return a.x1 - b.x1 })
    for (i = 0; i < out.length; i++) {
      out[i].gapL = out[i].x1 - (i ? out[i - 1].x2 : s.x0)
      out[i].gapR = (i < out.length - 1 ? out[i + 1].x1 : s.x0 + s.w) - out[i].x2
    }
    return out
  }
  function widget(key) {
    var sn = key.split("|")[0]
    for (var i = 0; i < scrs.length; i++) {
      if (scrs[i].name !== sn) continue
      var ws = widgetsOn(scrs[i])
      for (var j = 0; j < ws.length; j++) if (ws[j].key === key) return ws[j]
    }
    return null
  }
  // the edge he holds: the back edge when pushing, the near edge when pulling
  function jobEdge(j) {
    var w = widget(j.key)
    if (!w) return null
    return (j.kind === "push") === (j.dir > 0) ? w.x1 : w.x2
  }
  function jobSpot(j) {
    var e = jobEdge(j)
    if (e === null) return null
    return j.kind === "push" ? e - j.dir * 8 : e + j.dir * rope
  }
  // Pick something with room to slide into. Widgets sit ~6px apart, so a push
  // moves a whole cluster (he shoves the end one and the rest go with it);
  // a pull drags one widget out of its cluster, with room for him and the dog.
  function planMove(t, kind) {
    var s = scrAt(g.x)
    if (!s) return false
    var ws = widgetsOn(s), opts = [], groups = [], i, dir
    for (i = 0; i < ws.length; i++) {
      if (i && ws[i].gapL < 18) groups[groups.length - 1].push(ws[i])
      else groups.push([ws[i]])
    }
    function moved(list) {
      for (var q = 0; q < list.length; q++) if (Math.abs(PetBus.offsets[list[q].key] || 0) > 1) return true
      return false
    }
    function add(back, list, gapTo, need) {
      var room = gapTo - need
      if (room < 24 || moved(list)) return
      opts.push({ key: back.key, keys: list.map(function(w) { return w.key }), dir: dir,
                  dist: Math.min(room, 30 + Math.random() * 60), far: Math.abs((back.x1 + back.x2) / 2 - g.x) })
    }
    for (dir = -1; dir <= 1; dir += 2) {
      if (kind === "push") {
        for (i = 0; i < groups.length; i++) {
          var gr = groups[i], first = gr[0], last = gr[gr.length - 1]
          var behind = dir > 0 ? first.gapL : last.gapR
          if (behind >= 18) add(dir > 0 ? first : last, gr, dir > 0 ? last.gapR : first.gapL, 14)
        }
      } else {
        for (i = 0; i < ws.length; i++)
          if (ws[i].x2 - ws[i].x1 < 400) add(ws[i], [ws[i]], dir > 0 ? ws[i].gapR : ws[i].gapL, 110)
      }
    }
    if (!opts.length) return false
    opts.sort(function(a, b) { return a.far - b.far })
    var o = opts[Math.floor(Math.random() * Math.min(3, opts.length))]
    g.job = { kind: kind, key: o.key, keys: o.keys, dir: o.dir, dist: o.dist, moved: 0, t0: t, heave: 0 }
    g.tx = jobSpot(g.job)
    g.mode = "goPush"; g.until = t
    return true
  }
  function endJob(t, ok) {
    var j = g.job
    g.job = null
    if (!j) return
    if (j.moved > 0.5) {
      var back = t + 45000 + Math.random() * 30000
      for (var i = 0; i < j.keys.length; i++) homeAt[j.keys[i]] = back
    }
    if (!ok) return
    g.mode = "cheer"; g.until = t + 1400; g.vx = 0
    sayG(pick(j.kind === "pull" ? ["teamwork!", "good boy, Biscuit!", "got it!"] : ["it moved!", "phew", "there."]))
    burst(g.x, g.y - 32, "★", "#ffd166", 3, 24, 10)
    d.barkUntil = t + 400; sayD(pick(["woof!", "♥"]), 900)
  }

  // ---- characters -----------------------------------------------------------
  // Plain JS state; the r* properties below are what the overlays bind to.
  property var g: ({ x: 400, y: 0, vx: 0, vy: 0, ground: false, face: 1, mode: "idle", until: 0,
                     tx: 0, frameAt: 0, alt: false, hidden: false, job: null, fleeAt: 0, blinkAt: 0 })
  // d = the dog
  property var d: ({ x: 370, y: 0, vx: 0, vy: 0, ground: false, face: 1, mode: "follow", until: 0,
                     hidden: false, poofAt: 0, barkUntil: 0 })
  property var play: null

  property real gX: 400;  property real gY: 0;  property string gFrame: "stand"; property bool gFlip: false
  property real gRot: 0;  property real gAlpha: 0
  property real dX: 370;  property real dY: 0;  property string dFrame: "stand"; property bool dFlip: false
  property real dRot: 0;  property real dAlpha: 0
  property string gSay: ""; property real gSayUntil: 0
  property string dSay: ""; property real dSayUntil: 0
  property real now: Date.now()
  // fetch: { n: throws left, phase, t, toy: { kind, x, y, vx, vy, rot, state: held|air|roll|ground|mouth } }
  property var fetch: null
  property bool toyOn: false; property string toyKind: "ball"
  property real toyX: 0; property real toyY: 0; property real toyRot: 0
  property bool ropeOn: false
  property real rAx: 0; property real rAy: 0
  property real rBx: 0; property real rBy: 0
  property real rCx: 0; property real rCy: 0

  function sayG(t, ms) { gSay = t; gSayUntil = Date.now() + (ms || 1600) }
  function sayD(t, ms) { dSay = t; dSayUntil = Date.now() + (ms || 1200) }
  function pick(a) { return a[Math.floor(Math.random() * a.length)] }

  // particles: {x, y (screen-local), text, color, size, vx, vy, life}
  ListModel { id: parts }
  function burst(x, y, text, color, n, spread, size) {
    for (var i = 0; i < n; i++)
      parts.append({ px: x + (Math.random() - 0.5) * spread, py: y - Math.random() * 6, txt: text,
                     col: String(color), size: size || 11,
                     dx: (Math.random() - 0.5) * (spread + 30), dy: -18 - Math.random() * 30,
                     born: Date.now(), life: 900 + Math.random() * 600 })
  }
  function confetti(x, y) {
    var cols = ["#e5484d", "#3fa7f5", "#ffd166", "#4ade80", "#c084fc", "#ff7aa8"]
    for (var i = 0; i < 26; i++)
      parts.append({ px: x, py: y, txt: "▪", col: cols[i % cols.length], size: 10 + Math.random() * 6,
                     dx: (Math.random() - 0.5) * 160, dy: -30 - Math.random() * 60,
                     born: Date.now(), life: 1400 + Math.random() * 800 })
  }

  function poof(e, isGuy) {
    burst(e.x, e.y - 14, "✦", "#e8e8f0", 7, 24, 10)
  }
  function teleportGuy() {
    if (fetch) endFetch()
    poof(g, true)
    var x, tries = 0
    do {
      x = worldMin + 40 + Math.random() * (worldMax - worldMin - 80)
      tries++
    } while (Math.abs(x - cur.x) < 500 && tries < 20)
    g.x = x; g.y = surface(x, 6) - 50; g.vx = 0; g.vy = 0; g.ground = false
    g.mode = "taunt"; g.until = Date.now() + 1500
    g.face = cur.x > x ? 1 : -1
    sayG(pick(["over here!", "too slow!", "hehe", "nope", "missed me!", "Dash is too fast!"]))
    if (Math.abs(d.x - g.x) > 700) d.poofAt = Date.now() + 700
  }
  function hideAll() {
    if (fetch) endFetch()
    if (!g.hidden) poof(g, true)
    if (!d.hidden) poof(d, false)
    g.hidden = true; d.hidden = true
  }
  function showAll() {
    g.hidden = false; d.hidden = false
    g.x = Math.max(worldMin + 60, Math.min(worldMax - 60, g.x))
    g.y = surface(g.x, 7) - 60; d.x = g.x - 30; d.y = surface(d.x, 9) - 60; d.mode = "follow"
    g.mode = "idle"; g.until = 0
    poof(g, true)
  }

  function react(kind, who) {
    if (g.hidden) return
    if (kind === "done") { g.mode = "cheer"; g.until = Date.now() + 2600; g.vx = 0; sayG("✓ " + who + " done!", 2600); burst(g.x, g.y - 32, "★", "#ffd166", 5, 30, 11) }
    else { g.mode = "wave"; g.until = Date.now() + 2600; g.vx = 0; sayG("! " + who + " needs you", 2600) }
  }

  function guyTouched() {
    if (g.hidden || g.mode === "caught") return
    if (g.mode !== "vault") teleportGuy()
  }
  function guyClicked() {
    if (g.hidden || g.mode === "caught") return
    if (Math.random() < 0.001) {
      g.mode = "caught"; g.until = Date.now() + 5200; g.vx = 0
      caughtCount++; save()
      confetti(g.x, g.y - 30)
      sayG("you got me!! 🏆 #" + caughtCount, 5000)
      d.mode = "pet"; d.until = Date.now() + 5000
      notifier.command = ["notify-send", "-a", "Bar Buddies", "-u", "critical", "🏆 You caught Dash!",
                          "Catch #" + caughtCount + ". The odds were 1 in 1000. Biscuit is proud of you."]
      notifier.running = true
    } else teleportGuy()
  }
  function dogClicked() {
    if (d.hidden) return
    d.mode = "pet"; d.until = Date.now() + 1600; d.vx = 0
    petCount++; save()
    burst(d.x, d.y - 22, "♥", "#ff7aa8", 3, 16, 12)
    sayD(pick(["♥", "woof!", "*wag wag*", "♥♥"]))
  }

  // ---- physics -----------------------------------------------------------------
  // noHop: walking up to a widget to push it, so don't hop onto it
  function physics(e, hw, f, noHop) {
    var dir = e.vx > 0 ? 1 : (e.vx < 0 ? -1 : 0)
    if (e.ground && dir !== 0 && !noHop) {
      var ahead = surface(e.x + dir * (hw + 4), hw)
      if (ahead < e.y - 3) { e.vy = -Math.sqrt(2 * grav * (e.y - ahead + 10)); e.ground = false }
    }
    e.x = Math.max(worldMin + hw, Math.min(worldMax - hw, e.x + e.vx * f))
    e.vy += grav * f
    e.y += e.vy * f
    var sy = surface(e.x, hw)
    if (e.vy >= 0 && e.y >= sy) {
      if (!e.ground && e.vy > 2.5) {
        var on = obsAt(e.x, hw)
        if (on && on.ws !== undefined) PetBus.emit({ type: "stomp", ws: on.ws, screen: scrAt(e.x).name })
      }
      e.y = sy; e.vy = 0; e.ground = true
    } else if (e.y < sy - 0.5) e.ground = false
  }

  // ---- fetch -------------------------------------------------------------------
  function startFetch(t) {
    if (d.hidden || Math.abs(d.x - g.x) > 400) return false
    fetch = { n: 2 + Math.floor(Math.random() * 2), phase: "windup", t: t + 900,
              toy: { kind: pick(["ball", "ball", "bone", "frisbee"]), x: 0, y: 0, vx: 0, vy: 0, rot: 0, state: "held" } }
    g.mode = "fetch"; g.until = t + 45000; g.vx = 0
    g.face = d.x > g.x ? 1 : -1
    sayG(pick(["Biscuit! fetch?", "wanna play, boy?", "look what I got!"]), 1300)
    return true
  }
  function endFetch() {
    if (fetch && fetch.toy.state !== "held") burst(fetch.toy.x, fetch.toy.y - 4, "✦", "#e8e8f0", 4, 12, 9)
    fetch = null
    if (d.mode === "fetch") d.mode = "follow"
  }
  function launchToy() {
    var T = fetch.toy, s = scrAt(g.x)
    var lo = s ? s.x0 + 30 : worldMin + 30, hi = s ? s.x0 + s.w - 30 : worldMax - 30
    var dir = (hi - g.x) > (g.x - lo) ? 1 : -1
    g.face = dir
    T.x = g.x + dir * 6; T.y = g.y - 34
    T.vx = dir * (3.6 + Math.random() * 3.4); T.vy = -(5.5 + Math.random() * 3)
    T.lo = lo; T.hi = hi
    T.state = "air"
  }
  function toyPhysics(f) {
    var T = fetch.toy
    if (T.state === "air") {
      T.vy += grav * 0.8 * f
      T.x += T.vx * f; T.y += T.vy * f
      if (T.x < T.lo || T.x > T.hi) { T.x = Math.max(T.lo, Math.min(T.hi, T.x)); T.vx = -T.vx * 0.5 }
      T.rot += T.vx * f * (T.kind === "frisbee" ? 3 : 9)
      var sy = surface(T.x, 3)
      if (T.y >= sy && T.vy > 0) {
        T.y = sy
        if (T.vy > 1.6) { T.vy = -T.vy * 0.42; T.vx *= 0.75 }
        else { T.vy = 0; T.state = "roll" }
      }
    } else if (T.state === "roll") {
      T.vx *= Math.pow(0.9, f); T.x += T.vx * f; T.rot += T.vx * f * 9
      T.y = surface(T.x, 3)
      if (Math.abs(T.vx) < 0.08) T.state = "ground"
    } else if (T.state === "mouth") {
      T.x = d.x + d.face * 13; T.y = d.y - 18; T.rot = 0
    }
  }

  // ---- brains -------------------------------------------------------------------
  function guyBrain(t, f) {
    if (g.hidden) return
    var dx = g.x - cur.x
    var near = Math.abs(dx) < 105 && cur.y > g.y - 110 && cur.y < g.y + 30
    if (g.mode === "caught") { g.vx = 0; if (t > g.until) { g.mode = "taunt"; g.until = t + 1500; sayG("…lucky.") } return }
    if (g.mode === "vault") { if (t > g.until && g.ground) { g.mode = "flee"; g.fleeAt = t } return }


    if (near) {
      if (g.mode !== "flee") { if (Math.random() < 0.5) sayG(pick(["eek!", "nope!", "!!"]), 700) }
      if (g.job) endJob(t, false)
      if (fetch) endFetch()
      g.mode = "flee"; g.fleeAt = t; play = null
      var dir = Math.abs(dx) < 3 ? (Math.random() < 0.5 ? -1 : 1) : (dx > 0 ? 1 : -1)
      var close = 1 - Math.abs(dx) / 105
      g.vx = dir * (3.2 + 5 * close); g.face = dir
      var cornered = (dir > 0 && g.x > worldMax - 45) || (dir < 0 && g.x < worldMin + 45)
      if (cornered) {
        if (g.ground && Math.random() < 0.55) {
          g.vy = -9.5; g.vx = -dir * 8.5; g.face = -dir; g.ground = false
          g.mode = "vault"; g.until = t + 600
          sayG("hup!", 700)
        } else teleportGuy()
      } else if (close > 0.75 && Math.random() < 0.01) teleportGuy()
      if (Math.random() < 0.015) { sayD("woof!", 700); d.barkUntil = t + 400 }
      return
    }
    if (g.mode === "flee") {
      if (t - g.fleeAt > 450) {
        g.mode = "taunt"; g.until = t + 1600; g.vx = 0
        g.face = cur.x > g.x ? 1 : -1
        sayG(pick(["catch me!", "too slow!", "nice try", "hehe", "nope", "get 'em, Biscuit!"]))
        if (Math.random() < 0.6) { d.barkUntil = t + 500; sayD("woof!", 800) }
      } else g.vx *= 0.92
      return
    }

    // timed modes
    if (g.mode === "walk" || g.mode === "goPush") {
      if (g.mode === "goPush") {
        var spot = g.job ? jobSpot(g.job) : null
        if (spot === null) { endJob(t, false); g.mode = "idle"; g.until = t + 800; return }
        g.tx = spot
      }
      var to = g.tx - g.x
      if (Math.abs(to) < 4 && g.ground) {
        g.vx = 0
        if (g.mode === "goPush") {
          var j0 = g.job
          g.face = j0.kind === "push" ? j0.dir : -j0.dir
          if (j0.kind === "pull") { g.mode = "tie"; g.until = t + 1500; sayG(pick(["tying…", "hold on", "knot…"]), 1300) }
          else { g.mode = "push"; j0.t0 = t; sayG(pick(["hnngh", "move it!", "one… two…"]), 1200) }
        } else { g.mode = "idle"; g.until = t + 800 + Math.random() * 2500 }
      } else { g.vx = (to > 0 ? 1 : -1) * Math.min(1.7, Math.max(0.6, Math.abs(to) / 6)); g.face = to > 0 ? 1 : -1 }
      if (t > g.until + 20000) { endJob(t, false); g.mode = "idle"; g.until = 0 }
      return
    }
    if (g.mode === "tie") {
      g.vx = 0
      if (!g.job) { g.mode = "idle"; return }
      if (t > g.until) { g.mode = "pull"; g.job.t0 = t; sayG(pick(["heave!", "pull, Biscuit!", "ready… PULL"]), 1300) }
      return
    }
    if (g.mode === "push" || g.mode === "pull") {
      var j = g.job, edge = j ? jobEdge(j) : null
      if (!j || edge === null || !g.ground) { endJob(t, false); g.mode = "idle"; g.until = t + 800; return }
      // effort comes in heaves, with a breath between them
      var heave = Math.max(0, Math.sin((t - j.t0) / 230 - 0.4))
      j.heave = heave
      var step = Math.min((j.kind === "push" ? 0.55 : 0.65) * heave * f, j.dist - j.moved)
      j.moved += step
      for (var ki = 0; ki < j.keys.length; ki++)
        setOff(j.keys[ki], (PetBus.offsets[j.keys[ki]] || 0) + j.dir * step)
      edge += j.dir * step
      g.x = j.kind === "push" ? edge - j.dir * 8 : edge + j.dir * rope
      g.vx = 0; g.face = j.kind === "push" ? j.dir : -j.dir
      if (heave > 0.95 && Math.random() < 0.12)
        burst(g.x - g.face * 6, g.y - 2, "·", "#c9b79a", 1, 8, 12)
      if (j.moved >= j.dist - 0.05 || t - j.t0 > 25000) endJob(t, true)
      return
    }
    if (g.mode === "fetch") {
      var F = fetch
      g.vx = 0
      if (!F || t > g.until) { endFetch(); g.mode = "idle"; g.until = t + 1200; return }
      if (F.phase === "windup" && t > F.t) { F.phase = "throw"; F.t = t + 380; launchToy(); sayD("!!", 600) }
      else if (F.phase === "throw" && t > F.t) F.phase = "chase"
      else if (F.phase === "chase" || F.phase === "return") g.face = d.x > g.x ? 1 : -1
      else if (F.phase === "drop" && t > F.t) { F.phase = "pickup"; F.t = t + 450 }
      else if (F.phase === "pickup" && t > F.t) {
        F.toy.state = "held"
        F.n--
        if (F.n > 0) { F.phase = "windup"; F.t = t + 800; g.face = d.x > g.x ? 1 : -1; sayG(pick(["again?", "ready?", "go get it!", "one more!"]), 1000) }
        else {
          endFetch(); g.mode = "cheer"; g.until = t + 1500
          sayG(pick(["good boy, Biscuit!", "who's a good boy?", "best dog ever"]), 1800)
          burst(d.x, d.y - 26, "♥", "#ff7aa8", 3, 18, 12)
        }
      }
      return
    }
    if (g.mode === "play") {
      if (!play || t > g.until) { play = null; g.mode = "idle"; g.until = t + 1500; g.vx = 0; return }
      // tag: chase the dog back and forth, hop now and then
      var dogT = play.c + Math.sin((t - play.t0) / 650) * 85
      var want = dogT - g.face * 24
      var dd = want - g.x
      g.vx = Math.abs(dd) > 6 ? (dd > 0 ? 1 : -1) * Math.min(3.4, Math.abs(dd) / 10) : 0
      if (g.vx !== 0) g.face = g.vx > 0 ? 1 : -1
      if (g.ground && Math.random() < 0.012) { g.vy = -5.5; g.ground = false }
      if (t - play.heart > 900) { play.heart = t; burst((g.x + d.x) / 2, Math.min(g.y, d.y) - 30, "♥", "#ff7aa8", 1, 20, 12) }
      return
    }
    if (g.mode === "dance") {
      g.vx = 0
      if (t - (g.noteAt || 0) > 650) { g.noteAt = t; burst(g.x + 10 * g.face, g.y - 30, pick(["♪", "♫"]), "#c084fc", 1, 10, 13) }
      if (!musicOn || t > g.until) { g.mode = "idle"; g.until = t + 1500 }
      return
    }
    if (g.mode === "cheer") { g.vx = 0; if (g.ground && Math.random() < 0.06) { g.vy = -4.5; g.ground = false } if (t > g.until) { g.mode = "idle"; g.until = t + 1000 } return }
    if (g.mode === "sleep") {
      g.vx = 0
      if (t - (g.zAt || 0) > 1400) { g.zAt = t; burst(g.x + 8, g.y - 26, "z", "#9bdcff", 1, 6, 10) }
      if (t - cur.moved < 3000 || t > g.until) { g.mode = "idle"; g.until = t + 1000; sayG("huh?", 900) }
      return
    }
    if (t < g.until) { g.vx = 0; return }   // idle / sit / wave / taunt waiting

    chooseNext(t)
  }

  function chooseNextForced(m) { forced = m; chooseNext(Date.now()); forced = "" }
  property string forced: ""
  function chooseNext(t) {
    if (fetch) endFetch()          // a game cut short leaves no toy behind
    var hour = new Date().getHours()
    var idleLong = t - cur.moved > 180000
    if ((hour >= 23 || hour < 6) && idleLong) { g.mode = "sleep"; g.until = t + 120000; return }
    var opts = [["walk", 32], ["sit", 11], ["idle", 10], ["wave", 3], ["push", 6], ["pull", 4], ["play", 12], ["fetch", 7]]
    if (musicOn) opts.push(["dance", 15])
    var total = 0
    for (var i = 0; i < opts.length; i++) total += opts[i][1]
    var r = Math.random() * total, m = "walk"
    for (i = 0; i < opts.length; i++) { r -= opts[i][1]; if (r <= 0) { m = opts[i][0]; break } }
    if (forced) m = forced

    if (m === "walk") {
      var span = Math.random() < 0.15 ? (worldMax - worldMin) : 700
      g.tx = Math.max(worldMin + 30, Math.min(worldMax - 30, g.x + (Math.random() - 0.5) * span))
      g.mode = "walk"; g.until = t
    } else if (m === "push" || m === "pull") {
      if (!planMove(t, m) && !planMove(t, m === "push" ? "pull" : "push")) { g.mode = "idle"; g.until = t + 1500 }
    } else if (m === "play") {
      if (Math.abs(d.x - g.x) > 300) { g.mode = "idle"; g.until = t + 1000; return }
      play = { c: Math.max(worldMin + 100, Math.min(worldMax - 100, (g.x + d.x) / 2)), t0: t, heart: t }
      g.mode = "play"; g.until = t + 7000
      sayD("!!", 900)
    } else if (m === "fetch") {
      if (!startFetch(t)) { g.mode = "idle"; g.until = t + 1000 }
    } else if (m === "dance") { g.mode = "dance"; g.until = t + 6000 + Math.random() * 4000 }
    else if (m === "sit") { g.mode = "sit"; g.until = t + 3000 + Math.random() * 6000 }
    else if (m === "wave") { g.mode = "wave"; g.until = t + 1500; sayG(pick(["hi!", "yo", "👋", "I'm Dash!", "say hi, Biscuit"])) }
    else { g.mode = "idle"; g.until = t + 1000 + Math.random() * 2500 }
  }

  function dogBrain(t, f) {
    if (d.hidden) return
    if (d.poofAt && t > d.poofAt) {        // he teleported far away: catch up
      d.poofAt = 0; poof(d, false)
      d.x = g.x - g.face * 30; d.y = surface(d.x, 9) - 40; d.vy = 0; d.ground = false
      poof(d, false)
    }
    if (d.mode === "pet") { d.vx = 0; if (t > d.until) d.mode = "follow"; return }
    if (g.mode === "fetch" && fetch) {
      var F = fetch, T = F.toy
      d.mode = "fetch"
      if (F.phase === "chase") {
        var mx = d.x + d.face * 13
        if (T.state === "air") {
          // leap for it when it comes down close by
          if (d.ground && T.vy > 0 && Math.abs(T.x - d.x) < 26 && T.y > d.y - 60) { d.vy = -6.4; d.ground = false }
          if (Math.abs(T.x - mx) < 7 && Math.abs(T.y - (d.y - 19)) < 9) {
            T.state = "mouth"; F.phase = "return"
            sayG(pick(["nice catch!", "woah!", "got it!"]), 1100); burst(T.x, T.y - 6, "★", "#ffd166", 3, 14, 10)
          }
        } else if (Math.abs(T.x - mx) < 5 && d.ground) { T.state = "mouth"; F.phase = "return"; d.grabAt = t }
        if (F.phase === "chase") {
          var want = T.x - (T.x > d.x ? 13 : -13) - d.x
          d.vx = Math.abs(want) > 2 ? (want > 0 ? 1 : -1) * Math.min(6, 1.5 + Math.abs(want) / 12) : 0
          if (d.vx !== 0) d.face = d.vx > 0 ? 1 : -1
          else d.face = T.x > d.x ? 1 : -1
        } else d.vx = 0
      } else if (F.phase === "return") {
        var spot = g.x + g.face * 26, back = spot - d.x
        if (Math.abs(back) < 4 && d.ground) {
          d.vx = 0; d.face = g.x > d.x ? 1 : -1
          F.phase = "drop"; F.t = t + 700
          T.state = "ground"; T.x = d.x + d.face * 13; T.y = surface(T.x, 3)
          sayD(pick(["woof!", "again!", "♥"]), 900)
        } else {
          d.vx = (back > 0 ? 1 : -1) * Math.min(4, 1.2 + Math.abs(back) / 18)
          d.face = d.vx > 0 ? 1 : -1
        }
      } else { d.vx = 0; d.face = g.x > d.x ? 1 : -1 }
      return
    }
    if (d.mode === "fetch") d.mode = "follow"
    var j = g.job
    if (j && (g.mode === "push" || g.mode === "pull" || g.mode === "tie")) {
      // push: shove his back. pull: grab the rope behind him and tug.
      var spot = j.kind === "push" ? g.x - j.dir * 22 : g.x + j.dir * 27
      var gap = spot - d.x
      if (Math.abs(gap) < 7 && d.ground) {
        d.x = spot; d.vx = 0; d.mode = "assist"
        d.face = j.kind === "push" ? j.dir : -j.dir
      } else {
        d.vx = (gap > 0 ? 1 : -1) * Math.min(5, 1.2 + Math.abs(gap) / 20)
        d.face = d.vx > 0 ? 1 : -1
        if (d.mode === "assist") d.mode = "follow"
      }
      return
    }
    if (d.mode === "assist") { d.mode = "follow"; d.barkUntil = Date.now() + 300 }
    if (g.mode === "play" && play) {
      var tgt = play.c + Math.sin((t - play.t0) / 650) * 85
      var dd = tgt - d.x
      d.vx = Math.abs(dd) > 4 ? (dd > 0 ? 1 : -1) * Math.min(3.8, Math.abs(dd) / 8) : 0
      if (d.vx !== 0) d.face = d.vx > 0 ? 1 : -1
      else d.face = g.x > d.x ? 1 : -1
      d.mode = "play"
      return
    }
    if (d.mode === "play") d.mode = "follow"
    var tx = g.x - g.face * 30
    var dist = tx - d.x
    if (Math.abs(dist) > 16) {
      d.vx = (dist > 0 ? 1 : -1) * Math.min(7, 1.6 + Math.abs(dist) / 45)
      d.face = d.vx > 0 ? 1 : -1
    } else {
      d.vx = 0
      d.face = g.x > d.x ? 1 : -1
    }
  }

  // ---- frames -----------------------------------------------------------------
  function guyFrame(t) {
    var two = function(a, b, ms) { return Math.floor(t / ms) % 2 ? a : b }
    if (!g.ground && g.mode !== "sleep") return "jump"
    switch (g.mode) {
    case "caught": return two("caught", "cheer2", 300)
    case "cheer": return two("cheer", "cheer2", 250)
    case "wave": return two("wave", "wave2", 260)
    case "taunt": return two("taunt", "taunt2", 300)
    case "dance": return "dance" + (Math.floor(t / 260) % 4)
    case "sit": return (t % 4200) < 150 ? "sitBlink" : "sit"
    case "sleep": return "sleep"
    case "push": return g.job && g.job.heave > 0.15 ? two("push", "push2", 180) : "push2"
    case "pull": return g.job && g.job.heave > 0.15 ? two("pull", "pull2", 170) : "pull2"
    case "tie": return two("tie", "tie2", 260)
    case "fetch":
      if (!fetch) return "stand"
      if (fetch.phase === "windup") return t > fetch.t - 400 ? "throw" : "stand"
      if (fetch.phase === "throw") return "throw2"
      if (fetch.phase === "pickup") return "tie"
      return (t % 3600) < 140 ? "blink" : "stand"
    }
    if (Math.abs(g.vx) > 0.2) {
      var fast = g.mode === "flee"
      return (fast ? "flee" : "run") + (Math.floor(t / (fast ? 55 : 95)) % 6)
    }
    return (t % 3600) < 140 ? "blink" : "stand"
  }
  function dogFrame(t) {
    var two = function(a, b, ms) { return Math.floor(t / ms) % 2 ? a : b }
    if (!d.ground) return "jump"
    if (t < d.barkUntil) return "bark"
    if (d.mode === "fetch" && fetch) {
      if (t - (d.grabAt || 0) < 260) return "bow"
      if (Math.abs(d.vx) > 0.2) return "run" + (Math.floor(t / 70) % 6)
      if (fetch.phase === "windup" || fetch.phase === "throw") return "bow"
      if (fetch.phase === "drop" || fetch.phase === "pickup") return two("sitWag", "sit", 140)
      return two("wag", "wag2", 120)
    }
    if (Math.abs(d.vx) > 0.2) return "run" + (Math.floor(t / 70) % 6)
    if (d.mode === "pet") return two("sitWag", "sit", 120)
    if (d.mode === "assist") {
      if (g.mode === "tie") return two("wag", "wag2", 140)
      var hv = g.job ? g.job.heave : 0
      if (g.mode === "push") return hv > 0.15 ? two("shove", "shove2", 160) : "shove2"
      return hv > 0.15 ? two("tug", "tug2", 150) : "tug2"
    }
    if (d.mode === "play") return "bow"
    if (g.mode === "sleep" && Math.abs(d.x - g.x) < 70) return "sleep"
    if (g.mode === "sit" || g.mode === "dance") return two("sitWag", "sit", 380)
    if (g.mode === "taunt" || g.mode === "cheer" || g.mode === "caught") return two("wag", "wag2", 110)
    return Math.floor(t / 900) % 4 === 0 ? two("wag", "wag2", 150) : "stand"
  }

  // ---- loop ------------------------------------------------------------------
  property real lastTick: Date.now()
  property bool started: false

  Timer {
    id: loop
    interval: 33
    running: root.leader && root.scrs.length > 0
    repeat: true
    onTriggered: root.tick()
  }
  Timer { interval: 3000; running: root.leader; repeat: true; triggeredOnStart: true; onTriggered: root.refreshWorld() }

  function tick() {
    var t = Date.now()
    var f = Math.min(3, (t - lastTick) / 16.67)
    lastTick = t
    now = t
    if (!started) {
      started = true
      g.x = worldMin + 300 + Math.random() * 400; g.y = surface(g.x, 7) - 80
      d.x = g.x - 30; d.y = g.y
      if (!enabled || focusActive) { g.hidden = true; d.hidden = true }
      else poof(g, true)
    }
    guyBrain(t, f)
    dogBrain(t, f)
    if (!g.hidden) {
      physics(g, 7, f, g.mode === "goPush" && Math.abs(g.tx - g.x) < 14)
    }
    if (!d.hidden) physics(d, 9, f, false)

    if (fetch) toyPhysics(f)
    var T0 = fetch ? fetch.toy : null
    toyOn = !!T0 && T0.state !== "held"
    if (T0) { toyKind = T0.kind; toyX = T0.x; toyY = T0.y; toyRot = T0.rot }

    // widgets he moved glide home after a while
    var homing = false
    for (var k in homeAt) {
      if (t < homeAt[k] || (g.job && g.job.keys.indexOf(k) >= 0)) continue
      var o0 = PetBus.offsets[k] || 0
      var nv = Math.abs(o0) < 0.6 ? 0 : o0 * Math.pow(0.92, f)
      setOff(k, nv)
      if (nv === 0) delete homeAt[k]
      homing = true
    }

    // the rope: widget edge -> his hands -> the dog's mouth
    var rj = g.job
    if (!g.hidden && rj && rj.kind === "pull" && (g.mode === "tie" || g.mode === "pull")) {
      var rw = widget(rj.key), re = jobEdge(rj)
      if (rw && re !== null) {
        ropeOn = true
        rAx = re; rAy = rw.top + rw.h / 2
        rBx = g.x + g.face * (g.mode === "tie" ? 9 : 6); rBy = g.y - (g.mode === "tie" ? 13 : 19)
        if (d.mode === "assist") { rCx = d.x + d.face * 13; rCy = d.y - 21 }
        else { rCx = rBx - g.face * 8; rCy = rBy + 12 }
      } else ropeOn = false
    } else ropeOn = false

    // cleanup particles
    for (var i = parts.count - 1; i >= 0; i--) {
      var p = parts.get(i)
      if (t - p.born > p.life) parts.remove(i)
    }

    gX = g.x; gY = g.y; gFlip = g.face < 0; gFrame = guyFrame(t)
    gAlpha = g.hidden ? 0 : 1
    dX = d.x; dY = d.y; dFlip = d.face < 0; dFrame = dogFrame(t); dRot = 0
    dAlpha = d.hidden ? 0 : 1
    // 60 fps while anything moves, 10 when everyone is resting.
    var guyBusy = cursorClose || parts.count > 0 || Math.abs(g.vx) > 0.01 || !g.ground
      || ["idle", "sit", "sleep"].indexOf(g.mode) < 0
    var dogBusy = !d.hidden && (Math.abs(d.vx) > 0.01 || !d.ground)
    loop.interval = guyBusy || dogBusy || homing ? 16 : 100
  }

  IpcHandler {
    target: "bar-buddies"
    function toggle(): string { root.enabled = !root.enabled; root.save(); return root.enabled ? "on" : "off" }
    function poof(): void { if (!root.g.hidden) root.teleportGuy() }
    function dance(): void { root.g.mode = "dance"; root.g.until = Date.now() + 8000 }
    function next(): void { root.g.until = 0; root.g.mode = "idle"; root.chooseNext(Date.now()) }
    function push(): string { root.g.mode = "idle"; root.chooseNextForced("push"); return root.g.job ? root.g.job.kind + " " + root.g.job.key : "no room" }
    function pull(): string { root.g.mode = "idle"; root.chooseNextForced("pull"); return root.g.job ? root.g.job.kind + " " + root.g.job.key : "no room" }
    function gaps(): string {
      var out = []
      for (var i = 0; i < root.scrs.length; i++) root.widgetsOn(root.scrs[i]).forEach(function(w) {
        out.push(w.key + " " + Math.round(w.x1) + "-" + Math.round(w.x2) + " L" + Math.round(w.gapL) + " R" + Math.round(w.gapR)) })
      return out.join("\n")
    }
    function home(): void { for (var k in root.homeAt) root.homeAt[k] = 0 }
    function play(): void { root.chooseNextForced("play") }
    function fetch(): string { root.g.mode = "idle"; root.chooseNextForced("fetch"); return root.fetch ? root.fetch.toy.kind : "dog too far" }
    // hooks for other tools: cheer when a job finishes, wave for attention,
    // hide during a focus session
    function cheer(who: string): void { root.react("done", who || "Task") }
    function alert(who: string): void { root.react("input", who || "Something") }
    function hide(): void { root.focusActive = true }
    function show(): void { root.focusActive = false }
    function stats(): string {
      return JSON.stringify({ caught: root.caughtCount, pets: root.petCount, mode: root.g.mode, job: root.g.job, offsets: PetBus.offsets,
        x: Math.round(root.g.x), cursor: [root.cur.x, root.cur.y], interval: loop.interval, screens: root.scrs.map(function(s) { return s.name + ":" + s.obstacles.length }) })
    }
  }

  // ---- overlays (leader only, one per monitor) ----------------------------------
  Variants {
    model: root.leader ? Quickshell.screens : []

    PanelWindow {
      id: ov
      required property var modelData
      screen: modelData
      readonly property real x0: modelData.x
      readonly property real top: modelData.height - implicitHeight
      anchors { left: true; right: true; bottom: true }
      implicitHeight: 190
      exclusionMode: ExclusionMode.Ignore
      color: "transparent"
      focusable: false
      WlrLayershell.layer: WlrLayer.Top
      WlrLayershell.namespace: "bar-buddies"
      mask: Region {
        item: guyHit
        Region { item: dogHit }
      }

      readonly property bool hasGuy: root.gAlpha > 0 && root.gX > x0 - 40 && root.gX < x0 + modelData.width + 40
      readonly property bool hasDog: root.dAlpha > 0 && root.dX > x0 - 40 && root.dX < x0 + modelData.width + 40

      // dog (drawn first, behind the guy)
      Image {
        id: dogImg
        visible: ov.hasDog
        readonly property var fr: root.spr.dog[root.dFrame] || root.spr.dog.stand
        source: fr.url
        width: fr.w; height: fr.h
        sourceSize.width: fr.w * 2; sourceSize.height: fr.h * 2
        x: root.dX - ov.x0 - width / 2
        y: root.dY - ov.top - height
        mirror: root.dFlip
        smooth: true
        rotation: root.dRot
        transformOrigin: Item.Bottom
      }
      Item {
        id: dogHit
        x: dogImg.x - 3; y: dogImg.y - 3
        width: ov.hasDog ? dogImg.width + 6 : 0
        height: ov.hasDog ? dogImg.height + 6 : 0
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.dogClicked() }
      }

      RopeSeg { visible: root.ropeOn; ax: root.rAx - ov.x0; ay: root.rAy - ov.top; bx: root.rBx - ov.x0; by: root.rBy - ov.top }
      RopeSeg { visible: root.ropeOn; ax: root.rBx - ov.x0; ay: root.rBy - ov.top; bx: root.rCx - ov.x0; by: root.rCy - ov.top }
      Rectangle {   // the knot on the widget
        visible: root.ropeOn
        width: 5; height: 5; radius: 2.5
        x: root.rAx - ov.x0 - 2.5; y: root.rAy - ov.top - 2.5
        color: "#c8955a"; border.width: 1; border.color: "#5e4024"
      }
      Image {
        id: guyImg
        visible: ov.hasGuy
        readonly property var fr: root.spr.guy[root.gFrame] || root.spr.guy.stand
        source: fr.url
        width: fr.w; height: fr.h
        sourceSize.width: fr.w * 2; sourceSize.height: fr.h * 2
        x: root.gX - ov.x0 - width / 2
        y: root.gY - ov.top - height
        mirror: root.gFlip
        smooth: true
      }
      Item {
        id: guyHit
        x: guyImg.x - 4; y: guyImg.y - 4
        width: ov.hasGuy ? guyImg.width + 8 : 0
        height: ov.hasGuy ? guyImg.height + 8 : 0
        MouseArea {
          anchors.fill: parent
          hoverEnabled: true
          onEntered: root.guyTouched()
          onPressed: root.guyClicked()
        }
      }

      Image {   // fetch toy
        readonly property var fr: root.spr.items[root.toyKind] || root.spr.items.ball
        visible: root.toyOn && root.toyX > ov.x0 - 20 && root.toyX < ov.x0 + ov.modelData.width + 20
        source: fr.url
        width: fr.w; height: fr.h
        sourceSize.width: fr.w * 2; sourceSize.height: fr.h * 2
        x: root.toyX - ov.x0 - width / 2
        y: root.toyY - ov.top - height
        rotation: root.toyKind === "frisbee" ? 0 : root.toyRot
        smooth: true
      }

      // speech bubbles
      Bubble { visible: ov.hasGuy && root.now < root.gSayUntil && root.gSay !== ""; text: root.gSay
               cx: guyImg.x + guyImg.width / 2; bottomY: guyImg.y - 4 }
      Bubble { visible: ov.hasDog && root.now < root.dSayUntil && root.dSay !== ""; text: root.dSay
               cx: dogImg.x + dogImg.width / 2; bottomY: dogImg.y - 4 }

      // particles
      Repeater {
        model: parts
        Text {
          id: pt
          required property real px
          required property real py
          required property string txt
          required property string col
          required property real size
          required property real dx
          required property real dy
          required property real life
          visible: px > ov.x0 - 20 && px < ov.x0 + ov.modelData.width + 20
          text: txt
          color: col
          font.pixelSize: size
          font.bold: true
          x: px - ov.x0
          y: py - ov.top
          Component.onCompleted: anim.start()
          ParallelAnimation {
            id: anim
            NumberAnimation { target: pt; property: "x"; to: pt.px - ov.x0 + pt.dx; duration: pt.life; easing.type: Easing.OutQuad }
            NumberAnimation { target: pt; property: "y"; to: pt.py - ov.top + pt.dy; duration: pt.life; easing.type: Easing.OutQuad }
            NumberAnimation { target: pt; property: "opacity"; from: 1; to: 0; duration: pt.life; easing.type: Easing.InQuad }
          }
        }
      }
    }
  }

  component RopeSeg: Item {
    property real ax: 0; property real ay: 0
    property real bx: 0; property real by: 0
    x: ax; y: ay - 1.5
    width: Math.hypot(bx - ax, by - ay); height: 3
    transformOrigin: Item.Left
    rotation: Math.atan2(by - ay, bx - ax) * 180 / Math.PI
    Rectangle { anchors.fill: parent; radius: 1.5; color: "#5e4024"; antialiasing: true }
    Rectangle { anchors.fill: parent; anchors.margins: 0.7; radius: 1; color: "#d6a464"; antialiasing: true }
  }

  component Bubble: Rectangle {
    id: bub
    property alias text: bt.text
    property real cx: 0
    property real bottomY: 0
    x: Math.round(cx - width / 2)
    y: Math.round(bottomY - height)
    width: bt.implicitWidth + 12
    height: bt.implicitHeight + 6
    radius: 6
    color: "#f4f4f8"
    border.width: 1
    border.color: "#1b1b1f"
    Text {
      id: bt
      anchors.centerIn: parent
      color: "#1b1b1f"
      font.pixelSize: 10
      font.bold: true
      font.family: "JetBrainsMono Nerd Font"
    }
    Rectangle {
      width: 6; height: 6; rotation: 45
      color: "#f4f4f8"
      border.width: 1; border.color: "#1b1b1f"
      anchors.horizontalCenter: parent.horizontalCenter
      y: parent.height - 4
      z: -1
    }
  }
}
