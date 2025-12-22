import "." 1.0
import Lomiri.Components 1.3
/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * sealed is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import QtQuick.Layouts 1.3
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: loginPage

    property string email: ""
    property string password: ""
    property string totp: ""
    property bool isLoggingIn: false
    property string loginMessage: ""
    property bool loginSuccess: false
    property var loginScreenData: null
    property var visibleFields: []
    property bool isCheckingLogin: false

    function navigateToPasswordList() {
        pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
    }

    function checkLoginScreen() {
        isCheckingLogin = true;
        python.call('main.login_screen', [], function(result) {
            loginScreenData = result;
            visibleFields = result.fields || [];
            isCheckingLogin = false;
            if (!result.show)
                navigateToPasswordList();

        });
    }

    function performLogin() {
        isLoggingIn = true;
        loginMessage = "";
        var emailValue = visibleFields.indexOf("email") !== -1 ? email : "";
        var passwordValue = visibleFields.indexOf("password") !== -1 ? password : "";
        var totpValue = visibleFields.indexOf("totp") !== -1 ? totp : "";
        python.call('main.login', [emailValue, passwordValue, totpValue], function(result) {
            isLoggingIn = false;
            if (result && result.success) {
                loginSuccess = true;
                loginMessage = "";
                SessionModel.setEncryptionKey(result.message);
                navigateToPasswordList();
            } else {
                loginSuccess = false;
                loginMessage = result && result.message ? result.message : i18n.tr("Login failed");
            }
        });
    }

    Component.onCompleted: {
        checkLoginScreen();
    }

    Flickable {
        contentHeight: loginContent.height + units.gu(4)

        anchors {
            top: loadingBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Column {
            id: loginContent

            spacing: units.gu(2)

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                margins: units.gu(2)
                topMargin: units.gu(4)
            }

            Label {
                text: i18n.tr("Bitwarden Login")
                fontSize: "large"
                font.weight: Font.Medium
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Form {
                id: loginForm

                buttonText: i18n.tr("Login")
                buttonIconName: "lock-broken"
                enabled: !loginPage.isLoggingIn
                onSubmitted: {
                    loginPage.performLogin();
                }

                InputField {
                    id: emailField

                    property bool isValid: loginPage.visibleFields.indexOf("email") === -1 || text.trim() !== ""

                    visible: loginPage.visibleFields.indexOf("email") !== -1
                    title: i18n.tr("Email")
                    placeholder: i18n.tr("Enter your email")
                    text: loginPage.email
                    onTextChanged: loginPage.email = text
                }

                InputField {
                    id: passwordField

                    property bool isValid: loginPage.visibleFields.indexOf("password") === -1 || text.trim() !== ""

                    visible: loginPage.visibleFields.indexOf("password") !== -1
                    title: i18n.tr("Password")
                    placeholder: i18n.tr("Enter your password")
                    text: loginPage.password
                    echoMode: TextInput.Password
                    onTextChanged: loginPage.password = text
                }

                InputField {
                    id: totpField

                    property bool isValid: true

                    visible: loginPage.visibleFields.indexOf("totp") !== -1
                    title: i18n.tr("Two-Factor Code - Only Authenticator app is supported")
                    placeholder: i18n.tr("Enter your 2fa code")
                    text: loginPage.totp
                    onTextChanged: loginPage.totp = text
                }

            }

            Label {
                id: loginMessageLabel

                text: loginPage.loginMessage
                color: loginPage.loginSuccess ? theme.palette.normal.positive : theme.palette.normal.negative
                wrapMode: Text.WordWrap
                horizontalAlignment: Text.AlignHCenter
                visible: loginPage.loginMessage !== ""

                anchors {
                    left: parent.left
                    right: parent.right
                }

            }

        }

    }

    LoadToast {
        id: loginLoadingToast

        showing: loginPage.isLoggingIn
        message: i18n.tr("Logging in... This may take a few moments")
    }

    LoadToast {
        id: checkingLoginToast

        showing: loginPage.isCheckingLogin
        message: i18n.tr("Checking login status...")
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('main', function() {
            });
        }
        onError: {
        }
    }

    LoadingBar {
        id: loadingBar

        anchors.top: loginHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    header: AppHeader {
        id: loginHeader

        pageTitle: i18n.tr('Sealed')
        isRootPage: true
        appIconName: "lock"
        showSettingsButton: true
        onSettingsClicked: {
            pageStack.push(Qt.resolvedUrl("ConfigurationPage.qml"));
        }
    }

}
