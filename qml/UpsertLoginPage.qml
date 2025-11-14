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
    id: upsertLoginPage

    property bool isEditMode: false
    property string loginId: ""
    property string loginName: ""
    property string loginUsername: ""
    property string loginPassword: ""
    property string loginNotes: ""
    property string loginTotpSecret: ""
    property bool favorite: false
    property string folderId: ""
    property string errorMessage: ""
    property bool isSaving: false
    property bool isLoadingFolders: false
    property var foldersData: []
    property string selectedFolderId: ""

    function saveLogin() {
        if (nameField.text.trim() === "") {
            errorMessage = i18n.tr("Name is required");
            return ;
        }
        errorMessage = "";
        isSaving = true;
        loadToast.showing = true;
        var name = nameField.text.trim();
        var username = usernameField.text.trim();
        var password = passwordField.text;
        var notes = notesField.text.trim();
        var totp = totpField.text.trim();
        var favorite = favoriteToggle.checked;
        var folderId = selectedFolderId || "";
        if (isEditMode) {
            python.call('main.edit_login', [loginId, name, username, password, notes, totp, favorite, folderId], function(result) {
                isSaving = false;
                loadToast.showing = false;
                if (result.success) {
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                } else {
                    errorMessage = result.message || i18n.tr("Failed to save login");
                }
            });
        } else {
            python.call('main.add_login', [name, username, password, notes, totp, favorite, folderId], function(result) {
                isSaving = false;
                loadToast.showing = false;
                if (result.success) {
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                } else {
                    errorMessage = result.message || i18n.tr("Failed to save login");
                }
            });
        }
    }

    function loadFolders() {
        isLoadingFolders = true;
        foldersLoadToast.showing = true;
        python.call('main.list_folders', [], function(result) {
            isLoadingFolders = false;
            foldersLoadToast.showing = false;
            if (result.success)
                foldersData = [{
                "id": "",
                "name": i18n.tr("No Folder")
            }].concat(result.folders);
            else
                foldersData = [{
                "id": "",
                "name": i18n.tr("No Folder")
            }];
            if (folderId !== "") {
                for (var i = 0; i < foldersData.length; i++) {
                    if (foldersData[i].id === folderId) {
                        folderSelector.selectedIndex = i;
                        selectedFolderId = folderId;
                        break;
                    }
                }
            }
        });
    }

    Flickable {
        contentHeight: loginForm.height + keyboardSpacer.height + units.gu(4)
        clip: true

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Form {
            id: loginForm

            buttonText: i18n.tr("Save")
            buttonIconName: "save"
            onSubmitted: {
                saveLogin();
            }

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            InputField {
                id: nameField

                property bool isValid: text.trim().length > 0

                width: parent.width
                title: i18n.tr("Name")
                placeholder: isEditMode ? "" : i18n.tr("e.g., Gmail Account")
                text: loginName
                required: true
            }

            InputField {
                id: usernameField

                property bool isValid: true

                width: parent.width
                title: i18n.tr("Username")
                placeholder: isEditMode ? "" : i18n.tr("e.g., user@example.com")
                text: loginUsername
            }

            PasswordField {
                id: passwordField

                property bool isValid: true

                width: parent.width
                title: i18n.tr("Password")
                placeholder: isEditMode ? "" : i18n.tr("Enter password")
                text: loginPassword
                onGeneratePassword: function() {
                    return python.call_sync("main.generate_password", []);
                }
            }

            Item {
                width: parent.width
                height: notesColumn.height + units.gu(2)

                Column {
                    id: notesColumn

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(0.5)

                    Label {
                        text: i18n.tr("Notes")
                        fontSize: "small"
                        color: theme.palette.normal.backgroundText
                    }

                    TextArea {
                        id: notesField

                        width: parent.width
                        height: units.gu(10)
                        placeholderText: isEditMode ? "" : i18n.tr("Additional notes...")
                        text: loginNotes
                    }

                }

            }

            InputField {
                id: totpField

                property bool isValid: true

                width: parent.width
                title: i18n.tr("TOTP Secret")
                placeholder: isEditMode ? "" : i18n.tr("e.g., JBSWY3DPEHPK3PXP")
                text: loginTotpSecret
            }

            ToggleOption {
                id: favoriteToggle

                width: parent.width
                title: i18n.tr("Favorite")
                subtitle: i18n.tr("Mark this login as a favorite")
                checked: favorite
            }

            Column {
                id: folderColumn

                width: parent.width
                spacing: units.gu(1)

                Item {
                    width: parent.width
                    height: units.gu(2)
                }

                Label {
                    text: i18n.tr("Folder")
                    fontSize: "small"
                    color: theme.palette.normal.backgroundText
                    anchors.left: parent.left
                    anchors.leftMargin: units.gu(2)
                }

                OptionSelector {
                    id: folderSelector

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    expanded: false
                    enabled: !isLoadingFolders
                    model: foldersData
                    containerHeight: 3 * itemHeight
                    onSelectedIndexChanged: {
                        if (selectedIndex > 0)
                            selectedFolderId = foldersData[selectedIndex].id;
                        else
                            selectedFolderId = "";
                    }

                    delegate: OptionSelectorDelegate {
                        text: modelData.name
                    }

                }

            }

            Item {
                width: parent.width
                height: errorLabel.visible ? errorLabel.height + units.gu(1) : 0

                Label {
                    id: errorLabel

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: errorMessage
                    color: theme.palette.normal.negative
                    fontSize: "small"
                    wrapMode: Text.WordWrap
                    visible: errorMessage !== ""
                    horizontalAlignment: Text.AlignHCenter
                }

            }

        }

        KeyboardSpacer {
            id: keyboardSpacer
        }

    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('main', function() {
                loadFolders();
            });
        }
        onError: {
            isSaving = false;
            errorMessage = i18n.tr("An error occurred while saving");
            loadToast.showing = false;
            isLoadingFolders = false;
            foldersLoadToast.showing = false;
        }
    }

    LoadToast {
        id: loadToast

        message: i18n.tr("Saving login...")
        showing: false
    }

    LoadToast {
        id: foldersLoadToast

        message: i18n.tr("Loading folders...")
        showing: false
    }

    header: AppHeader {
        id: header

        pageTitle: isEditMode ? i18n.tr("Edit Login") : i18n.tr("Add Login")
        isRootPage: false
        showSettingsButton: false
    }

}
