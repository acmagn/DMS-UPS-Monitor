import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "dankUpsMonitor"

    StyledText {
        text: "Dank UPS Monitor"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        text: "NUT via upsc on the DankBar. Use upsmon for shutdown and NOTIFYCMD for extra scripts."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        width: parent.width
        wrapMode: Text.WordWrap
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Connection"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    StringSetting {
        settingKey: "upsDevice"
        label: "UPS device"
        description: "Argument to upsc. List with upsc -l."
        placeholder: "ups@localhost"
        defaultValue: "ups@localhost"
    }

    StringSetting {
        settingKey: "upscPath"
        label: "upsc path (optional)"
        description: "Full path if upsc is not on PATH for the shell."
        placeholder: "/usr/bin/upsc"
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "pollIntervalSec"
        label: "UPS poll (mains)"
        description: "upsc interval on utility power. Bar and alerts follow this. Max 120 s."
        defaultValue: 10
        minimum: 5
        maximum: 120
        unit: "s"
        rightIcon: "schedule"
    }

    ToggleSetting {
        settingKey: "adaptiveBatteryPoll"
        label: "Faster poll on battery"
        description: "On battery, use the smaller of mains poll and battery poll."
        defaultValue: true
    }

    SliderSetting {
        settingKey: "batteryPollIntervalSec"
        label: "Battery poll"
        description: "Lower bound when adaptive is on and OB."
        defaultValue: 5
        minimum: 2
        maximum: 120
        unit: "s"
        rightIcon: "bolt"
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Chart"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "historyRecordIntervalSec"
        label: "Chart sample interval"
        description: "Minimum seconds between charge points on the graph."
        defaultValue: 30
        minimum: 5
        maximum: 3600
        unit: "s"
        rightIcon: "analytics"
    }

    SliderSetting {
        settingKey: "historyRetentionHours"
        label: "Chart retention"
        description: "Drop points older than this. In memory only."
        defaultValue: 24
        minimum: 1
        maximum: 168
        unit: "h"
        rightIcon: "history"
    }

    SliderSetting {
        settingKey: "historyMaxPoints"
        label: "Max chart points"
        description: "Hard cap after time pruning."
        defaultValue: 1440
        minimum: 50
        maximum: 5000
        rightIcon: "show_chart"
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Thresholds"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SliderSetting {
        settingKey: "warnChargeThreshold"
        label: "Low charge warning"
        description: "Notify on battery when charge is at or below this, or UPS sends LB. Full 0 to 100% for demos."
        defaultValue: 30
        minimum: 0
        maximum: 100
        unit: "%"
        rightIcon: "battery_3_bar"
    }

    SliderSetting {
        settingKey: "criticalChargeThreshold"
        label: "Critical charge"
        description: "Stronger bar styling on battery at or below this. Full 0 to 100% for demos."
        defaultValue: 15
        minimum: 0
        maximum: 100
        unit: "%"
        rightIcon: "battery_alert"
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Notifications"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    ToggleSetting {
        settingKey: "notifyOnPowerLoss"
        label: "Notify on power loss"
        description: "When status goes from utility to battery."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyLowBattery"
        label: "Notify on low battery"
        description: "Once per outage for LB or low charge."
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyOnMainsRestore"
        label: "Notify on mains restore"
        description: "When utility returns after battery."
        defaultValue: false
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }

    StyledText {
        text: "Display"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.DemiBold
        color: Theme.surfaceText
    }

    SelectionSetting {
        settingKey: "mainsBarStatistic"
        label: "Bar on mains"
        description: "Primary value while on utility power (not on battery)."
        options: [
            {
                label: "Battery %",
                value: "battery"
            },
            {
                label: "Load %",
                value: "load"
            },
            {
                label: "Power (W)",
                value: "realpower"
            },
            {
                label: "Input V",
                value: "inputV"
            },
            {
                label: "Output V",
                value: "outputV"
            },
            {
                label: "Status",
                value: "status"
            }
        ]
        defaultValue: "battery"
    }

    ToggleSetting {
        settingKey: "showRuntimeInBar"
        label: "Show runtime in bar"
        description: "On battery, append battery.runtime next to charge."
        defaultValue: true
    }
}
