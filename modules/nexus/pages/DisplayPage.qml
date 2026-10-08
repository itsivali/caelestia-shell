pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Display")

    // The monitor IPC cache only updates on Hyprland events; refresh on entry
    Component.onCompleted: Hyprland.refreshMonitors()

    // Scales offered for this output
    readonly property list<real> scaleOptions: [0.75, 1, 1.25, 1.5, 2]

    readonly property var info: Hypr.focusedMonitor?.lastIpcObject ?? ({})

    readonly property string currentMode: {
        const modes = info.availableModes ?? [];
        const exact = `${info.width}x${info.height}@${(info.refreshRate ?? 0).toFixed(2)}Hz`;
        if (modes.includes(exact))
            return exact;
        return modes.find(m => m.startsWith(`${info.width}x${info.height}@`)) ?? exact;
    }
    readonly property real currentScale: info.scale ?? 1

    // "" / 0 means "no pending choice, follow the live state"
    property string chosenMode
    property real chosenScale

    readonly property string effectiveMode: chosenMode || currentMode
    readonly property real effectiveScale: chosenScale || currentScale

    // Countdown before an unconfirmed change is rolled back
    property bool pending
    property int countdown
    property string snapshotMode
    property real snapshotScale

    readonly property string luaPath: `${Paths.config}/hypr-user.lua`
    readonly property string blockBegin: "-- >>> caelestia:display (managed by the shell, do not edit) >>>"
    readonly property string blockEnd: "-- <<< caelestia:display <<<"

    readonly property var activeModeItem: modeItems.instances.find(i => i.text === root.effectiveMode) ?? modeItems.instances[0] ?? null
    readonly property var activeScaleItem: scaleItems.instances.find(i => i.value === root.effectiveScale) ?? scaleItems.instances[0] ?? null

    function evalMonitor(mode: string, scale: real): void {
        const m = mode.replace(/Hz$/, "");
        Quickshell.execDetached([
            "hyprctl",
            "eval",
            `hl.monitor({ output = '${root.info.name ?? ""}', mode = '${m}', position = '${info.x ?? 0}x${info.y ?? 0}', scale = ${scale} })`
        ]);

        // hyprctl eval emits no Hyprland event, so refresh the cached IPC data ourselves
        refreshTimer.restart();
    }

    function beginChange(mode: string, scale: real): void {
        if (!root.pending) {
            root.snapshotMode = root.currentMode;
            root.snapshotScale = root.currentScale;
        }

        root.pending = true;
        root.countdown = 15;
        countdownTimer.restart();
        evalMonitor(mode, scale);
    }

    function applyMode(mode: string): void {
        root.chosenMode = mode;
        beginChange(mode, root.effectiveScale);
    }

    function applyScale(scale: real): void {
        root.chosenScale = scale;
        beginChange(root.effectiveMode, scale);
    }

    function keep(): void {
        countdownTimer.stop();
        root.pending = false;
        save();
    }

    function rollback(): void {
        countdownTimer.stop();
        root.pending = false;
        root.chosenMode = "";
        root.chosenScale = 0;
        evalMonitor(root.snapshotMode, root.snapshotScale);
    }

    function stripBlock(src: string): string {
        const i = src.indexOf(root.blockBegin);
        if (i === -1)
            return src;

        const j = src.indexOf(root.blockEnd, i);
        if (j === -1)
            return src;

        return src.slice(0, i) + src.slice(j + root.blockEnd.length);
    }

    function save(): void {
        let src = "";
        try {
            src = String(luaFile.text() ?? "");
        } catch (e) {
            src = "";
        }

        const mode = root.effectiveMode.replace(/Hz$/, "");
        const block = [
            "",
            root.blockBegin,
            `hl.monitor({`,
            `    output = "${root.info.name ?? ""}",`,
            `    mode = "${mode}",`,
            `    position = "${info.x ?? 0}x${info.y ?? 0}",`,
            `    scale = ${root.effectiveScale},`,
            `})`,
            root.blockEnd
        ].join("\n");

        // QV4 has no String.prototype.trimEnd, use a regex instead
        luaFile.setText(`${stripBlock(src).replace(/\s+$/, "")}\n${block}\n`);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // PageBase only accepts a single Item child, so helpers live in the layout
        Timer {
            id: countdownTimer

            repeat: true
            interval: 1000

            onTriggered: {
                root.countdown--;
                if (root.countdown <= 0)
                    root.rollback();
            }
        }

        Timer {
            id: refreshTimer

            repeat: false
            interval: 600

            onTriggered: Hyprland.refreshMonitors()
        }

        FileView {
            id: luaFile

            path: root.luaPath
            printErrors: false
        }

        Variants {
            id: modeItems

            model: root.info.availableModes ?? []

            MenuItem {
                required property string modelData

                text: modelData
            }
        }

        Variants {
            id: scaleItems

            model: root.scaleOptions

            MenuItem {
                required property var modelData

                text: `${modelData}×`
                value: modelData
            }
        }

        SectionHeader {
            first: true
            text: Tr.tr("Built-in display")
        }

        InfoRow {
            first: true
            icon: "monitor"
            label: Tr.tr("Output")
            subtext: root.info.name ?? ""
            value: [root.info.make, root.info.model].filter(s => s).join(" ")
        }

        InfoRow {
            label: Tr.tr("Resolution")
            value: `${root.info.width ?? 0} × ${root.info.height ?? 0}`
        }

        InfoRow {
            label: Tr.tr("Refresh rate")
            value: `${(root.info.refreshRate ?? 0).toFixed(2)} Hz`
        }

        InfoRow {
            label: Tr.tr("Scale")
            value: `${root.currentScale}×`
        }

        InfoRow {
            last: true
            label: Tr.tr("Position")
            value: `${root.info.x ?? 0}, ${root.info.y ?? 0}`
        }

        SectionHeader {
            text: Tr.tr("Mode")
        }

        SelectRow {
            first: true
            label: Tr.tr("Resolution & refresh rate")
            subtext: Tr.tr("Modes reported by the display")
            menuItems: modeItems.instances
            active: root.activeModeItem
            onSelected: item => root.applyMode(item.text)
        }

        SelectRow {
            last: true
            label: Tr.tr("Scale")
            subtext: Tr.tr("Interface size on this output")
            menuItems: scaleItems.instances
            active: root.activeScaleItem
            onSelected: item => root.applyScale(item.value)
        }

        SectionHeader {
            visible: root.pending
            text: Tr.tr("Confirm change")
        }

        RowButton {
            visible: root.pending
            first: true
            icon: "check"
            text: Tr.tr("Keep these settings")
            subtext: Tr.tr("Reverting in %1s").arg(root.countdown)
            onClicked: root.keep()
        }

        RowButton {
            visible: root.pending
            last: true
            icon: "undo"
            text: Tr.tr("Revert now")
            subtext: Tr.tr("Go back to the previous mode without saving")
            onClicked: root.rollback()
        }
    }
}
