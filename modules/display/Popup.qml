import Quickshell
import QtQuick
import qs
import qs.core.components

ModulePopup {
  id: popupHost

  onIsOpenChanged: {
    if (isOpen) {
      Compositor.fetchOutputs()
      DisplayManager.refreshBrightness()
    }
  }

  PopupBase {
    popupWidth: 360
    contentSpacing: 10

    Row {
      width: parent.width
      height: 28

      Text {
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍹"
        color: Theme.accent
        font.family: "Symbols Nerd Font"
        font.pixelSize: Theme.scaledFontSize(22)
      }

      Column {
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 10

        BodyText {
          text: DisplayManager.selectedOutput
            ? (DisplayManager.selectedOutput.model || DisplayManager.selectedOutput.name)
            : "No display"
        }

        AnnotationText {
          text: DisplayManager.selectedOutput ? DisplayManager.selectedOutput.name : ""
        }
      }

      Item { width: Math.max(0, parent.width - 190); height: 1 }

      FocusLink {
        anchors.verticalCenter: parent.verticalCenter
        text: "Configure"
        textColor: Theme.textMuted
        hoverColor: Theme.accent
        fontSize: 12
        onClicked: OverlayManager.open("settings", { category: "display" })
      }
    }

    Column {
      width: parent.width
      spacing: 4
      visible: DisplayManager.outputs.length > 1

      TitleText { text: "Displays" }

      Repeater {
        model: DisplayManager.outputs

        Row {
          required property var modelData
          width: parent.width
          height: 42
          spacing: 6

          FocusListItem {
            width: parent.width - 82
            itemHeight: 42
            bodyMargins: 0
            bodyRadius: 4
            enabled: modelData.active
            opacity: enabled ? 1 : 0.65
            icon: modelData.name.match(/^(eDP|LVDS|DSI)-/) ? "󰌢" : "󰍹"
            iconColor: DisplayManager.selectedOutputName === modelData.name
              ? Theme.accent : Theme.textPrimary
            text: modelData.model || modelData.name
            subtitle: modelData.name
            rightIcon: DisplayManager.selectedOutputName === modelData.name ? "󰄬" : ""
            rightIconColor: Theme.accent
            backgroundColor: Theme.bgCard
            hoverBackgroundColor: Theme.bgCardHover
            onClicked: DisplayManager.selectOutput(modelData.name)
          }

          FocusButton {
            width: 76
            height: 34
            anchors.verticalCenter: parent.verticalCenter
            text: modelData.active ? "Disable" : "Enable"
            fontSize: 11
            enabled: !modelData.active || DisplayManager.activeCount > 1
            opacity: enabled ? 1 : 0.45
            backgroundColor: Theme.bgCard
            hoverColor: Theme.bgCardHover
            onClicked: DisplayManager.setOutputActive(modelData.name, !modelData.active)
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgBorder
      visible: DisplayManager.brightnessAvailable
    }

    Column {
      width: parent.width
      spacing: 4
      visible: DisplayManager.brightnessAvailable

      Row {
        width: parent.width

        TitleText { text: "Brightness" }
        Item { width: Math.max(0, parent.width - 120); height: 1 }
        AnnotationText { text: DisplayManager.selectedBrightness + "%" }
      }

      Row {
        width: parent.width
        height: 28
        spacing: 8

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: DisplayManager.getBrightnessIcon(DisplayManager.selectedBrightness)
          color: Theme.warning
          font.family: "Symbols Nerd Font"
          font.pixelSize: Theme.scaledFontSize(18)
        }

        FocusSlider {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - 28
          from: 1
          to: 100
          stepSize: 1
          value: DisplayManager.selectedBrightness
          accentColor: Theme.warning
          onMoved: DisplayManager.setBrightness(value)
        }
      }
    }

    Rectangle { width: parent.width; height: 1; color: Theme.bgBorder }

    Column {
      width: parent.width
      spacing: 5

      Row {
        width: parent.width
        TitleText { text: "Text size" }
        Item { width: Math.max(0, parent.width - 112); height: 1 }
        AnnotationText { text: DisplayManager.textSize + "px" }
      }

      Row {
        width: parent.width
        spacing: 4

        Repeater {
          model: DisplayManager.textSizeStops

          FocusButton {
            required property int modelData
            width: (parent.width - 24) / 7
            height: 30
            text: String(modelData)
            fontSize: 11
            backgroundColor: DisplayManager.textSize === modelData
              ? Theme.accent : Theme.bgCard
            hoverColor: DisplayManager.textSize === modelData
              ? Theme.accent : Theme.bgCardHover
            textColor: DisplayManager.textSize === modelData
              ? Theme.bgDeep : Theme.textPrimary
            textHoverColor: textColor
            onClicked: DisplayManager.setTextSize(modelData)
          }
        }
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgBorder
      visible: DisplayManager.selectedOutput && DisplayManager.selectedOutput.active
    }

    Column {
      width: parent.width
      spacing: 5
      visible: DisplayManager.selectedOutput && DisplayManager.selectedOutput.active

      Row {
        width: parent.width
        TitleText { text: "Render scale" }
        Item { width: Math.max(0, parent.width - 140); height: 1 }
        AnnotationText {
          text: DisplayManager.selectedOutput
            ? Number(DisplayManager.selectedOutput.scale).toFixed(2).replace(/0+$/, "").replace(/[.]$/, "") + "x"
            : ""
        }
      }

      Row {
        width: parent.width
        spacing: 4

        Repeater {
          model: DisplayManager.scalePresets

          FocusButton {
            required property real modelData
            width: (parent.width - 20) / 6
            height: 30
            text: modelData + "x"
            fontSize: 10
            backgroundColor: DisplayManager.selectedOutput
                && Math.abs(DisplayManager.selectedOutput.scale - modelData) < 0.01
              ? Theme.accent : Theme.bgCard
            hoverColor: backgroundColor === Theme.accent ? Theme.accent : Theme.bgCardHover
            textColor: backgroundColor === Theme.accent ? Theme.bgDeep : Theme.textPrimary
            textHoverColor: textColor
            onClicked: DisplayManager.setScale(modelData)
          }
        }
      }
    }
  }
}
