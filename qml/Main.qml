import Lomiri.Components 1.3
import Qt.labs.platform 1.0 as Platform
import Qt.labs.settings 1.0
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

MainView {
    id: root

    objectName: 'mainView'
    applicationName: 'sealed.brennoflavio'
    automaticOrientation: true
    width: units.gu(45)
    height: units.gu(75)

    PageStack {
        id: pageStack

        anchors.fill: parent
        Component.onCompleted: {
            push(Qt.resolvedUrl("LoginPage.qml"));
        }
    }

    Python {
        id: python

        Component.onCompleted: {
            addImportPath(Qt.resolvedUrl('../src/'));
            importModule('main', function() {
                python.call('main.clear_loading_state', [], function() {
                });
                python.call('main.start_event_loop', [], function() {
                });
            });
        }
        onError: {
        }
    }

}
