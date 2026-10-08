pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Updates")

    readonly property string terminalCmd: (GlobalConfig.general.apps.terminal ?? []).join(" ")

    // package name -> { from, to }
    property list<var> updates: []
    property bool checking
    property bool failed
    property string lastChecked

    function check(): void {
        root.checking = true;
        root.failed = false;
        checkProc.running = false;
        checkProc.running = true;
    }

    function upgrade(): void {
        // Runs the upgrade in the configured terminal rather than in-place, so
        // nothing privileged happens inside the shell itself.
        Quickshell.execDetached([
            ...GlobalConfig.general.apps.terminal,
            `${Quickshell.shellDir}/assets/wrap_term_launch.sh`,
            "paru",
            "-Syu"
        ]);
    }

    Component.onCompleted: check()

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // PageBase only accepts a single Item child, so helpers live in the layout
        Process {
            id: checkProc

            command: ["checkupdates"]

            stdout: StdioCollector {
                onStreamFinished: {
                    const list = [];
                    for (const line of text.split("\n")) {
                        const m = line.match(/^(\S+)\s+(\S+)\s+->\s+(\S+)$/);
                        if (m)
                            list.push({ name: m[1], from: m[2], to: m[3] });
                    }
                    root.updates = list;
                }
            }

            onExited: exitCode => {
                root.checking = false;
                // checkupdates exits 2 when there is nothing to update
                root.failed = root.updates.length === 0 && exitCode !== 0 && exitCode !== 2;
                root.lastChecked = Qt.formatTime(new Date(), Units.twelveHourClock ? "hh:mm a" : "hh:mm");
            }
        }

        SectionHeader {
            first: true
            text: root.updates.length > 0 ? Tr.trN("%n update available", "%n updates available", root.updates.length) : root.checking ? Tr.tr("Checking for updates…") : Tr.tr("Available updates")
        }

        ItemList {
            id: updateList

            showList: root.updates.length > 0
            placeholderIcon: root.failed ? "cloud_off" : root.checking ? "sync" : "check_circle"
            placeholderText: root.failed ? Tr.tr("Couldn't run checkupdates") : root.checking ? Tr.tr("Checking…") : Tr.tr("All packages are up to date")

            model: ScriptModel {
                values: root.updates
            }

            delegate: InfoRow {
                required property int index
                required property var modelData

                // ListView does not size delegates itself; anchor them like the
                // rest of the shell's list delegates
                anchors.left: updateList.list.contentItem.left
                anchors.right: updateList.list.contentItem.right
                anchors.fill: undefined

                first: index === 0
                last: index === root.updates.length - 1
                label: modelData.name
                value: `${modelData.from} → ${modelData.to}`
            }
        }

        SectionHeader {
            text: Tr.tr("Actions")
        }

        RowButton {
            first: true
            icon: "refresh"
            text: Tr.tr("Check for updates")
            subtext: Tr.tr("Runs checkupdates against the package repos")
            trailingIcon: root.checking ? "sync" : ""
            disabled: root.checking
            onClicked: root.check()
        }

        RowButton {
            icon: "update"
            text: Tr.tr("Update system")
            subtext: root.terminalCmd ? Tr.tr("Runs paru -Syu in %1").arg(root.terminalCmd) : Tr.tr("Runs paru -Syu in a terminal")
            trailingIcon: "open_in_new"
            onClicked: root.upgrade()
        }

        RowButton {
            last: true
            icon: "history"
            text: Tr.tr("Last checked")
            subtext: root.lastChecked ? Tr.tr("at %1").arg(root.lastChecked) : Tr.tr("Not checked yet in this session")
        }
    }
}
