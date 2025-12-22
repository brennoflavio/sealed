import Lomiri.Components 1.3
import QtQuick 2.7
import io.thp.pyotherside 1.4

Rectangle {
    id: root

    property bool isLoading: false

    height: units.dp(3)
    color: "transparent"
    clip: true

    Rectangle {
        id: indicator

        width: parent.width * 0.3
        height: parent.height
        color: theme.palette.normal.focus
        visible: root.isLoading
        x: root.isLoading ? -width : -width
        onVisibleChanged: {
            if (!visible)
                indicator.x = -indicator.width;

        }

        SequentialAnimation {
            id: slideAnimation

            running: root.isLoading && root.width > 0
            loops: Animation.Infinite

            NumberAnimation {
                target: indicator
                property: "x"
                from: -indicator.width
                to: root.width
                duration: 1000
                easing.type: Easing.InOutQuad
            }

        }

    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../../src/'));
            importModule('main', function() {
                python.call('main.loading_initial_state', [], function(result) {
                    root.isLoading = result;
                });
            });
            setHandler('loading', function(show) {
                root.isLoading = show;
            });
        }
    }

}
