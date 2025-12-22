import Lomiri.Components 1.3
/*
 * Copyright (C) 2025  Brenno Flávio de Almeida
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; version 3.
 *
 * contactbridge is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 */
import QtQuick 2.7
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: configurationPage

    property bool crashReportEnabled: false
    property string serverUrl: ""

    function loadConfiguration() {
        python.call('main.get_configuration', [], function(config) {
            if (config) {
                if (config.hasOwnProperty('crash_logs'))
                    configurationPage.crashReportEnabled = config.crash_logs;

                if (config.hasOwnProperty('server_url')) {
                    configurationPage.serverUrl = config.server_url;
                    serverUrlField.text = config.server_url;
                }
            }
        });
    }

    function saveServerUrl() {
        serverErrorLabel.text = "";
        loadToast.message = i18n.tr("Saving server URL...");
        loadToast.showing = true;
        python.call('main.set_server', [serverUrlField.text], function(response) {
            loadToast.showing = false;
            if (response.success) {
                pageStack.clear();
                pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
            } else {
                serverErrorLabel.text = response.message;
            }
        });
    }

    function logout() {
        logoutErrorLabel.text = "";
        loadToast.message = i18n.tr("Logging out...");
        loadToast.showing = true;
        python.call('main.logout', [], function(response) {
            loadToast.showing = false;
            if (response.success) {
                pageStack.clear();
                pageStack.push(Qt.resolvedUrl("LoginPage.qml"));
            } else if (!response.success && response.message) {
                logoutErrorLabel.text = response.message;
            }
        });
    }

    Component.onCompleted: {
        loadConfiguration();
    }

    Flickable {
        contentHeight: contentColumn.height

        anchors {
            top: loadingBar.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Column {
            id: contentColumn

            spacing: units.gu(2)

            anchors {
                left: parent.left
                right: parent.right
                margins: units.gu(2)
            }

            ConfigurationGroup {
                width: parent.width
                title: i18n.tr("Bitwarden Server")

                InputField {
                    id: serverUrlField

                    width: parent.width
                    title: i18n.tr("Server URL")
                    placeholder: i18n.tr("https://vault.bitwarden.com")
                    text: configurationPage.serverUrl
                }

                ActionButton {
                    text: i18n.tr("Save Server URL")
                    color: theme.palette.normal.positive
                    onClicked: configurationPage.saveServerUrl()
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - units.gu(4)
                    iconName: "save"
                }

                Label {
                    id: serverErrorLabel

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    color: theme.palette.normal.negative
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }

            }

            ConfigurationGroup {
                width: parent.width
                title: i18n.tr("Account")

                ActionButton {
                    text: i18n.tr("Logout")
                    color: theme.palette.normal.negative
                    onClicked: configurationPage.logout()
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - units.gu(4)
                    iconName: "edit-clear"
                }

                Label {
                    id: logoutErrorLabel

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: ""
                    color: theme.palette.normal.negative
                    wrapMode: Text.WordWrap
                    visible: text !== ""
                }

            }

            ConfigurationGroup {
                width: parent.width
                title: i18n.tr("Privacy")

                ToggleOption {
                    width: parent.width
                    title: i18n.tr("Crash logs")
                    subtitle: i18n.tr("Send anonymous crash reports")
                    checked: configurationPage.crashReportEnabled
                    onToggled: function(checked) {
                        configurationPage.crashReportEnabled = checked;
                        python.call('main.set_crash_logs', [checked], function() {
                        });
                    }
                }

            }

        }

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

    LoadToast {
        id: loadToast
    }

    LoadingBar {
        id: loadingBar

        anchors.top: configHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    header: AppHeader {
        id: configHeader

        pageTitle: i18n.tr("Configuration")
        isRootPage: false
        showSettingsButton: false
    }

}
