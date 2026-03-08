const { app, BrowserWindow, ipcMain } = require('electron')
const { execSync, execFileSync, spawn } = require('child_process')
const fs = require('fs')
const os = require('os')
const path = require('path')

let win
let terminalProcess = null
let outputTailProcess = null
let tmuxCaptureTimer = null
let lastTmuxSnapshot = ''
let attachedSession = null
let anchoredPid = null
let anchoredWindowId = null
let anchorTimer = null
const WININFO = path.join(__dirname, 'wininfo')
const OVERLAY_SESSION_ID = 'overlay-local-shell'
const SESSION_SCAN_CMD = 'ps -axo pid=,ppid=,tpgid=,tty=,command='
const BRIDGE_ROOT = path.join(os.homedir(), '.adal-overlay')
const TMUX_LIST_FORMAT = '#{pane_id}\t#{pane_tty}\t#{session_name}:#{window_index}.#{pane_index}\t#{pane_current_command}\t#{pane_active}\t#{pane_title}'
const overlaySession = {
  id: OVERLAY_SESSION_ID,
  type: 'local',
  title: 'Local Shell (overlay)',
}

app.whenReady().then(() => {
  const { screen } = require('electron')
  const { width } = screen.getPrimaryDisplay().workAreaSize

  win = new BrowserWindow({
    width: 340,
    height: 460,
    x: width - 350,
    y: 0,
    frame: false,
    transparent: true,
    alwaysOnTop: true,
    resizable: true,
    hasShadow: true,
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
    },
  })

  win.setAlwaysOnTop(true, 'screen-saver')
  win.loadFile('index.html')
})

// ── window listing ────────────────────────────────────────
function getWindows() {
  try {
    const out = execFileSync(WININFO, { encoding: 'utf8', timeout: 1000 })
    return JSON.parse(out)
  } catch { return [] }
}

ipcMain.handle('list-windows', () => getWindows())

// ── anchor to a window by pid ─────────────────────────────
ipcMain.handle('anchor', (_, pid) => {
  clearInterval(anchorTimer)
  const targetPid = Number(pid?.pid ?? pid)
  const targetWindowId = Number(pid?.id ?? pid?.windowId ?? 0)
  if (!targetPid && !targetWindowId) {
    anchoredPid = null
    anchoredWindowId = null
    return { ok: true }
  }
  anchoredPid = Number.isFinite(targetPid) ? targetPid : null
  anchoredWindowId = Number.isFinite(targetWindowId) ? targetWindowId : null
  anchorTimer = setInterval(() => {
    if ((!anchoredPid && !anchoredWindowId) || !win) return
    const windows = getWindows()
    const target = windows.find((w) => {
      if (anchoredWindowId && Number(w.id) === anchoredWindowId) return true
      if (anchoredPid && Number(w.pid) === anchoredPid) return true
      return false
    })
    if (!target) return
    const [ow] = win.getSize()
    const padding = 12
    // CGWindowList coords are already logical points, origin top-left of primary display
    const x = Math.round(target.x + target.w - ow - padding)
    const y = Math.round(target.y + padding)
    win.setPosition(x, y)
  }, 300)
  return { ok: true }
})

ipcMain.handle('unanchor', () => {
  clearInterval(anchorTimer)
  anchoredPid = null
  anchoredWindowId = null
  return { ok: true }
})

// ── terminal session listing ──────────────────────────────
function getBridgeLogPath(tty) {
  const safeName = String(tty).replace(/[^a-zA-Z0-9._-]/g, '_')
  return path.join(BRIDGE_ROOT, `${safeName}.log`)
}

function listTtySessions(excludedTtys = new Set()) {
  try {
    const out = execSync(SESSION_SCAN_CMD, { encoding: 'utf8' })
    const procs = out
      .split('\n')
      .map((line) => {
        const trimmed = line.trim()
        if (!trimmed) return null
        const match = trimmed.match(/^(\d+)\s+(\d+)\s+(-?\d+)\s+(\S+)\s+(.+)$/)
        if (!match) return null
        const [, pid, ppid, tpgid, tty, command] = match
        return { pid: Number(pid), ppid: Number(ppid), tpgid: Number(tpgid), tty, command }
      })
      .filter((p) => p && p.tty !== '?' && p.tty !== '??')

    const byPid = new Map(procs.map((p) => [p.pid, p]))
    const byTty = new Map()
    for (const proc of procs) {
      if (!byTty.has(proc.tty)) byTty.set(proc.tty, [])
      byTty.get(proc.tty).push(proc)
    }

    const shellRegex = /(^|\/)(zsh|bash|fish|sh|nu)(\s|$)/i
    const adalRegex = /(^|\s|\/)adal(\s|$)/i
    const rankedSessions = []
    for (const [tty, members] of byTty.entries()) {
      if (excludedTtys.has(tty)) continue
      const ranked = [...members].sort((a, b) => {
        const aAdal = adalRegex.test(a.command) ? 1 : 0
        const bAdal = adalRegex.test(b.command) ? 1 : 0
        if (bAdal !== aAdal) return bAdal - aAdal
        const aShell = shellRegex.test(a.command) ? 1 : 0
        const bShell = shellRegex.test(b.command) ? 1 : 0
        if (bShell !== aShell) return bShell - aShell
        return b.pid - a.pid
      })

      const best = ranked[0]
      const hasAdal = members.some((p) => adalRegex.test(p.command))
      const tpgid = members[0]?.tpgid ?? -1
      const foreground = members.find((p) => p.pid === tpgid)
      const foregroundCmd = foreground ? foreground.command.replace(/\s+/g, ' ').trim() : ''
      const adalForeground = Boolean(foregroundCmd && adalRegex.test(foregroundCmd))
      const bridgeLog = getBridgeLogPath(tty)
      const bridgeReady = fs.existsSync(bridgeLog)
      let cur = byPid.get(best.ppid)
      let owner = ''
      let depth = 0
      while (cur && depth < 8) {
        if (cur.tty === '?' || cur.tty === '??') {
          owner = path.basename(cur.command.split(/\s+/)[0] || '')
          break
        }
        cur = byPid.get(cur.ppid)
        depth += 1
      }

      const cmd = best.command.replace(/\s+/g, ' ').trim()
      const bridgeLabel = bridgeReady ? 'bridge:on' : 'bridge:off'
      const fgLabel = adalForeground ? 'fg:adal' : 'fg:other'
      const title = `${hasAdal ? 'AdaL' : 'Shell'}${owner ? ` @ ${owner}` : ''} — ${tty} (${bridgeLabel}, ${fgLabel}) — ${cmd}`
      rankedSessions.push({
        id: `tty:${tty}`,
        type: 'tty',
        tty,
        pid: best.pid,
        hasAdal,
        bridgeReady,
        adalForeground,
        foregroundCmd,
        title,
        cmd,
      })
    }

    rankedSessions.sort((a, b) => {
      if (a.hasAdal !== b.hasAdal) return a.hasAdal ? -1 : 1
      return a.title.localeCompare(b.title)
    })
    return rankedSessions
  } catch {
    return []
  }
}

function listTmuxSessions() {
  try {
    const ttyIndex = new Map(listTtySessions().map((s) => [s.tty, s]))
    const out = execFileSync('tmux', ['list-panes', '-a', '-F', TMUX_LIST_FORMAT], {
      encoding: 'utf8',
      stdio: ['ignore', 'pipe', 'ignore'],
    })
    const adalRegex = /(^|\s|\/)adal(\s|$)/i
    const sessions = out
      .split('\n')
      .map((line) => {
        const trimmed = line.trim()
        if (!trimmed) return null
        const [paneId, paneTtyPath, paneRef, paneCurrentCommand, paneActive, paneTitle] = trimmed.split('\t')
        if (!paneId || !paneTtyPath) return null
        const tty = paneTtyPath.replace('/dev/', '')
        const ttyMeta = ttyIndex.get(tty)
        const hasAdal = Boolean(ttyMeta?.hasAdal || adalRegex.test(paneCurrentCommand || '') || adalRegex.test(paneTitle || ''))
        const adalForeground = ttyMeta?.adalForeground ?? (hasAdal && paneActive === '1')
        const foregroundCmd = ttyMeta?.foregroundCmd || paneCurrentCommand || ''
        const fgLabel = adalForeground ? 'fg:adal' : 'fg:other'
        const title = `TMUX ${paneRef} — ${tty} (${fgLabel}) — ${paneCurrentCommand || ''}`
        return {
          id: `tmux:${paneId}`,
          type: 'tmux',
          paneId,
          paneRef,
          tty,
          hasAdal,
          bridgeReady: true,
          adalForeground,
          foregroundCmd,
          title,
          cmd: paneCurrentCommand || '',
        }
      })
      .filter(Boolean)
      .sort((a, b) => {
        if (a.hasAdal !== b.hasAdal) return a.hasAdal ? -1 : 1
        return a.title.localeCompare(b.title)
      })
    return sessions
  } catch {
    return []
  }
}

function listAllSessions() {
  const tmuxSessions = listTmuxSessions()
  const tmuxTtys = new Set(tmuxSessions.map((s) => s.tty))
  const ttySessions = listTtySessions(tmuxTtys)
  return [...tmuxSessions, ...ttySessions, overlaySession]
}

ipcMain.handle('list-sessions', () => listAllSessions())

function emitOutput(text, isError = false, mode = 'append') {
  if (!win || win.isDestroyed()) return
  win.webContents.send('output', { text, isError, mode })
}

function stopOutputTail() {
  if (outputTailProcess && !outputTailProcess.killed) {
    outputTailProcess.kill()
  }
  outputTailProcess = null
}

function stopTmuxCapture() {
  if (tmuxCaptureTimer) clearInterval(tmuxCaptureTimer)
  tmuxCaptureTimer = null
  lastTmuxSnapshot = ''
}

function stopTerminal() {
  if (terminalProcess && !terminalProcess.killed) {
    terminalProcess.kill()
  }
  terminalProcess = null
}

function stopSessionTransports() {
  stopTerminal()
  stopOutputTail()
  stopTmuxCapture()
}

function hasWritableTerminal() {
  return Boolean(
    attachedSession &&
    attachedSession.type === 'local' &&
    terminalProcess &&
    !terminalProcess.killed &&
    terminalProcess.stdin &&
    !terminalProcess.stdin.destroyed &&
    !terminalProcess.stdin.writableEnded
  )
}

function startTerminal(session) {
  const shell = process.env.SHELL || '/bin/zsh'
  const shellEnv = { ...process.env, TERM: process.env.TERM || 'xterm-256color' }
  const cwd = process.cwd()

  // Login shell over pipes gives a stable persistent command channel.
  const proc = spawn(shell, ['-l'], { cwd, env: shellEnv, stdio: 'pipe' })
  terminalProcess = proc
  attachedSession = session

  proc.stdout.on('data', (d) => {
    if (terminalProcess !== proc) return
    emitOutput(d.toString(), false)
  })
  proc.stderr.on('data', (d) => {
    if (terminalProcess !== proc) return
    emitOutput(d.toString(), true)
  })
  proc.on('error', (e) => {
    if (terminalProcess !== proc) return
    emitOutput(`terminal error: ${e.message}`, true)
  })
  proc.on('exit', (code, signal) => {
    if (terminalProcess !== proc) return
    const exitReason = signal ? `signal ${signal}` : `code ${code ?? 0}`
    emitOutput(`[detached: ${exitReason}]`, true)
    terminalProcess = null
    attachedSession = null
  })
}

function startOutputTail(logFile) {
  fs.mkdirSync(path.dirname(logFile), { recursive: true })
  if (!fs.existsSync(logFile)) fs.writeFileSync(logFile, '', 'utf8')

  const proc = spawn('tail', ['-n', '0', '-F', logFile], { stdio: 'pipe' })
  outputTailProcess = proc

  proc.stdout.on('data', (d) => {
    if (outputTailProcess !== proc) return
    emitOutput(d.toString(), false)
  })
  proc.stderr.on('data', (d) => {
    if (outputTailProcess !== proc) return
    emitOutput(d.toString(), true)
  })
  proc.on('error', (e) => {
    if (outputTailProcess !== proc) return
    emitOutput(`tail error: ${e.message}`, true)
  })
  proc.on('exit', () => {
    if (outputTailProcess !== proc) return
    outputTailProcess = null
  })
}

function attachTtySession(session) {
  stopSessionTransports()
  const logPath = getBridgeLogPath(session.tty)
  startOutputTail(logPath)
  attachedSession = session
  const hint = session.bridgeReady
    ? `[bridge] watching ${logPath}. Direct TTY send is limited; use tmux session for reliable TUI submit.`
    : `[bridge] watching ${logPath}. Start Adal via ./bridge-adal.sh in that terminal for live stream.`
  emitOutput(hint, false)
}

function attachTmuxSession(session) {
  stopSessionTransports()
  attachedSession = session
  const capture = () => {
    if (attachedSession?.id !== session.id) return
    try {
      const snap = execFileSync('tmux', ['capture-pane', '-p', '-J', '-S', '-200', '-t', session.paneId], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'ignore'],
      })
      if (snap !== lastTmuxSnapshot) {
        lastTmuxSnapshot = snap
        emitOutput(snap, false, 'replace')
      }
    } catch (e) {
      emitOutput(`tmux capture error: ${e.message}`, true)
      stopTmuxCapture()
    }
  }
  capture()
  tmuxCaptureTimer = setInterval(capture, 250)
  emitOutput(`[tmux] attached ${session.paneRef} on ${session.tty}`, false)
}

function getLiveSession(sessionId) {
  return listAllSessions().find((s) => s.id === sessionId)
}

// ── attach / detach ───────────────────────────────────────
ipcMain.handle('attach', (_, session) => {
  if (!session || !session.id) {
    return { ok: false, error: 'invalid session' }
  }

  if (attachedSession?.id === session.id) {
    return { ok: true }
  }

  if (session.type === 'tty') {
    try {
      const live = getLiveSession(session.id)
      if (!live) {
        return { ok: false, error: 'selected tty session is no longer available' }
      }
      if (!live.bridgeReady) {
        return {
          ok: false,
          error: `bridge not active for ${live.tty}. In that terminal run: cd ${__dirname} && ./bridge-adal.sh`,
        }
      }
      attachTtySession(live)
      return { ok: true }
    } catch (e) {
      stopSessionTransports()
      attachedSession = null
      return { ok: false, error: e.message }
    }
  }

  if (session.type === 'tmux') {
    try {
      const live = getLiveSession(session.id)
      if (!live || live.type !== 'tmux') {
        return { ok: false, error: 'selected tmux pane is no longer available' }
      }
      attachTmuxSession(live)
      return { ok: true }
    } catch (e) {
      stopSessionTransports()
      attachedSession = null
      return { ok: false, error: e.message }
    }
  }

  if (session.id !== OVERLAY_SESSION_ID) {
    return { ok: false, error: 'unknown session type' }
  }

  stopSessionTransports()
  startTerminal(overlaySession)
  return { ok: true }
})

ipcMain.handle('send-message', async (_, text) => {
  if (attachedSession?.type === 'tmux') {
    try {
      const live = getLiveSession(attachedSession.id)
      if (!live || live.type !== 'tmux') return { ok: false, error: 'attached tmux pane disappeared' }
      if (live.hasAdal && !live.adalForeground) {
        return {
          ok: false,
          error: `adal is not foreground in ${live.paneRef} (fg: ${live.foregroundCmd || 'unknown'})`,
        }
      }
      execFileSync('tmux', ['send-keys', '-t', live.paneId, '-l', String(text).trimEnd()], { encoding: 'utf8' })
      execFileSync('tmux', ['send-keys', '-t', live.paneId, 'Enter'], { encoding: 'utf8' })
      return { ok: true }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  }

  if (attachedSession?.type === 'tty') {
    if (!attachedSession?.tty) return { ok: false, error: 'no tty attached' }
    try {
      const live = getLiveSession(attachedSession.id)
      if (!live) return { ok: false, error: 'attached tty session disappeared' }
      if (!live.bridgeReady) return { ok: false, error: `bridge not active for ${live.tty}` }
      return {
        ok: false,
        error: `direct TTY submit is unreliable for TUIs. Use TMUX session for ${live.tty}.`,
      }
    } catch (e) {
      return { ok: false, error: e.message }
    }
  }

  if (!hasWritableTerminal()) {
    try {
      stopSessionTransports()
      startTerminal(overlaySession)
      emitOutput('[re-attached local shell]', false)
    } catch (e) {
      return { ok: false, error: `no session attached: ${e.message}` }
    }
  }
  try {
    await new Promise((resolve, reject) => {
      terminalProcess.stdin.write(`${String(text).trimEnd()}\n`, (err) => {
        if (err) reject(err)
        else resolve()
      })
    })
    return { ok: true }
  } catch (e) {
    return { ok: false, error: e.message }
  }
})

ipcMain.handle('detach', () => {
  stopSessionTransports()
  attachedSession = null
  return { ok: true }
})

app.on('before-quit', () => {
  clearInterval(anchorTimer)
  stopSessionTransports()
})

app.on('window-all-closed', () => app.quit())
