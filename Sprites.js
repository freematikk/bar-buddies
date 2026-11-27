.pragma library
// Bar Buddies art: small rigged vector characters. Every frame is an SVG built
// from a pose (limb angles, face), so motion is smooth and edges stay crisp.
// Everything faces right; the overlay mirrors for left.

var INK = "#1d1b26"

function n(v) { return Math.round(v * 100) / 100 }

// ---------------------------------------------------------------- the runner
var GUY_VB = [44, 58]
var GUY_SIZE = [31, 41]      // display px

var C = {
  skin: "#f6c9a4", skinShade: "#e2a982", blush: "#ff8f9e",
  hat: "#e5484d", hatShade: "#b8323a", pom: "#ffd3d5",
  hood: "#3f8cff", hoodShade: "#2f6fd6", hoodBack: "#2a62bd",
  jeans: "#33416b", jeansBack: "#273255",
  shoe: "#ffffff", stripe: "#e5484d", hair: "#5a3a26"
}

function leg(x, y, a, back) {
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + n(-a) + ')">'
    + '<rect x="-2.6" y="-1" width="5.2" height="12.5" rx="2.6" fill="' + (back ? C.jeansBack : C.jeans) + '" stroke="' + INK + '" stroke-width="1"/>'
    + '<path d="M-3.2 10.6 Q-3.4 14.4 0 14.4 L5.6 14.4 Q7.6 14.4 7 12.4 Q6.2 10.4 2.8 10.4 Z" fill="' + C.shoe + '" stroke="' + INK + '" stroke-width="1"/>'
    + '<path d="M-1.8 12.6 L5.6 12.6" stroke="' + C.stripe + '" stroke-width="1.1"/>'
    + '</g>'
}
function arm(x, y, a, back) {
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + n(-a) + ')">'
    + '<rect x="-2.3" y="-1.5" width="4.6" height="11" rx="2.3" fill="' + (back ? C.hoodBack : C.hood) + '" stroke="' + INK + '" stroke-width="1"/>'
    + '<circle cx="0" cy="10.3" r="2.5" fill="' + C.skin + '" stroke="' + INK + '" stroke-width="1"/>'
    + '</g>'
}
function eyes(kind) {
  var out = "", xs = [23.6, 29.2], y = 17.2
  for (var i = 0; i < 2; i++) {
    var x = xs[i]
    if (kind === "blink" || kind === "sleep")
      out += '<path d="M' + (x - 2) + ' ' + (y + (kind === "sleep" ? 0.6 : 0.2)) + ' Q' + x + ' ' + (y + (kind === "sleep" ? 2 : 1.4)) + ' ' + (x + 2) + ' ' + (y + 0.2) + '" stroke="' + INK + '" stroke-width="1.2" fill="none" stroke-linecap="round"/>'
    else if (kind === "happy")
      out += '<path d="M' + (x - 2) + ' ' + (y + 1) + ' Q' + x + ' ' + (y - 1.8) + ' ' + (x + 2) + ' ' + (y + 1) + '" stroke="' + INK + '" stroke-width="1.3" fill="none" stroke-linecap="round"/>'
    else if (kind === "wink" && i === 1)
      out += '<path d="M' + (x - 2) + ' ' + y + ' L' + (x + 2) + ' ' + (y - 0.6) + '" stroke="' + INK + '" stroke-width="1.3" stroke-linecap="round"/>'
    else {
      var big = kind === "shock"
      out += '<ellipse cx="' + x + '" cy="' + y + '" rx="' + (big ? 2.5 : 2.1) + '" ry="' + (big ? 3.1 : 2.7) + '" fill="#fff" stroke="' + INK + '" stroke-width="0.8"/>'
        + '<circle cx="' + (x + (big ? 0.2 : 0.6)) + '" cy="' + (y + 0.3) + '" r="' + (big ? 1 : 1.45) + '" fill="' + INK + '"/>'
        + '<circle cx="' + (x + 1) + '" cy="' + (y - 0.6) + '" r="0.5" fill="#fff"/>'
    }
  }
  return out
}
function mouth(kind) {
  var x = 27.2, y = 22.6
  switch (kind) {
  case "open": return '<path d="M' + (x - 2.2) + ' ' + y + ' Q' + x + ' ' + (y + 4) + ' ' + (x + 2.2) + ' ' + y + ' Z" fill="#7a2531" stroke="' + INK + '" stroke-width="0.9"/>'
  case "o": return '<ellipse cx="' + x + '" cy="' + (y + 0.8) + '" rx="1.3" ry="1.7" fill="#7a2531" stroke="' + INK + '" stroke-width="0.8"/>'
  case "tongue": return '<path d="M' + (x - 2) + ' ' + y + ' Q' + x + ' ' + (y + 1.6) + ' ' + (x + 2) + ' ' + y + '" stroke="' + INK + '" stroke-width="1" fill="none"/>'
      + '<path d="M' + (x - 0.4) + ' ' + (y + 0.6) + ' q0.4 3 1.8 2.4 q1 -0.6 0.4 -2.6 Z" fill="#ff6f91" stroke="' + INK + '" stroke-width="0.7"/>'
  case "flat": return '<path d="M' + (x - 1.4) + ' ' + (y + 0.6) + ' L' + (x + 1.4) + ' ' + (y + 0.6) + '" stroke="' + INK + '" stroke-width="1" stroke-linecap="round"/>'
  default: return '<path d="M' + (x - 2.2) + ' ' + y + ' Q' + x + ' ' + (y + 2.6) + ' ' + (x + 2.2) + ' ' + y + '" stroke="' + INK + '" stroke-width="1.1" fill="none" stroke-linecap="round"/>'
  }
}
function head(eyeKind, mouthKind, tilt) {
  return '<g transform="rotate(' + n(tilt || 0) + ' 23 24)">'
    + '<path d="M13 16 Q12 22 15 24 L16 16 Z" fill="' + C.hair + '"/>'
    + '<circle cx="23" cy="17.5" r="10.4" fill="' + C.skin + '" stroke="' + INK + '" stroke-width="1.1"/>'
    + '<path d="M14.2 22 Q17 27 23 27.6 Q16.5 26 14.2 22 Z" fill="' + C.skinShade + '"/>'
    + '<ellipse cx="15.6" cy="19.4" rx="2" ry="2.6" fill="' + C.skin + '" stroke="' + INK + '" stroke-width="1"/>'
    + '<ellipse cx="28.8" cy="21.4" rx="1.9" ry="1.1" fill="' + C.blush + '" opacity="0.55"/>'
    + eyes(eyeKind) + mouth(mouthKind)
    + '<path d="M11.6 14.2 Q12 3.4 23 3.6 Q33.8 3.8 34.4 14.2 Z" fill="' + C.hat + '" stroke="' + INK + '" stroke-width="1.1"/>'
    + '<path d="M17 5.4 Q16 9 16.6 13.6 M23 4.2 L23 13.6 M29 5.4 Q30 9 29.4 13.6" stroke="' + C.hatShade + '" stroke-width="1" fill="none"/>'
    + '<rect x="10.6" y="11.6" width="24.8" height="4.6" rx="2.3" fill="' + C.hatShade + '" stroke="' + INK + '" stroke-width="1.1"/>'
    + '<circle cx="21" cy="3" r="2.9" fill="' + C.pom + '" stroke="' + INK + '" stroke-width="1"/>'
    + '</g>'
}
function torso() {
  return '<path d="M15.6 28.4 Q22 25.6 29 28.4 Q30.6 35 29.4 41.6 Q22 43.4 15 41.6 Q14 35 15.6 28.4 Z" fill="' + C.hood + '" stroke="' + INK + '" stroke-width="1.1"/>'
    + '<path d="M26.6 29 Q28.6 35 27.8 41.4 Q29.2 41.4 29.4 41.4 Q30.4 35 29 28.6 Z" fill="' + C.hoodShade + '"/>'
    + '<path d="M18 36.6 L26 36.6 L25.2 40 L18.8 40 Z" fill="' + C.hoodShade + '" stroke="' + INK + '" stroke-width="0.7"/>'
    + '<path d="M22.6 28 L22.8 32" stroke="#fff" stroke-width="0.8" stroke-linecap="round"/>'
}
// pose: legF, legB, armF, armB (degrees, + = forward), bob (px down), lean (deg), eyes, mouth, tilt
function guy(p) {
  var hipX = 22, hipY = 40, shX = 22, shY = 30.5
  var body = leg(hipX - 1.6, hipY, p.legB || 0, true)
    + arm(shX - 2.2, shY, p.armB || 0, true)
    + torso()
    + leg(hipX + 1.4, hipY, p.legF || 0, false)
    + head(p.eyes || "open", p.mouth || "smile", p.tilt || 0)
    + arm(shX + 1.6, shY, p.armF || 0, false)
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="-4 -1 ' + (GUY_VB[0] + 8) + ' ' + GUY_VB[1] + '">'
    + '<g transform="translate(0,' + n(p.bob || 0) + ') rotate(' + n(p.lean || 0) + ' 22 54)">' + body + '</g></svg>'
}

// -------------------------------------------------------------------- the dog
// Biscuit: a white Lab-type dog modelled on a pencil sketch — long
// legs, deep chest, tucked belly, long muzzle, floppy ear, thin tail.
// Ground is y = 50 in the viewBox; faces right.
var DOG_SIZE = [34, 30]
var D = { fur: "#fbfaf6", shade: "#e2e1dc", far: "#cfd0d0", muzzle: "#ffffff", ear: "#ece7dd",
          nose: "#26232b", tongue: "#ff6f91", collar: "#e5484d", tag: "#ffd166", line: "#2a2730" }
var LW = 1.05

// front leg: hangs from (x,y), swings by a (deg, + = forward)
function fleg(x, y, a, far, len) {
  len = len || 19
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + n(-a) + ')">'
    + '<path d="M-2.6 -2 Q-2.8 ' + (len * 0.5) + ' -1.9 ' + (len - 2.6) + ' L1.9 ' + (len - 2.6) + ' Q2.6 ' + (len * 0.5) + ' 2.8 -2 Z" fill="' + (far ? D.far : D.fur) + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + (far ? "" : '<circle cx="0" cy="' + (len * 0.62) + '" r="1.2" fill="none" stroke="' + D.shade + '" stroke-width="0.8"/>')
    + '<path d="M-2.2 ' + (len - 3.2) + ' Q-2.6 ' + (len + 0.3) + ' 0.6 ' + (len + 0.3) + ' L3.8 ' + (len + 0.3) + ' Q5 ' + (len - 1.4) + ' 1.8 ' + (len - 3.2) + ' Z" fill="' + (far ? D.far : D.fur) + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '</g>'
}
// hind leg: thigh, then the angled hock down to the paw
function hleg(x, y, a, far) {
  return '<g transform="translate(' + x + ',' + y + ') rotate(' + n(-a) + ')">'
    + '<path d="M-4.6 -3 Q-6.4 4 -3.4 10.4 L-4.4 19.6 L-1 19.6 L1.6 11 Q4.6 4.6 3.6 -3 Z" fill="' + (far ? D.far : D.fur) + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '<path d="M-5.4 18.8 Q-6 23.3 -2.4 23.3 L1.2 23.3 Q2.4 21.4 -0.6 18.8 Z" fill="' + (far ? D.far : D.fur) + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '</g>'
}
function dtail(a, x, y) {
  return '<g transform="translate(' + (x || 13.4) + ',' + (y || 19.4) + ') rotate(' + n(-a) + ')">'
    + '<path d="M1 -1.4 Q-6 -1 -10 3.4 Q-12.6 6.4 -13.6 9.6 Q-11.2 7.6 -8.6 5.6 Q-4.4 2.6 1 2 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '</g>'
}
function dhead(p) {
  var eye = p.eyes === "closed"
    ? '<path d="M45.4 6.6 Q46.8 7.8 48.2 6.6" stroke="' + D.line + '" stroke-width="1.1" fill="none" stroke-linecap="round"/>'
    : p.eyes === "happy"
    ? '<path d="M45.4 7 Q46.8 5 48.2 7" stroke="' + D.line + '" stroke-width="1.2" fill="none" stroke-linecap="round"/>'
    : '<ellipse cx="46.8" cy="6.2" rx="1.35" ry="1.5" fill="' + D.line + '"/><circle cx="47.2" cy="5.7" r="0.45" fill="#fff"/>'
  var jaw = p.mouth === "bark"
    ? '<path d="M48.6 11.4 L55.4 12 Q54 16.4 49.4 14.6 Z" fill="#7a2531" stroke="' + D.line + '" stroke-width="0.9" stroke-linejoin="round"/>'
      + '<path d="M48.4 13.2 Q51.6 16.6 55 13.4 Q54.4 15.8 51 15.6 Q49 15.2 48.4 13.2 Z" fill="' + D.muzzle + '" stroke="' + D.line + '" stroke-width="0.9"/>'
    : '<path d="M49 12.4 Q52 13 55 11.8" stroke="' + D.line + '" stroke-width="0.85" fill="none" stroke-linecap="round"/>'
      + (p.mouth === "tongue" ? '<path d="M50.6 12.6 Q50.6 17 52.4 16.8 Q54 16.4 53.2 12.4 Z" fill="' + D.tongue + '" stroke="' + D.line + '" stroke-width="0.75"/>' : "")
  return '<g transform="translate(' + n(p.hx || 0) + ',' + n(p.hy || 0) + ') rotate(' + n(p.headTilt || 0) + ' 42 10)">'
    // skull + long muzzle in one outline
    + '<path d="M39.4 8.6 Q39 1 45.4 0.6 Q49.4 0.6 50.4 3.6 Q53.6 4.2 56 6.2 Q57.4 7.8 56.6 10 Q56 12.4 53.6 12.6 Q50.6 13.6 48.2 13.8 Q43.6 14.6 41 12.6 Q39.6 11 39.4 8.6 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '<path d="M50 4 Q50.6 6.4 50 8.6" stroke="' + D.shade + '" stroke-width="0.9" fill="none" stroke-linecap="round"/>'
    + jaw
    + '<ellipse cx="56" cy="7.8" rx="1.7" ry="1.45" fill="' + D.nose + '"/><circle cx="55.5" cy="7.3" r="0.45" fill="#fff" opacity="0.8"/>'
    + eye
    // floppy ear
    + '<g transform="rotate(' + n(p.ear || 0) + ' 43 2.6)">'
    + '<path d="M44.6 1.8 Q40.4 1 39.6 5.6 Q39 10.6 40.6 13 Q42.6 14 43.4 11.4 Q44.2 7.6 46 3.6 Z" fill="' + D.ear + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '</g></g>'
}
// neck + deep chest + back + tucked belly + rump, as one outline
function dtorso() {
  return '<path d="M40.6 9.4 Q36.6 14.6 33.6 17.4 Q24 18.6 17.6 18.2 Q11.6 18.6 11.6 25.2 Q11.8 31.4 18.6 32 Q23.6 31.2 28.6 32.6 Q34 36.2 40.6 35.8 Q46.6 35 47.2 28.4 Q47.4 23 45 19.6 Q44 15.6 45.6 12.6 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
    + '<path d="M36.6 21 Q34.6 27 37.6 33.4" stroke="' + D.shade + '" stroke-width="1" fill="none" stroke-linecap="round"/>'
    + '<path d="M19.4 21.6 Q15.6 24.6 17.4 30" stroke="' + D.shade + '" stroke-width="1" fill="none" stroke-linecap="round"/>'
    + '<path d="M29.4 32.6 Q34.6 35.4 40.4 35" stroke="' + D.shade + '" stroke-width="1.4" fill="none" stroke-linecap="round"/>'
    + '<path d="M40.4 11.6 Q43 15.4 45.4 15.6" stroke="' + D.collar + '" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
    + '<circle cx="45" cy="16.8" r="1.15" fill="' + D.tag + '" stroke="' + D.line + '" stroke-width="0.5"/>'
}
// pose: legs (fnear/ffar/bnear/bfar, + = forward), tail, ear, bob, lean, eyes, mouth, sit, lie, headTilt
function dog(p) {
  var body
  if (p.sit) {
    body = dtail((p.tail || 10) - 70, 14, 44)
      + fleg(38.4, 31.4, 0, true, 18.6)
      + '<path d="M40.4 10.4 Q36 14 32 18.4 Q24 24 17.6 33 Q12.6 40 15 46.4 Q18 50.4 25 50 L30 50 Q33 45 35.4 39 Q40.6 37.6 44.6 33 Q47.4 28 46 21 Q44.4 16.4 45.8 12.6 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
      + '<ellipse cx="22.4" cy="43.4" rx="7.6" ry="6.6" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '"/>'
      + '<path d="M20 49.6 Q26 51.6 31.6 49.6 Q31 47.4 27.4 47.4 Q23 47.4 20 49.6 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
      + '<path d="M40.4 11.6 Q43 15.4 45.4 15.6" stroke="' + D.collar + '" stroke-width="2.2" fill="none" stroke-linecap="round"/>'
      + '<circle cx="45" cy="16.8" r="1.15" fill="' + D.tag + '" stroke="' + D.line + '" stroke-width="0.5"/>'
      + fleg(41.4, 31.6, 0, false, 18.4)
      + dhead({ hx: -1, hy: -1, eyes: p.eyes, mouth: p.mouth, ear: p.ear, headTilt: p.headTilt })
  } else if (p.lie) {
    body = dtail(80, 12, 42)
      + '<path d="M11.6 45 Q11.6 37 19 36.6 Q30 35.6 40 37.6 Q46 39 46 45 Q46 50.2 40 50.2 L17 50.2 Q11.6 50.2 11.6 45 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
      + '<path d="M15 47.6 Q22 50.6 30 50" stroke="' + D.shade + '" stroke-width="1.2" fill="none" stroke-linecap="round"/>'
      + '<path d="M40 46.4 L55.6 46.4 Q58 48.2 55.6 50.2 L40 50.2 Z" fill="' + D.fur + '" stroke="' + D.line + '" stroke-width="' + LW + '" stroke-linejoin="round"/>'
      + dhead({ hx: -1, hy: 33.4, eyes: "closed", ear: 6, headTilt: 4 })
  } else {
    // long legs need a shorter swing than the old pup poses were tuned for;
    // all legs sit under the torso so their tops tuck into the body
    var k = 0.55
    body = dtail(p.tail || 0)
      + fleg(38.4, 30.6, (p.ffar || 0) * k, true) + hleg(21, 26.6, (p.bfar || 0) * k, true)
      + fleg(41.8, 30.6, (p.fnear || 0) * k, false) + hleg(17.6, 26.8, (p.bnear || 0) * k, false)
      + dtorso()
      + dhead({ eyes: p.eyes, mouth: p.mouth, ear: p.ear, headTilt: p.headTilt })
  }
  return '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 -3 62 54">'
    + '<g transform="translate(0,' + n(p.bob || 0) + ') rotate(' + n((p.lean || 0) * 0.5) + ' 24 50)">' + body + '</g></svg>'
}

function uri(svgText) { return "data:image/svg+xml;utf8," + encodeURIComponent(svgText) }

function build() {
  var g = {}
  function add(name, pose) { g[name] = { url: uri(guy(pose)), w: GUY_SIZE[0], h: GUY_SIZE[1] } }

  add("stand", { armF: 6, armB: -6 })
  add("blink", { armF: 6, armB: -6, eyes: "blink" })
  for (var i = 0; i < 6; i++) {
    var ph = i / 6 * Math.PI * 2, s = Math.sin(ph)
    add("run" + i,  { legF: 34 * s, legB: -34 * s, armF: -32 * s, armB: 32 * s, bob: -1.4 * Math.abs(Math.cos(ph)) + 0.7, lean: 4 })
    add("flee" + i, { legF: 48 * s, legB: -48 * s, armF: -55 * s + 10, armB: 55 * s + 10, bob: -2 * Math.abs(Math.cos(ph)) + 1,
                      lean: 10, eyes: "shock", mouth: "o" })
  }
  add("jump",   { legF: 30, legB: -24, armF: 125, armB: -120, eyes: "happy", mouth: "open" })
  add("cheer",  { armF: 118, armB: -112, eyes: "happy", mouth: "open" })
  add("cheer2", { armF: 132, armB: -126, eyes: "happy", mouth: "open", bob: -1.5 })
  add("wave",   { armF: 112, armB: -6, eyes: "happy", mouth: "smile" })
  add("wave2",  { armF: 138, armB: -6, eyes: "happy", mouth: "smile" })
  add("taunt",  { armF: 100, armB: -10, eyes: "wink", mouth: "tongue", tilt: -6 })
  add("taunt2", { armF: 122, armB: -10, eyes: "wink", mouth: "tongue", tilt: 4 })
  add("dance0", { legF: 22, legB: -8, armF: 128, armB: -50, lean: -7, eyes: "happy", mouth: "open" })
  add("dance1", { legF: -6, legB: 14, armF: 40, armB: -125, lean: 7, eyes: "happy", mouth: "smile", bob: -1.5 })
  add("dance2", { legF: 10, legB: -20, armF: 122, armB: -122, eyes: "happy", mouth: "open", bob: -2 })
  add("dance3", { legF: -14, legB: 6, armF: 60, armB: 60, lean: 3, eyes: "wink", mouth: "tongue" })
  add("push",   { legF: -20, legB: -44, armF: 82, armB: 74, lean: 14, eyes: "open", mouth: "flat" })
  add("push2",  { legF: -36, legB: -16, armF: 86, armB: 70, lean: 16, eyes: "blink", mouth: "flat" })
  add("pull",   { legF: 38, legB: -4, armF: 80, armB: 72, lean: -15, eyes: "blink", mouth: "flat" })
  add("pull2",  { legF: 24, legB: -16, armF: 86, armB: 78, lean: -10, eyes: "open", mouth: "o" })
  add("tie",    { legF: 46, legB: -14, armF: 58, armB: 44, lean: 18, bob: 2.5, eyes: "open", mouth: "tongue", tilt: 6 })
  add("tie2",   { legF: 46, legB: -14, armF: 70, armB: 36, lean: 18, bob: 2.5, eyes: "open", mouth: "tongue", tilt: 6 })
  add("throw",  { legF: 18, legB: -16, armF: -135, armB: 30, lean: -8, eyes: "open", mouth: "smile" })
  add("throw2", { legF: -12, legB: 22, armF: 115, armB: -35, lean: 9, eyes: "happy", mouth: "open" })
  add("sit",    { legF: 84, legB: 76, armF: 26, armB: 10, bob: 9 })
  add("sitBlink", { legF: 84, legB: 76, armF: 26, armB: 10, bob: 9, eyes: "blink" })
  add("sleep",  { legF: 84, legB: 76, armF: 18, armB: 8, bob: 9.6, eyes: "sleep", mouth: "flat", tilt: 10 })
  add("caught", { armF: 128, armB: -128, eyes: "shock", mouth: "o" })
  add("hang",   { legF: 10, legB: -12, armF: 150, armB: -150, eyes: "happy", mouth: "open" })

  var dg = {}
  function addD(name, pose) { dg[name] = { url: uri(dog(pose)), w: DOG_SIZE[0], h: DOG_SIZE[1] } }
  addD("stand", { tail: 25 })
  addD("wag", { tail: -5, eyes: "happy", mouth: "tongue" })
  addD("wag2", { tail: 45, eyes: "happy", mouth: "tongue" })
  for (var r = 0; r < 6; r++) {
    var q = Math.sin(r / 6 * Math.PI * 2)
    addD("run" + r, { fnear: 38 * q, ffar: 30 * q, bnear: -38 * q, bfar: -30 * q, tail: 30 + 10 * q, ear: -22,
                      bob: -1.2 * Math.abs(Math.cos(r / 6 * Math.PI * 2)) + 0.6, mouth: "tongue" })
  }
  addD("jump", { fnear: 50, ffar: 40, bnear: -50, bfar: -40, tail: 40, ear: -30, mouth: "tongue", lean: -8 })
  addD("bark", { tail: 30, mouth: "bark", headTilt: -8 })
  addD("bow", { fnear: 70, ffar: 64, tail: 50, lean: 14, eyes: "happy", mouth: "tongue" })
  addD("tug", { fnear: 34, ffar: 26, bnear: 14, bfar: 8, lean: -7, tail: 8, ear: 18, headTilt: 10, eyes: "closed" })
  addD("tug2", { fnear: 26, ffar: 20, bnear: 6, bfar: 2, lean: -4, tail: 22, ear: 10, headTilt: 4 })
  addD("shove", { fnear: -24, ffar: -16, bnear: -38, bfar: -30, lean: 12, tail: 12, ear: -18, headTilt: 14, eyes: "closed" })
  addD("shove2", { fnear: -12, ffar: -26, bnear: -26, bfar: -40, lean: 10, tail: 24, ear: -12, headTilt: 10 })
  addD("sit", { sit: true, tail: 0 })
  addD("sitWag", { sit: true, tail: 40, eyes: "happy", mouth: "tongue" })
  addD("sleep", { lie: true })
  // toys for fetch
  var it = {}
  function addI(name, w, h, svg) { it[name] = { url: uri(svg), w: w, h: h } }
  addI("ball", 9, 9, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">'
    + '<circle cx="10" cy="10" r="8.6" fill="#d4ee4e" stroke="' + INK + '" stroke-width="1.4"/>'
    + '<path d="M3.2 5.6 Q9 10 3.4 14.6 M16.8 5.4 Q11 10 16.6 14.6" stroke="#ffffff" stroke-width="1.6" fill="none" stroke-linecap="round"/>'
    + '<circle cx="7" cy="6.4" r="1.6" fill="#f2ffb8" opacity="0.8"/></svg>')
  addI("bone", 15, 7, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 15">'
    + '<path d="M7 4.6 Q6.6 1.2 4 1.4 Q1 1.6 1.4 4.4 Q0.6 7.4 1.4 10.4 Q1 13.4 4 13.6 Q6.6 13.8 7 10.4 L25 10.4 Q25.4 13.8 28 13.6 Q31 13.4 30.6 10.4 Q31.4 7.4 30.6 4.4 Q31 1.6 28 1.4 Q25.4 1.2 25 4.6 Z" fill="#f6eedc" stroke="' + INK + '" stroke-width="1.3" stroke-linejoin="round"/>'
    + '<path d="M8 8.6 L24 8.6" stroke="#ded3bc" stroke-width="1.2" stroke-linecap="round"/></svg>')
  addI("frisbee", 14, 6, '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 30 13">'
    + '<ellipse cx="15" cy="6.6" rx="13.6" ry="5" fill="#ff5f6d" stroke="' + INK + '" stroke-width="1.3"/>'
    + '<ellipse cx="15" cy="5.6" rx="8" ry="2.4" fill="#ff8f99"/></svg>')
  return { guy: g, dog: dg, items: it }
}
