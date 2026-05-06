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
    id: passwordLoginPage

    property string loginId: ""
    property string name: ""
    property string username: ""
    property string password: ""
    property string totpSecret: ""
    property string notes: ""
    property string created: ""
    property string updated: ""
    property bool passwordVisible: false
    property bool favorite: false
    property bool totpVisible: false
    property bool isTrashed: false
    property string folderId: ""
    property string folderName: ""
    property var fields: []
    property string currentTotpCode: ""
    property int currentTotpSecondsRemaining: 0
    property bool totpLoaded: false
    property bool pythonReady: false

    signal backRequested()

    function copyToClipboard(text, itemName) {
        Clipboard.push(text);
        toast.show(i18n.tr("%1 copied to clipboard").arg(itemName));
    }

    function resetTotpState() {
        currentTotpCode = "";
        currentTotpSecondsRemaining = 0;
        totpLoaded = false;
        totpVisible = false;
    }

    function refreshTotp(copyAfterRefresh) {
        var requestedSecret = totpSecret;
        if (requestedSecret === "") {
            resetTotpState();
            return ;
        }
        python.call('main.get_totp', [requestedSecret], function(result) {
            if (requestedSecret !== passwordLoginPage.totpSecret)
                return ;

            currentTotpCode = result && result.code ? result.code : "";
            currentTotpSecondsRemaining = result && result.seconds_remaining ? result.seconds_remaining : 0;
            totpLoaded = true;
            if (copyAfterRefresh) {
                if (currentTotpCode !== "")
                    copyToClipboard(currentTotpCode, i18n.tr("TOTP Code"));
                else
                    toast.show(i18n.tr("TOTP unavailable"));
            }
        });
    }

    function totpTitle() {
        if (!totpLoaded)
            return i18n.tr("TOTP - Loading...");

        if (currentTotpCode === "")
            return i18n.tr("TOTP - Unavailable");

        return i18n.tr("TOTP - %1 seconds remaining").arg(currentTotpSecondsRemaining);
    }

    function totpSubtitle() {
        if (!totpLoaded)
            return i18n.tr("Loading...");

        if (currentTotpCode === "")
            return i18n.tr("Unavailable");

        return "";
    }

    onTotpSecretChanged: {
        resetTotpState();
        if (pythonReady && visible && totpSecret !== "")
            refreshTotp();

    }

    Flickable {
        contentHeight: contentColumn.height + units.gu(4)
        clip: true

        anchors {
            top: loadingBar.bottom
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
        }

        Column {
            id: contentColumn

            spacing: units.gu(2)

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
                topMargin: units.gu(2)
            }

            ConfigurationGroup {
                title: i18n.tr("Main")

                DetailField {
                    title: i18n.tr("Name")
                    subtitle: name
                    onCopyClicked: copyToClipboard(name, i18n.tr("Name"))
                    showDivider: true
                }

                DetailField {
                    title: i18n.tr("Folder")
                    subtitle: folderName || "-"
                    onCopyClicked: copyToClipboard(folderName, i18n.tr("Folder"))
                }

            }

            ConfigurationGroup {
                title: i18n.tr("Credentials")

                DetailField {
                    title: i18n.tr("Username")
                    subtitle: username
                    showDivider: true
                    onCopyClicked: copyToClipboard(username, i18n.tr("Username"))
                }

                DetailField {
                    title: i18n.tr("Password")
                    visibleContent: password
                    showVisibilityToggle: true
                    isContentVisible: passwordLoginPage.passwordVisible
                    showDivider: totpSecret !== ""
                    onVisibilityToggled: passwordLoginPage.passwordVisible = !passwordLoginPage.passwordVisible
                    onCopyClicked: copyToClipboard(password, i18n.tr("Password"))
                }

                DetailField {
                    visible: totpSecret !== ""
                    title: passwordLoginPage.totpTitle()
                    subtitle: passwordLoginPage.totpSubtitle()
                    visibleContent: currentTotpCode
                    showVisibilityToggle: totpLoaded && currentTotpCode !== ""
                    isContentVisible: passwordLoginPage.totpVisible
                    onVisibilityToggled: passwordLoginPage.totpVisible = !passwordLoginPage.totpVisible
                    onCopyClicked: passwordLoginPage.refreshTotp(true)
                }

            }

            CustomFieldsList {
                fields: passwordLoginPage.fields
                onCopyClicked: passwordLoginPage.copyToClipboard(value, fieldName)
            }

            ConfigurationGroup {
                title: i18n.tr("Misc")

                DetailField {
                    title: i18n.tr("Notes")
                    subtitle: notes
                    showDivider: true
                    onCopyClicked: copyToClipboard(notes, i18n.tr("Notes"))
                }

                DetailField {
                    title: i18n.tr("Created")
                    subtitle: created
                    showDivider: true
                    onCopyClicked: copyToClipboard(created, i18n.tr("Created date"))
                }

                DetailField {
                    title: i18n.tr("Updated")
                    subtitle: updated
                    onCopyClicked: copyToClipboard(updated, i18n.tr("Updated date"))
                }

            }

        }

    }

    Timer {
        interval: 1000
        repeat: true
        running: passwordLoginPage.pythonReady && passwordLoginPage.visible && passwordLoginPage.totpSecret !== ""
        triggeredOnStart: true
        onTriggered: {
            if (!passwordLoginPage.totpLoaded) {
                passwordLoginPage.refreshTotp();
                return ;
            }
            if (passwordLoginPage.currentTotpSecondsRemaining > 1) {
                passwordLoginPage.currentTotpSecondsRemaining -= 1;
                return ;
            }
            passwordLoginPage.refreshTotp();
        }
    }

    BottomBar {
        id: bottomBar

        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        IconButton {
            visible: !passwordLoginPage.isTrashed
            iconName: "edit"
            text: i18n.tr("Edit")
            onClicked: {
                pageStack.push(Qt.resolvedUrl("UpsertLoginPage.qml"), {
                    "isEditMode": true,
                    "loginId": passwordLoginPage.loginId || "",
                    "loginName": passwordLoginPage.name,
                    "loginUsername": passwordLoginPage.username,
                    "loginPassword": passwordLoginPage.password,
                    "loginNotes": passwordLoginPage.notes,
                    "loginTotpSecret": passwordLoginPage.totpSecret,
                    "favorite": favorite,
                    "folderId": passwordLoginPage.folderId || ""
                });
            }
        }

        IconButton {
            visible: !passwordLoginPage.isTrashed
            iconName: "delete"
            text: i18n.tr("Trash")
            onClicked: {
                trashLoadToast.showing = true;
                python.call('main.trash_item', [SessionModel.getEncryptionKey(), passwordLoginPage.loginId], function(result) {
                    trashLoadToast.showing = false;
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                });
            }
        }

        IconButton {
            visible: passwordLoginPage.isTrashed
            iconName: "undo"
            text: i18n.tr("Restore")
            onClicked: {
                loadToast.showing = true;
                python.call('main.restore_item', [SessionModel.getEncryptionKey(), passwordLoginPage.loginId], function(result) {
                    loadToast.showing = false;
                    pageStack.pop();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                });
            }
        }

        IconButton {
            visible: passwordLoginPage.isTrashed
            iconName: "delete"
            text: i18n.tr("Delete")
            onClicked: {
                deleteLoadToast.showing = true;
                python.call('main.delete_item', [SessionModel.getEncryptionKey(), passwordLoginPage.loginId], function(result) {
                    deleteLoadToast.showing = false;
                    pageStack.pop();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                });
            }
        }

    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('main', function() {
                passwordLoginPage.pythonReady = true;
            });
        }
        onError: {
        }
    }

    KeyboardAwareToast {
        id: toast
    }

    LoadToast {
        id: loadToast

        message: i18n.tr("Restoring item...")
    }

    LoadToast {
        id: deleteLoadToast

        message: i18n.tr("Deleting item...")
    }

    LoadToast {
        id: trashLoadToast

        message: i18n.tr("Moving to trash...")
    }

    LoadingBar {
        id: loadingBar

        anchors.top: detailHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    header: AppHeader {
        id: detailHeader

        pageTitle: name
        isRootPage: false
        showSettingsButton: false
    }

}
