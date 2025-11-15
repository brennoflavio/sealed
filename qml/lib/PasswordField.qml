import Lomiri.Components 1.3
import QtQuick 2.7
import QtQuick.Layouts 1.3

Item {
    id: passwordField

    property string title: ""
    property string placeholder: ""
    property alias text: textField.text
    property string validationRegex: ""
    property string errorMessage: i18n.tr("Invalid input")
    property bool required: false
    property alias isValid: internal.isValid
    property bool showPassword: false
    property var onGeneratePassword: null

    width: parent.width
    height: units.gu(12)
    onTextChanged: {
        internal.validate();
    }

    QtObject {
        id: internal

        property bool isValid: (required || validationRegex) ? false : true
        property bool showError: false

        function validate() {
            if (required && text.trim().length === 0) {
                isValid = false;
                showError = text.length > 0 || textField.focus === false;
                return false;
            }
            if (validationRegex === "") {
                isValid = true;
                showError = false;
                return true;
            }
            var regex = new RegExp(validationRegex);
            isValid = regex.test(text);
            showError = !isValid && text.length > 0;
            return isValid;
        }

    }

    Connections {
        target: textField
        onFocusChanged: {
            if (!textField.focus)
                internal.validate();

        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: units.gu(1)
        spacing: units.gu(0.5)

        Label {
            id: titleLabel

            text: passwordField.title
            fontSize: "small"
            color: theme.palette.normal.backgroundText
            Layout.fillWidth: true
        }

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: units.gu(1)

            TextField {
                id: textField

                placeholderText: passwordField.placeholder
                Layout.fillWidth: true
                echoMode: showPassword ? TextInput.Normal : TextInput.Password
                color: internal.showError ? theme.palette.normal.negative : theme.palette.normal.fieldText
            }

            Icon {
                id: visibilityToggle

                name: showPassword ? "view-off" : "view-on"
                width: units.gu(3)
                height: units.gu(3)
                color: theme.palette.normal.backgroundText

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        showPassword = !showPassword;
                    }
                }

            }

            Icon {
                id: generateButton

                name: "reload"
                width: units.gu(3)
                height: units.gu(3)
                color: theme.palette.normal.backgroundText
                visible: onGeneratePassword !== null

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (onGeneratePassword) {
                            var generatedPassword = onGeneratePassword();
                            if (generatedPassword)
                                textField.text = generatedPassword;

                        }
                    }
                }

            }

        }

        Label {
            id: errorLabel

            text: required && textField.text.trim().length === 0 ? i18n.tr("This field is required") : errorMessage
            fontSize: "x-small"
            color: theme.palette.normal.negative
            visible: internal.showError
            Layout.fillWidth: true
        }

    }

}
