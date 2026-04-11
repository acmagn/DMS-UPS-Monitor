import QtQuick
import Quickshell.Io
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root

    property string upsDevice: pluginData.upsDevice || "ups@localhost"
    property string upscPath: pluginData.upscPath || ""
    property int pollIntervalSec: Math.min(120, Math.max(5, pluginData.pollIntervalSec ?? 10))
    property bool adaptiveBatteryPoll: pluginData.adaptiveBatteryPoll ?? true
    property int batteryPollIntervalSec: Math.max(2, Math.min(120, pluginData.batteryPollIntervalSec ?? 5))
    property int historyRecordIntervalSec: Math.max(5, Math.min(3600, pluginData.historyRecordIntervalSec ?? 30))
    property int historyRetentionHours: Math.max(1, Math.min(168, pluginData.historyRetentionHours ?? 24))
    property int warnChargeThreshold: Math.max(0, Math.min(100, pluginData.warnChargeThreshold ?? 30))
    property int criticalChargeThreshold: Math.max(0, Math.min(100, pluginData.criticalChargeThreshold ?? 15))
    property bool notifyOnPowerLoss: pluginData.notifyOnPowerLoss ?? true
    property bool notifyLowBattery: pluginData.notifyLowBattery ?? true
    property bool notifyOnMainsRestore: pluginData.notifyOnMainsRestore ?? false
    property bool showRuntimeInBar: pluginData.showRuntimeInBar ?? true
    property string mainsBarStatistic: pluginData.mainsBarStatistic || "battery"
    property int historyMaxPoints: Math.max(50, Math.min(5000, pluginData.historyMaxPoints ?? 1440))

    property bool upscOk: false
    property string upscError: ""
    property string upscErrorDetail: ""
    property int upscLastExitCode: 0

    readonly property string upscShellCmd: {
        const bin = root.upscPath.trim() || "upsc";
        const dev = root.upsDevice.replace(/'/g, "'\\''");
        const b = bin.replace(/'/g, "'\\''");
        return "'" + b + "' '" + dev + "' 2>&1";
    }

    readonly property string upscDisplayCommand: {
        const bin = root.upscPath.trim() || "upsc";
        return bin + " " + root.upsDevice;
    }
    property var upsData: ({})
    property string upsStatusRaw: ""
    property int batteryCharge: -1
    property int runtimeSeconds: -1
    property string upsModel: ""
    property string upsVendor: ""
    property real inputVoltage: -1
    property real outputVoltage: -1
    property real loadPercent: -1
    property real upsRealPowerW: -1

    property var chargeHistory: []

    property real _lastHistoryRecordMs: 0

    property var _notifyStateLocal: ({})

    property int notifyDedupeWindowMs: 15000

    function notifyStateKey(k) {
        return "notify_" + k;
    }

    function notifyStateGet(key, defVal) {
        if (root.pluginService)
            return root.pluginService.loadPluginState("dankUpsMonitor", root.notifyStateKey(key), defVal);
        const o = root._notifyStateLocal;
        return o[key] !== undefined ? o[key] : defVal;
    }

    function notifyStateSet(key, value) {
        if (root.pluginService) {
            root.pluginService.savePluginState("dankUpsMonitor", root.notifyStateKey(key), value);
            return;
        }
        const o = Object.assign({}, root._notifyStateLocal);
        o[key] = value;
        root._notifyStateLocal = o;
    }

    readonly property bool flagOL: root.statusHas("OL")
    readonly property bool flagOB: root.statusHas("OB")
    readonly property bool flagLB: root.statusHas("LB")
    readonly property bool flagCHRG: root.statusHas("CHRG")
    readonly property bool flagDISCHRG: root.statusHas("DISCHRG")

    readonly property bool onMains: root.flagOL && !root.flagOB
    readonly property bool onBattery: root.flagOB

    readonly property int effectivePollIntervalSec: {
        if (!root.upscOk)
            return root.pollIntervalSec;
        if (root.adaptiveBatteryPoll && root.onBattery)
            return Math.min(root.pollIntervalSec, root.batteryPollIntervalSec);
        return root.pollIntervalSec;
    }
    readonly property bool lowBatteryFlag: root.flagLB

    readonly property bool chargeCritical: root.batteryCharge >= 0 && root.batteryCharge <= root.criticalChargeThreshold

    readonly property bool emergency: root.upscOk && root.onBattery
    readonly property bool criticalAttention: root.upscOk && (root.lowBatteryFlag || root.chargeCritical)

    readonly property string barLabel: {
        if (!root.upscOk)
            return root.upscError || ("upsc " + root.upscLastExitCode);
        if (root.onBattery) {
            let parts = [];
            if (root.batteryCharge >= 0)
                parts.push(root.batteryCharge + "%");
            if (root.showRuntimeInBar && root.runtimeSeconds >= 0)
                parts.push(root.formatRuntimeBar(root.runtimeSeconds));
            if (parts.length === 0)
                return root.shortStatusText();
            return parts.join(" · ");
        }
        return root.mainsBarStatText();
    }

    readonly property color pillIconColor: {
        if (!root.upscOk)
            return Theme.surfaceVariantText;
        if (root.criticalAttention)
            return Theme.error;
        if (root.onBattery)
            return Theme.warning;
        return Theme.primary;
    }

    readonly property color pillTextColor: {
        if (!root.upscOk)
            return Theme.surfaceVariantText;
        if (root.criticalAttention)
            return Theme.error;
        if (root.onBattery)
            return Theme.warning;
        return Theme.surfaceVariantText;
    }

    readonly property int pillFontSize: (root.emergency || root.criticalAttention) ? Theme.fontSizeMedium : Theme.fontSizeSmall

    readonly property string pillIconName: {
        if (!root.upscOk)
            return "power_off";
        if (root.criticalAttention)
            return "battery_alert";
        if (root.onBattery)
            return "battery_5_bar";
        if (root.flagCHRG)
            return "battery_charging_full";
        return "electrical_services";
    }

    function statusHas(flag) {
        if (!root.upsStatusRaw)
            return false;
        const tokens = root.upsStatusRaw.split(/\s+/).filter(Boolean);
        return tokens.indexOf(flag) >= 0;
    }

    function shortStatusText() {
        if (root.onMains)
            return "Utility";
        if (root.onBattery)
            return "Battery";
        return root.upsStatusRaw || "—";
    }

    function mainsBarStatText() {
        const mode = root.mainsBarStatistic || "battery";
        let s = "—";
        if (mode === "load")
            s = root.loadPercent >= 0 ? root.loadPercent + "%" : "—";
        else if (mode === "realpower")
            s = root.upsRealPowerW >= 0 ? Math.round(root.upsRealPowerW) + " W" : "—";
        else if (mode === "inputV")
            s = root.inputVoltage >= 0 ? root.inputVoltage + " V" : "—";
        else if (mode === "outputV")
            s = root.outputVoltage >= 0 ? root.outputVoltage + " V" : "—";
        else if (mode === "status") {
            const p = root.formatUpsStatusPretty(root.upsStatusRaw);
            s = p !== "—" ? root.shortenForBar(p, 48) : "—";
        } else
            s = root.batteryCharge >= 0 ? root.batteryCharge + "%" : "—";
        if (s === "—" && root.batteryCharge >= 0)
            s = root.batteryCharge + "%";
        return s;
    }

    function formatUpscFailure(exitCode, mergedOutput) {
        const merged = (mergedOutput || "").trim();
        if (merged)
            return merged.replace(/\s+/g, " ").trim();
        if (exitCode === 127 || exitCode === 32512)
            return "upsc not found. Set full path in settings.";
        return "upsc failed (exit " + exitCode + ")";
    }

    function shortenForBar(message, maxLen) {
        const m = maxLen !== undefined ? maxLen : 44;
        if (!message)
            return "upsc error";
        const t = message.length > m ? message.substring(0, m - 2) + "…" : message;
        return t;
    }

    function formatRuntimeBar(sec) {
        if (sec < 0)
            return "";
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const s = sec % 60;
        if (h > 0)
            return h + "h " + m + "m";
        if (m > 0 && s > 0)
            return m + "m " + s + "s";
        if (m > 0)
            return m + "m";
        return s + "s";
    }

    function formatRuntimeHuman(sec) {
        if (sec < 0)
            return "—";
        const h = Math.floor(sec / 3600);
        const m = Math.floor((sec % 3600) / 60);
        const s = sec % 60;
        if (h > 0)
            return h + " h " + m + " min " + s + " s";
        if (m > 0 && s > 0)
            return m + " min " + s + " s";
        if (m > 0)
            return m + " min";
        return s + " s";
    }

    function formatChartClock(ms) {
        const d = new Date(ms);
        const h = d.getHours();
        const mi = d.getMinutes();
        return h + ":" + (mi < 10 ? "0" : "") + mi;
    }

    // ups.status: opaque space-separated flags (NUT developer guide). Known tokens get a short label; others pass through unchanged.
    function upsStatusTokenLabel(token) {
        const labels = {
            OL: "Online",
            OB: "On battery",
            LB: "Low battery",
            HB: "High battery",
            RB: "Replace battery",
            CHRG: "Charging",
            DISCHRG: "Discharging",
            BYPASS: "Bypass",
            CAL: "Calibrating",
            OFF: "Off",
            OVER: "Overload",
            TRIM: "Trimming",
            BOOST: "Boosting",
            FSD: "Force shutdown",
            SD: "Shutdown",
            WAIT: "Waiting",
            TEST: "Self test"
        };
        return labels[token] || "";
    }

    function formatUpsStatusPretty(statusRaw) {
        if (!statusRaw || !statusRaw.trim())
            return "—";
        const tokens = statusRaw.split(/\s+/).filter(Boolean);
        const parts = [];
        for (let i = 0; i < tokens.length; i++) {
            const lab = root.upsStatusTokenLabel(tokens[i]);
            parts.push(lab || tokens[i]);
        }
        return parts.join(", ");
    }

    function parseUpscOutput(text) {
        const lines = text.split(/\n/);
        const map = {};
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            const idx = line.indexOf(":");
            if (idx <= 0)
                continue;
            const key = line.substring(0, idx).trim();
            const val = line.substring(idx + 1).trim();
            map[key] = val;
        }
        return map;
    }

    function parseIntSafe(s, def) {
        const n = parseInt(s, 10);
        return isNaN(n) ? def : n;
    }

    function parseFloatSafe(s, def) {
        const n = parseFloat(s);
        return isNaN(n) ? def : n;
    }

    function applyUpsMap(map) {
        root.upsData = map;
        root.upsStatusRaw = map["ups.status"] || "";
        root.batteryCharge = map["battery.charge"] !== undefined ? parseIntSafe(map["battery.charge"], -1) : -1;
        root.runtimeSeconds = map["battery.runtime"] !== undefined ? parseIntSafe(map["battery.runtime"], -1) : -1;
        root.upsModel = map["device.model"] || map["ups.model"] || "";
        root.upsVendor = map["device.mfr"] || map["ups.mfr"] || "";
        root.inputVoltage = map["input.voltage"] !== undefined ? parseFloatSafe(map["input.voltage"], -1) : -1;
        root.outputVoltage = map["output.voltage"] !== undefined ? parseFloatSafe(map["output.voltage"], -1) : -1;
        root.loadPercent = map["ups.load"] !== undefined ? parseFloatSafe(map["ups.load"], -1) : -1;
        root.upsRealPowerW = map["ups.realpower"] !== undefined ? parseFloatSafe(map["ups.realpower"], -1) : -1;

        const now = Date.now();
        const retentionMs = root.historyRetentionHours * 3600 * 1000;
        const cutoff = now - retentionMs;
        const max = root.historyMaxPoints;

        let h = root.chargeHistory.slice().filter(p => p.t >= cutoff);
        const recordMs = root.historyRecordIntervalSec * 1000;
        const canRecord = root.batteryCharge >= 0 && (h.length === 0 || (now - root._lastHistoryRecordMs >= recordMs));
        if (canRecord) {
            h.push({
                t: now,
                c: root.batteryCharge
            });
            root._lastHistoryRecordMs = now;
        }
        h = h.filter(p => p.t >= cutoff);
        if (h.length > max)
            h = h.slice(h.length - max);
        root.chargeHistory = h;
    }

    function notify(title, message, urgency, iconName) {
        const o = notifyProcessComponent.createObject(root, {
            notifyTitle: title,
            notifyMessage: message,
            notifyUrgency: urgency,
            notifyIcon: iconName
        });
        o.running = true;
    }

    function notifyDeduped(title, message, urgency, iconName) {
        const key = title + "\0" + message;
        const t = Date.now();
        const lastKey = root.notifyStateGet("dedupeKey", "");
        const lastAt = root.notifyStateGet("dedupeAt", 0);
        if (key === lastKey && (t - lastAt) < root.notifyDedupeWindowMs)
            return;
        root.notifyStateSet("dedupeKey", key);
        root.notifyStateSet("dedupeAt", t);
        notify(title, message, urgency, iconName);
    }

    function considerNotifications() {
        if (!root.upscOk)
            return;

        const online = root.onMains;
        const batt = root.onBattery;

        const lastPS = root.notifyStateGet("lastPowerState", "");
        if (lastPS === "") {
            root.notifyStateSet("lastPowerState", batt ? "battery" : "online");
            return;
        }

        let powerLossThisCycle = false;

        if (root.notifyOnPowerLoss && batt && lastPS === "online") {
            notifyDeduped("UPS on battery", "Mains lost. UPS is on battery.", "critical", "battery_alert");
            powerLossThisCycle = true;
        }

        if (root.notifyOnMainsRestore && !batt && lastPS === "battery")
            notifyDeduped("UPS on utility power", "Mains restored.", "normal", "electrical_services");

        root.notifyStateSet("lastPowerState", batt ? "battery" : "online");

        const lowBattSent = root.notifyStateGet("lowBattSent", false) === true;

        if (online) {
            root.notifyStateSet("lowBattSent", false);
        } else if (root.notifyLowBattery && !lowBattSent && root.onBattery && !powerLossThisCycle) {
            const low = root.lowBatteryFlag || root.chargeCritical || (root.batteryCharge >= 0 && root.batteryCharge <= root.warnChargeThreshold);
            if (low) {
                notifyDeduped("UPS low battery", "Charge at " + root.batteryCharge + "%. Check power soon.", "critical", "battery_alert");
                root.notifyStateSet("lowBattSent", true);
            }
        }
    }

    Component.onCompleted: {
        Qt.callLater(runUpsc);
    }

    Timer {
        id: pollTimer
        interval: root.effectivePollIntervalSec * 1000
        repeat: true
        running: true
        onTriggered: runUpsc()
    }

    Connections {
        target: root
        function onEffectivePollIntervalSecChanged() {
            pollTimer.restart();
        }
    }

    property var upscLineBuffer: []

    function runUpsc() {
        upscLineBuffer = [];
        upscProcess.running = true;
    }

    Process {
        id: upscProcess
        command: ["sh", "-c", root.upscShellCmd]
        running: false

        stdout: SplitParser {
            onRead: data => {
                root.upscLineBuffer.push(data);
            }
        }

        onExited: exitCode => {
            const text = root.upscLineBuffer.join("\n");
            root.upscLineBuffer = [];
            root.upscLastExitCode = exitCode;
            if (exitCode !== 0) {
                root.upscOk = false;
                const detail = root.formatUpscFailure(exitCode, text);
                root.upscErrorDetail = detail;
                root.upscError = root.shortenForBar(detail);
                root.upsData = {};
                root.upsStatusRaw = "";
                root.upsRealPowerW = -1;
                console.warn("DankUpsMonitor: upsc failed\n  exit:", exitCode, "\n  cmd:", root.upscDisplayCommand, "\n  shell:", root.upscShellCmd, "\n  output:", text);
                return;
            }
            root.upscOk = true;
            root.upscError = "";
            root.upscErrorDetail = "";
            const map = root.parseUpscOutput(text);
            if (Object.keys(map).length === 0) {
                root.upscOk = false;
                root.upscErrorDetail = "Empty upsc output. Check device name (upsc -l).";
                root.upscError = root.shortenForBar(root.upscErrorDetail);
                return;
            }
            root.applyUpsMap(map);
            root.considerNotifications();
        }
    }

    Component {
        id: notifyProcessComponent

        Process {
            property string notifyTitle: ""
            property string notifyMessage: ""
            property string notifyUrgency: "normal"
            property string notifyIcon: "electrical_services"

            command: ["notify-send", "-a", "DankMaterialShell", "-i", notifyIcon, "-u", notifyUrgency, notifyTitle, notifyMessage]

            onExited: code => {
                if (code !== 0)
                    console.error("DankUpsMonitor: notify-send failed:", code);
                destroy();
            }
        }
    }

    horizontalBarPill: Component {
        Item {
            implicitWidth: inner.implicitWidth + pad * 2
            implicitHeight: inner.implicitHeight + pad * 2

            readonly property int pad: root.emergency || root.criticalAttention ? 6 : 2

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: root.emergency ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.2) : "transparent"
                border.width: root.criticalAttention ? 2 : (root.emergency ? 1 : 0)
                border.color: root.criticalAttention ? Theme.error : Theme.warning
                visible: root.emergency || root.criticalAttention
            }

            Row {
                id: inner
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.pillIconName
                    size: (root.emergency || root.criticalAttention) ? Theme.iconSize - 2 : Theme.iconSize - 6
                    color: root.pillIconColor
                    anchors.verticalCenter: parent.verticalCenter
                }

                StyledText {
                    text: root.barLabel
                    font.pixelSize: root.pillFontSize
                    font.bold: root.emergency || root.criticalAttention
                    font.weight: root.emergency || root.criticalAttention ? Font.Bold : Font.Medium
                    color: root.pillTextColor
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    verticalBarPill: Component {
        Item {
            implicitWidth: inner.implicitWidth + pad * 2
            implicitHeight: inner.implicitHeight + pad * 2

            readonly property int pad: root.emergency || root.criticalAttention ? 6 : 2

            Rectangle {
                anchors.fill: parent
                radius: Theme.cornerRadius
                color: root.emergency ? Qt.rgba(Theme.warning.r, Theme.warning.g, Theme.warning.b, 0.2) : "transparent"
                border.width: root.criticalAttention ? 2 : (root.emergency ? 1 : 0)
                border.color: root.criticalAttention ? Theme.error : Theme.warning
                visible: root.emergency || root.criticalAttention
            }

            Column {
                id: inner
                anchors.centerIn: parent
                spacing: Theme.spacingXS

                DankIcon {
                    name: root.pillIconName
                    size: (root.emergency || root.criticalAttention) ? Theme.iconSize - 2 : Theme.iconSize - 6
                    color: root.pillIconColor
                    anchors.horizontalCenter: parent.horizontalCenter
                }

                StyledText {
                    text: root.barLabel
                    font.pixelSize: Math.min(root.pillFontSize, Theme.fontSizeMedium)
                    font.bold: root.emergency || root.criticalAttention
                    color: root.pillTextColor
                    horizontalAlignment: Text.AlignHCenter
                    anchors.horizontalCenter: parent.horizontalCenter
                }
            }
        }
    }

    popoutContent: Component {
        PopoutComponent {
            headerText: "UPS (NUT)"
            detailsText: root.upscOk ? (root.upsVendor || root.upsModel ? [root.upsVendor, root.upsModel].filter(Boolean).join(" · ") : root.upsDevice) : ("upsc failed, exit " + root.upscLastExitCode)
            showCloseButton: true

            Column {
                width: parent.width
                spacing: Theme.spacingM

                Row {
                    width: parent.width
                    spacing: Theme.spacingS

                    DankButton {
                        text: "Refresh"
                        iconName: "refresh"
                        onClicked: root.runUpsc()
                    }
                }

                StyledRect {
                    width: parent.width
                    height: detailCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh

                    Column {
                        id: detailCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        Repeater {
                            model: root.upscOk ? [
                                {
                                    k: "Status",
                                    v: root.formatUpsStatusPretty(root.upsStatusRaw)
                                },
                                {
                                    k: "Battery",
                                    v: root.batteryCharge >= 0 ? root.batteryCharge + "%" : "—"
                                },
                                {
                                    k: "Runtime",
                                    v: root.runtimeSeconds >= 0 ? root.formatRuntimeHuman(root.runtimeSeconds) + " (est.)" : "—"
                                },
                                {
                                    k: "Load",
                                    v: root.loadPercent >= 0 ? root.loadPercent + "%" : "—"
                                },
                                {
                                    k: "Power",
                                    v: root.upsRealPowerW >= 0 ? Math.round(root.upsRealPowerW) + " W" : "—"
                                },
                                {
                                    k: "Input V",
                                    v: root.inputVoltage >= 0 ? root.inputVoltage + " V" : "—"
                                },
                                {
                                    k: "Output V",
                                    v: root.outputVoltage >= 0 ? root.outputVoltage + " V" : "—"
                                }
                            ] : [
                                {
                                    k: "Command",
                                    v: root.upscDisplayCommand
                                },
                                {
                                    k: "Exit code",
                                    v: String(root.upscLastExitCode)
                                },
                                {
                                    k: "Message",
                                    v: root.upscErrorDetail || "—"
                                }
                            ]

                            Row {
                                required property var modelData
                                width: parent.width
                                spacing: Theme.spacingS

                                StyledText {
                                    text: modelData.k
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceVariantText
                                    width: 88
                                }

                                StyledText {
                                    text: modelData.v
                                    font.pixelSize: Theme.fontSizeSmall
                                    color: Theme.surfaceText
                                    wrapMode: Text.WordWrap
                                    width: parent.width - 88 - Theme.spacingS
                                }
                            }
                        }
                    }
                }

                StyledRect {
                    width: parent.width
                    height: graphCol.implicitHeight + Theme.spacingM * 2
                    radius: Theme.cornerRadius
                    color: Theme.surfaceContainerHigh
                    visible: root.chargeHistory.length >= 2

                    Column {
                        id: graphCol
                        anchors.fill: parent
                        anchors.margins: Theme.spacingM
                        spacing: Theme.spacingXS

                        StyledText {
                            text: "Battery charge %"
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.surfaceVariantText
                        }

                        Item {
                            width: parent.width
                            height: 128
                            clip: true

                            Canvas {
                                id: histCanvas
                                anchors.fill: parent

                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()

                                onPaint: {
                                    const ctx = getContext("2d");
                                    ctx.clearRect(0, 0, width, height);
                                    const data = root.chargeHistory;
                                    if (data.length < 2)
                                        return;

                                    const leftPad = 34;
                                    const bottomPad = 22;
                                    const topPad = 4;
                                    const rightPad = 8;
                                    const chartW = width - leftPad - rightPad;
                                    const chartH = height - topPad - bottomPad;
                                    if (chartW < 8 || chartH < 8)
                                        return;

                                    const tMin = data[0].t;
                                    const tMax = data[data.length - 1].t;
                                    const timeSpan = tMax - tMin;
                                    const useTimeX = timeSpan > 500;

                                    function xAt(i) {
                                        if (useTimeX)
                                            return leftPad + chartW * (data[i].t - tMin) / (timeSpan || 1);
                                        return leftPad + chartW * i / (data.length - 1);
                                    }

                                    function yAtCharge(c) {
                                        const clamped = Math.max(0, Math.min(100, c));
                                        return topPad + chartH * (1 - clamped / 100);
                                    }

                                    ctx.strokeStyle = Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.28);
                                    ctx.lineWidth = 1;
                                    ctx.setLineDash([4, 3]);
                                    for (let g = 0; g <= 4; g++) {
                                        const pct = 100 - g * 25;
                                        const y = topPad + chartH * g / 4;
                                        ctx.beginPath();
                                        ctx.moveTo(leftPad, y);
                                        ctx.lineTo(leftPad + chartW, y);
                                        ctx.stroke();
                                    }
                                    ctx.setLineDash([]);

                                    ctx.fillStyle = Theme.surfaceVariantText;
                                    ctx.font = "10px sans-serif";
                                    ctx.textAlign = "right";
                                    ctx.textBaseline = "middle";
                                    for (let g = 0; g <= 4; g++) {
                                        const pct = 100 - g * 25;
                                        const y = topPad + chartH * g / 4;
                                        ctx.fillText(String(pct), leftPad - 4, y);
                                    }

                                    ctx.strokeStyle = Theme.primary;
                                    ctx.lineWidth = 2;
                                    ctx.lineJoin = "round";
                                    ctx.beginPath();
                                    for (let i = 0; i < data.length; i++) {
                                        const x = xAt(i);
                                        const y = yAtCharge(data[i].c);
                                        if (i === 0)
                                            ctx.moveTo(x, y);
                                        else
                                            ctx.lineTo(x, y);
                                    }
                                    ctx.stroke();

                                    ctx.fillStyle = Theme.surfaceVariantText;
                                    ctx.font = "10px sans-serif";
                                    ctx.textBaseline = "top";
                                    const yLab = topPad + chartH + 4;
                                    const lab0 = root.formatChartClock(tMin);
                                    ctx.textAlign = "left";
                                    ctx.fillText(lab0, leftPad + 2, yLab);
                                    ctx.textAlign = "center";
                                    ctx.fillText(root.formatChartClock((tMin + tMax) / 2), leftPad + chartW * 0.5, yLab);
                                    ctx.textAlign = "right";
                                    ctx.fillText(root.formatChartClock(tMax), leftPad + chartW - 2, yLab);

                                    ctx.strokeStyle = Qt.rgba(Theme.surfaceVariantText.r, Theme.surfaceVariantText.g, Theme.surfaceVariantText.b, 0.45);
                                    ctx.lineWidth = 1;
                                    ctx.beginPath();
                                    ctx.moveTo(leftPad, topPad + chartH);
                                    ctx.lineTo(leftPad + chartW, topPad + chartH);
                                    ctx.stroke();
                                }

                                Connections {
                                    target: root
                                    function onChargeHistoryChanged() {
                                        histCanvas.requestPaint();
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
