#+build windows
package main

import "core:strings"
import win32 "core:sys/windows"

LPITEMIDLIST :: rawptr

BROWSEINFOW :: struct {
	hwndOwner:      win32.HWND,
	pidlRoot:       LPITEMIDLIST,
	pszDisplayName: win32.LPWSTR,
	lpszTitle:      win32.LPCWSTR,
	ulFlags:        win32.UINT,
	lpfn:           rawptr,
	lParam:         win32.LPARAM,
	iImage:         win32.c_int,
}

BIF_RETURNONLYFSDIRS :: 0x0001
BIF_NEWDIALOGSTYLE :: 0x0040

foreign import shell32_ext "system:shell32.lib"

@(default_calling_convention = "system")
foreign shell32_ext {
	SHBrowseForFolderW :: proc(lpbi: ^BROWSEINFOW) -> LPITEMIDLIST ---
	SHGetPathFromIDListW :: proc(pidl: LPITEMIDLIST, pszPath: win32.LPWSTR) -> win32.BOOL ---
}

pick_folder :: proc(title: string) -> (path: string, ok: bool) {
	hr := win32.CoInitializeEx()
	defer if hr >= 0 {
		win32.CoUninitialize()
	}

	display_name: [win32.MAX_PATH]win32.WCHAR
	bi := BROWSEINFOW {
		pszDisplayName = &display_name[0],
		lpszTitle      = win32.utf8_to_wstring(title),
		ulFlags        = BIF_RETURNONLYFSDIRS | BIF_NEWDIALOGSTYLE,
	}

	pidl := SHBrowseForFolderW(&bi)
	if pidl == nil {
		return "", false
	}
	defer win32.CoTaskMemFree(pidl)

	path_buf: [win32.MAX_PATH]win32.WCHAR
	if !bool(SHGetPathFromIDListW(pidl, &path_buf[0])) {
		return "", false
	}

	raw, _ := win32.utf16_to_utf8(path_buf[:], context.allocator)
	defer delete(raw)

	return strings.clone(strings.trim_right_null(raw)), true
}

