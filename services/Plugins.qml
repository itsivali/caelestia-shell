pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs.utils

Singleton {
    id: root

    // Plugins are plain .qml files dropped into this directory. A plugin's root
    // object must be an Item; optional "// Description: ..." comment lines show
    // up in the settings UI.
    readonly property string dir: `${Paths.data}/plugins`
    readonly property string statePath: `${Paths.state}/plugins.json`

    // Absolute paths of every discovered plugin, sorted
    property list<string> files: []
    // file path -> { name, description }
    property var meta: ({})
    // file paths the user switched on
    property list<string> enabledFiles: []
    // file path -> message from the last failed load
    property var errors: ({})

    readonly property int count: files.length
    readonly property int enabledCount: enabledFiles.filter(f => files.includes(f)).length

    signal rescanned

    function rescan(): void {
        scanProc.running = false;
        scanProc.running = true;
    }

    function setEnabled(file: string, on: bool): void {
        const next = root.enabledFiles.filter(f => f !== file);
        if (on)
            next.push(file);
        next.sort();

        root.setEnabledState(next, file);
    }

    function setEnabledState(next: var, changed: string): void {
        root.enabledFiles = next;
        root.reportError(changed, "");
        stateFile.setText(JSON.stringify(next));
    }

    function reportError(file: string, message: string): void {
        const next = Object.assign({}, root.errors);
        if (message)
            next[file] = message;
        else
            delete next[file];
        root.errors = next;
    }

    function displayName(file: string): string {
        return root.meta[file]?.name ?? file.split("/").pop().replace(/\.qml$/, "");
    }

    function description(file: string): string {
        return root.meta[file]?.description ?? "";
    }

    Process {
        id: scanProc

        command: ["sh", "-c", `for f in "$1"/*.qml; do [ -f "$f" ] || continue; printf '%s\\t%s\\n' "$f" "$(grep -m1 -oP '^//\\s*[Dd]escription:\\s*\\K.*' "$f" 2>/dev/null)"; done`, "sh", root.dir]

        stdout: StdioCollector {
            onStreamFinished: {
                const found = [];
                const meta = {};

                for (const line of text.split("\n")) {
                    if (!line)
                        continue;

                    const i = line.indexOf("\t");
                    const path = i === -1 ? line : line.slice(0, i);
                    found.push(path);
                    meta[path] = {
                        name: path.split("/").pop().replace(/\.qml$/, ""),
                        description: i === -1 ? "" : line.slice(i + 1).trim()
                    };
                }

                found.sort();
                root.files = found;
                root.meta = meta;
                root.rescanned();
            }
        }

        onExited: exitCode => {
            if (exitCode !== 0)
                root.rescanned();
        }
    }

    FileView {
        id: stateFile

        path: root.statePath
        printErrors: false

        onLoaded: {
            let data = [];
            try {
                data = JSON.parse(stateFile.text());
            } catch (e) {
                data = [];
            }

            if (!Array.isArray(data))
                data = [];

            data = data.filter(f => typeof f === "string");
            if (JSON.stringify(data) !== JSON.stringify(root.enabledFiles))
                root.enabledFiles = data;
        }

        onLoadFailed: err => {
            if (err === FileViewError.FileNotFound)
                Qt.callLater(() => stateFile.setText("[]"));
        }
    }

    Component.onCompleted: rescan()
}
