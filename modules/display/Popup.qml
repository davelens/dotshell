import Quickshell
import QtQuick
import QtQuick.Window
import qs
import qs.core.components

ModulePopup {
  id: popupHost

  component SectionSeparator: Item {
    width: parent.width
    height: 17

    Rectangle {
      readonly property real pixelRatio: Window.window ? Window.window.devicePixelRatio : 1

      anchors.verticalCenter: parent.verticalCenter
      width: parent.width
      height: 1 / pixelRatio
      color: Theme.bgBorder
    }
  }

  component ValueHeading: Item {
    property string title
    property string value

    width: parent.width
    height: Math.max(titleText.implicitHeight, valueText.implicitHeight)

    TitleText {
      id: titleText
      anchors.left: parent.left
      text: title
    }

    AnnotationText {
      id: valueText
      anchors.left: titleText.right
      anchors.right: parent.right
      horizontalAlignment: Text.AlignRight
      text: value
    }
  }

  onIsOpenChanged: {
    if (isOpen) {
      Compositor.fetchOutputs()
      DisplayManager.refreshBrightness()
    }
  }

  PopupBase {
    popupWidth: 360
    contentSpacing: 10

    Item {
      width: parent.width
      height: 28

      Text {
        id: displayIcon
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        text: "󰍹"
        color: Theme.accent
        font.family: "Symbols Nerd Font"
        font.pixelSize: Theme.scaledFontSize(22)
      }

      Text {
        anchors.left: displayIcon.right
        anchors.leftMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: "Displays"
        color: Theme.textPrimary
        font.family: Theme.fontFamily
        font.pixelSize: Theme.scaledFontSize(16)
      }

      FocusLink {
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: "Configure"
        textColor: Theme.textMuted
        hoverColor: Theme.accent
        fontSize: 12
        onClicked: OverlayManager.open("settings", { category: "display" }, PopupManager.targetScreen)
      }
    }

    Rectangle {
      width: parent.width
      height: 1
      color: Theme.bgCardHover
    }

    Column {
      width: parent.width
      spacing: 4
      visible: DisplayManager.outputs.length > 1

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

    SectionSeparator {
      visible: DisplayManager.brightnessAvailable
    }

    Column {
      width: parent.width
      spacing: 4
      visible: DisplayManager.brightnessAvailable

      ValueHeading {
        title: "Brightness"
        value: DisplayManager.selectedBrightness + "%"
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

    SectionSeparator {
      visible: DisplayManager.selectedOutput && DisplayManager.selectedOutput.active
    }

    Column {
      width: parent.width
      spacing: 5
      visible: DisplayManager.selectedOutput && DisplayManager.selectedOutput.active

      ValueHeading {
        title: "Render scale"
        value: DisplayManager.selectedOutput
          ? Number(DisplayManager.selectedOutput.scale).toFixed(2).replace(/0+$/, "").replace(/[.]$/, "") + "x"
          : ""
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

    SectionSeparator {}

    Column {
      width: parent.width
      spacing: 5

      ValueHeading {
        title: "Text size (global)"
        value: DisplayManager.textSize + "px"
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
  }
}
