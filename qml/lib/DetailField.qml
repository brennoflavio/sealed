import Lomiri.Components 1.3
import QtQuick 2.7
import QtQuick.Layouts 1.3

/**
 * DetailField Component
 *
 * A flexible field component for displaying information with optional action buttons.
 * Commonly used for displaying form data, credentials, and other read-only information
 * with built-in support for copy-to-clipboard and visibility toggling (for sensitive data).
 *
 * Features:
 * - Title and subtitle display
 * - Copy button for clipboard operations
 * - Visibility toggle for sensitive content (passwords)
 * - Custom action buttons support
 * - Optional bottom divider
 *
 * Usage Examples:
 *
 * Basic field with copy button:
 * DetailField {
 *     title: i18n.tr("Username")
 *     subtitle: "john.doe@example.com"
 *     onCopyClicked: copyToClipboard(subtitle, title)
 * }
 *
 * Password field with visibility toggle:
 * DetailField {
 *     title: i18n.tr("Password")
 *     visibleContent: actualPassword
 *     showVisibilityToggle: true
 *     isContentVisible: false
 *     onCopyClicked: copyToClipboard(actualPassword, title)
 * }
 *
 * Field with custom actions:
 * DetailField {
 *     title: i18n.tr("URL")
 *     subtitle: "https://example.com"
 *     customActions: [
 *         { iconName: "external-link", action: function() { Qt.openUrlExternally(subtitle) } }
 *     ]
 * }
 */
Item {
    id: detailField

    // Display title for the field (e.g., "Username", "Password")
    property string title: ""
    // Display content when visibility toggle is not used
    property string subtitle: ""
    // Whether to show the copy button (default: true)
    property bool showCopyButton: true
    // Whether to show the visibility toggle button for sensitive content
    property bool showVisibilityToggle: false
    // Current visibility state when using visibility toggle
    property bool isContentVisible: true
    // Content to show when visible (used with showVisibilityToggle)
    property string visibleContent: subtitle
    // Content to show when hidden (default: bullet points)
    property string hiddenContent: "••••••••••••"
    // Array of custom action objects with iconName and action properties
    property var customActions: []
    // Whether to show a divider line at the bottom
    property bool showDivider: false

    // Emitted when the copy button is clicked
    signal copyClicked()
    // Emitted when the visibility toggle is clicked
    signal visibilityToggled()

    height: Math.max(units.gu(6), contentColumn.height + units.gu(2))
    anchors.left: parent.left
    anchors.right: parent.right
    anchors.leftMargin: units.gu(2)
    anchors.rightMargin: units.gu(2)

    Column {
        id: contentColumn

        spacing: units.gu(0.5)

        anchors {
            left: parent.left
            right: actionsRow.visible ? actionsRow.left : parent.right
            rightMargin: actionsRow.visible ? units.gu(1) : 0
            verticalCenter: parent.verticalCenter
        }

        Label {
            text: detailField.title
            fontSize: "small"
            color: theme.palette.normal.backgroundTertiaryText
        }

        Label {
            width: parent.width
            text: detailField.showVisibilityToggle ? (detailField.isContentVisible ? detailField.visibleContent : detailField.hiddenContent) : detailField.subtitle
            wrapMode: Text.WordWrap
            fontSize: "medium"
            elide: Text.ElideRight
        }

    }

    Row {
        id: actionsRow

        spacing: units.gu(1)
        visible: showCopyButton || showVisibilityToggle || customActions.length > 0

        anchors {
            right: parent.right
            verticalCenter: parent.verticalCenter
        }

        Repeater {
            model: detailField.customActions

            delegate: Icon {
                width: units.gu(2.5)
                height: units.gu(2.5)
                name: modelData.iconName

                MouseArea {
                    anchors.fill: parent
                    onClicked: modelData.action()
                }

            }

        }

        Icon {
            width: units.gu(2.5)
            height: units.gu(2.5)
            name: detailField.isContentVisible ? "view-off" : "view-on"
            visible: detailField.showVisibilityToggle

            MouseArea {
                anchors.fill: parent
                onClicked: {
                    detailField.isContentVisible = !detailField.isContentVisible;
                    detailField.visibilityToggled();
                }
            }

        }

        Icon {
            width: units.gu(2.5)
            height: units.gu(2.5)
            name: "edit-copy"
            visible: detailField.showCopyButton

            MouseArea {
                anchors.fill: parent
                onClicked: detailField.copyClicked()
            }

        }

    }

    Rectangle {
        visible: detailField.showDivider
        height: units.dp(1)
        color: theme.palette.normal.base

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

    }

}
