#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

run_node_test <<'JS'
const fs = require('fs')
const panelSource = fs.readFileSync(root + '/shell/plugins/agents/Panel.qml', 'utf8')

const signInFunctions = ['supportsSignIn', 'needsSignIn', 'otherTrouble'].map(name => {
  const match = panelSource.match(new RegExp('function ' + name + '\\([^]*?\\n  \\}'))
  return match ? match[0] : ''
}).join('\n')
const signIn = new Function('addProviders', signInFunctions + '\nreturn {needsSignIn, otherTrouble}')(
  [{providerId: 'claude'}, {providerId: 'codex'}, {providerId: 'grok'}]
)
for (const id of ['claude', 'codex', 'grok'])
  assert(signIn.needsSignIn({providerId: id, usageStatusText: 'Sign-in expired'}), id + ' keeps its sign-in link')
assert(signIn.needsSignIn({usageStatusText: 'Sign-in expired'}), 'account rows keep their sign-in link')
for (const status of ['Sign-in expired', 'Waiting for auth']) {
  assert(!signIn.needsSignIn({providerId: 'agy', usageStatusText: status}), 'an agent the panel cannot sign in gets no link for ' + status)
  assert(signIn.otherTrouble({providerId: 'agy', usageStatusText: status}) === status, 'an agent the panel cannot sign in still shows ' + status)
}
assert(/function launchAgent\(\)/.test(panelSource), 'agents panel launches the default agent')
assert(/root\.bar\.run\("omarchy-agent --pick"\)/.test(panelSource), 'agents panel uses the desktop agent launcher')
assert(/if \(buttonCode === Qt\.RightButton\) root\.launchAgent\(\)/.test(panelSource), 'agents right click launches the agent')
assert(/else if \(buttonCode === Qt\.MiddleButton\) root\.refreshNow\(\)/.test(panelSource), 'agents middle click refreshes the limits')
assert(/else root\.toggle\(\)/.test(panelSource), 'agents left click still toggles the panel')
assert(!/if \(buttonCode === Qt\.RightButton\) root\.refreshNow\(\)/.test(panelSource), 'agents right click no longer refreshes')
assert(/if \(root\.addStage === "" \|\| root\.picking\) root\.moveKey\(dx, dy\)/.test(panelSource), 'arrows move the agents panel cursor on the page and while picking an agent to add')
assert(/target\.kind === "choice"\) chooseAddProvider\(/.test(panelSource), 'Enter on an agent to add chooses it')
assert(!/text: root\.addStage === "running" \? "Cancel" : "Back"/.test(panelSource), 'the hero X is the only way back from adding')
assert(/hasCursor: root\.hasKey\("add"\)/.test(panelSource) && /hasCursor: root\.hasKey\("launch"\)/.test(panelSource), 'the hero buttons take the keyboard cursor')
assert(/hasCursor: root\.hasKey\("starter", index\)/.test(panelSource), 'the starter tiles take the keyboard cursor')
assert(/root\.pointAt\("account", Number\(t\) - 1\)/.test(panelSource), 'number keys move the cursor to an account')
assert(/target\.kind === "launch"\) launchAgent\(\)/.test(panelSource), 'Enter on the launcher starts the default agent')
assert(/row\.push\(\{ kind: "autoswitch", index: entry \}\)/.test(panelSource), 'an inactive account offers Autoswitch and Use as separate stops')
assert(/kind: "signin", index: entry/.test(panelSource) && /kind: "providerSignin", index: p/.test(panelSource), 'Sign-in required links are keyboard stops')
assert(/target\.kind === "signin"\) signInAgain\(/.test(panelSource) && /target\.kind === "providerSignin"\) signInAgain\(/.test(panelSource), 'Enter on Sign-in required signs in again')
assert(/target\.kind === "autoswitch"\) setSwitchMode\(/.test(panelSource), 'Enter on Autoswitch flips the switch mode')
assert(/keyColumn = use >= 0 \? use : /.test(panelSource), 'moving up or down onto an account lands on Use')
assert(/Qt\.callLater\(function\(\) \{ if \(picking\) pointAt\("choice", 0\) \}\)/.test(panelSource), 'picking an agent to add starts with the first one focused')
assert(!/opacity: stale \?/.test(panelSource) && /I18n\.t\("agents\.lastUpdatedAgo"\)\.arg\(root\.formatDuration/.test(panelSource), 'stale limits say how old they are only on hover')
assert(/onPickingChanged: resetKeys\(\)/.test(panelSource), 'the cursor starts over when the agent list comes or goes')
assert(!/t === "a" \|\| t === "A"/.test(panelSource), 'adding an account has no hotkey; the + is the way in')
assert(/if \(!accounts\[a\]\.active\) \{/.test(panelSource) && /if \(row\.length > 0\) rows\.push\(row\)/.test(panelSource), 'the active account with nothing to fix is not a keyboard stop')
assert(/text: section\.provider \? \(root\.helpDisplayText\(section\.provider\.authHelpText\) \|\| root\.statusDisplayText\(section\.provider\.usageStatusText\) \|\| ""\) : ""/.test(panelSource), 'the trouble line falls back to the usage status when a record has no auth help')
assert(/case "Run `codex login` to authenticate\.":\s*return Commons\.I18n\.t\("agents\.helpRunToAuthenticate"\)\.arg\("`codex login`"\)/.test(panelSource), 'known collector help lines are translated at display, commands kept verbatim')
// A reworded collector line would silently fall back to English, so every
// fixed help line the collectors cache must still be one the panel maps.
for (const name of ['claude', 'codex', 'grok', 'fireworks']) {
  const collector = fs.readFileSync(root + '/bin/omarchy-agent-usage-' + name, 'utf8')
  const help = collector.match(/^AUTH_HELP = "([^"]+)"$/m)
  assert(help && panelSource.includes('case ' + JSON.stringify(help[1]) + ':'), name + ' auth help is translated in the panel')
}
const mainSource = fs.readFileSync(root + '/shell/plugins/agents/Main.qml', 'utf8')
assert(/var from = Math\.min\(0\.8, \(threshold - 15\) \/ 100\)/.test(mainSource), 'faster checks start 15 points below the switch threshold')
assert(/rows\.push\(\[\{ kind: "provider", index: p \}\]\)/.test(panelSource), "every agent's header is a keyboard stop")
assert(/reorderable: root\.addStage === "" && !root\.renaming/.test(panelSource) && /onEditingChanged: root\.renaming = editing/.test(panelSource) && /onReorderRequested: function\(dy\) \{ root\.reorderProvider\(dy\) \}/.test(panelSource), 'Ctrl+Up/Down moves the agent the cursor is in')
assert(/onReleased: root\.dropProvider\(\)/.test(panelSource), 'an agent can be dragged by its mark')
assert(/function moveProvider\(id, to\)/.test(mainSource) && /return orderedProviders\(result\)/.test(mainSource), 'the agents keep the order they were moved into')
const catcherSource = fs.readFileSync(root + '/shell/Ui/PanelKeyCatcher.qml', 'utf8')
assert(/if \(reorderable && \(event\.modifiers & Qt\.ControlModifier\)\)/.test(catcherSource), 'only panels that ask for it turn Ctrl+Up/Down into a reorder')
assert(/if \(\["account", "autoswitch", "signin"\]\.indexOf\(target\.kind\) < 0\) return -1/.test(panelSource), 'Ctrl+Up/Down does nothing outside an agent')
JS

# The panel reads a window out of a label, and that guess cannot survive a
# model name — "Opus 5 (1M context)" parses as a one-minute window. A collector
# that states the title outright is taken at its word.
run_node_test <<'JS'
const fs = require('fs')
const source = fs.readFileSync(root + '/shell/plugins/agents/Panel.qml', 'utf8')
const panelRoot = { nowMs: Date.now() }
const start = source.indexOf('function windowIsLong')
const end = source.indexOf('// The window that decides')
assert(start > 0 && end > start, 'agents panel exposes its limit-window helpers')
eval(source.slice(start, end).replaceAll('root.nowMs', 'panelRoot.nowMs'))
eval(source.slice(source.indexOf('function needsSignIn'), source.indexOf('// Sign an account')))

const paused = { usageStatusText: 'Limits paused', limits: [] }
assertEqual(pausedWithoutLimits(paused), true, 'paused usage without a cache shows a recovery placeholder')
assertEqual(otherTrouble(paused), '', 'paused usage never puts the confusing status in the header')
assertEqual(pausedWithoutLimits({ ...paused, limits: [{ label: 'Session (5-hour)', percent: 0, resetsAt: '' }] }), false, 'cached usage replaces the recovery placeholder')
assertEqual(pausedWithoutLimits({ usageStatusText: 'Sign-in expired', limits: [] }), false, 'expired sign-ins retain their sign-in action')
assertEqual(pausedWithoutLimits(null), false, 'missing records do not show a paused-usage placeholder')

assertDeepEqual(
  limitWindows({ limits: [
    { label: 'Session (5-hour)', percent: 0.78, resetsAt: '' },
    { label: 'Opus 5 (1M context) Weekly', title: 'Opus 5 (1M context) Weekly', percent: 0.42, resetsAt: '' }
  ] }),
  [
    { title: 'Session', percent: 0.78, resetAt: '', spanMs: 18000000 },
    { title: 'Opus 5 (1M context) Weekly', percent: 0.42, resetAt: '', spanMs: 604800000 }
  ],
  'agents panel titles a limit off the collector when it states one'
)

assertDeepEqual(
  limitWindows({ limits: [{ label: 'Weekly (7-day)', percent: 0.12, resetsAt: '' }] }),
  [{ title: 'Weekly', percent: 0.12, resetAt: '', spanMs: 604800000 }],
  'agents panel still reads a window out of a label that carries no title'
)

const resetAt = new Date(panelRoot.nowMs + 1000).toISOString()
const measured = { limits: [{ label: 'Session (5-hour)', percent: 0.78, resetsAt: resetAt }] }
assertEqual(limitWindows(measured)[0].percent, 0.78, 'usage remains until the reset time')
panelRoot.nowMs += 1000
assertDeepEqual(limitWindows(measured), [{ title: 'Session', percent: 0, resetAt: '', spanMs: 18000000 }], 'usage resets at the deadline while the panel stays open')
assertEqual(measured.limits[0].percent, 0.78, 'display reset leaves the measured record intact')

// A model's weekly allowance is a row of its own, paced on the weekly clock.
assertDeepEqual(
  limitWindows({ limits: [{ label: 'Fable Weekly', title: 'Fable Weekly', percent: 0.09, resetsAt: '' }] }),
  [{ title: 'Fable Weekly', percent: 0.09, resetAt: '', spanMs: 604800000 }],
  'agents panel gives a model-scoped window the span of the window it runs on'
)
// A scoped session's label carries no length; it borrows the session's.
assertDeepEqual(
  limitWindows({ limits: [
    { label: 'Session (5-hour)', percent: 0.5, resetsAt: '' },
    { label: 'Fable Session', title: 'Fable Session', percent: 0.2, resetsAt: '' },
    { label: 'Opus Monthly', title: 'Opus Monthly', percent: 0.1, resetsAt: '' }
  ] }).map(w => [w.title, w.spanMs]),
  [['Session', 18000000], ['Fable Session', 18000000], ['Opus Monthly', 0]],
  'a model-scoped session paces on the session clock, and a monthly one still draws no pace'
)

// Pace weighs what is left against the share of the window still ahead; the
// projection carries the rate so far to the reset and stays quiet where it
// would only guess.
const clamp = (v, lo, hi) => Math.max(lo, Math.min(hi, v))
eval(source.slice(source.indexOf('function resetMsFor'), source.indexOf('function formatDuration')).replaceAll('root.nowMs', 'panelRoot.nowMs'))
eval(source.slice(source.indexOf('function windowLeft'), source.indexOf('// Within the on-pace band')).replaceAll('root.nowMs', 'panelRoot.nowMs'))
const hour = 3600 * 1000
const weekly = (percent, hoursLeft) => ({ percent, resetAt: new Date(panelRoot.nowMs + hoursLeft * hour).toISOString(), spanMs: 168 * hour })

const heavy = paceFor(weekly(0.4, 128))
assertEqual(heavy.state, 'ahead', 'less left than the share of the window ahead is ahead of pace')
assertEqual(Math.round(heavy.evenLeft * 100), 76, 'the pace tick sits at the share of the window still ahead')
assertEqual(Math.round(-heavy.leftAtReset * 100), 68, 'an allowance that runs dry says how much more the rate needs')
assertEqual(Math.round(heavy.runsOutMs / hour), 60, 'an allowance that runs dry says when')
assertEqual(paceFor(weekly(0.27, 128)).state, 'on', 'within five points of the clock is on pace')
const light = paceFor(weekly(0.1, 128))
assertEqual(light.state, 'under', 'more left than the clock is under pace')
assertEqual(Math.round(light.leftAtReset * 100), 58, 'the projection says what is still left at the reset')
assertEqual(light.runsOutMs, -1, 'an allowance that outlasts its window never runs out')
assertEqual(paceFor(weekly(0.03, 167)).projected, false, 'the first 5% of a window projects nothing')
assertEqual(paceFor({ ...weekly(0.4, 128), spanMs: 60 * 1000 }), null, 'a span shorter than the time to reset is a misread label')
const session = { limits: [{ label: 'Session (5-hour)', percent: 0.5, resetsAt: new Date(panelRoot.nowMs + 2.5 * hour).toISOString() }] }
assertEqual(paceFor(limitWindows(session)[0]).evenLeft, 0.5, 'the window length comes from the collector label')
const monthly = { limits: [{ label: 'Monthly', percent: 0.15, resetsAt: new Date(panelRoot.nowMs + 26 * 24 * hour).toISOString() }] }
assertEqual(paceFor(limitWindows(monthly)[0]), null, 'a monthly window of unknown length draws no pace')
JS
