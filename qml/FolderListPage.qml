import "." 1.0
import Lomiri.Components 1.3
import Lomiri.Components.Popups 1.3
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
import io.thp.pyotherside 1.4
import "lib"
import "ut_components"

Page {
    id: folderListPage

    property var folders: []
    property bool hasLoaded: false

    function loadFolders() {
        python.call('main.list_folders', [SessionModel.getEncryptionKey()], function(result) {
            if (result.success) {
                folders = result.folders;
                hasLoaded = true;
            } else {
                toast.show(i18n.tr("Failed to load folders"));
            }
        });
    }

    Component.onCompleted: {
        loadFolders();
    }

    ActionableList {
        id: folderList

        items: folders.map(function(folder) {
            return {
                "id": folder.id,
                "title": folder.name,
                "subtitle": "",
                "icon": "folder-symbolic"
            };
        })
        showSearchBar: true
        searchPlaceholder: i18n.tr("Search folders...")
        searchFields: ["title"]
        emptyMessage: hasLoaded ? i18n.tr("No folders found") : i18n.tr("Loading folders...")
        itemActions: [{
            "id": "edit-folder",
            "iconName": "edit"
        }, {
            "id": "delete-folder",
            "iconName": "delete"
        }, {
            "id": "view-folder",
            "iconName": "next"
        }]
        onActionTriggered: {
            if (actionId === "view-folder")
                pageStack.push(Qt.resolvedUrl("FolderPasswordListPage.qml"), {
                "folderId": item.id,
                "folderName": item.title
            });
            else if (actionId === "edit-folder")
                PopupUtils.open(editFolderDialog, null, {
                "folderId": item.id,
                "folderName": item.title
            });
            else if (actionId === "delete-folder")
                PopupUtils.open(deleteFolderDialog, null, {
                "folderId": item.id,
                "folderName": item.title
            });
        }

        anchors {
            top: loadingBar.bottom
            topMargin: units.gu(2)
            left: parent.left
            right: parent.right
            bottom: bottomBar.top
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
            iconName: "reload"
            text: i18n.tr("Refresh")
            onClicked: {
                toast.show(i18n.tr("Refreshing folders..."));
                python.call('main.refresh_folders', [SessionModel.getEncryptionKey()], function() {
                });
            }
        }

        IconButton {
            iconName: "add"
            text: i18n.tr("Add")
            onClicked: {
                PopupUtils.open(addFolderDialog);
            }
        }

    }

    Component {
        id: addFolderDialog

        Dialog {
            id: dialogue

            property string errorText: ""
            property bool isLoading: false

            title: i18n.tr("Add New Folder")

            TextField {
                id: folderNameField

                placeholderText: i18n.tr("Folder name")
                width: parent.width
                enabled: !dialogue.isLoading
            }

            Label {
                visible: dialogue.errorText !== ""
                text: dialogue.errorText
                color: theme.palette.normal.negative
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                visible: dialogue.isLoading
                spacing: units.gu(2)
                anchors.horizontalCenter: parent.horizontalCenter

                ActivityIndicator {
                    running: dialogue.isLoading
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: i18n.tr("Loading...")
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            Button {
                width: parent.width
                text: i18n.tr("Save")
                color: theme.palette.normal.positive
                enabled: folderNameField.text.trim() !== "" && !dialogue.isLoading
                onClicked: {
                    dialogue.errorText = "";
                    dialogue.isLoading = true;
                    python.call('main.add_folder', [SessionModel.getEncryptionKey(), folderNameField.text.trim()], function(result) {
                        dialogue.isLoading = false;
                        if (result.success) {
                            PopupUtils.close(dialogue);
                            toast.show(i18n.tr("Folder created successfully"));
                            loadFolders();
                        } else {
                            dialogue.errorText = result.message || i18n.tr("Failed to create folder");
                        }
                    });
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Cancel")
                enabled: !dialogue.isLoading
                onClicked: {
                    PopupUtils.close(dialogue);
                }
            }

        }

    }

    Component {
        id: editFolderDialog

        Dialog {
            id: editDialogue

            property string folderId: ""
            property string folderName: ""
            property string errorText: ""
            property bool isLoading: false

            title: i18n.tr("Edit Folder")

            TextField {
                id: editFolderNameField

                placeholderText: i18n.tr("Folder name")
                text: editDialogue.folderName
                width: parent.width
                enabled: !editDialogue.isLoading
            }

            Label {
                visible: editDialogue.errorText !== ""
                text: editDialogue.errorText
                color: theme.palette.normal.negative
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                visible: editDialogue.isLoading
                spacing: units.gu(2)
                anchors.horizontalCenter: parent.horizontalCenter

                ActivityIndicator {
                    running: editDialogue.isLoading
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: i18n.tr("Loading...")
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            Button {
                width: parent.width
                text: i18n.tr("Save")
                color: theme.palette.normal.positive
                enabled: editFolderNameField.text.trim() !== "" && !editDialogue.isLoading
                onClicked: {
                    editDialogue.errorText = "";
                    editDialogue.isLoading = true;
                    python.call('main.edit_folder', [SessionModel.getEncryptionKey(), editDialogue.folderId, editFolderNameField.text.trim()], function(result) {
                        editDialogue.isLoading = false;
                        if (result.success) {
                            PopupUtils.close(editDialogue);
                            toast.show(i18n.tr("Folder updated successfully"));
                            loadFolders();
                        } else {
                            editDialogue.errorText = result.message || i18n.tr("Failed to update folder");
                        }
                    });
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Cancel")
                enabled: !editDialogue.isLoading
                onClicked: {
                    PopupUtils.close(editDialogue);
                }
            }

        }

    }

    Component {
        id: deleteFolderDialog

        Dialog {
            id: deleteDialogue

            property string folderId: ""
            property string folderName: ""
            property string errorText: ""
            property bool isLoading: false

            title: i18n.tr("Delete Folder")

            Label {
                width: parent.width
                wrapMode: Text.WordWrap
                text: i18n.tr("Are you sure you want to delete \"%1\"?").arg(deleteDialogue.folderName)
            }

            Label {
                visible: deleteDialogue.errorText !== ""
                text: deleteDialogue.errorText
                color: theme.palette.normal.negative
                width: parent.width
                wrapMode: Text.WordWrap
            }

            Row {
                visible: deleteDialogue.isLoading
                spacing: units.gu(2)
                anchors.horizontalCenter: parent.horizontalCenter

                ActivityIndicator {
                    running: deleteDialogue.isLoading
                    anchors.verticalCenter: parent.verticalCenter
                }

                Label {
                    text: i18n.tr("Loading...")
                    anchors.verticalCenter: parent.verticalCenter
                }

            }

            Button {
                width: parent.width
                text: i18n.tr("Delete")
                color: theme.palette.normal.negative
                enabled: !deleteDialogue.isLoading
                onClicked: {
                    deleteDialogue.errorText = "";
                    deleteDialogue.isLoading = true;
                    python.call('main.delete_folder', [SessionModel.getEncryptionKey(), deleteDialogue.folderId], function(result) {
                        deleteDialogue.isLoading = false;
                        if (result.success) {
                            PopupUtils.close(deleteDialogue);
                            toast.show(i18n.tr("Folder deleted successfully"));
                            loadFolders();
                        } else {
                            deleteDialogue.errorText = result.message || i18n.tr("Failed to delete folder");
                        }
                    });
                }
            }

            Button {
                width: parent.width
                text: i18n.tr("Cancel")
                enabled: !deleteDialogue.isLoading
                onClicked: {
                    PopupUtils.close(deleteDialogue);
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
            setHandler('sync-folders', function(result) {
                if (result.success) {
                    folders = result.folders;
                    hasLoaded = true;
                    toast.show(i18n.tr("Folders synced"));
                } else {
                    toast.show(i18n.tr("Failed to load folders"));
                }
            });
        }
        onError: {
            toast.show(i18n.tr("An error occurred"));
        }
    }

    Toast {
        id: toast
    }

    LoadingBar {
        id: loadingBar

        anchors.top: folderHeader.bottom
        anchors.left: parent.left
        anchors.right: parent.right
    }

    header: AppHeader {
        id: folderHeader

        pageTitle: i18n.tr('Folders')
        isRootPage: false
        appIconName: "folder-symbolic"
        showSettingsButton: false
    }

}
