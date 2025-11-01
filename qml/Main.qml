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
import Lomiri.Components 1.3
import QtQuick.Layouts 1.3
import Qt.labs.settings 1.0
import io.thp.pyotherside 1.4
import "ut_components"
import Qt.labs.platform 1.0 as Platform

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'sealed.brennoflavio'
    automaticOrientation: true

    width: units.gu(45)
    height: units.gu(75)

    function navigateToPasswordList() {
        var passwordListPage = pageStack.push(Qt.resolvedUrl("PasswordListPage.qml"));
        passwordListPage.backRequested.connect(function () {
                pageStack.pop();
            });
        passwordListPage.passwordSelected.connect(function (passwordId, passwordName) {
                var detailPage = pageStack.push(Qt.resolvedUrl("PasswordLoginPage.qml"));
                detailPage.passwordData = {
                    "name": passwordName,
                    "folder": "Development",
                    "username": "user@example.com",
                    "password": "••••••••••••",
                    "totp": "123456",
                    "notes": "Account details for " + passwordName,
                    "created": "2024-01-15 10:30:00",
                    "updated": "2025-01-10 14:25:00"
                };
                detailPage.backRequested.connect(function () {
                        pageStack.pop();
                    });
            });
    }

    PageStack {
        id: pageStack
        anchors.fill: parent

        Component.onCompleted: {
            var loginPage = push(Qt.resolvedUrl("LoginPage.qml"));
            loginPage.loginSuccessful.connect(root.navigateToPasswordList);
        }
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('main', function () {});
        }

        onError: {
        }
    }

    Component.onDestruction: {
        python.call('main.cleanup', [], function () {});
    }
}
