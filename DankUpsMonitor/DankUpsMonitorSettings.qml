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
        text: "Reads NUT variables via upsc and shows status on the DankBar. Pair with upsmon for shutdown and NOTIFYCMD for extra scripts."
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
        description: "NUT ups name (e.g. ups@localhost or myups@192.168.1.10). Run: upsc -l"
        placeholder: "ups@localhost"
        defaultValue: "ups@localhost"
    }

    StringSetting {
        settingKey: "upscPath"
        label: "upsc path (optional)"
        description: "If the bar shows “upsc not found”, set the full path (e.g. /usr/bin/upsc). Leave empty to use PATH inside sh."
        placeholder: "/usr/bin/upsc"
        defaultValue: ""
    }

    SliderSetting {
        settingKey: "pollIntervalSec"
        label: "Poll interval"
        description: "How often to run upsc. Longer intervals mean less CPU and fewer samples per day (see history caps below)."
        defaultValue: 60
        minimum: 5
        maximum: 3600
        unit: "s"
        rightIcon: "schedule"
    }

    SliderSetting {
        settingKey: "historyRetentionHours"
        label: "History retention"
        description: "Drop charge samples older than this window. In-memory only (not saved to disk)."
        defaultValue: 24
        minimum: 1
        maximum: 168
        unit: "h"
        rightIcon: "history"
    }

    SliderSetting {
        settingKey: "historyMaxPoints"
        label: "Max history samples"
        description: "Hard cap on points kept after time pruning. Example: 24h at 60s poll ≈ 1440 points."
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
        description: "Treat as low battery for desktop notifications (and LB flag from UPS always counts)"
        defaultValue: 30
        minimum: 5
        maximum: 90
        unit: "%"
        rightIcon: "battery_3_bar"
    }

    SliderSetting {
        settingKey: "criticalChargeThreshold"
        label: "Critical charge"
        description: "Stronger bar styling when on battery and charge is at or below this level"
        defaultValue: 15
        minimum: 1
        maximum: 50
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
        description: "When ups.status switches from utility to battery"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyLowBattery"
        label: "Notify on low battery"
        description: "Once per outage when LB or charge falls below thresholds"
        defaultValue: true
    }

    ToggleSetting {
        settingKey: "notifyOnMainsRestore"
        label: "Notify on mains restore"
        description: "When utility power returns"
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

    ToggleSetting {
        settingKey: "showRuntimeInBar"
        label: "Show runtime in bar"
        description: "When on battery, show remaining runtime (battery.runtime) next to charge"
        defaultValue: true
    }

    StyledRect {
        width: parent.width
        height: 1
        color: Theme.surfaceVariant
    }
}
