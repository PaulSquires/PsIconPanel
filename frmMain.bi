'    PsIconPanel - reusable owner-drawn icon panel control
'    Copyright (C) 2016-2026 Paul Squires, PlanetSquires Software
'
'    This program is free software: you can redistribute it and/or modify
'    it under the terms of the GNU General Public License as published by
'    the Free Software Foundation, either version 3 of the License, or
'    (at your option) any later version.
'
'    This program is distributed in the hope that it will be useful,
'    but WITHOUT any WARRANTY; without even the implied warranty of
'    MERCHANTABILITY or FITNESS for A PARTICULAR PURPOSE.  See the
'    GNU General Public License for more details.

#pragma once


#define IDC_FRMMAIN_ICONPANEL_LEFT     1000
#define IDC_FRMMAIN_ICONPANEL_CENTER   1001
#define IDC_FRMMAIN_ICONPANEL_RIGHT    1002

' Command ids handed to the click callback. Toggles report through SelChange instead, so
' they need no ids -- but they get them anyway, because a real host looks items up by id.
#define IDM_SAVE        100
#define IDM_REFRESH     101
#define IDM_DELETE      102
#define IDM_SETTINGS    103
#define IDM_FAVOURITE   200
#define IDM_READONLY    201
#define IDM_FIND        202

declare function frmMain_Show( byval hWndParent as HWND ) as LRESULT
