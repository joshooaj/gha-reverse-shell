const WebSocket = require('ws')
const fs = require('node:fs');
const { v4: uuidv4, stringify } = require("uuid");
var os = require('os');
var pty = require('node-pty');

const wss = new WebSocket.Server({ port: 6060 })

console.log("Socket is up and running...")

var shell = 'pwsh';
if (process.platform === 'win32') {
    shell = 'powershell.exe';
}

wss.on('connection', ws => {
    const sessionId = uuidv4();

    var ptyProcess = pty.spawn(shell, ["-NoLogo", "-NonInteractive"], {
        name: 'xterm-color',
        cwd: process.cwd(),
        env: process.env,
    });

    // Catch incoming request
    ws.on('message', command => {
        var processedCommand = commandProcessor(command);
        ptyProcess.write(processedCommand);
    })

    // Output: Sent to the frontend
    ptyProcess.on('data', function (rawOutput) {
        var processedOutput = outputProcessor(rawOutput);
        ws.send(processedOutput);
        process.stdout.write(processedOutput)
    });

    

    ws.on('close', (event) => {
        ptyProcess.write("\r\nexit\r\n");
    });

    const commandProcessor = function (command) {
        return command;
    }
    
    const outputProcessor = function (output) {
        return output;
    }
})


