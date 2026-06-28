
; ==============================================================================
; 采用 GPLv3 开源协议（Copyleft）
; Copyright (C) 2026 birdy178 /birdy1788
;
; This program is free software: you can redistribute it and/or modify
; it under the terms of the GNU General Public License as published by
; the Free Software Foundation, either version 3 of the License, or
; (at your option) any later version.
;
; This program is distributed in the hope that it will be useful,
; but WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
; GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public License
; along with this program.  If not, see <https://www.gnu.org/licenses/>.
; ==============================================================================

; 更新日期: 2026-06-28

; ==============================================================================

if !A_IsAdmin {
    try {
        Run('*RunAs "' A_AhkPath '" /Restart "' A_ScriptFullPath '"')
    }
    ExitApp()
}

; 启动强制关闭大写灯
SetCapsLockState "Off"

Global ConfigFile := A_ScriptDir "\GamesList.txt"
if !FileExist(ConfigFile) {
    FileAppend("", ConfigFile, "UTF-8")
}

Global ExcludeListCache := FileRead(ConfigFile, "UTF-8")
Global IsEnvReady := false 
Global IsWinDisabled := false 

; --- 1. 核心控制逻辑 ---

GetDefaultIMEWnd(hWnd) {
    if !WinExist(hWnd) {
        return 0
    }
    return DllCall("imm32\ImmGetDefaultIMEWnd", "Ptr", hWnd, "Ptr")
}

SetIMEMode(hWnd, mode) {
    DetectHiddenWindows True
    defaultIMEWnd := GetDefaultIMEWnd(hWnd)
    if (defaultIMEWnd) {
        SendMessage(0x283, 0x002, mode, , "ahk_id " defaultIMEWnd)
    }
}

GetCurrentLayout(hWnd) {
    if !hWnd || !WinExist(hWnd) {
        return 0
    }
    threadID := DllCall("GetWindowThreadProcessId", "Ptr", hWnd, "Ptr", 0, "UInt")
    if !threadID {
        return 0
    }
    return DllCall("GetKeyboardLayout", "UInt", threadID, "Ptr")
}

SwitchAndFix() {
    if (!IsEnvReady || IsInExcludeList()) {
        return
    }
    hwnd := WinActive("A")
    if (!hwnd || !WinExist(hwnd)) {
        return
    }
    
    ; 
    SendEvent "{Blind}{LWin Down}{Space}{LWin Up}"
    
    ; 切换后的状态补强
    Sleep 150
    currLayout := GetCurrentLayout(hwnd)
    if (currLayout != 0 && currLayout != 0x04090409) {
        SetIMEMode(hwnd, 1) 
    }
}

; --- 2. UI 逻辑 ---

ShowHelp() {
    HelpGui := Gui("+AlwaysOnTop", "英切 · 使用说明")
    HelpGui.SetFont("s11", "Microsoft YaHei UI")
    
    HelpGui.SetFont("Bold c0055AA")
    HelpGui.Add("Text", "w420", "【 主要功能 】")
    HelpGui.SetFont("Norm cBlack")
    HelpGui.Add("Text", "xp+10 y+5", "● 新建/切换窗口后，优先使用英文输入。")
    HelpGui.Add("Text", "xp+10 y+5", "避免搞不清楚自己的输入法状态而打错")
    HelpGui.Add("Text", "", "")  
    HelpGui.SetFont("Bold c666666")
    HelpGui.Add("Text", "x10 y+10", "【 次要功能 】")
    HelpGui.SetFont("Norm cBlack")
    HelpGui.Add("Text", "xp+10 y+5", "● CapsLock键 中英切换(看你的输入法)。`n● Ctrl+Alt+F7 屏蔽不需要此功能的程序,加入排除名单(游戏静默模式)。`n● 右键菜单提供Win键屏蔽，防止游戏时错按退到桌面。")
    
    btn := HelpGui.Add("Button", "Default w100 h35 x165 y+20", "确定")
    btn.OnEvent("Click", (*) => HelpGui.Destroy())
    HelpGui.Show()
}

UpdateCache() {
    Global ExcludeListCache
    try {
        ExcludeListCache := FileRead(ConfigFile, "UTF-8")
    }
}

MenuToggleWinKey(*) {
    Global IsWinDisabled
    IsWinDisabled := !IsWinDisabled
    A_TrayMenu.ToggleCheck("屏蔽 Win 键")
    if (IsWinDisabled) {
        ToolTip("Win 键已屏蔽")
    } else {
        ToolTip("Win 键已恢复")
    }
    SetTimer(() => ToolTip(), -2000)
}

; --- 3. 托盘菜单构建 (从下到上排序) ---

A_TrayMenu.Delete()
; 醒目标题
A_TrayMenu.Add("◢  ⚡ 英切 By birdy178  ◣", (*) => 0)
A_TrayMenu.Disable("◢  ⚡ 英切 By birdy178  ◣")
A_TrayMenu.Add() 
A_TrayMenu.Add("用法", (*) => ShowHelp())
A_TrayMenu.Add("屏蔽 Win 键", MenuToggleWinKey)
A_TrayMenu.Add("编辑排除名单", (*) => Run("notepad.exe " ConfigFile))
A_TrayMenu.Add("重启 (Ctrl+Alt+F9)", (*) => Reload())
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Add("暂停", (*) => (Pause(-1), A_TrayMenu.ToggleCheck("暂停")))

A_TrayMenu.Default := "◢  ⚡ 英切 By birdy178  ◣"

; --- 4. 环境自检 ---

CheckEnvironment() {
    Global IsEnvReady
    size := DllCall("GetKeyboardLayoutList", "Int", 0, "Ptr", 0)
    list := Buffer(size * A_PtrSize)
    DllCall("GetKeyboardLayoutList", "Int", size, "Ptr", list)
    hasEng := false
    loop size {
        layout := NumGet(list, (A_Index - 1) * A_PtrSize, "Ptr")
        if ((layout & 0xFFFF) = 0x0409) {
            hasEng := true
        }
    }
    
    if (!hasEng) {
        IsEnvReady := false
        MsgResult := MsgBox("未唤醒美国键盘。`n`n是否尝试一键唤醒？", "环境部署", "YesNo Iconi")
        if (MsgResult = "Yes") {
            RegWrite("00000409", "REG_SZ", "HKEY_CURRENT_USER\Keyboard Layout\Preload", "2")
            DllCall("LoadKeyboardLayout", "Str", "00000409", "UInt", 1)
            DllCall("user32\SystemParametersInfo", "UInt", 0x005A, "UInt", 0, "Ptr", 0, "UInt", 2)
            Reload()
        }
    } else {
        IsEnvReady := true
        ToolTip("英切 已就绪")
        SetTimer(() => ToolTip(), -2000)
    }
}

CheckEnvironment()

IsInExcludeList() {
    try {
        pName := WinGetProcessName("A")
        if (pName != "" && InStr(ExcludeListCache, pName)) {
            return true
        }
    } catch {
        return false
    }
    return false
}

; --- 5. 扫描逻辑 ---

#HotIf IsWinDisabled && !IsInExcludeList()
LWin::return 
RWin::return 
#HotIf

if (IsEnvReady) {
    SetTimer(MainLogic, 500)
}

MainLogic() {
    static last_hwnd := 0
    curr_hwnd := 0
    try {
        curr_hwnd := WinActive("A")
    } catch {
        return
    }

    if (!curr_hwnd || !WinExist(curr_hwnd)) {
        return
    }

    if (IsInExcludeList()) {
        SetCapsLockState "Default"
        return
    }
    
    if (!GetKeyState("CapsLock", "T")) {
        SetCapsLockState "AlwaysOff"
    }

    if (curr_hwnd != last_hwnd) {
        try {
            ; 切换窗口强制固定英文
            PostMessage(0x0050, 0, 0x04090409, , "ahk_id " curr_hwnd)
        }
        last_hwnd := curr_hwnd
    }
}

; --- 6. 热键定义 ---

#HotIf IsEnvReady && !IsInExcludeList()
$CapsLock::SwitchAndFix()
#HotIf

^!F7:: {
    try {
        pName := WinGetProcessName("A")
        if (!InStr(ExcludeListCache, pName)) {
            FileAppend(pName "`n", ConfigFile, "UTF-8")
            ToolTip("已加入静默名单")
        } else {
            newContent := StrReplace(ExcludeListCache, pName "`n", "")
            FileDelete(ConfigFile)
            FileAppend(newContent, ConfigFile, "UTF-8")
            ToolTip("已恢复功能状态")
        }
        UpdateCache()
        SetTimer(() => ToolTip(), -2000)
    }
}

; 重启快捷键 Ctrl+Alt+F9
^!F9::Reload()