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
import "ut_components"

Page {
    id: upsertCardPage

    property bool isEditMode: false
    property string cardId: ""
    property string cardName: ""
    property string cardCardholderName: ""
    property string cardBrand: ""
    property string cardNumber: ""
    property string cardExpiryMonth: ""
    property string cardExpiryYear: ""
    property string cardCode: ""
    property string cardNotes: ""
    property bool favorite: false
    property string folderId: ""
    property string errorMessage: ""
    property bool isSaving: false
    property bool isLoadingFolders: false
    property var foldersData: []
    property string selectedFolderId: ""

    function saveCard() {
        if (nameField.text.trim() === "") {
            errorMessage = i18n.tr("Name is required");
            return ;
        }
        errorMessage = "";
        isSaving = true;
        loadToast.showing = true;
        var name = nameField.text.trim();
        var cardholderName = cardholderNameField.text.trim();
        var brand = brandField.text.trim();
        var number = numberField.text;
        var expMonth = expiryMonthField.text.trim();
        var expYear = expiryYearField.text.trim();
        var code = codeField.text;
        var isFavorite = favoriteToggle.checked;
        var folderId = selectedFolderId || "";
        if (isEditMode) {
            python.call('main.edit_card', [cardId, name, cardholderName, brand, number, expMonth, expYear, code, isFavorite, folderId], function(result) {
                isSaving = false;
                loadToast.showing = false;
                if (result.success) {
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                } else {
                    errorMessage = result.message || i18n.tr("Failed to update card");
                }
            });
        } else {
            python.call('main.add_card', [name, cardholderName, brand, number, expMonth, expYear, code, isFavorite, folderId], function(result) {
                isSaving = false;
                loadToast.showing = false;
                if (result.success) {
                    pageStack.clear();
                    pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
                } else {
                    errorMessage = result.message || i18n.tr("Failed to add card");
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
        contentHeight: cardForm.height + keyboardSpacer.height + units.gu(4)
        clip: true

        anchors {
            top: header.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }

        Form {
            id: cardForm

            buttonText: i18n.tr("Save")
            buttonIconName: "save"
            onSubmitted: {
                saveCard();
            }

            anchors {
                top: parent.top
                left: parent.left
                right: parent.right
            }

            InputField {
                id: nameField

                width: parent.width
                title: i18n.tr("Name")
                placeholder: isEditMode ? "" : i18n.tr("e.g., Personal Visa")
                text: cardName
                required: true
            }

            InputField {
                id: cardholderNameField

                width: parent.width
                title: i18n.tr("Cardholder Name")
                placeholder: isEditMode ? "" : i18n.tr("e.g., John Doe")
                text: cardCardholderName
            }

            InputField {
                id: brandField

                width: parent.width
                title: i18n.tr("Brand")
                placeholder: isEditMode ? "" : i18n.tr("e.g., Visa, Mastercard, Amex")
                text: cardBrand
            }

            InputField {
                id: numberField

                width: parent.width
                title: i18n.tr("Card Number")
                placeholder: isEditMode ? "" : i18n.tr("e.g., 4111 1111 1111 1111")
                text: cardNumber
                validationRegex: "^[0-9\\s]*$"
                errorMessage: i18n.tr("Only numbers and spaces are allowed")
            }

            Item {
                width: parent.width
                height: expiryRow.height

                Row {
                    id: expiryRow

                    width: parent.width - units.gu(4)
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: units.gu(2)

                    InputField {
                        id: expiryMonthField

                        width: (parent.width - parent.spacing) / 2
                        title: i18n.tr("Expiry Month")
                        placeholder: isEditMode ? "" : i18n.tr("MM")
                        text: cardExpiryMonth
                        validationRegex: "^(0[1-9]|1[0-2]|[1-9])?$"
                        errorMessage: i18n.tr("Enter a valid month (1-12)")
                    }

                    InputField {
                        id: expiryYearField

                        width: (parent.width - parent.spacing) / 2
                        title: i18n.tr("Expiry Year")
                        placeholder: isEditMode ? "" : i18n.tr("YYYY")
                        text: cardExpiryYear
                        validationRegex: "^[0-9]{0,4}$"
                        errorMessage: i18n.tr("Enter a 4-digit year")
                    }

                }

            }

            InputField {
                id: codeField

                width: parent.width
                title: i18n.tr("Security Code")
                placeholder: isEditMode ? "" : i18n.tr("e.g., 123")
                text: cardCode
                validationRegex: "^[0-9]{0,4}$"
                errorMessage: i18n.tr("Enter a 3 or 4 digit security code")
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
                        text: cardNotes
                    }

                }

            }

            ToggleOption {
                id: favoriteToggle

                width: parent.width
                title: i18n.tr("Favorite")
                subtitle: i18n.tr("Mark this card as a favorite")
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

        message: isEditMode ? i18n.tr("Updating card...") : i18n.tr("Saving card...")
        showing: false
    }

    LoadToast {
        id: foldersLoadToast

        message: i18n.tr("Loading folders...")
        showing: false
    }

    header: AppHeader {
        id: header

        pageTitle: isEditMode ? i18n.tr("Edit Card") : i18n.tr("Add Card")
        isRootPage: false
        showSettingsButton: false
    }

}
