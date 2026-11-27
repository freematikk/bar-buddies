.pragma library
// Tiny event bus shared by every plugin that imports this file
// (a .pragma library script is one instance per engine).
// Bar Buddies keeps its shared world here: each bar's obstacle map, the
// widgets Dash can move and their offsets, plus a small event channel
// ({type:"stomp", ws, screen}) other widgets may listen to.
var listeners = []
var screens = ({})        // screenName -> { x0, w, h, ground, obstacles: [...] }

function listen(fn) { listeners.push(fn); return fn }
function unlisten(fn) { var i = listeners.indexOf(fn); if (i >= 0) listeners.splice(i, 1) }
function emit(ev) {
  for (var i = listeners.length - 1; i >= 0; i--) {
    try { listeners[i](ev) } catch (e) { listeners.splice(i, 1) }
  }
}
function setScreen(name, info) { screens[name] = info }
function allScreens() { return screens }

// Widgets the runner can move: "<screen>|<moduleName>" -> bar item, and the
// horizontal offset (px) each one currently has.
var items = ({})
var offsets = ({})
