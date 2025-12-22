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
    id: passwordCardPage

    property string cardId: ""
    property string name: ""
    property string cardholderName: ""
    property string brand: ""
    property string number: ""
    property string expiryMonth: ""
    property string expiryYear: ""
    property string code: ""
    property string notes: ""
    property string created: ""
    property string updated: ""
    property bool numberVisible: false
    property bool codeVisible: false
    property bool favorite: false
    property bool isTrashed: false
    property string folderId: ""
    property string folderName: ""

    signal backRequested()

    function copyToClipboard(text, itemName) {
        Clipboard.push(text);
        toast.show(i18n.tr("%1 copied to clipboard").arg(itemName));
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
                title: i18n.tr("Card Details")

                DetailField {
                    title: i18n.tr("Cardholder Name")
                    subtitle: cardholderName
                    showDivider: true
                    onCopyClicked: copyToClipboard(cardholderName, i18n.tr("Cardholder Name"))
                }

                DetailField {
                    title: i18n.tr("Brand")
                    subtitle: brand
                    showDivider: true
                    onCopyClicked: copyToClipboard(brand, i18n.tr("Brand"))
                }

                DetailField {
                    title: i18n.tr("Card Number")
                    visibleContent: number
                    hiddenContent: "•••• •••• •••• ••••"
                    showVisibilityToggle: true
                    isContentVisible: passwordCardPage.numberVisible
                    showDivider: true
                    onVisibilityToggled: passwordCardPage.numberVisible = !passwordCardPage.numberVisible
                    onCopyClicked: copyToClipboard(number, i18n.tr("Card Number"))
                }

                DetailField {
                    title: i18n.tr("Expiry Date")
                    subtitle: expiryMonth ? expiryMonth + "/" + expiryYear : ""
                    showDivider: true
                    onCopyClicked: copyToClipboard(expiryMonth + "/" + expiryYear, i18n.tr("Expiry Date"))
                }

                DetailField {
                    title: i18n.tr("Security Code")
                    visibleContent: code
                    hiddenContent: "•••"
                    showVisibilityToggle: true
                    isContentVisible: passwordCardPage.codeVisible
                    onVisibilityToggled: passwordCardPage.codeVisible = !passwordCardPage.codeVisible
                    onCopyClicked: copyToClipboard(code, i18n.tr("Security Code"))
                }

            }

            ConfigurationGroup {
                title: i18n.tr("Misc")
                visible: notes !== "" || created !== "" || updated !== ""

                DetailField {
                    visible: notes !== ""
                    title: i18n.tr("Notes")
                    subtitle: notes
                    showDivider: created !== "" || updated !== ""
                    onCopyClicked: copyToClipboard(notes, i18n.tr("Notes"))
                }

                DetailField {
                    visible: created !== ""
                    title: i18n.tr("Created")
                    subtitle: created
                    showDivider: updated !== ""
                    onCopyClicked: copyToClipboard(created, i18n.tr("Created date"))
                }

                DetailField {
                    visible: updated !== ""
                    title: i18n.tr("Updated")
                    subtitle: updated
                    onCopyClicked: copyToClipboard(updated, i18n.tr("Updated date"))
                }

            }

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
            visible: !passwordCardPage.isTrashed
            iconName: "edit"
            text: i18n.tr("Edit")
            onClicked: {
                pageStack.push(Qt.resolvedUrl("UpsertCardPage.qml"), {
                    "isEditMode": true,
                    "cardId": cardId || "",
                    "cardName": name,
                    "cardCardholderName": cardholderName,
                    "cardBrand": brand,
                    "cardNumber": number,
                    "cardExpiryMonth": expiryMonth,
                    "cardExpiryYear": expiryYear,
                    "cardCode": code,
                    "cardNotes": notes,
                    "favorite": favorite,
                    "folderId": passwordCardPage.folderId || ""
                });
            }
        }

        IconButton {
            visible: !passwordCardPage.isTrashed
            iconName: "delete"
            text: i18n.tr("Trash")
            onClicked: {
                trashLoadToast.showing = true;
                python.call('main.trash_item', [SessionModel.getEncryptionKey(), passwordCardPage.cardId], function(result) {
                    trashLoadToast.showing = false;
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                });
            }
        }

        IconButton {
            visible: passwordCardPage.isTrashed
            iconName: "undo"
            text: i18n.tr("Restore")
            onClicked: {
                loadToast.showing = true;
                python.call('main.restore_item', [SessionModel.getEncryptionKey(), passwordCardPage.cardId], function(result) {
                    loadToast.showing = false;
                    pageStack.pop();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                });
            }
        }

        IconButton {
            visible: passwordCardPage.isTrashed
            iconName: "delete"
            text: i18n.tr("Delete")
            onClicked: {
                deleteLoadToast.showing = true;
                python.call('main.delete_item', [SessionModel.getEncryptionKey(), passwordCardPage.cardId], function(result) {
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
            });
        }
        onError: {
        }
    }

    Toast {
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
