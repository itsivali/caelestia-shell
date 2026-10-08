import QtQuick
import QtQuick.Layouts
import Quickshell
import Caelestia.Config
import Caelestia.I18n
import qs.components
import qs.components.controls
import qs.services
import qs.modules.nexus.common

PageBase {
    id: root

    // Suggestions stay up while the city field has focus and a search has run
    readonly property bool cityResultsOpen: cityField.field.activeFocus && Weather.citySearchAttempted

    function coordInRange(value: string, limit: int): bool {
        const n = parseFloat(value);
        return Number.isFinite(n) && Math.abs(n) <= limit;
    }

    // Temperature units (there must be one for each value of the TemperatureUnit enum)
    readonly property list<MenuItem> tempItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: TemperatureUnit.Auto
        },
        MenuItem {
            text: Tr.tr("°C")
            value: TemperatureUnit.Celsius
        },
        MenuItem {
            text: Tr.tr("°F")
            value: TemperatureUnit.Fahrenheit
        },
        MenuItem {
            text: Tr.tr("K")
            value: TemperatureUnit.Kelvin
        }
    ]

    // Data size units (there must be one for each value of the DataUnit enum)
    readonly property list<MenuItem> dataItems: [
        MenuItem {
            text: Tr.tr("Binary (KiB, MiB)")
            value: DataUnit.Binary
        },
        MenuItem {
            text: Tr.tr("Decimal (KB, MB)")
            value: DataUnit.Decimal
        }
    ]

    // Clock formats (there must be one for each value of the ClockFormat enum)
    readonly property list<MenuItem> clockItems: [
        MenuItem {
            text: Tr.tr("Auto")
            value: ClockFormat.Auto
        },
        MenuItem {
            text: Tr.tr("12-hour")
            value: ClockFormat.TwelveHour
        },
        MenuItem {
            text: Tr.tr("24-hour")
            value: ClockFormat.TwentyFourHour
        }
    ]

    title: Tr.tr("Language & region")

    ColumnLayout {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        width: root.cappedWidth
        spacing: Tokens.spacing.extraSmall / 2

        // Language
        SectionHeader {
            first: true
            text: Tr.tr("Language")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("UI language")
            subtext: Tr.tr("The language used in the shell UI")
            active: menuItems.find(i => i.modelData === Tr.language) ?? autoLang
            onSelected: item => {
                Tr.language = item.modelData ?? ""; // qmllint disable missing-property
            }

            menuItems: [autoLang, ...langItems.instances]

            MenuItem {
                id: autoLang

                text: Tr.tr("Auto")
            }

            Variants {
                id: langItems

                model: Tr.supportedLanguages

                MenuItem {
                    required property string modelData

                    text: {
                        const locale = Qt.locale(modelData);
                        return locale.name === "C" ? modelData : locale.nativeLanguageName || locale.name;
                    }
                }
            }
        }

        // Weather location
        SectionHeader {
            text: Tr.tr("Weather location")
        }

        TextFieldRow {
            id: cityField

            first: true
            label: Tr.tr("City")
            subtext: Tr.tr("Search by name, then pick a result")
            placeholderText: Tr.tr("City name")
            onValueEdited: value => Weather.requestCitySearch(value)
            onEditingFinished: value => Weather.requestCitySearch(value)
        }

        ItemList {
            id: cityResults

            visible: root.cityResultsOpen
            showList: Weather.citySuggestions.length > 0
            placeholderIcon: "location_off"
            placeholderText: Weather.citySearchPending ? Tr.tr("Searching…") : Tr.tr("No matching cities")

            model: ScriptModel {
                values: Weather.citySuggestions
            }

            delegate: StateLayer {
                id: cityResult

                required property int index
                required property var modelData

                anchors.left: cityResults.list.contentItem.left
                anchors.right: cityResults.list.contentItem.right
                anchors.fill: undefined
                implicitHeight: cityResultLayout.implicitHeight + cityResultLayout.anchors.margins * 2
                radius: Tokens.rounding.extraSmall
                bottomLeftRadius: index === Weather.citySuggestions.length - 1 ? Tokens.rounding.extraLarge : radius
                bottomRightRadius: index === Weather.citySuggestions.length - 1 ? Tokens.rounding.extraLarge : radius

                onClicked: {
                    Weather.setLocation(cityResult.modelData.coords);
                    cityField.field.focus = false;
                }

                RowLayout {
                    id: cityResultLayout

                    anchors.fill: parent
                    anchors.margins: Tokens.padding.large
                    anchors.leftMargin: Tokens.padding.extraLarge
                    anchors.rightMargin: Tokens.padding.extraLarge
                    spacing: Tokens.spacing.medium

                    MaterialIcon {
                        text: "location_on"
                        color: Colours.palette.m3onSurfaceVariant
                        fontStyle: Tokens.font.icon.medium
                    }

                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0

                        StyledText {
                            Layout.fillWidth: true
                            text: cityResult.modelData.name
                            font: Tokens.font.body.small
                            elide: Text.ElideRight
                        }

                        StyledText {
                            Layout.fillWidth: true
                            visible: cityResult.modelData.detail !== ""
                            text: cityResult.modelData.detail
                            color: Colours.palette.m3outline
                            font: Tokens.font.label.small
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }

        TextFieldRow {
            id: coordsField

            label: Tr.tr("Coordinates")
            subtext: Tr.tr("Latitude, longitude")
            placeholderText: "52.4064, 16.9251"
            validate: /^\s*-?\d{1,3}(?:\.\d+)?\s*,\s*-?\d{1,3}(?:\.\d+)?\s*$/
            errorText: Tr.tr("Enter a latitude and longitude")
            onEditingFinished: value => {
                const parts = value.split(",").map(part => part.trim());
                if (parts.length === 2 && root.coordInRange(parts[0], 90) && root.coordInRange(parts[1], 180))
                    Weather.setLocation(`${parts[0]},${parts[1]}`);
            }
        }

        RowButton {
            icon: "my_location"
            text: Tr.tr("Use my location")
            subtext: Tr.tr("Detect my city from my IP address")
            onClicked: Weather.useIpLocation()
        }

        InfoRow {
            last: true
            icon: "explore"
            iconColour: Colours.palette.m3primary
            label: Tr.tr("Active location")
            subtext: {
                const name = Weather.city || Tr.tr("Looking up…");
                const coords = GlobalConfig.services.weatherLocation;
                return coords ? `${name} • ${coords}` : `${name} • ${Tr.tr("detected from IP")}`;
            }
            value: Weather.temp
        }

        // Units
        SectionHeader {
            text: Tr.tr("Units")
        }

        SelectRow {
            first: true
            label: Tr.tr("Temperature")
            subtext: Tr.tr("Units for weather temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.weatherUnits)
            onSelected: item => GlobalConfig.services.weatherUnits = item.value
        }

        SelectRow {
            label: Tr.tr("System temperatures")
            subtext: Tr.tr("Units for CPU and GPU temperatures")
            menuItems: root.tempItems
            active: root.tempItems.find(i => i.value === GlobalConfig.services.sensorUnits)
            onSelected: item => GlobalConfig.services.sensorUnits = item.value
        }

        SelectRow {
            last: true
            label: Tr.tr("Data sizes")
            subtext: Tr.tr("Units for data sizes and network speeds")
            menuItems: root.dataItems
            active: root.dataItems.find(i => i.value === GlobalConfig.services.dataUnits)
            onSelected: item => GlobalConfig.services.dataUnits = item.value
        }

        // Time & date
        SectionHeader {
            text: Tr.tr("Time & date")
        }

        SelectRow {
            first: true
            last: true
            label: Tr.tr("Clock format")
            subtext: Tr.tr("How times are shown across the shell")
            menuItems: root.clockItems
            active: root.clockItems.find(i => i.value === GlobalConfig.services.clockFormat)
            onSelected: item => GlobalConfig.services.clockFormat = item.value
        }
    }
}
