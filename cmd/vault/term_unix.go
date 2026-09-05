//go:build !windows
// +build !windows

package main

import (
	"os"
	"os/exec"
)

func disableEcho() (func(), error) {
	cmd := exec.Command("stty", "-echo")
	cmd.Stdin = os.Stdin
	if err := cmd.Run(); err != nil {
		return func() {}, err
	}
	return func() {
		cmdFix := exec.Command("stty", "echo")
		cmdFix.Stdin = os.Stdin
		cmdFix.Run()
	}, nil
}
