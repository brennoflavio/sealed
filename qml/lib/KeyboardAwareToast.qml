import "../ut_components"
import Lomiri.Components 1.3
import QtQuick 2.7

Item {
    id: root

    property alias message: toast.message
    property alias duration: toast.duration
    property alias bottomMargin: toast.bottomMargin

    function show(text) {
        toast.show(text);
    }

    anchors.fill: parent
    z: 1000

    KeyboardSpacer {
        id: keyboardSpacer

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

    }

    Toast {
        id: toast

        anchors.bottom: keyboardSpacer.top
    }

}
