import QtQuick 2.12
import QtQuick.Window 2.12

Item {
    readonly property real s: Screen.height / 768
    anchors.fill: parent

    // Static frame instead of video — avoids video-decode overhead on
    // Intel integrated graphics at SDDM startup
    Image {
        id: bgImage
        anchors.fill: parent
        source: "bg.jpg"
        fillMode: Image.PreserveAspectCrop
        smooth: true
        asynchronous: false
        cache: true
    }
}

