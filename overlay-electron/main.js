const { app, BrowserWindow, ipcMain } = require('electron')
const { execSync, execFileSync, spawn } = require('child_process')
const fs = require('fs')
const os = require('os')
const path = require('path')

let win
let terminalProcess = null
let outputTailProcess = null
let attachedSession = null
let anchoredPid = null
let anchoredWindowId = null
let anchorTimer = null
const WININFO = path.join(__dirname, 'wininfo')
const OVERLAY_SESSION_ID = 'overlay-local-shell'
const SESSION_SCAN_CMD = 'ps -axo pid=,ppid=,tty=,command='
const BRIDGE_ROOT = path.join(os.homedir(), '.adal-overlay')
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

function listTtySessions() {
  try {
    const out = execSync(SESSION_SCAN_CMD, { encoding: 'utf8' })
    const procs = out
      .split('\n')
      .map((line) => {
        const trimmed = line.trim()
        if (!trimmed) return null
        const match = trimmed.match(/^(\d+)\s+(\d+)\s+(\S+)\s+(.+)$/)
        if (!match) return null
        const [, pid, ppid, tty, command] = match
        return { pid: Number(pid), ppid: Number(ppid), tty, command }
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
      const title = `${hasAdal ? 'AdaL' : 'Shell'}${owner ? ` @ ${owner}` : ''} — ${tty} (${bridgeLabel}) — ${cmd}`
      rankedSessions.push({
        id: `tty:${tty}`,
        type: 'tty',
        tty,
        pid: best.pid,
        hasAdal,
        bridgeReady,
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

ipcMain.handle('list-sessions', () => [...listTtySessions(), overlaySession])

function emitOutput(text, isError = false) {
  if (!win || win.isDestroyed()) return
  win.webContents.send('output', { text, isError })
}

function stopOutputTail() {
  if (outputTailProcess && !outputTailProcess.killed) {
    outputTailProcess.kill()
  }
  outputTailProcess = null
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

function startTtyOutputTail(session) {
  const logFile = getBridgeLogPath(session.tty)
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
  startTtyOutputTail(session)
  attachedSession = session
  const logPath = getBridgeLogPath(session.tty)
  const hint = session.bridgeReady
    ? `[bridge] watching ${logPath}`
    : `[bridge] watching ${logPath}. Start Adal via ./bridge-adal.sh in that terminal for live stream.`
  emitOutput(hint, false)
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
      attachTtySession(session)
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
  if (attachedSession?.type === 'tty') {
    if (!attachedSession?.tty) return { ok: false, error: 'no tty attached' }
    try {
      fs.writeFileSync(`/dev/${attachedSession.tty}`, `${String(text).trimEnd()}\n`)
      return { ok: true }
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
