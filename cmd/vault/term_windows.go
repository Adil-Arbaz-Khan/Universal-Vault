//go:build windows
// +build windows

package main

import (
	"os"
	"syscall"
	"unsafe"
)

var (
	kernel32           = syscall.NewLazyDLL("kernel32.dll")
	procGetConsoleMode = kernel32.NewProc("GetConsoleMode")
	procSetConsoleMode = kernel32.NewProc("SetConsoleMode")
)

func disableEcho() (func(), error) {
	handle := syscall.Handle(os.Stdin.Fd())
	var mode uint32
	r, _, err := procGetConsoleMode.Call(uintptr(handle), uintptr(unsafe.Pointer(&mode)))
	if r == 0 {
		return func() {}, err
	}
	const enableEchoInput = 0x0004
	procSetConsoleMode.Call(uintptr(handle), uintptr(mode&^enableEchoInput))
	return func() {
		procSetConsoleMode.Call(uintptr(handle), uintptr(mode))
	}, nil
}
