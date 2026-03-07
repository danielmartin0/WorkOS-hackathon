const { contextBridge, ipcRenderer } = require('electron')

contextBridge.exposeInMainWorld('adal', {
  listSessions: () => ipcRenderer.invoke('list-sessions'),
  attach: (session) => ipcRenderer.invoke('attach', session),
  sendMessage: (text) => ipcRenderer.invoke('send-message', text),
  detach: () => ipcRenderer.invoke('detach'),
  onOutput: (cb) => ipcRenderer.on('output', (_, data) => cb(data)),
  listWindows: () => ipcRenderer.invoke('list-windows'),
  anchor: (pid) => ipcRenderer.invoke('anchor', pid),
  unanchor: () => ipcRenderer.invoke('unanchor'),
})
