#!/bin/bash
# AltTab (com.lwouis.alt-tab-macos) — re-runs when this file changes

defaults write com.lwouis.alt-tab-macos appearanceSize -int 2
defaults write com.lwouis.alt-tab-macos appsToShow -int 0
defaults write com.lwouis.alt-tab-macos spacesToShow -int 1
defaults write com.lwouis.alt-tab-macos showWindowlessApps -int 1
defaults write com.lwouis.alt-tab-macos showHiddenWindows -int 1
defaults write com.lwouis.alt-tab-macos showMinimizedWindows -int 0
defaults write com.lwouis.alt-tab-macos previewFocusedWindow -bool true
defaults write com.lwouis.alt-tab-macos menubarIconShown -bool true
defaults write com.lwouis.alt-tab-macos updatePolicy -int 1

# Exceptions: hide Finder + Ghostty from switcher; ignore VM/remote-desktop apps
defaults write com.lwouis.alt-tab-macos exceptions -string '[{"ignore":"0","hide":"1","bundleIdentifier":"com.McAfee.McAfeeSafariHost"},{"ignore":"0","hide":"2","bundleIdentifier":"com.apple.finder"},{"ignore":"0","hide":"2","bundleIdentifier":"com.mitchellh.ghostty"},{"ignore":"2","hide":"0","bundleIdentifier":"com.microsoft.rdc.macos"},{"ignore":"2","hide":"0","bundleIdentifier":"com.teamviewer.TeamViewer"},{"ignore":"2","hide":"0","bundleIdentifier":"org.virtualbox.app.VirtualBoxVM"},{"ignore":"2","hide":"0","bundleIdentifier":"com.parallels."},{"ignore":"2","hide":"0","bundleIdentifier":"com.citrix.XenAppViewer"},{"ignore":"2","hide":"0","bundleIdentifier":"com.citrix.receiver.icaviewer.mac"},{"ignore":"2","hide":"0","bundleIdentifier":"com.nicesoftware.dcvviewer"},{"ignore":"2","hide":"0","bundleIdentifier":"com.vmware.fusion"},{"ignore":"2","hide":"0","bundleIdentifier":"com.apple.ScreenSharing"},{"ignore":"2","hide":"0","bundleIdentifier":"com.utmapp.UTM"}]'
