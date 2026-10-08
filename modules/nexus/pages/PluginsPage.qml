pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.utils
import qs.modules.nexus.common

PageBase {
    id: root

    title: Tr.tr("Plugins")

    readonly property bool anyFound: Plugins.count > 0

    function openDir(): void {
        Quickshell.execDetached([...(GlobalConfig.general.apps.explorer ?? []), Plugins.dir]);
    }

    function statusOf(file: string): string {
        if (Plugins.errors[file])
            return Tr.tr("Error");
        return Plugins.enabledFiles.includes(file) ? Tr.tr("Loaded") : Tr.tr("Off");
    }

    function subOf(file: string): string {
        if (Plugins.errors[file])
            return Plugins.errors[file];
        return Plugins.description(file);
    }

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        SectionHeader {
            first: true
            text: Tr.tr("Plugins")
        }

        RowButton {
            first: true
            icon: "folder_open"
            text: Tr.tr("Open plugins folder")
            subtext: Plugins.dir
            trailingIcon: "open_in_new"
            onClicked: root.openDir()
        }

        RowButton {
            last: true
            icon: "refresh"
            text: Tr.tr("Scan for plugins")
            subtext: Tr.tr("Pick up new or removed files")
            onClicked: Plugins.rescan()
        }

        SectionHeader {
            text: root.anyFound ? Tr.trN("%n plugin", "%n plugins", Plugins.count) : Tr.tr("Installed")
        }

        ItemList {
            visible: !root.anyFound
            showList: false
            placeholderIcon: "extension"
            placeholderText: Tr.tr("No plugins found")
        }

        Repeater {
            model: Plugins.files

            delegate: ConnectedRect {
                id: pluginRow

                required property string modelData
                required property int index

                readonly property bool failed: !!Plugins.errors[modelData]
                readonly property bool active: Plugins.enabledFiles.includes(modelData)

                Layout.fillWidth: true
                first: index === 0
                last: index === Plugins.count - 1
                implicitHeight: row.implicitHeight + Tokens.padding.medium * 2

                RowLayout {
                    id: row

                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.margins: Tokens.padding.largeIncreased

                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "extension"
                        color: pluginRow.failed ? Colours.palette.m3error : pluginRow.active ? Colours.palette.m3primary : Colours.palette.m3outlineVariant
                        fontStyle: Tokens.font.icon.medium
                        fill: pluginRow.active ? 1 : 0

                        Behavior on color {
                            Anim {}
                        }
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: Plugins.displayName(pluginRow.modelData)
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: text
                            text: root.subOf(pluginRow.modelData)
                            color: pluginRow.failed ? Colours.palette.m3error : Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }

                    StyledText {
                        text: root.statusOf(pluginRow.modelData)
                        color: pluginRow.failed ? Colours.palette.m3error : pluginRow.active ? Colours.palette.m3primary : Colours.palette.m3outline
                        font: Tokens.font.label.small
                    }

                    StyledSwitch {
                        checked: pluginRow.active
                        disabled: pluginRow.failed
                        onToggled: checked => Plugins.setEnabled(pluginRow.modelData, checked)
                    }
                }
            }
        }

        SectionHeader {
            text: Tr.tr("About plugins")
        }

        InfoRow {
            first: true
            label: Tr.tr("Format")
            subtext: Tr.tr("A .qml file whose root object is an Item, with an optional // Description: line")
        }

        InfoRow {
            last: true
            label: Tr.tr("Behaviour")
            subtext: Tr.tr("Loaded plugins run on every screen, refresh when toggled, and never take mouse input")
        }
    }
}
